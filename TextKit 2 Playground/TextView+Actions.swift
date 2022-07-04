//
//  TextView+Actions.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 7/4/22.
//

import Cocoa

extension TextView: NSMenuItemValidation {
    // List of all key commands for completeness testing: https://support.apple.com/en-us/HT201236
    // NSStandardKeyBindingResponding: https://developer.apple.com/documentation/appkit/nsstandardkeybindingresponding

    // MARK: - Text input

    override func insertNewline(_ sender: Any?) {
        replaceCharacters(in: selectedTextRanges, with: "\n")
    }

    // MARK: - Text deletion

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

    // MARK: - Character navigation

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

    // MARK: - Character selection

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

    // MARK: - Word selection

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

    // MARK: - Line selection

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


    // MARK: - Paragraph selection

    override func moveToBeginningOfParagraphAndModifySelection(_ sender: Any?) {
        updateSelections(direction: .left, destination: .paragraph, extending: true)
    }

    override func moveToEndOfParagraphAndModifySelection(_ sender: Any?) {
        updateSelections(direction: .right, destination: .paragraph, extending: true)
    }

    // MARK: - Document navigation

    override func moveToBeginningOfDocument(_ sender: Any?) {
        updateSelections(direction: .up, destination: .document, extending: false)
    }

    override func moveToEndOfDocument(_ sender: Any?) {
        updateSelections(direction: .down, destination: .document, extending: false)
    }

    // MARK: - Document selection

    // TODO: Eventually, we need to figure out how to deal with multiple selections that become overlapped. E.g., create two selections on two separate lines, and then press Command-Shift-Down Arrow to highlight to the end of the line. We should probably only have one selection at this point. Check to see how other editors behave.

    override func moveToBeginningOfDocumentAndModifySelection(_ sender: Any?) {
        updateSelections(direction: .up, destination: .document, extending: true)
    }

    override func moveToEndOfDocumentAndModifySelection(_ sender: Any?) {
        updateSelections(direction: .down, destination: .document, extending: true)
    }

    // MARK: - Menus

    class override var defaultMenu: NSMenu? {
        let menu = NSMenu()

        menu.addItem(withTitle: "Cut", action: #selector(cut(_ :)), keyEquivalent: "")
        menu.addItem(withTitle: "Copy", action: #selector(copy(_ :)), keyEquivalent: "")
        menu.addItem(withTitle: "Paste", action: #selector(paste(_ :)), keyEquivalent: "")

        return menu
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(selectAll(_:)):
            return isSelectable
        case #selector(copy(_:)):
            return isSelectable && hasSelectedText
        case #selector(cut(_:)):
            return isEditable && hasSelectedText
        case #selector(paste(_:)):
            return isEditable && NSPasteboard.general.canReadObject(forClasses: pastableTypes)
        default:
            return true
        }
    }

    // MARK: - Pasteboard

    @objc func cut(_ sender: Any) {
        copy(sender)

        replaceCharacters(in: nonEmptySelectedTextRanges, with: "")
    }

    @objc func copy(_ sender: Any) {
        let nsRanges = nonEmptySelectedTextRanges.compactMap { NSRange($0, in: textContentStorage) }
        let attributedStrings = nsRanges.map { textStorage.attributedSubstring(from: $0) }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(attributedStrings)
    }

    private var pastableTypes: [AnyClass] { [NSAttributedString.self, NSString.self] }

    @objc func paste(_ sender: Any) {
        guard let objects = NSPasteboard.general.readObjects(forClasses: pastableTypes) else { return }

        switch objects.first {
        case let attributedString as NSAttributedString:
            replaceCharacters(in: selectedTextRanges, with: attributedString)
        case let string as String:
            replaceCharacters(in: selectedTextRanges, with: string)
        default:
            break
        }
    }

    @objc override func selectAll(_ sender: Any?) {
        guard isSelectable else { return }

        textSelections = [NSTextSelection(range: textLayoutManager.documentRange, affinity: .downstream, granularity: .character)]

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
    }
}
