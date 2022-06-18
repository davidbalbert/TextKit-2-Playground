//
//  SelectionLayout.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/18/22.
//

import Cocoa

class SelectionLayoutManager: NSObject, CALayoutManager {
    weak var textView: TextView?

    init(textView: TextView) {
        self.textView = textView
        super.init()
    }

    func layoutSublayers(of layer: CALayer) {
        guard let textView = textView else { return }

        guard let textLayoutManager = textView.textLayoutManager, let viewportRange = textView.textViewportLayoutController?.viewportRange else {
            return
        }

        layer.sublayers = nil

        let textRanges = textLayoutManager.textSelections.flatMap(\.textRanges).filter { !$0.isEmpty }
        let rangesInViewport = textRanges.compactMap { $0.intersection(viewportRange) }

        let color: NSColor
        if textView.windowIsKey && textView.isFirstResponder {
            color = NSColor.selectedTextBackgroundColor
        } else {
            color = NSColor.unemphasizedSelectedTextBackgroundColor
        }

        for textRange in rangesInViewport {
            textLayoutManager.enumerateTextSegments(in: textRange, type: .selection, options: .rangeNotRequired) { _, segmentFrame, _, _ in
                let l = NonAnimatingLayer()
                l.anchorPoint = CGPoint(x: 0, y: 0)

                let pixelAlignedFrame = NSIntegralRectWithOptions(segmentFrame, .alignAllEdgesNearest)
                l.bounds = CGRect(origin: .zero, size: pixelAlignedFrame.size)
                l.position = pixelAlignedFrame.origin
                l.backgroundColor = color.cgColor

                layer.addSublayer(l)

                return true
            }
        }
    }
}
