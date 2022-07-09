//
//  MarkedTextSelection.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 7/4/22.
//

import Cocoa

class MarkedTextSelection: NSTextSelection {
    var _markedTextRange: NSTextRange

    override var markedTextRange: NSTextRange {
        _markedTextRange
    }

    init(_ textRanges: [NSTextRange], affinity: NSTextSelection.Affinity, granularity: NSTextSelection.Granularity, markedRange: NSTextRange) {
        _markedTextRange = markedRange
        super.init(textRanges, affinity: affinity, granularity: granularity)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isMarked: Bool {
        true
    }

    override var unmarked: NSTextSelection {
        NSTextSelection(textRanges, affinity: affinity, granularity: granularity)
    }

    override func withTextRanges(_ textRanges: [NSTextRange]) -> NSTextSelection {
        return MarkedTextSelection(textRanges, affinity: affinity, granularity: granularity, markedRange: markedTextRange)
    }
}
