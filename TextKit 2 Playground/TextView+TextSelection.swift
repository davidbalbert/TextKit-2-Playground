//
//  TextView+TextSelection.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/12/22.
//

import Cocoa

extension TextView {
    func startSelection(at point: CGPoint) {
        let navigation = textLayoutManager.textSelectionNavigation

        textLayoutManager.textSelections = navigation.textSelections(interactingAt: point,
                                                                     inContainerAt: textLayoutManager.documentRange.location,
                                                                     anchors: [],
                                                                     modifiers: [],
                                                                     selecting: false,
                                                                     bounds: .zero)
    }

    func extendSelection(to point: CGPoint) {
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

    func delete(direction: NSTextSelectionNavigation.Direction, destination: NSTextSelectionNavigation.Destination) {
        guard isEditable else { return }

        let deletionRanges = textLayoutManager.textSelections.flatMap { textSelection in
            textLayoutManager.textSelectionNavigation.deletionRanges(for: textSelection,
                                                                     direction: direction,
                                                                     destination: destination,
                                                                     allowsDecomposition: false)
        }

        replaceCharacters(in: deletionRanges, with: "")
    }

    func removeZeroLengthSelections() {
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
        get {
            textLayoutManager.textSelections
        }
        set {
            textLayoutManager.textSelections = newValue
        }
    }

    var selectedTextRanges: [NSTextRange] {
        textSelections.flatMap(\.textRanges)
    }

    var nonEmptySelectedTextRanges: [NSTextRange] {
        selectedTextRanges.filter { !$0.isEmpty }
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

    var insertionPointTextRanges: [NSTextRange] {
        selectedTextRanges.filter { $0.isEmpty }
    }

    internal var hasSelectedText: Bool {
        nonEmptySelectedTextRanges.count > 0
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
}

