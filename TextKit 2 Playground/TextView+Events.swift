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
        guard isEditable else { return }

        NSCursor.setHiddenUntilMouseMoves(true)

        if inputContext?.handleEvent(event) ?? false {
            return
        }

        // Don't know if handleEvent ever returns false here. Just want to know about it.
        print("keyDown: inputContext didn't handle this event:", event)
    }

    override func mouseDown(with event: NSEvent) {
        guard isSelectable else { return }

        if inputContext?.handleEvent(event) ?? false {
            return
        }

        // HACK: Doing this on the next run loop tick fixes a bug with the PressAndHold input method editor.
        //
        // To reproduce the bug:
        // 1. Remove DispatchQueue.main.async
        // 2. Click in the middle of a paragraph
        // 3. Press and hold "e" until the popover from the PressAndHold IME appears
        // 4. Click somewhere in the same paragraph above the current insertion point
        // 5. The insertion point will move above the line that you clicked on
        //
        // TODO: file a feedback reporting this

        DispatchQueue.main.async {
            let point = self.convert(event.locationInWindow, from: nil)

            if event.modifierFlags.contains(.shift) && !self.textSelections.isEmpty {
                self.extendSelection(to: point)
            } else {
                self.startSelection(at: point)
            }

            self.selectionLayer.setNeedsLayout()
            self.insertionPointLayer.setNeedsLayout()
            self.updateInsertionPointTimer()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isSelectable else { return }

        if inputContext?.handleEvent(event) ?? false {
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        extendSelection(to: point)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func mouseUp(with event: NSEvent) {
        guard isSelectable else { return }

        if inputContext?.handleEvent(event) ?? false {
            return
        }

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
