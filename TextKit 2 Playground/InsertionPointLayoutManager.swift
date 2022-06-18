//
//  InsertionPointLayout.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/18/22.
//

import Cocoa

class InsertionPointLayoutManager: NSObject, CALayoutManager {
    weak var textView: TextView?

    init(textView: TextView) {
        self.textView = textView
        super.init()
    }

    func layoutSublayers(of layer: CALayer) {
        guard let textLayoutManager = textView?.textLayoutManager, let viewportRange = textView?.textViewportLayoutController?.viewportRange, let insertionPointTextRanges = textView?.insertionPointTextRanges else {
            return
        }

        layer.sublayers = nil

        let rangesInViewport = insertionPointTextRanges.compactMap { $0.intersection(viewportRange) }

        for textRange in rangesInViewport {
            textLayoutManager.enumerateTextSegments(in: textRange, type: .selection, options: .rangeNotRequired) { _, segmentFrame, _, _ in
                var insertionPointFrame = NSIntegralRectWithOptions(segmentFrame, .alignAllEdgesNearest)
                insertionPointFrame.size.width = 1

                let l = NonAnimatingLayer()
                l.anchorPoint = .zero
                l.bounds = CGRect(origin: .zero, size: insertionPointFrame.size)
                l.position = insertionPointFrame.origin
                l.backgroundColor = NSColor.black.cgColor

                layer.addSublayer(l)

                return true
            }
        }

    }
}
