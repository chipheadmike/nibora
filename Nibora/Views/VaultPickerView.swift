//
//  VaultPickerView.swift
//  Nibora
//

import SwiftUI

struct VaultPickerView: View {
    @Environment(VaultManager.self) private var vaultManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Welcome to Nibora")
                .font(.title)
                .bold()

            Text("Choose a folder where your journal entries will live. This can be an existing folder in iCloud Drive, Dropbox, or anywhere else on your Mac.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Button("Choose Vault Folder…") {
                vaultManager.pickVault()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(minWidth: 480, minHeight: 360)
    }
}

#Preview {
    VaultPickerView()
        .environment(VaultManager())
}
