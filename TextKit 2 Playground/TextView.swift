//
//  TextView.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 5/11/22.
//

import Cocoa

class TextView: NSView, NSTextViewportLayoutControllerDelegate, NSTextContentStorageDelegate, NSTextLayoutManagerDelegate {
    class func scrollableTextView() -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let textView = Self()
        textView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.documentView = textView

        return scrollView
    }

    override var frame: NSRect {
        didSet {
            textContainer.size = CGSize(width: bounds.width, height: 0)
        }
    }

    var string: String {
        textContentStorage.textStorage!.string
    }

    var textContentStorage = NSTextContentStorage()
    var textLayoutManager = NSTextLayoutManager()
    var textContainer = NSTextContainer()

    var viewportLayoutController: NSTextViewportLayoutController {
        textLayoutManager.textViewportLayoutController
    }

    var layoutFragments: [NSTextLayoutFragment] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func setup() {
        textLayoutManager.textContainer = textContainer
        textContentStorage.delegate = self
        textLayoutManager.delegate = self
        textLayoutManager.textViewportLayoutController.delegate = self
        textContentStorage.addTextLayoutManager(textLayoutManager)
        textContainer.lineFragmentPadding = 5
        print(textContainer.lineFragmentPadding)
    }

    override func layout() {
        viewportLayoutController.layoutViewport()
    }

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.textBackgroundColor.set()
        dirtyRect.fill()

        for fragment in layoutFragments {
            fragment.draw(at: fragment.layoutFragmentFrame.origin, in: NSGraphicsContext.current!.cgContext)
        }
    }

    func viewportBounds(for textViewportLayoutController: NSTextViewportLayoutController) -> CGRect {
        // TODO: make this take into account responsive scrolling overdraw with preparedContectRect
        return bounds
    }

    func textViewportLayoutControllerWillLayout(_ textViewportLayoutController: NSTextViewportLayoutController) {
        layoutFragments = []
    }

    func textViewportLayoutController(_ textViewportLayoutController: NSTextViewportLayoutController, configureRenderingSurfaceFor textLayoutFragment: NSTextLayoutFragment) {
        layoutFragments.append(textLayoutFragment)
    }

    func textViewportLayoutControllerDidLayout(_ textViewportLayoutController: NSTextViewportLayoutController) {
        print(layoutFragments.map { [$0.renderingSurfaceBounds.origin, $0.layoutFragmentFrame.origin] })
    }
}

