//
//  TextView+Events.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 7/4/22.
//

import Cocoa

extension TextView {
    // MARK: - First responder
    override var acceptsFirstResponder: Bool {
        true
    }

    override var canBecomeKeyView: Bool {
        true
    }

    internal var isFirstResponder: Bool {
        window?.firstResponder == self
    }

    internal var windowIsKey: Bool {
        window?.isKeyWindow ?? false
    }

    override func becomeFirstResponder() -> Bool {
        setSelectionNeedsDisplay()
        updateInsertionPointTimer()
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        setSelectionNeedsDisplay()
        updateInsertionPointTimer()
        return super.resignFirstResponder()
    }

    override func cursorUpdate(with event: NSEvent) {
        if isSelectable {
            NSCursor.iBeam.set()
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isEditable, let inputContext = inputContext else { return }

        NSCursor.setHiddenUntilMouseMoves(true)

        if !inputContext.handleEvent(event) {
            // Not sure handleEvent returns false. Just want to know about it.
            print("inputContext didn't handle this event:", event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard isSelectable else { return }

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
}