//
//  TextView+NSTextInputClient.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/11/22.
//

import Cocoa

extension TextView {
    override func keyDown(with event: NSEvent) {
        guard isEditable else { return }

        // TODO: should I use interpretKeyEvents here instead?
        inputContext?.handleEvent(event)
    }

    override func deleteBackward(_ sender: Any?) {
        delete(direction: .backward, destination: .character)
    }

    override func deleteForward(_ sender: Any?) {
        delete(direction: .forward, destination: .character)
    }

    override func deleteWordBackward(_ sender: Any?) {
        delete(direction: .backward, destination: .word)
    }

    override func deleteWordForward(_ sender: Any?) {
        delete(direction: .forward, destination: .word)
    }

    override func deleteToBeginningOfLine(_ sender: Any?) {
        delete(direction: .backward, destination: .line)
    }

    override func deleteToEndOfLine(_ sender: Any?) {
        delete(direction: .forward, destination: .line)
    }

    override func deleteToBeginningOfParagraph(_ sender: Any?) {
        delete(direction: .backward, destination: .paragraph)
    }

    override func deleteToEndOfParagraph(_ sender: Any?) {
        delete(direction: .forward, destination: .paragraph)
    }

    func delete(direction: NSTextSelectionNavigation.Direction, destination: NSTextSelectionNavigation.Destination) {
        guard isEditable else { return }

        guard let textContentStorage = textContentStorage, let textLayoutManager = textLayoutManager else {
            return
        }

        let deletionRanges = textLayoutManager.textSelections.flatMap { textSelection in
            textLayoutManager.textSelectionNavigation.deletionRanges(for: textSelection,
                                                                     direction: direction,
                                                                     destination: destination,
                                                                     allowsDecomposition: false)
        }

        textContentStorage.performEditingTransaction {
            for textRange in deletionRanges {
                replaceCharacters(in: textRange, with: "")
            }
        }
    }

    func replaceCharacters(in textRange: NSTextRange, with string: String) {
        replaceCharacters(in: textRange, with: NSAttributedString(string: string))
    }

    // TODO: Maybe we should work with AttributedStrings instead?
    func replaceCharacters(in textRange: NSTextRange, with attributedString: NSAttributedString) {
        guard let textContentStorage = textContentStorage, let textStorage = textStorage else {
            return
        }

        textContentStorage.performEditingTransaction {
            textStorage.replaceCharacters(in: NSRange(textRange, in: textContentStorage), with: attributedString)
        }

        textLayer.setNeedsLayout()
        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }
}

extension TextView: NSTextInputClient {
    func insertText(_ string: Any, replacementRange: NSRange) {
        guard isEditable else { return }

        // I seem to always get {NSNotFound, 0} for replacementRange. For now, I'm
        // going to ignore replacement range, but if I get a real replacementRange,
        // I want to know about it.
        assert(replacementRange.location == NSNotFound)

        guard let textContentStorage = textContentStorage, let textSelections = textLayoutManager?.textSelections else {
            return
        }

        textContentStorage.performEditingTransaction {
            for textRange in textSelections.flatMap(\.textRanges) {
                switch string {
                case let attributedString as NSAttributedString:
                    replaceCharacters(in: textRange, with: attributedString)
                case let string as String:
                    replaceCharacters(in: textRange, with: string)
                default:
                    continue
                }
            }
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
    }

    func unmarkText() {
        print("unmarkText")
    }

    func selectedRange() -> NSRange {
        print("selectedRange")

        guard let textContentStorage = textContentStorage, let textRange = textLayoutManager?.textSelections.first?.textRanges.first else {
            return NSRange(location: NSNotFound, length: 0)
        }

        return NSRange(textRange, in: textContentStorage)
    }

    func markedRange() -> NSRange {
        print("markedRange")

        return NSRange(location: 0, length: 0)
    }

    func hasMarkedText() -> Bool {
        return false
    }

    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        print("attributedSubstringForProposedRange", range, actualRange)

        return nil
    }

    func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        return []
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
