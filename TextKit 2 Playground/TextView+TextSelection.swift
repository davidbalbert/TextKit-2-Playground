//
//  TextView+TextSelection.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/12/22.
//

import Cocoa

extension TextView {
    // TODO: make this user setable
    var textSelectionColor: NSColor {
        if windowIsKey && isFirstResponder {
            return .selectedTextBackgroundColor
        } else {
            return .unemphasizedSelectedTextBackgroundColor
        }
    }

    var textSelections: [NSTextSelection] {
        get {
            textLayoutManager.textSelections
        }
        set {
            textLayoutManager.textSelections = newValue
        }
    }

    var nonEmptyTextSelections: [NSTextSelection] {
        textSelections.filter { textSelection in
            textSelection.textRanges.contains { !$0.isEmpty }
        }
    }

    var insertionPointTextSelections: [NSTextSelection] {
        textSelections.filter { textSelection in
            textSelection.textRanges.allSatisfy { $0.isEmpty }
        }
    }

    var selectedTextRanges: [NSTextRange] {
        textSelections.flatMap(\.textRanges)
    }

    var nonEmptySelectedTextRanges: [NSTextRange] {
        nonEmptyTextSelections.flatMap(\.textRanges)
    }

    var insertionPointTextRanges: [NSTextRange] {
        insertionPointTextSelections.flatMap(\.textRanges)
    }

    var markedTextRanges: [NSTextRange] {
        textSelections.compactMap(\.markedTextRange)
    }

    internal var hasSelectedText: Bool {
        nonEmptySelectedTextRanges.count > 0
    }

    func startSelection(at point: CGPoint) {
        let navigation = textLayoutManager.textSelectionNavigation

        // TODO: What is bounds for? It should probably not just be .zero, right?
        textSelections = navigation.textSelections(interactingAt: point,
                                                   inContainerAt: textLayoutManager.documentRange.location,
                                                   anchors: [],
                                                   modifiers: [],
                                                   selecting: true,
                                                   bounds: .zero)
    }

    func extendSelection(to point: CGPoint) {
        let navigation = textLayoutManager.textSelectionNavigation

        // TODO: What is bounds for? It should probably not just be .zero, right?
        textSelections = navigation.textSelections(interactingAt: point,
                                                   inContainerAt: textLayoutManager.documentRange.location,
                                                   anchors: textSelections,
                                                   modifiers: .extend,
                                                   selecting: true,
                                                   bounds: .zero)
    }

    // TODO: handle zero length selections when isEditable is false
    func updateSelections(direction: NSTextSelectionNavigation.Direction, destination: NSTextSelectionNavigation.Destination, extending: Bool, confined: Bool = false) {
        guard isSelectable else { return }

        let navigation = textLayoutManager.textSelectionNavigation

        textSelections = textSelections.compactMap { textSelection in
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

    func delete(direction: NSTextSelectionNavigation.Direction, destination: NSTextSelectionNavigation.Destination) {
        guard isEditable else { return }

        let deletionRanges = textSelections.flatMap { textSelection in
            textLayoutManager.textSelectionNavigation.deletionRanges(for: textSelection,
                                                                     direction: direction,
                                                                     destination: destination,
                                                                     allowsDecomposition: false)
        }

        textContentStorage.performEditingTransaction {
            for textRange in deletionRanges {
                internalDeleteCharacters(in: textRange)
            }
        }

        updateInsertionPointTimer()
        unmarkText()
        inputContext?.invalidateCharacterCoordinates()
    }

    func removeZeroLengthSelections() {
        textSelections.removeAll { textSelection in
            textSelection.textRanges.allSatisfy { $0.isEmpty }
        }
    }

    func enumerateSelectionFramesInViewport(using block: (CGRect) -> Void) {
        guard let viewportRange = textViewportLayoutController.viewportRange else {
            return
        }

        let rangesInViewport = nonEmptySelectedTextRanges.compactMap { $0.intersection(viewportRange) }

        for textRange in rangesInViewport {
            textLayoutManager.enumerateTextSegments(in: textRange, type: .selection, options: .rangeNotRequired) { _, segmentFrame, _, _ in
                block(segmentFrame.pixelAligned)
                return true
            }
        }
    }

    func enumerateInsertionPointFramesInViewport(using block: (CGRect) -> Void) {
        guard let viewportRange = textViewportLayoutController.viewportRange else {
            return
        }

        let rangesInViewport = insertionPointTextRanges.compactMap { $0.intersection(viewportRange) }

        for textRange in rangesInViewport {
            textLayoutManager.enumerateTextSegments(in: textRange, type: .selection, options: .rangeNotRequired) { _, segmentFrame, _, _ in
                var insertionPointFrame = segmentFrame.pixelAligned
                insertionPointFrame.size.width = 1

                block(insertionPointFrame)
                return true
            }
        }
    }

    // TODO: split into an onInterval and offInterval and read NSTextInsertionPointBlinkPeriodOn and NSTextInsertionPointBlinkPeriodOff from defaults
    private var insertionPointBlinkInterval: TimeInterval {
        0.5
    }

    var shouldDrawInsertionPoint: Bool {
        isEditable && isFirstResponder && windowIsKey && superview != nil
    }

    func updateInsertionPointTimer() {
        insertionPointTimer?.invalidate()

        if shouldDrawInsertionPoint {
            insertionPointLayer.isHidden = false

            insertionPointTimer = Timer.scheduledTimer(withTimeInterval: insertionPointBlinkInterval, repeats: true) { [weak self] timer in
                guard let self = self else { return }
                self.insertionPointLayer.isHidden.toggle()
            }
        } else {
            insertionPointLayer.isHidden = true
        }
    }

    func createInsertionPointIfNecessary() {
        if !isEditable {
            return
        }

        let textRange = NSTextRange(location: textLayoutManager.documentRange.location)
        textSelections = [NSTextSelection(range: textRange, affinity: .downstream, granularity: .character)]
    }
}

