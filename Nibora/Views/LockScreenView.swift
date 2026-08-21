//
//  LockScreenView.swift
//  Nibora
//

import SwiftUI

/// Full-window prompt shown while AppLockManager.isLocked is true. Normally
/// just a password field, but offers a "Forgot password?" path into
/// recovery-code entry, which — on success — forces setting a new password
/// before unlocking (the old, unremembered one can't just stay in place).
struct LockScreenView: View {
    let lockManager: AppLockManager

    private enum Mode {
        case password
        case recoveryCode
        case newPassword
    }

    @State private var mode: Mode = .password
    @State private var password = ""
    @State private var recoveryCode = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()

            Group {
                switch mode {
                case .password: passwordContent
                case .recoveryCode: recoveryCodeContent
                case .newPassword: newPasswordContent
                }
            }
            .padding(40)
            .frame(width: 320)
        }
        .onAppear { isFocused = true }
        .onChange(of: mode) { isFocused = true }
    }

    private var passwordContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Nibora is Locked")
                .font(.title2.bold())

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit { attemptUnlock() }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Unlock") {
                attemptUnlock()
            }
            .buttonStyle(.borderedProminent)
            .disabled(password.isEmpty)

            if lockManager.hasRecoveryCode {
                Button("Forgot password?") {
                    errorMessage = nil
                    password = ""
                    mode = .recoveryCode
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
    }

    private var recoveryCodeContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Enter Recovery Code")
                .font(.title2.bold())

            Text("This is the one-time code you saved when you set up your password lock.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("XXXX-XXXX-XXXX-XXXX", text: $recoveryCode)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit { attemptRecovery() }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Continue") {
                attemptRecovery()
            }
            .buttonStyle(.borderedProminent)
            .disabled(recoveryCode.isEmpty)

            Button("Back to Password") {
                errorMessage = nil
                recoveryCode = ""
                mode = .password
            }
            .buttonStyle(.link)
            .font(.caption)
        }
    }

    private var newPasswordContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Set a New Password")
                .font(.title2.bold())

            Text("Your old password no longer works. Choose a new one to finish unlocking.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            SecureField("New Password", text: $newPassword)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
            SecureField("Confirm New Password", text: $confirmPassword)
                .textFieldStyle(.roundedBorder)
                .onSubmit { finishRecovery() }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Set Password & Unlock") {
                finishRecovery()
            }
            .buttonStyle(.borderedProminent)
            .disabled(newPassword.isEmpty || confirmPassword.isEmpty)
        }
    }

    private func attemptUnlock() {
        if lockManager.unlock(with: password) {
            password = ""
            errorMessage = nil
        } else {
            errorMessage = "Incorrect password."
        }
    }

    private func attemptRecovery() {
        if lockManager.verifyRecoveryCode(recoveryCode) {
            recoveryCode = ""
            errorMessage = nil
            mode = .newPassword
        } else {
            errorMessage = "Incorrect recovery code."
        }
    }

    private func finishRecovery() {
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords don't match."
            return
        }
        lockManager.completeRecovery(newPassword: newPassword)
        newPassword = ""
        confirmPassword = ""
        errorMessage = nil
        mode = .password
    }
}
