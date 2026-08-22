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
        case recoveryChoice
        case recoveryCode
        case temporaryCode
        case newPassword
    }

    @State private var mode: Mode = .password
    @State private var password = ""
    @State private var recoveryCode = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    /// Tracks which path produced the code being verified, so finishRecovery
    /// clears the right one (saved recovery code vs. emailed temporary code)
    /// without the two interfering with each other.
    @State private var recoveryUsedTemporaryCode = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()

            Group {
                switch mode {
                case .password: passwordContent
                case .recoveryChoice: recoveryChoiceContent
                case .recoveryCode: recoveryCodeContent
                case .temporaryCode: temporaryCodeContent
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

            if lockManager.hasRecoveryCode || lockManager.hasRecoveryEmail {
                Button("Forgot password?") {
                    errorMessage = nil
                    password = ""
                    if lockManager.hasRecoveryCode && lockManager.hasRecoveryEmail {
                        mode = .recoveryChoice
                    } else if lockManager.hasRecoveryCode {
                        mode = .recoveryCode
                    } else {
                        sendTemporaryCode()
                    }
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
    }

    private var recoveryChoiceContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Forgot Your Password?")
                .font(.title2.bold())

            Text("Choose how you'd like to recover access.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Enter Recovery Code") {
                errorMessage = nil
                mode = .recoveryCode
            }
            .buttonStyle(.borderedProminent)

            Button("Email Me a Temporary Code") {
                sendTemporaryCode()
            }
            .buttonStyle(.bordered)

            Button("Back to Password") {
                errorMessage = nil
                mode = .password
            }
            .buttonStyle(.link)
            .font(.caption)
        }
    }

    private var temporaryCodeContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Enter Temporary Code")
                .font(.title2.bold())

            Text("A draft email with your code opened in Mail — send it to yourself, then enter the code here. It expires in 15 minutes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("XXXX-XXXX-XXXX-XXXX", text: $recoveryCode)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit { attemptTemporaryCodeVerification() }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Continue") {
                attemptTemporaryCodeVerification()
            }
            .buttonStyle(.borderedProminent)
            .disabled(recoveryCode.isEmpty)

            Button("Resend Code") {
                sendTemporaryCode()
            }
            .buttonStyle(.link)
            .font(.caption)

            Button("Back") {
                errorMessage = nil
                recoveryCode = ""
                mode = lockManager.hasRecoveryCode ? .recoveryChoice : .password
            }
            .buttonStyle(.link)
            .font(.caption)
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
                mode = lockManager.hasRecoveryEmail ? .recoveryChoice : .password
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
            recoveryUsedTemporaryCode = false
            mode = .newPassword
        } else {
            errorMessage = "Incorrect recovery code."
        }
    }

    /// Generates a fresh temporary code and opens a pre-filled Mail.app
    /// draft with it — the code is never shown anywhere in this view, only
    /// inside that draft, so unlocking this way genuinely requires access
    /// to the recovery inbox, not just physical access to this Mac.
    private func sendTemporaryCode() {
        let code = lockManager.generateTemporaryCode()
        errorMessage = nil
        guard MailComposer.openTemporaryCodeDraft(code: code, to: lockManager.recoveryEmail) else {
            errorMessage = "Couldn't open Mail — make sure a mail account is configured in the Mail app, then try again."
            return
        }
        recoveryCode = ""
        mode = .temporaryCode
    }

    private func attemptTemporaryCodeVerification() {
        if lockManager.verifyTemporaryCode(recoveryCode) {
            recoveryCode = ""
            errorMessage = nil
            recoveryUsedTemporaryCode = true
            mode = .newPassword
        } else {
            errorMessage = "Incorrect or expired code."
        }
    }

    private func finishRecovery() {
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords don't match."
            return
        }
        lockManager.completeRecovery(newPassword: newPassword, usingTemporaryCode: recoveryUsedTemporaryCode)
        newPassword = ""
        confirmPassword = ""
        errorMessage = nil
        recoveryUsedTemporaryCode = false
        mode = .password
    }
}
