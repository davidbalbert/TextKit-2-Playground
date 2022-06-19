//
//  SelectionLayout.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/18/22.
//

import Cocoa

class SelectionLayoutManager: NSObject, CALayoutManager {
    weak var textView: TextView?
    var frameLayerMap: WeakDictionary<CGRect, CALayer> = WeakDictionary()

    init(textView: TextView) {
        self.textView = textView
        super.init()
    }

    func layoutSublayers(of layer: CALayer) {
        guard let textView = textView else { return }

        guard let textLayoutManager = textView.textLayoutManager, let viewportRange = textView.textViewportLayoutController?.viewportRange else {
            return
        }

        let textRanges = textLayoutManager.textSelections.flatMap(\.textRanges).filter { !$0.isEmpty }
        let rangesInViewport = textRanges.compactMap { $0.intersection(viewportRange) }

        let color: NSColor
        if textView.windowIsKey && textView.isFirstResponder {
            color = NSColor.selectedTextBackgroundColor
        } else {
            color = NSColor.unemphasizedSelectedTextBackgroundColor
        }

        layer.sublayers = nil

        for textRange in rangesInViewport {
            textLayoutManager.enumerateTextSegments(in: textRange, type: .selection, options: .rangeNotRequired) { _, segmentFrame, _, _ in
                let l = frameLayerMap[segmentFrame] ?? makeLayer(for: segmentFrame)
                l.backgroundColor = color.cgColor

                frameLayerMap[segmentFrame] = l
                layer.addSublayer(l)

                return true
            }
        }
    }

    func makeLayer(for rect: CGRect) -> CALayer {
        let l = NonAnimatingLayer()

        l.anchorPoint = CGPoint(x: 0, y: 0)

        let pixelAlignedFrame = NSIntegralRectWithOptions(rect, .alignAllEdgesNearest)
        l.bounds = CGRect(origin: .zero, size: pixelAlignedFrame.size)
        l.position = pixelAlignedFrame.origin

        return l
    }
}
