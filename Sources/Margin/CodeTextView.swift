import AppKit
import MarginCore
import SwiftUI

/// Plain-text code editor (NSTextView) with tree-sitter highlighting.
struct CodeTextView: NSViewRepresentable {
    @ObservedObject var document: EditorDocument

    func makeCoordinator() -> Coordinator { Coordinator(document: document) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = Theme.font
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.string = document.text
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        context.coordinator.highlight()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        guard let textView = coordinator.textView else { return }
        if textView.string != document.text {
            // The document was reloaded from disk.
            let selection = textView.selectedRange()
            textView.string = document.text
            textView.undoManager?.removeAllActions()
            textView.setSelectedRange(NSRange(location: min(selection.location, (document.text as NSString).length), length: 0))
            coordinator.highlight()
        }
        if let line = document.pendingLine {
            coordinator.reveal(line: line)
            DispatchQueue.main.async { document.pendingLine = nil }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        let document: EditorDocument
        weak var textView: NSTextView?
        private var pendingHighlight: DispatchWorkItem?

        init(document: EditorDocument) { self.document = document }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            document.text = textView.string
            pendingHighlight?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.highlight() }
            pendingHighlight = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
        }

        func highlight() {
            guard let textView, let storage = textView.textStorage else { return }
            let full = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            storage.setAttributes([.font: Theme.font, .foregroundColor: NSColor.labelColor], range: full)
            if let language = document.language {
                for span in SyntaxHighlighter.highlights(in: textView.string, language: language)
                where NSMaxRange(span.range) <= full.length {
                    storage.addAttribute(.foregroundColor, value: Theme.color(for: span.capture), range: span.range)
                }
            }
            storage.endEditing()
            textView.typingAttributes = [.font: Theme.font, .foregroundColor: NSColor.labelColor]
        }

        func reveal(line: Int) {
            guard let textView else { return }
            let text = textView.string as NSString
            var location = 0
            for _ in 1..<max(line, 1) {
                guard location < text.length else { break }
                location = NSMaxRange(text.lineRange(for: NSRange(location: location, length: 0)))
            }
            let range = text.lineRange(for: NSRange(location: min(location, text.length), length: 0))
            textView.scrollRangeToVisible(range)
            textView.setSelectedRange(NSRange(location: range.location, length: 0))
            textView.showFindIndicator(for: range)
            textView.window?.makeFirstResponder(textView)
        }
    }
}
