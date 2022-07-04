//
//  TextView+NSTextInputClient.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/11/22.
//

import Cocoa

extension TextView {
}

extension TextView: NSTextInputClient {
    func insertText(_ string: Any, replacementRange: NSRange) {
        guard isEditable else { return }

        // I seem to always get {NSNotFound, 0} for replacementRange. For now, I'm
        // going to ignore replacement range, but if I get a real replacementRange,
        // I want to know about it.
        assert(replacementRange == .notFound)

        switch string {
        case let attributedString as NSAttributedString:
            replaceCharacters(in: selectedTextRanges, with: attributedString)
        case let string as String:
            replaceCharacters(in: selectedTextRanges, with: string)
        default:
            break
        }
    }

    override func doCommand(by selector: Selector) {
        if responds(to: selector) {
            perform(selector, with: nil)
        } else {
            print("doCommandBySelector:", selector)
        }
    }

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        print("setMarkedText", string, selectedRange, replacementRange)

        guard let textRange = NSTextRange(selectedRange, in: textContentStorage) else {
            return
        }

        markedRanges = [textRange]
    }

    func unmarkText() {
        print("unmarkText")
        markedRanges = []

    }

    func selectedRange() -> NSRange {
        print("selectedRange")

        guard let textRange = textSelections.first?.textRanges.first else {
            return .notFound
        }

        return NSRange(textRange, in: textContentStorage)
    }

    func markedRange() -> NSRange {
        print("markedRange")

        return .notFound
    }

    func hasMarkedText() -> Bool {
        print("hasMarkedText", !markedRanges.isEmpty)
        return !markedRanges.isEmpty
    }

    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        print("attributedSubstringForProposedRange", range, actualRange)

        return nil
    }

    func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        // print("validAttributesForMarkedText")
        // Copied from NSTextView on macOS 12.4. Missing NSTextInsertionUndoable, which I can't any documentation for.
        return [.font, .underlineStyle, .foregroundColor, .backgroundColor, .underlineColor, .markedClauseSegment, .languageIdentifier, .replacementIndex, .glyphInfo, .textAlternatives, .attachment]
    }

    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        print("firstRectForCharacterRange", range, actualRange)

        return .zero
    }

    func characterIndex(for point: NSPoint) -> Int {
        print("characterIndexFor", point)

        return 0
    }
}
