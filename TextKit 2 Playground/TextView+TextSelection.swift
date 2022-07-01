//
//  TextView+TextSelection.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/12/22.
//

import Cocoa

extension TextView {
    // MARK: Mouse events
    override func mouseDown(with event: NSEvent) {
        guard isSelectable else { return }

        guard let textLayoutManager = textLayoutManager else { return }
        let point = convert(event.locationInWindow, from: nil)

        if event.modifierFlags.contains(.shift) && !textLayoutManager.textSelections.isEmpty {
            extendSelection(to: point)
        } else {
            startSelection(at: point)
        }

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isSelectable else { return }

        let point = convert(event.locationInWindow, from: nil)
        extendSelection(to: point)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func mouseUp(with event: NSEvent) {
        guard isSelectable else { return }

        // Zero length selections are insertion points. We only allow
        // insertion points if we're editable
        if !isEditable {
            removeZeroLengthSelections()
        }

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    // MARK: - Character navigation
    // List of all key commands for completeness testing: https://support.apple.com/en-us/HT201236
    // NSStandardKeyBindingResponding: https://developer.apple.com/documentation/appkit/nsstandardkeybindingresponding

    override func moveLeft(_ sender: Any?) {
        updateSelections(direction: .left, destination: .character, extending: false)
    }

    override func moveRight(_ sender: Any?) {
        updateSelections(direction: .right, destination: .character, extending: false)
    }

    override func moveUp(_ sender: Any?) {
        updateSelections(direction: .up, destination: .character, extending: false)
    }

    override func moveDown(_ sender: Any?) {
        updateSelections(direction: .down, destination: .character, extending: false)
    }

    override func moveBackward(_ sender: Any?) {
        updateSelections(direction: .backward, destination: .character, extending: false)
    }

    override func moveForward(_ sender: Any?) {
        updateSelections(direction: .forward, destination: .character, extending: false)
    }

    override func moveLeftAndModifySelection(_ sender: Any?) {
        updateSelections(direction: .left, destination: .character, extending: true)
    }

    override func moveRightAndModifySelection(_ sender: Any?) {
        updateSelections(direction: .right, destination: .character, extending: true)
    }

    override func moveUpAndModifySelection(_ sender: Any?) {
        updateSelections(direction: .up, destination: .character, extending: true)
    }

    override func moveDownAndModifySelection(_ sender: Any?) {
        updateSelections(direction: .down, destination: .character, extending: true)
    }

    override func moveBackwardAndModifySelection(_ sender: Any?) {
        updateSelections(direction: .backward, destination: .character, extending: true)
    }

    override func moveForwardAndModifySelection(_ sender: Any?) {
        updateSelections(direction: .forward, destination: .character, extending: true)
    }

    // MARK: - Word navigation

    override func moveWordLeft(_ sender: Any?) {
        updateSelections(direction: .left, destination: .word, extending: false)
    }

    override func moveWordRight(_ sender: Any?) {
        updateSelections(direction: .right, destination: .word, extending: false)
    }

    override func moveWordLeftAndModifySelection(_ sender: Any?) {
        updateSelections(direction: .left, destination: .word, extending: true)
    }

    override func moveWordRightAndModifySelection(_ sender: Any?) {
        updateSelections(direction: .right, destination: .word, extending: true)
    }

    // MARK: - Line navigation

    // TODO: If we're already at the end or beginning of the line, these should be no-ops. They should not wrap to the nextline. (i.e. Command-Right Arrow + Command-Right Arrow should not navigate past the end of the line you were originally on.
    override func moveToLeftEndOfLine(_ sender: Any?) {
        updateSelections(direction: .left, destination: .line, extending: false, confined: true)
    }

    override func moveToRightEndOfLine(_ sender: Any?) {
        updateSelections(direction: .right, destination: .line, extending: false, confined: true)
    }

    override func moveToLeftEndOfLineAndModifySelection(_ sender: Any?) {
        updateSelections(direction: .left, destination: .line, extending: true, confined: true)
    }

    override func moveToRightEndOfLineAndModifySelection(_ sender: Any?) {
        updateSelections(direction: .right, destination: .line, extending: true, confined: true)
    }

    // MARK: - Paragraph navigation
    override func moveToBeginningOfParagraph(_ sender: Any?) {
        updateSelections(direction: .left, destination: .paragraph, extending: false)
    }

    override func moveToEndOfParagraph(_ sender: Any?) {
        updateSelections(direction: .right, destination: .paragraph, extending: false)
    }

    override func moveToBeginningOfParagraphAndModifySelection(_ sender: Any?) {
        updateSelections(direction: .left, destination: .paragraph, extending: true)
    }

    override func moveToEndOfParagraphAndModifySelection(_ sender: Any?) {
        updateSelections(direction: .right, destination: .paragraph, extending: true)
    }

    // MARK: - Document navigation

    // TODO: Eventually, we need to figure out how to deal with multiple selections that become overlapped. E.g., create two selections on two separate lines, and then press Command-Shift-Down Arrow to highlight to the end of the line. We should probably only have one selection at this point. Check to see how other editors behave.
    override func moveToBeginningOfDocument(_ sender: Any?) {
        updateSelections(direction: .up, destination: .document, extending: false)
    }

    override func moveToEndOfDocument(_ sender: Any?) {
        updateSelections(direction: .down, destination: .document, extending: false)
    }

    override func moveToBeginningOfDocumentAndModifySelection(_ sender: Any?) {
        updateSelections(direction: .up, destination: .document, extending: true)
    }

    override func moveToEndOfDocumentAndModifySelection(_ sender: Any?) {
        updateSelections(direction: .down, destination: .document, extending: true)
    }


    // MARK: - Selection manipulation

    func startSelection(at point: CGPoint) {
        guard let textLayoutManager = textLayoutManager else { return }
        let navigation = textLayoutManager.textSelectionNavigation

        textLayoutManager.textSelections = navigation.textSelections(interactingAt: point,
                                                                     inContainerAt: textLayoutManager.documentRange.location,
                                                                     anchors: [],
                                                                     modifiers: [],
                                                                     selecting: false,
                                                                     bounds: .zero)
    }

    func extendSelection(to point: CGPoint) {
        guard let textLayoutManager = textLayoutManager else { return }
        let navigation = textLayoutManager.textSelectionNavigation

        textLayoutManager.textSelections = navigation.textSelections(interactingAt: point,
                                                                     inContainerAt: textLayoutManager.documentRange.location,
                                                                     anchors: textLayoutManager.textSelections,
                                                                     modifiers: .extend,
                                                                     selecting: false,
                                                                     bounds: .zero)
    }

    // TODO: handle zero length selections when isEditable is false
    func updateSelections(direction: NSTextSelectionNavigation.Direction, destination: NSTextSelectionNavigation.Destination, extending: Bool, confined: Bool = false) {
        guard isSelectable else { return }

        guard let textLayoutManager = textLayoutManager else { return }
        let navigation = textLayoutManager.textSelectionNavigation

        textLayoutManager.textSelections = textLayoutManager.textSelections.compactMap { textSelection in
            navigation.destinationSelection(for: textSelection,
                                            direction: direction,
                                            destination: destination,
                                            extending: extending,
                                            confined: confined)
        }

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    func removeZeroLengthSelections() {
        guard let textLayoutManager = textLayoutManager else { return }

        textLayoutManager.textSelections.removeAll { textSelection in
            textSelection.textRanges.allSatisfy { $0.isEmpty }
        }
    }

    var textSelectionColor: NSColor {
        if windowIsKey && isFirstResponder {
            return NSColor.selectedTextBackgroundColor
        } else {
            return NSColor.unemphasizedSelectedTextBackgroundColor
        }
    }

    var textSelections: [NSTextSelection] {
        guard let textLayoutManager = textLayoutManager else {
            return []
        }

        return textLayoutManager.textSelections
    }

    var selectedTextRanges: [NSTextRange] {
        textSelections.flatMap(\.textRanges)
    }

    var nonEmptySelectedTextRanges: [NSTextRange] {
        selectedTextRanges.filter { !$0.isEmpty }
    }

    func enumerateSelectionFramesInViewport(using block: (CGRect) -> Void) {
        guard let textLayoutManager = textLayoutManager, let viewportRange = textViewportLayoutController?.viewportRange else {
            return
        }

        let rangesInViewport = nonEmptySelectedTextRanges.compactMap { $0.intersection(viewportRange) }

        for textRange in rangesInViewport {
            textLayoutManager.enumerateTextSegments(in: textRange, type: .selection) { _, segmentFrame, _, _ in
                block(segmentFrame.pixelAligned)
                return true
            }
        }
    }

    var insertionPointTextRanges: [NSTextRange] {
        selectedTextRanges.filter { $0.isEmpty }
    }

    func enumerateInsertionPointFramesInViewport(using block: (CGRect) -> Void) {
        guard let textLayoutManager = textLayoutManager, let viewportRange = textViewportLayoutController?.viewportRange else {
            return
        }

        let rangesInViewport = insertionPointTextRanges.compactMap { $0.intersection(viewportRange) }

        for textRange in rangesInViewport {
            textLayoutManager.enumerateTextSegments(in: textRange, type: .selection) { _, segmentFrame, _, _ in
                var insertionPointFrame = segmentFrame.pixelAligned
                insertionPointFrame.size.width = 1

                block(insertionPointFrame)
                return true
            }
        }
    }
}

