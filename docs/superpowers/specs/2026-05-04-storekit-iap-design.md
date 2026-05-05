# StoreKit IAP for Credit Packs — Design

Date: 2026-05-04
Status: Draft (pending user review)

## Summary

Consumable in-app purchases for credit packs using StoreKit 2. Server-side receipt validation via the App Store Server API. On successful purchase, the credit ledger is topped up via the same idempotent debit/credit path used elsewhere.

## Goals

1. Three credit packs at clean price points.
2. Bulletproof idempotency: an Apple `transactionId` is credited at most once, ever.
3. Server-authoritative grants — never trust the client to tell us a purchase succeeded.
4. Handle the StoreKit edge cases that bite everyone: refunds, family sharing, transaction restoration on new device, deferred parental approvals.

## Non-goals

- Subscriptions (consumables only)
- Promotional offers / introductory pricing
- Volume discount tiers beyond the three packs
- Promo codes (Apple's promo codes work natively with StoreKit; no custom codes)
- Cross-platform purchase parity (iOS only)

## Pack design

Three consumable products. Names and ids final at first ship; price points are the design intent.

| Product Id | Display name | Credits | Micros | Price (USD) | Effective $/credit |
|---|---|---|---|---|---|
| `com.hydraflow.muesli.credits.20` | 20 credits | 20 | 4,000,000 | $4.99 | $0.250 |
| `com.hydraflow.muesli.credits.100` | 100 credits | 100 | 20,000,000 | $19.99 | $0.200 |
| `com.hydraflow.muesli.credits.500` | 500 credits | 500 | 100,000,000 | $79.99 | $0.160 |

Price points map cleanly to App Store tiers (Tier 5, Tier 20, Tier 80). Per-credit cost decreases with bulk to encourage larger packs and offset Apple's 30%/15% take.

Apple takes 30% of the first year of revenue from a developer; for net economics on a 20-credit pack at $4.99 → ~$3.49 net → ~$0.175/credit net revenue, vs ~$0.20 cost-of-goods at the rule-of-thumb rate. Margins are thin on the smallest pack — accept it as a customer acquisition price; the 100/500 packs make the unit economics work.

## Architecture

### Purchase flow (StoreKit 2, iOS 15+)

```
iOS                                              Backend                     Apple
 │                                                                            │
 │── Product.products(for: ids) ──────────────────────────────────────────────│
 │◀─ [Product] (with localized prices) ───────────────────────────────────────│
 │                                                                            │
 │── product.purchase() ──────────────────────────────────────────────────────│
 │◀─ Transaction (signed JWS) ────────────────────────────────────────────────│
 │                                                                            │
 │── POST /v1/iap/redeem { transactionJws } ──▶ Backend
 │                                       │
 │                                       ├─ verify JWS signature against Apple root cert
 │                                       ├─ decode transaction payload
 │                                       ├─ check bundleId matches
 │                                       ├─ check productId in known set
 │                                       ├─ check transactionId not already redeemed
 │                                       ├─ within tx:
 │                                       │     INSERT ledger_entries (idempotency_key='iap:<transactionId>')
 │                                       │     UPDATE credit_balances (+pack micros)
 │                                       ├─ call StoreKit Server API to mark consumed
 │◀────────── { newBalance } ────────────│
 │                                                                            │
 │── transaction.finish() (only after backend 200) ───────────────────────────│
```

Critically: **`transaction.finish()` is called only after the backend confirms the credit has been recorded.** If the backend call fails, the transaction stays unfinished. StoreKit will redeliver it on the next app launch via `Transaction.unfinished`. The backend's idempotency-by-`transactionId` ensures redelivery doesn't double-credit.

### JWS verification

Apple sends a `JWSTransaction` — a signed JWS that includes the full transaction payload. We verify:

1. Signature chain against Apple's root certificate (`AppleRootCA-G3.cer`, bundled in the API repo)
2. `bundleId` matches `APPLE_BUNDLE_ID`
3. `productId` is one of our known credit packs
4. `transactionId` not already in `ledger_entries` (idempotency key `iap:{transactionId}`)
5. `purchaseDate` is recent (sanity check; reject anything > 30 days old as suspicious)
6. `revocationDate` is null (refunded transactions get rejected)

Library: **`app-store-server-library`** (Apple's official Node SDK) handles JWS verification, App Store Server API calls, and notification parsing. Don't roll our own.

### Backend route

```
POST /v1/iap/redeem
  Auth: required
  Body: { transactionJws: string }
  Responses:
    200 { creditsAdded: Int, newBalance: Int }
    400 { error: 'invalid_transaction' | 'unknown_product' | 'foreign_bundle' }
    401 { error: 'unauthenticated' }
    409 { error: 'already_redeemed' }   // idempotent: returns the original credit silently as 200 in practice
    422 { error: 'transaction_revoked' }
```

Implementation pseudocode:

```js
router.post('/iap/redeem', requireAuth, async (req, res) => {
  const { transactionJws } = req.body;
  const tx = await verifyAndDecode(transactionJws);   // throws on invalid JWS
  const pack = PACK_BY_PRODUCT_ID[tx.productId];
  if (!pack) return res.status(400).json({ error: 'unknown_product' });
  if (tx.bundleId !== config.apple.bundleId) return res.status(400).json({ error: 'foreign_bundle' });
  if (tx.revocationDate) return res.status(422).json({ error: 'transaction_revoked' });

  const idempotencyKey = `iap:${tx.transactionId}`;
  const result = await ledger.recordTopup({
    userId: req.userId,
    micros: pack.micros,
    idempotencyKey,
    metadata: { transactionId: tx.transactionId, productId: tx.productId, originalTransactionId: tx.originalTransactionId, purchaseDate: tx.purchaseDate }
  });

  // Notify Apple's StoreKit Server we've consumed this transaction
  await appStoreServer.sendConsumptionInfo(tx.transactionId, {
    customerConsented: true,
    consumptionStatus: 'fully_consumed',
    platform: 'apple',
    sampleContentProvided: false,
    deliveryStatus: 'delivered_and_working',
    appAccountToken: req.userId,    // for fraud signals
    accountTenure: accountTenureDays(req.userId),
    playTime: 'undeclared',
    lifetimeDollarsRefunded: 'undeclared',
    lifetimeDollarsPurchased: 'undeclared',
    userStatus: 'active',
    refundPreference: 'undeclared'
  });

  return res.json({ creditsAdded: pack.credits, newBalance: result.newBalanceCredits });
});
```

Sending consumption info improves Apple's fraud signal and refund decisions. Required for consumables.

### App Store Server Notifications V2

Apple sends server-to-server notifications for events we care about:

- `REFUND` / `REVOKE` — Apple refunded the user. We must reverse the credit.
- `CONSUMPTION_REQUEST` — Apple asks for consumption details (we already send these proactively, but the webhook is a backup).

Endpoint: `POST /v1/iap/apple-webhook`. No auth (Apple-to-server); JWS verification is the auth.

Refund handling:

```js
async function handleRefund(notification) {
  const tx = notification.signedTransactionInfo;
  const idempotencyKey = `iap_refund:${tx.transactionId}`;
  await ledger.recordEntry({
    userId: lookupUserByOriginalTransactionId(tx.originalTransactionId),
    micros: -PACK_BY_PRODUCT_ID[tx.productId].micros,    // reverse the credit
    reason: 'refund',
    idempotencyKey,
    metadata: { originalTransactionId: tx.originalTransactionId, refundedAt: tx.revocationDate }
  });
}
```

This may push the user's balance negative if they've already spent the credits. That's correct — Apple has already refunded the money; the user no longer has a claim on the credits. With `CREDITS_ENFORCED=true`, the user just can't run new ops until they top up again. Don't try to claw back already-rendered AI output.

### Family sharing

Consumables are **not shareable** via Family Sharing (Apple enforces this). No special handling needed.

### Restoration on new device

StoreKit 2's `Transaction.currentEntitlements` returns active subscriptions — irrelevant for consumables. For consumables, **there is no restoration path**: a consumable is one-shot. If the user buys 100 credits on phone A, those credits live in our backend tied to their Apple ID-derived user account. Signing in on phone B with the same Apple ID lands them in the same backend account → balance follows. No StoreKit restore button needed. Document this in the UI: "Credits are tied to your account, not your device."

The `Transaction.unfinished` stream still matters: any purchase the client started but didn't finish gets redelivered. Process those on app launch:

```swift
@MainActor
func processUnfinishedTransactions() async {
  for await result in Transaction.unfinished {
    if case .verified(let tx) = result {
      do {
        try await api.redeemTransaction(tx.jwsRepresentation)
        await tx.finish()
      } catch {
        // retry next launch; backend is idempotent
      }
    }
  }
}
```

### Deferred / Ask to Buy

When a parent must approve a child's purchase, StoreKit returns `.pending`. The transaction lands later via the `Transaction.updates` stream. Same flow: `redeem → finish` once it arrives.

### Sandbox testing

- Sandbox tester accounts in App Store Connect for QA.
- StoreKit configuration file (`Muesli.storekit`) for Xcode-local testing without hitting Apple servers.
- Backend has a `APPLE_ENV=sandbox|production` flag that selects the correct App Store Server API host and root cert.

### iOS integration

```swift
@MainActor
final class IAPStore: ObservableObject {
  @Published private(set) var products: [Product] = []
  @Published private(set) var purchaseInProgress = false

  private let productIds = [
    "com.hydraflow.muesli.credits.20",
    "com.hydraflow.muesli.credits.100",
    "com.hydraflow.muesli.credits.500"
  ]

  func loadProducts() async throws {
    products = try await Product.products(for: productIds)
      .sorted { $0.price < $1.price }
  }

  func purchase(_ product: Product) async throws {
    purchaseInProgress = true
    defer { purchaseInProgress = false }

    let result = try await product.purchase()
    switch result {
    case .success(.verified(let tx)):
      try await api.redeemTransaction(tx.jwsRepresentation)
      await tx.finish()
    case .success(.unverified(_, let error)):
      throw error
    case .pending:
      // Ask to Buy; redelivery handled on next launch
      break
    case .userCancelled:
      break
    @unknown default:
      break
    }
  }
}
```

Single-screen `BuyCreditsView` lists the three packs, current balance at the top, "Why credits?" link to a help page.

### Environment variables

```
APPLE_BUNDLE_ID=com.hydraflow.muesli
APPLE_ENV=sandbox                    # or 'production'
APPLE_ISSUER_ID=...                  # from App Store Connect for App Store Server API
APPLE_KEY_ID=...
APPLE_PRIVATE_KEY_PATH=/path/to/SubscriptionKey.p8
```

## Failure modes

| Failure | Behavior |
|---|---|
| Apple JWS verification fails | 400 to client; client surfaces "Could not verify purchase, contact support". Transaction stays unfinished and retries on next launch. |
| Backend ledger insert fails | 500 to client; transaction stays unfinished; redelivery on next launch credits idempotently. |
| Refund webhook fails to deliver | Apple retries the webhook. Idempotency key prevents double-reversal. |
| Network drops mid-purchase after Apple charged | Transaction is unfinished on client; next launch redelivers; backend idempotency makes it safe. |
| Foreign bundle id (someone replays a JWS from another app) | 400 `foreign_bundle`; logged as fraud signal. |
| Product id we don't recognize (rolled out a pack we forgot to deploy) | 400 `unknown_product`; alert; transaction stays unfinished pending fix. |
| User signs out and signs in as different Apple ID, has unfinished tx | The unfinished tx is tied to the *current* Apple account on the device. We credit whichever user account the JWS was generated for, identified via `appAccountToken`. Set `appAccountToken` to the user's UUID at purchase time. |

### Linking purchases to users via `appAccountToken`

When initiating purchase:

```swift
let options: Set<Product.PurchaseOption> = [.appAccountToken(currentUser.id)]
let result = try await product.purchase(options: options)
```

The `appAccountToken` (UUID) is bundled into the signed transaction. Backend reads it and credits *that* user, not whoever happens to be signed in at redeem time. Solves the multi-Apple-ID-per-device case and gives us a fraud signal Apple uses too.

## Migration / sequencing

1. Create products in App Store Connect (sandbox first).
2. Add `Muesli.storekit` for local testing.
3. Implement backend `/v1/iap/redeem` and `/v1/iap/apple-webhook` using `app-store-server-library`.
4. Implement iOS `IAPStore` and `BuyCreditsView`.
5. Wire the unfinished-transactions processor into app launch.
6. End-to-end test in sandbox: purchase, refund (via TestFlight refund tool), Ask-to-Buy, network failure mid-purchase.
7. Submit pack products with first App Store build.
8. After verifying in production, flip `CREDITS_ENFORCED=true` server-side.

## Acceptance criteria

- Buy a 100-credit pack in sandbox → balance increases by 100 → ledger entry exists with `idempotency_key='iap:<transactionId>'`.
- Force-quit during purchase, relaunch → transaction redelivered, balance still increases by exactly 100.
- Trigger a TestFlight refund → webhook fires → ledger has reversal entry → balance decreases by 100 (may go negative).
- Sign in on a second device with same Apple ID → balance shown is the same.
- Replay a JWS from a different bundle id → 400, no credit.
- Two-pack purchase in same session → two distinct ledger entries, both credited.
- `npm test` covers: JWS verification (valid, expired, wrong bundle, unknown product, revoked), idempotent redeem, refund webhook, consumption info send-on-redeem.

## Open questions

- (resolved) Three packs at $4.99 / $19.99 / $79.99
- (resolved) `appAccountToken` set to user UUID for cross-device linking
- (resolved) Refunds push balance negative without clawback
- Pricing tier review in 6 months once we see real usage; the per-credit cost may need adjustment if Sonnet pricing shifts
- Whether to add a 1000- or 5000-credit "power user" pack later — defer until usage justifies it
