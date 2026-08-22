//
//  MailComposer.swift
//  Nibora
//

import AppKit

/// Opens a pre-filled Mail.app compose window — never sends anything
/// automatically, no SMTP credentials, no network code in Nibora itself.
/// Used for the lock screen's "email me a temporary code" recovery path:
/// the code only ever leaves the app inside this draft, and the user has
/// to explicitly review and click Send in Mail.app themselves.
enum MailComposer {
    @discardableResult
    static func openTemporaryCodeDraft(code: String, to email: String) -> Bool {
        guard let service = NSSharingService(named: .composeEmail) else { return false }
        service.recipients = [email]
        service.subject = "Nibora Temporary Access Code"
        let body = "Your temporary Nibora access code is:\n\n\(code)\n\nThis code expires in 15 minutes and can only be used once."
        guard service.canPerform(withItems: [body]) else { return false }
        service.perform(withItems: [body])
        return true
    }
}
