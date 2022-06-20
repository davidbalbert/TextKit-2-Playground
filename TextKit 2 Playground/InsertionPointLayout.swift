//
//  InsertionPointLayout.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/18/22.
//

import Cocoa

class InsertionPointLayout: NSObject, CALayoutManager {
    weak var textView: TextView?
    var frameLayerMap: WeakDictionary<CGRect, CALayer> = WeakDictionary()

    init(textView: TextView) {
        self.textView = textView
        super.init()
    }

    func layoutSublayers(of layer: CALayer) {
        guard let textView = textView else { return }

        // TODO: use layer.sublayers.difference? That could be fun.
        layer.sublayers = nil

        textView.enumerateInsertionPointFramesInViewport { insertionPointFrame in
            let l = frameLayerMap[insertionPointFrame] ?? makeLayer(for: insertionPointFrame)
            frameLayerMap[insertionPointFrame] = l
            layer.addSublayer(l)
        }
    }

    func makeLayer(for rect: CGRect) -> CALayer {
        let layer = NonAnimatingLayer()

        layer.anchorPoint = .zero
        layer.bounds = CGRect(origin: .zero, size: rect.size)
        layer.position = rect.origin
        layer.backgroundColor = NSColor.black.cgColor

        return layer
    }
}
