//
//  TextView+NSTextInputClient.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/11/22.
//

import Cocoa

extension TextView: NSTextInputClient {
    override func keyDown(with event: NSEvent) {
        guard isEditable else { return }

        inputContext?.handleEvent(event)
    }

    func insertText(_ string: Any, replacementRange: NSRange) {
        print("insertText", string, replacementRange)
    }

    override func doCommand(by selector: Selector) {
        print("doCommandBySelector:", selector)
    }

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        print("setMarkedText", string, selectedRange, replacementRange)
    }

    func unmarkText() {
        print("unmarkText")
    }

    func selectedRange() -> NSRange {
        print("selectedRange")

        return NSRange(location: 0, length: 0)
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
