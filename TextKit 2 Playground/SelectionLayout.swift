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

        guard let textView = textView else { return }

        // TODO: use layer.sublayers.difference? That could be fun.
        layer.sublayers = nil

        textView.enumerateSelectionFramesInViewport { selectionFrame in
            let l = frameLayerMap[selectionFrame] ?? makeLayer(for: selectionFrame)
            frameLayerMap[selectionFrame] = l
            layer.addSublayer(l)
        }
    }

    func display(_ layer: CALayer) {
        guard let textView = textView else { return }

        layer.backgroundColor = textView.textSelectionColor.cgColor
    }

    func makeLayer(for rect: CGRect) -> CALayer {
        let layer = NonAnimatingLayer()

        layer.delegate = self

        layer.anchorPoint = .zero
        layer.bounds = CGRect(origin: .zero, size: rect.size)
        layer.position = rect.origin

        layer.setNeedsDisplay()

        return layer
    }
}
