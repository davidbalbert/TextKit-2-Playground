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

        print("insertText(_:replacementRange:)", string, replacementRange)

        // I seem to always get {NSNotFound, 0} for replacementRange. For now, I'm
        // going to ignore replacement range, but if I get a real replacementRange,
        // I want to know about it.
        assert(replacementRange == .notFound)

        guard let attributedString = NSAttributedString(anyString: string, typingAttributes: typingAttributes) else {
            return
        }

        textContentStorage.performEditingTransaction {
            internalReplaceCharacters(in: textSelections, with: attributedString)
        }

        updateInsertionPointTimer()
        unmarkText()
        inputContext?.invalidateCharacterCoordinates()
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

        assert(replacementRange == .notFound)

        guard let attributedString = NSAttributedString(anyString: string, typingAttributes: typingAttributes) else {
            return
        }

        let replacementSelections = textSelections

        textContentStorage.performEditingTransaction {
            if attributedString.length == 0 {
                internalReplaceCharacters(in: textSelections, with: "")
                unmarkText()
            } else {
                textSelections = replacementSelections.compactMap { $0.markedSelection(for: attributedString, selectedRange: selectedRange, in: textContentStorage) }
                internalReplaceCharacters(in: textSelections, with: attributedString)
            }
        }

        updateInsertionPointTimer()
        inputContext?.invalidateCharacterCoordinates()
    }

    func unmarkText() {
        print("unmarkText")
        textSelections = textSelections.map(\.unmarked)
        inputContext?.discardMarkedText()
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
        textSelections.contains(where: \.isMarked)
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
