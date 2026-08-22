//
//  VaultBackupService.swift
//  Nibora
//

import Foundation

/// Exports the whole vault folder as a single .zip file. A real zip
/// normally means shelling out to /usr/bin/zip or ditto, which this
/// sandboxed app can't do without relaxing entitlements (the same wall hit
/// when considering git-backed history). NSFileCoordinator's
/// `.forUploading` reading option sidesteps that entirely: it's public,
/// sandbox-legal API that hands back a URL to a real temporary zip archive
/// of the item it's coordinating — originally meant for share-sheet/cloud-
/// upload flows, but works just as well here.
enum VaultBackupService {
    static func exportZip(vaultURL: URL, to destinationURL: URL) throws {
        var coordinatorError: NSError?
        var thrownError: Error?

        NSFileCoordinator().coordinate(readingItemAt: vaultURL, options: [.forUploading], error: &coordinatorError) { zippedURL in
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: zippedURL, to: destinationURL)
            } catch {
                thrownError = error
            }
        }

        if let coordinatorError { throw coordinatorError }
        if let thrownError { throw thrownError }
    }
}
