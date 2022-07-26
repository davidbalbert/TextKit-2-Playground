//
//  TextView+NSTextInputClient.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/11/22.
//

import Cocoa

// This extension is a pseudo re-imagined NSTextInputClient for use with TextKit 2. We implement
// NSTextInputClient in terms of this extension, though we don't do it rigorously as the NSTextInputClient
// methods depend on other methods and properties defined on TextView.
extension TextView {
    func insertText(_ string: Any, replacementTextSelections: [NSTextSelection]?) {
        guard let attributedString = NSAttributedString(anyString: string, attributes: typingAttributes) else {
            return
        }

        if let replacementTextSelections = replacementTextSelections {
            textSelections = replacementTextSelections
        }

        textContentStorage.performEditingTransaction {
            internalReplaceCharacters(in: textSelections, with: attributedString)
        }

        updateInsertionPointTimer()
        unmarkText()
        inputContext?.invalidateCharacterCoordinates()
    }

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementTextSelections: [NSTextSelection]?) {
        guard let attributedString = NSAttributedString(anyString: string, attributes: typingAttributes) else {
            return
        }

        if let replacementTextSelections = replacementTextSelections {
            textSelections = replacementTextSelections
        }

        textContentStorage.performEditingTransaction {
            if attributedString.length == 0 {
                internalReplaceCharacters(in: textSelections, with: "")
                unmarkText()
            } else {
                let previousSelections = textSelections
                internalReplaceCharacters(in: textSelections, with: attributedString)
                textSelections = previousSelections.compactMap { $0.markedSelection(for: attributedString, selectedRange: selectedRange, in: textContentStorage) }
            }
        }

        updateInsertionPointTimer()
        inputContext?.invalidateCharacterCoordinates()
    }

    var textSelectionsInViewport: [NSTextSelection] {
        guard let visibleRange = visibleRange else {
            return []
        }

        return textSelections.filter { textSelection in
            guard let location = textSelection.textRanges.first?.location else {
                return false
            }

            return visibleRange.contains(location)
        }
    }

    var textSelectionForInputClient: NSTextSelection? {
        textSelectionsInViewport.last ?? textSelections.last
    }

    var visibleRange: NSTextRange? {
        let x = visibleRect.minX
        let minY = visibleRect.minY
        let maxY = visibleRect.maxY

        guard let firstFragment = textLayoutManager.textLayoutFragment(for: CGPoint(x: x, y: minY)) else { return nil }
        guard let lastFragment = textLayoutManager.textLayoutFragment(for: CGPoint(x: x, y: maxY)) else { return nil }

        return NSTextRange(location: firstFragment.rangeInElement.location, end: lastFragment.rangeInElement.endLocation)
    }

    func replacementTextSelections(for replacementRange: NSRange) -> [NSTextSelection]? {
        guard replacementRange != .notFound else {
            return nil
        }

        // If the system gives us a replacementRange, it's derived from what we gave it
        // for selectedRange() – which is to say, the first range of the text selection
        // that's most appropriate for use with an input method editor.
        let baseRange = selectedRange()

        guard baseRange != .notFound else {
            return nil
        }

        let offset = replacementRange.location - baseRange.location
        let length = replacementRange.length

        return textSelections.compactMap { textSelection in
            textSelection.contiguousTextSelection(offsetBy: offset, length: length, in: textContentStorage)
        }
    }
}

extension TextView: NSTextInputClient {
    func insertText(_ string: Any, replacementRange: NSRange) {
        guard isEditable else { return }

        print("insertText(_:replacementRange:)", string, replacementRange == .notFound ? "NSRange.notFound" : replacementRange)

        insertText(string, replacementTextSelections: replacementTextSelections(for: replacementRange))
    }

    override func doCommand(by selector: Selector) {
        // print("doCommand(by:)", selector)

        if responds(to: selector) {
            perform(selector, with: nil)
        } else {
            print("doCommandBySelector:", selector)
        }
    }

    // selectedRange - the new in the coordinate system of the string
    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        guard isEditable else { return }

        print("setMarkedText(_:selectedRange:replacementRange:)", string, selectedRange == .notFound ? "NSRange.notFound" : selectedRange, replacementRange == .notFound ? "NSRange.notFound" : replacementRange)

        setMarkedText(string, selectedRange: selectedRange, replacementTextSelections: replacementTextSelections(for: replacementRange))
    }

    func unmarkText() {
        print("unmarkText()")
        textSelections = textSelections.map(\.unmarked)
        inputContext?.discardMarkedText()
    }

    // Should return the newestTextSelection in the current viewport. If no textSelection is in the viewport when
    // insertText is called, we should move the viewport to the newest textSelection, centered if necessary.
    func selectedRange() -> NSRange {
        // print("selectedRange()")
        return NSRange(textSelectionForInputClient?.textRanges.first, in: textContentStorage)
    }

    func markedRange() -> NSRange {
        // print("markedRange()")
        guard let markedTextRange = markedTextRanges.first else {
            return .notFound
        }

        return NSRange(markedTextRange, in: textContentStorage)
    }

    func hasMarkedText() -> Bool {
        // print("hasMarkedText()")
        return textSelections.contains(where: \.isMarked)
    }

    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        print("attributedSubstring(forProposedRange:actualRange:)", range == .notFound ? "NSRange.notFound" : range, actualRange)

        return nil
    }

    func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        // print("validAttributesForMarkedText()")
        // Copied from NSTextView on macOS 12.4. Missing NSTextInsertionUndoable, which I can't any documentation for.
        return [.font, .underlineStyle, .foregroundColor, .backgroundColor, .underlineColor, .markedClauseSegment, .languageIdentifier, .replacementIndex, .glyphInfo, .textAlternatives, .attachment]
    }

    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        print("firstRect(forCharacterRange:actualRange:)", range == .notFound ? "NSRange.notFound" : range, actualRange)
        guard let textRange = NSTextRange(range, in: textContentStorage) else { return .zero  }

        var rect: NSRect = .zero
        textLayoutManager.enumerateTextSegments(in: textRange, type: .standard) { segmentTextRange, segmentRect, _, _ in
            rect = segmentRect

            if let segmentTextRange = segmentTextRange, let actualRange = actualRange {
                actualRange.pointee = NSRange(segmentTextRange, in: textContentStorage)
            }

            return false
        }

        let windowRect = convert(rect, to: nil)
        let screenRect = window?.convertToScreen(windowRect) ?? .zero

        return screenRect
    }

    // TODO: there's a bug where if you hold "e" and then instead of selecting an accented character from the popup window, click elsewhere in the same paragraph, your selection won't move to the location you click, it will move somewhere in a previous paragraph
    func characterIndex(for screenPoint: NSPoint) -> Int {
        print("characterIndex(for:)", screenPoint)
        guard let window = window else {
            return NSNotFound
        }

        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        let point = convert(windowPoint, from: nil)

        // TODO: textLayoutManager.characterIndex(for:) expects a point in the textContainer's coordinate space. We're giving it a point in the textView's coordinate space. For now this is fine because they're one in the same, but when we add textContainerInsets, that will have to change.

        let characterIndex = textLayoutManager.characterIndex(for: point)

        return characterIndex
    }

    // TODO: add appropriate optional methods on NSTextInputClient (like attributedString())
}
