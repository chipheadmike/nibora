//
//  EntryPDFExporter.swift
//  Nibora
//

import AppKit
import SwiftUI

/// Renders a single entry (title + styled markdown body) to a PDF file via
/// NSPrintOperation's standard "save to file" job disposition — stock
/// AppKit printing machinery, not custom drawing, so it doesn't touch any of
/// the click/paint-related paths that have proven unreliable elsewhere in
/// this beta.
enum EntryPDFExporter {
    static func export(title: String, body: String, theme: ThemeManager, fontPreferences: FontPreferences, to destinationURL: URL) {
        let pageWidth: CGFloat = 612 // US Letter at 72pt/inch
        let margin: CGFloat = 48

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: pageWidth, height: 792))
        textView.isEditable = false
        textView.textContainerInset = NSSize(width: margin, height: margin)
        textView.string = body
        textView.font = EditorFontSet(fontName: fontPreferences.fontName, fontSize: fontPreferences.fontSize).regular

        MarkdownTextView.applyMarkdownStyling(in: textView, theme: theme, fontPreferences: fontPreferences)

        if let textStorage = textView.textStorage, !title.isEmpty {
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 20),
                .foregroundColor: NSColor(theme.bodyColor)
            ]
            textStorage.insert(NSAttributedString(string: "\(title)\n\n", attributes: titleAttributes), at: 0)
        }

        textView.sizeToFit()

        let printInfo = NSPrintInfo()
        printInfo.jobDisposition = .save
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = destinationURL
        printInfo.topMargin = 0
        printInfo.bottomMargin = 0
        printInfo.leftMargin = 0
        printInfo.rightMargin = 0
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic

        let operation = NSPrintOperation(view: textView, printInfo: printInfo)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        operation.run()
    }
}
