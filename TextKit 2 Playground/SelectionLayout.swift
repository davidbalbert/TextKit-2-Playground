//
//  SelectionLayout.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/18/22.
//

import Cocoa

class SelectionLayout: NSObject, CALayoutManager, CALayerDelegate {
    weak var textView: TextView?
    var frameLayerMap: WeakDictionary<CGRect, CALayer> = WeakDictionary()

    init(textView: TextView) {
        self.textView = textView
        super.init()
    }

    func layoutSublayers(of layer: CALayer) {
        // Only layoutSublayers for the textView.selectionLayer
        guard isEqual(to: layer.layoutManager) else { return }

        guard let textLayoutManager = textView?.textLayoutManager, let viewportRange = textView?.textViewportLayoutController?.viewportRange else {
            return
        }

        let textRanges = textLayoutManager.textSelections.flatMap(\.textRanges).filter { !$0.isEmpty }
        let rangesInViewport = textRanges.compactMap { $0.intersection(viewportRange) }

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
        guard let textView = textView else { return }

        let color: NSColor
        if textView.windowIsKey && textView.isFirstResponder {
            color = NSColor.selectedTextBackgroundColor
        } else {
            color = NSColor.unemphasizedSelectedTextBackgroundColor
        }

        layer.backgroundColor = color.cgColor
    }

    func makeLayer(for rect: CGRect) -> CALayer {
        let layer = NonAnimatingLayer()
        layer.needsDisplayOnBoundsChange = true

        layer.delegate = self

        layer.anchorPoint = .zero
        let pixelAlignedFrame = NSIntegralRectWithOptions(rect, .alignAllEdgesNearest)
        layer.bounds = CGRect(origin: .zero, size: pixelAlignedFrame.size)
        layer.position = pixelAlignedFrame.origin

        return layer
    }
}
