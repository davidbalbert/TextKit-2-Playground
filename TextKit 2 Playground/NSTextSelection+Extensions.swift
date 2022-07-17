//
//  NSTextSelection+Extensions.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 7/4/22.
//

import Cocoa

extension NSTextSelection {
    @objc var isMarked: Bool {
        false
    }

    @objc var unmarked: NSTextSelection {
        self
    }

    @objc var markedTextRange: NSTextRange? {
        nil
    }

    func markedSelection(for markedString: NSAttributedString, selectedRange: NSRange, in textElementProvider: NSTextElementProvider) -> MarkedTextSelection? {
        guard let firstTextRange = textRanges.first else {
            return nil
        }

        let markLocation = firstTextRange.location
        guard let markEnd = textElementProvider.location?(markLocation, offsetBy: markedString.length) else { return nil }
        guard let markedRange = NSTextRange(location: markLocation, end: markEnd) else { return nil }

        guard let selectionLocation = textElementProvider.location?(firstTextRange.location, offsetBy: selectedRange.location) else { return nil }
        guard let selectionEnd = textElementProvider.location?(selectionLocation, offsetBy: selectedRange.length) else { return nil }
        guard let selectedRange = NSTextRange(location: selectionLocation, end: selectionEnd) else { return nil}

        return MarkedTextSelection([selectedRange], affinity: affinity, granularity: granularity, markedRange: markedRange)
    }
}
