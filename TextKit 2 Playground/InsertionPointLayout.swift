//
//  InsertionPointLayout.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/18/22.
//

import Cocoa

class InsertionPointLayout: NSObject, CALayoutManager, CALayerDelegate {
    weak var textView: TextView?
    var frameLayerMap: WeakDictionary<CGRect, CALayer> = WeakDictionary()

    init(textView: TextView) {
        self.textView = textView
        super.init()
    }

    func layoutSublayers(of layer: CALayer) {
        guard isEqual(to: layer.layoutManager) else { return }

        guard let textLayoutManager = textView?.textLayoutManager, let viewportRange = textView?.textViewportLayoutController?.viewportRange, let insertionPointTextRanges = textView?.insertionPointTextRanges else {
            return
        }

        let rangesInViewport = insertionPointTextRanges.compactMap { $0.intersection(viewportRange) }

        // TODO: use layer.sublayers.difference? That could be fun.
        layer.sublayers = nil

        for textRange in rangesInViewport {
            textLayoutManager.enumerateTextSegments(in: textRange, type: .selection, options: .rangeNotRequired) { _, segmentFrame, _, _ in
                let l = frameLayerMap[segmentFrame] ?? makeLayer(for: segmentFrame)
                frameLayerMap[segmentFrame] = l
                layer.addSublayer(l)

                return true
            }
        }
    }

    func display(_ layer: CALayer) {
        layer.backgroundColor = NSColor.black.cgColor
    }

    func makeLayer(for rect: CGRect) -> CALayer {
        let layer = NonAnimatingLayer()
        layer.needsDisplayOnBoundsChange = true

        layer.delegate = self

        layer.anchorPoint = .zero

        var insertionPointFrame = NSIntegralRectWithOptions(rect, .alignAllEdgesNearest)
        insertionPointFrame.size.width = 1

        layer.bounds = CGRect(origin: .zero, size: insertionPointFrame.size)
        layer.position = insertionPointFrame.origin

        return layer
    }
}
