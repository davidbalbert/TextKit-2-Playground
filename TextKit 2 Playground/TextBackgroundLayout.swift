//
//  TextBackgroundLayout.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 7/2/22.
//

import Cocoa

class TextBackgroundLayout: NSObject, CALayerDelegate, NSViewLayerContentScaleDelegate {
    weak var textView: TextView?
    var parentLayer: CALayer
    var frameLayerMap: WeakDictionary<CGRect, CALayer> = WeakDictionary()

    init(textView: TextView, layer: CALayer) {
        self.textView = textView
        self.parentLayer = layer
        super.init()
    }

    func textView(_ textView: TextView, textViewportLayoutControllerWillLayout textViewportLayoutController: NSTextViewportLayoutController) {
        parentLayer.sublayers = nil
    }

    func textView(_ textView: TextView, textViewportLayoutController: NSTextViewportLayoutController, configureRenderingSurfaceFor textLayoutFragment: NSTextLayoutFragment) {

        textView.enumerateBackgroundColorFrames(in: textLayoutFragment) { frame, color in
            let l = frameLayerMap[frame] ?? makeLayer(for: frame, color: color)
            frameLayerMap[frame] = l
            parentLayer.addSublayer(l)
        }
    }

    func makeLayer(for rect: CGRect, color: NSColor) -> CALayer {
        let layer = NonAnimatingLayer()
        layer.setValue(color, forKey: "nsColor")

        layer.anchorPoint = .zero
        layer.bounds = CGRect(origin: .zero, size: rect.size)
        layer.position = rect.origin
        layer.contentsScale = textView?.window?.backingScaleFactor ?? 1.0

        layer.delegate = self
        layer.setNeedsDisplay()

        return layer
    }

    func display(_ layer: CALayer) {
        guard let textView = textView, let color = layer.value(forKey: "nsColor") as? NSColor else {
            return
        }

        textView.effectiveAppearance.performAsCurrentDrawingAppearance {
            layer.backgroundColor = color.cgColor
        }
    }

    func layer(_ layer: CALayer, shouldInheritContentsScale newScale: CGFloat, from window: NSWindow) -> Bool {
        true
    }
}
