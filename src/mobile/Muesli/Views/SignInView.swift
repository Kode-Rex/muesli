//
//  SignInView.swift
//  Muesli
//
//  Dev sign-in screen: enter an email, hit Sign in, the backend mints a
//  token and the rest of the app picks it up via TokenStore. Wired into
//  the app at launch when no access token exists yet.
//

import SwiftUI

struct SignInView: View {
    @State private var email: String = ""
    @State private var fullName: String = ""
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    /// Called after a successful sign-in so the host can dismiss / refresh.
    var onSignedIn: () -> Void = {}

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 56))
                    .foregroundColor(.accentColor)
                Text("Sign in to Muesli")
                    .font(.title2.weight(.bold))
                Text("Dev sign-in for non-production backends. Production sign-in via Google is a future step.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Display name (optional)", text: $fullName)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal, 32)
                .padding(.top, 16)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    Task { await submit() }
                } label: {
                    if isSigningIn {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    } else {
                        Text("Sign in")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 32)
                .disabled(isSigningIn || !isEmailValid)

                Spacer()
            }
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    private func submit() async {
        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }
        do {
            try await AuthService.shared.signInDev(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                fullName: fullName.isEmpty ? nil : fullName
            )
            onSignedIn()
        } catch {
            errorMessage = (error as? AuthError)?.errorDescription ?? error.localizedDescription
        }
    }
}
