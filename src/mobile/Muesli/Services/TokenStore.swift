//
//  TokenStore.swift
//  Muesli
//
//  Holds the access + refresh tokens for backend API calls. v1 stores
//  in UserDefaults; a future revision should move to the Keychain.
//
//  The Google sign-in UI flow that mints these tokens via /v1/auth/google
//  is a separate piece of work; this store gives live adapters a place to
//  read from, and `MUESLI_DEV_ACCESS_TOKEN` env var lets developers stamp
//  a token in at launch for testing.
//

import Foundation

actor TokenStore {
    static let shared = TokenStore()

    private static let accessKey = "muesli.auth.accessToken"
    private static let refreshKey = "muesli.auth.refreshToken"

    private init() {
        // Dev convenience: a token from the environment overrides storage so
        // a developer can paste a token in their scheme env vars and use the
        // app against an AUTH_ENABLED backend without wiring sign-in.
        if let envToken = ProcessInfo.processInfo.environment["MUESLI_DEV_ACCESS_TOKEN"],
           !envToken.isEmpty {
            UserDefaults.standard.set(envToken, forKey: Self.accessKey)
        }
    }

    var accessToken: String? {
        UserDefaults.standard.string(forKey: Self.accessKey)
    }

    var refreshToken: String? {
        UserDefaults.standard.string(forKey: Self.refreshKey)
    }

    func setTokens(access: String, refresh: String) {
        UserDefaults.standard.set(access, forKey: Self.accessKey)
        UserDefaults.standard.set(refresh, forKey: Self.refreshKey)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: Self.accessKey)
        UserDefaults.standard.removeObject(forKey: Self.refreshKey)
    }
}
