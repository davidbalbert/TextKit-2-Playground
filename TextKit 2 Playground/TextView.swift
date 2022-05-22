//
//  TextView.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 5/11/22.
//

import Cocoa

class TextView: NSView, NSTextViewportLayoutControllerDelegate {
    class func scrollableTextView() -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true

        let textView = Self()
        textView.autoresizingMask = [.width, .height]

        scrollView.documentView = textView

        return scrollView
    }

    @Invalidating(.layout, .display) var textContentStorage = NSTextContentStorage()
    @Invalidating(.layout, .display) var textContainer = NSTextContainer()
    @Invalidating(.layout, .display) var textLayoutManager = NSTextLayoutManager() {
        willSet {
            textLayoutManager.textViewportLayoutController.delegate = nil
        }
        didSet {
            textLayoutManager.textViewportLayoutController.delegate = self
            // This is done in the LayoutWithTextKit2 sample, but I don't think it's necessary.
            // If we invalidate layout when we set textLayoutManager, we'll call viewportLayoutController.layoutViewport()
            // which will call updateFrameHeight when we're done. We probably do need updateTextContainerSize. If the
            // textLayoutManager has a new textContainer, it has to be updated.
            updateFrameHeightIfNeeded()
            updateTextContainerSize()
        }
    }

    private var viewportLayoutController: NSTextViewportLayoutController {
        textLayoutManager.textViewportLayoutController
    }

    private var layoutFragments: [NSTextLayoutFragment] = []

    var textStorage: NSTextStorage {
        get {
            if let textStorage = textContentStorage.textStorage {
                return textStorage
            } else {
                let textStorage = NSTextStorage()
                textContentStorage.textStorage = textStorage
                return textStorage
            }
        }
        set {
            textContentStorage.textStorage = newValue
        }
    }

    var string: String {
        get {
            textContentStorage.textStorage?.string ?? ""
        }
        set {
            if let textStorage = textContentStorage.textStorage {
                textStorage.mutableString.setString(newValue)
            } else {
                textContentStorage.textStorage = NSTextStorage(string: newValue)
            }
        }
    }

    override var isFlipped: Bool {
        true
    }

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
        textLayoutManager.textViewportLayoutController.delegate = self
        textContentStorage.addTextLayoutManager(textLayoutManager)
    }

    override func layout() {
        super.layout()
        viewportLayoutController.layoutViewport()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.textBackgroundColor.set()
        dirtyRect.fill()

        for fragment in layoutFragments {
            fragment.draw(at: fragment.layoutFragmentFrame.origin, in: NSGraphicsContext.current!.cgContext)
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateTextContainerSize()
    }

    private func updateTextContainerSize() {
        if (textContainer.size.width != bounds.width) {
            textContainer.size = CGSize(width: frame.width, height: 0)
        }
    }

    private func updateFrameHeightIfNeeded() {
        guard let scrollView = enclosingScrollView else {
            return
        }

        let contentHeight = finalLayoutFragment?.layoutFragmentFrame.maxY ?? 0
        let viewportHeight = scrollView.contentSize.height
        let newHeight = max(contentHeight, viewportHeight)

        let currentHeight = frame.height

        if abs(currentHeight - newHeight) > 1e-10 {
            setFrameSize(NSSize(width: frame.width, height: newHeight))
        }
    }

    private var finalLayoutFragment: NSTextLayoutFragment? {
        var layoutFragment: NSTextLayoutFragment? = nil

        textLayoutManager.enumerateTextLayoutFragments(from: textLayoutManager.documentRange.endLocation, options: [.ensuresLayout, .reverse]) { fragment in
            layoutFragment = fragment
            return false
        }

        return layoutFragment
    }

    // MARK: - NSTextViewportLayoutControllerDelegate

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
        updateFrameHeightIfNeeded()
    }
}
