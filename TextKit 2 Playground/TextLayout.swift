//
//  TextLayout.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/20/22.
//

import Cocoa

class TextLayout: NSObject, CALayoutManager, CALayerDelegate {
    weak var textView: TextView?
    var fragmentLayerMap: NSMapTable<NSTextLayoutFragment, CALayer> = .weakToWeakObjects()

    var layerBeingLayedOut: CALayer?

    init(textView: TextView) {
        self.textView = textView
        super.init()
    }

    func layoutSublayers(of layer: CALayer) {
        guard isEqual(to: layer.layoutManager) else { return }

        guard let textView = textView else { return }

        layerBeingLayedOut = layer
        textView.layoutViewport()
        layerBeingLayedOut = nil
    }

    func textView(_ textView: TextView, textViewportLayoutControllerWillLayout textViewportLayoutController: NSTextViewportLayoutController) {
        layerBeingLayedOut?.sublayers = nil
    }

    func textView(_ textView: TextView, textViewportLayoutController: NSTextViewportLayoutController, configureRenderingSurfaceFor textLayoutFragment: NSTextLayoutFragment) {
        guard let layerBeingLayedOut = layerBeingLayedOut else {
            return
        }

        let layer = fragmentLayerMap.object(forKey: textLayoutFragment) ?? makeLayer(for: textLayoutFragment, contentsScale: textView.window?.backingScaleFactor ?? 1.0)
        (layer as! TextLayoutFragmentLayer).updateGeometry()

        fragmentLayerMap.setObject(layer, forKey: textLayoutFragment)
        layerBeingLayedOut.addSublayer(layer)
    }

    func makeLayer(for textLayoutFragment: NSTextLayoutFragment, contentsScale: CGFloat) -> CALayer {
        let layer = TextLayoutFragmentLayer(textLayoutFragment: textLayoutFragment)
        layer.contentsScale = contentsScale
        return layer
    }
}
