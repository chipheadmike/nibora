//
//  LockScreenView.swift
//  Nibora
//

import SwiftUI

/// Full-window password prompt shown while AppLockManager.isLocked is true.
struct LockScreenView: View {
    let lockManager: AppLockManager

    @State private var password = ""
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                Text("Nibora is Locked")
                    .font(.title2.bold())

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
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
            }
            .padding(40)
        }
        .onAppear { isFocused = true }
    }

    private func attemptUnlock() {
        if lockManager.unlock(with: password) {
            password = ""
            errorMessage = nil
        } else {
            errorMessage = "Incorrect password."
        }
    }
}
