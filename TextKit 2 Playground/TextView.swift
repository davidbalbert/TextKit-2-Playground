//
//  TextView.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 5/11/22.
//

import Cocoa

class TextView: NSView, NSTextViewportLayoutControllerDelegate, NSMenuItemValidation {
    class func scrollableTextView() -> NSScrollView {
        let textView = Self()

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        // TODO: when we're drawing paragraphs into CALayers, we can disable drawsBackground. Our root layer will never move, and will draw its background.
        // scrollView.drawsBackground = false
        scrollView.documentView = textView

        textView.autoresizingMask = [.width, .height]

        return scrollView
    }

    @Invalidating(.layout) var textContentStorage: NSTextContentStorage? = nil
    @Invalidating(.layout) var textLayoutManager: NSTextLayoutManager? = nil {
        willSet {
            textLayoutManager?.textViewportLayoutController.delegate = nil
        }
        didSet {
            textLayoutManager?.textViewportLayoutController.delegate = self
            // The LayoutWithTextKit2 sample also calls updateFrameHeightIfNeeded(). I don't think we need
            // to do that here. Setting textLayoutManager invalidates display. draw(_:) calls
            // viewportLayoutController.layoutViewport(), which eventually calls updateFrameHeightIfNeeded().
            updateTextContainerSize()
        }
    }

    internal var textViewportLayoutController: NSTextViewportLayoutController? {
        textLayoutManager?.textViewportLayoutController
    }

    var textContainer: NSTextContainer? {
        get {
            textLayoutManager?.textContainer
        }
        set {
            // TODO: do we have to do something smarter here (like take other TextKit objects from the textContainer)
            textLayoutManager?.textContainer = newValue
        }
    }

    var textStorage: NSTextStorage? {
        get {
            textContentStorage?.textStorage
        }
        set {
            // TODO: do we have to do something smarter here (like take other TextKit objects from the textStorage)
            textContentStorage?.textStorage = newValue
            createInsertionPointIfNecessary()
        }
    }

    var string: String {
        get {
            textContentStorage?.textStorage?.string ?? ""
        }
        set {
            if let textStorage = textContentStorage?.textStorage {
                textStorage.mutableString.setString(newValue)
            } else {
                textContentStorage?.textStorage = NSTextStorage(string: newValue)
            }

            createInsertionPointIfNecessary()
        }
    }

    override var isFlipped: Bool {
        true
    }

    override var isOpaque: Bool {
        true
    }

    @Invalidating(.layout) public var isSelectable: Bool = true {
        didSet {
            if !isSelectable {
                isEditable = false
                textLayoutManager?.textSelections = []
            }
        }
    }

    @Invalidating(.layout) public var isEditable: Bool = true {
        didSet {
            if isEditable {
                isSelectable = true
            }

            createInsertionPointIfNecessary()
            updateInsertionPointTimer()
        }
    }

    convenience override init(frame frameRect: NSRect) {
        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true // TODO: we don't actually consult this yet

        let textLayoutManager = NSTextLayoutManager()
        textLayoutManager.textContainer = textContainer

        let textContentStorage = NSTextContentStorage()
        textContentStorage.addTextLayoutManager(textLayoutManager)
        textContentStorage.primaryTextLayoutManager = textLayoutManager

        self.init(frame: frameRect, textContainer: textContainer)
    }

    init(frame frameRect: NSRect, textContainer: NSTextContainer?) {
        textLayoutManager = textContainer?.textLayoutManager
        textContentStorage = textContainer?.textLayoutManager?.textContentManager as? NSTextContentStorage
        super.init(frame: frameRect)

        textViewportLayoutController?.delegate = self

        let trackingArea = NSTrackingArea(rect: .zero, options: [.inVisibleRect, .cursorUpdate, .activeInKeyWindow], owner: self)
        addTrackingArea(trackingArea)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // Pretty sure this is unnecessary, but the LayoutWithTextKit2 sets it, so
    // we might as well. One thing that's odd: no matter what I do, I haven't
    // seen the scroll view ask me for overdraw without scrolling
    override class var isCompatibleWithResponsiveScrolling: Bool {
        true
    }

    override func prepareContent(in rect: NSRect) {
        needsLayout = true
        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        super.prepareContent(in: rect)
    }

    var fragmentLayerMap: NSMapTable<NSTextLayoutFragment, TextLayoutFragmentLayer> = .weakToWeakObjects()

    var selectionLayer: CALayer = NonAnimatingLayer()
    var contentLayer: CALayer = NonAnimatingLayer()
    var insertionPointLayer: CALayer = NonAnimatingLayer()

    lazy var selectionLayoutManager = {
        SelectionLayoutManager(textView: self)
    }()

    lazy var insertionPointLayoutManager = {
        InsertionPointLayoutManager(textView: self)
    }()

    override func layout() {
        super.layout()

        guard let layer = layer else { return }

        if selectionLayer.superlayer == nil {
            selectionLayer.layoutManager = selectionLayoutManager

            selectionLayer.anchorPoint = CGPoint(x: 0, y: 0)
            selectionLayer.name = "Selections"
            layer.addSublayer(selectionLayer)
        }

        if contentLayer.superlayer == nil {
            contentLayer.anchorPoint = CGPoint(x: 0, y: 0)
            contentLayer.name = "Content"
            layer.addSublayer(contentLayer)
        }

        if insertionPointLayer.superlayer == nil {
            insertionPointLayer.layoutManager = insertionPointLayoutManager

            insertionPointLayer.anchorPoint = CGPoint(x: 0, y: 0)
            insertionPointLayer.name = "Insertion points"
            layer.addSublayer(insertionPointLayer)
        }

        selectionLayer.bounds = layer.bounds
        contentLayer.bounds = layer.bounds
        insertionPointLayer.bounds = layer.bounds

        textViewportLayoutController?.layoutViewport()
        // TODO: it would be nice to:
        //   a) Not throw out the selection layers earch time
        //   b) not re-layout the text every time we have to re-layout the selection
        insertionPointLayer.layoutSublayers()
    }

    override func updateLayer() {
        // Noop (for now?). It's presence tells AppKit that we want to have our own backing layer.
    }

    func selectionNeedsDisplay() {
        guard let sublayers = selectionLayer.sublayers else { return }

        for layer in sublayers {
            layer.setNeedsDisplay()
        }
    }

    private var insertionPointTimer: Timer?

    // TODO: split into an onInterval and offInterval and read NSTextInsertionPointBlinkPeriodOn and NSTextInsertionPointBlinkPeriodOff from defaults
    private var insertionPointBlinkInterval: TimeInterval {
        0.5
    }

    var insertionPointTextRanges: [NSTextRange] {
        guard let textLayoutManager = textLayoutManager else {
            return []
        }

        return textLayoutManager.textSelections.flatMap(\.textRanges).filter { $0.isEmpty }
    }

    var shouldBlinkInsertionPoint: Bool {
        isEditable && insertionPointTextRanges.count > 0 && isFirstResponder && windowIsKey && superview != nil
    }

    func updateInsertionPointTimer() {
        insertionPointTimer?.invalidate()

        if shouldBlinkInsertionPoint {
            insertionPointLayer.isHidden = false

            insertionPointTimer = Timer.scheduledTimer(withTimeInterval: insertionPointBlinkInterval, repeats: true) { [weak self] timer in
                guard let self = self else { return }
                self.insertionPointLayer.isHidden.toggle()
            }
        } else {
            insertionPointLayer.isHidden = true
        }
    }

    func createInsertionPointIfNecessary() {
        if !isEditable {
            return
        }

        guard let textLayoutManager = textLayoutManager else {
            return
        }

        let textRange = NSTextRange(location: textLayoutManager.documentRange.location)
        textLayoutManager.textSelections = [NSTextSelection(range: textRange, affinity: .downstream, granularity: .character)]

    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateTextContainerSize()
    }

    private func updateTextContainerSize() {
        if (textContainer?.size.width != bounds.width) {
            textContainer?.size = CGSize(width: frame.width, height: 0)
        }
    }

    private func updateFrameHeightIfNeeded() {
        guard let scrollView = enclosingScrollView else {
            return
        }

        let contentHeight = finalLayoutFragment?.layoutFragmentFrame.maxY ?? 0
        let viewportHeight = scrollView.contentSize.height
        let newHeight = round(max(contentHeight, viewportHeight))

        let currentHeight = frame.height

        if abs(currentHeight - newHeight) > 1e-10 {
            setFrameSize(NSSize(width: frame.width, height: newHeight))
        }
    }

    private var previousFinalLayoutFragment: NSTextLayoutFragment?

    private var finalLayoutFragment: NSTextLayoutFragment? {
        guard let textLayoutManager = textLayoutManager else {
            return nil
        }

        // finalLayoutFragment is read after we finish laying out the text, but before we draw. If the viewport contains
        // the finalLayoutFragment, we don't want to invalidate it, because then we wouldn't draw it.
//        if let previousFinalLayoutFragment = previousFinalLayoutFragment, !layoutFragments.contains(previousFinalLayoutFragment) {
//            textLayoutManager.invalidateLayout(for: previousFinalLayoutFragment.rangeInElement)
//        }

        var layoutFragment: NSTextLayoutFragment? = nil

        textLayoutManager.enumerateTextLayoutFragments(from: textLayoutManager.documentRange.endLocation, options: [.ensuresLayout, .reverse]) { fragment in
            layoutFragment = fragment
            return false
        }

        previousFinalLayoutFragment = layoutFragment

        return layoutFragment
    }

    // MARK: - NSTextViewportLayoutControllerDelegate

    func viewportBounds(for textViewportLayoutController: NSTextViewportLayoutController) -> CGRect {
        var viewportBounds: CGRect
        if preparedContentRect.intersects(visibleRect) {
            viewportBounds = preparedContentRect.union(visibleRect)
        } else {
            viewportBounds = visibleRect
        }

        viewportBounds.size.width = bounds.width

        assert(viewportBounds.minY >= 0)

        return viewportBounds
    }

    func textViewportLayoutControllerWillLayout(_ textViewportLayoutController: NSTextViewportLayoutController) {
        contentLayer.sublayers = nil
    }

    func textViewportLayoutController(_ textViewportLayoutController: NSTextViewportLayoutController, configureRenderingSurfaceFor textLayoutFragment: NSTextLayoutFragment) {
        // The textLayoutFragment has a bounds and a frame, like a view, but the bounds and the
        // frame are different sizes. The layoutFragmentFrame is generally smaller and inset within
        // the renderingSurfaceBounds, but not always (blank lines have bounds that are smaller
        // than the frames).
        //
        // We want our layer's size to be set by the renderingSurfaceBounds (the actual area that
        // the layout fragment needs to draw into), and we need to set our position by the layout
        // fragment frame.
        //
        // The bounds origin seems to never be at zero, which means (conceptually) that the
        // layoutFragmentFrame is translated within the bounds. In order to use the frame's
        // origin as our position, we set our layer's anchor to be the the frame's origin
        // in the (slightly translated) coordinate space of the frame.

        let layer = fragmentLayerMap.object(forKey: textLayoutFragment) ?? TextLayoutFragmentLayer(textLayoutFragment: textLayoutFragment)
        layer.contentsScale = window?.backingScaleFactor ?? 1.0
        layer.updateGeometry()

        fragmentLayerMap.setObject(layer, forKey: textLayoutFragment)
        contentLayer.addSublayer(layer)
    }

    func textViewportLayoutControllerDidLayout(_ textViewportLayoutController: NSTextViewportLayoutController) {
        updateFrameHeightIfNeeded()
    }

    override func cursorUpdate(with event: NSEvent) {
        if isSelectable {
            NSCursor.iBeam.set()
        }
    }

    // MARK: - First responder

    override var acceptsFirstResponder: Bool {
        true
    }

    internal var isFirstResponder: Bool {
        window?.firstResponder == self
    }

    internal var windowIsKey: Bool {
        window?.isKeyWindow ?? false
    }

    override func becomeFirstResponder() -> Bool {
        selectionNeedsDisplay()
        updateInsertionPointTimer()
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        selectionNeedsDisplay()
        updateInsertionPointTimer()
        return super.resignFirstResponder()
    }

    private var didBecomeKeyObserver: Any?
    private var didResignKeyObserver: Any?

    // TODO: it's possible that viewDidMoveToWindow gets called even when window was just set to nil. If that's the case, we might be able to get rid of viewWillMove(toWindow:) and put all behavior into viewDidMoveToWindow
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if let didBecomeKeyObserver = didBecomeKeyObserver {
            NotificationCenter.default.removeObserver(didBecomeKeyObserver)
        }

        if let didResignKeyObserver = didResignKeyObserver {
            NotificationCenter.default.removeObserver(didResignKeyObserver)
        }
    }

    override func viewDidMoveToWindow() {
        guard let window = window else { return }

        didBecomeKeyObserver = NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: nil) { [weak self] notification in
            self?.selectionNeedsDisplay()
            self?.updateInsertionPointTimer()
        }

        didResignKeyObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: nil) { [weak self] notification in
            self?.selectionNeedsDisplay()
            self?.updateInsertionPointTimer()
        }
    }

    override func viewDidMoveToSuperview() {
        updateInsertionPointTimer()
    }

    // MARK: - Pasteboard

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(selectAll(_:)):
            return isSelectable
        case #selector(copy(_:)):
            return hasSelectedText
        case #selector(cut(_:)), #selector(paste(_:)):
            return false
        default:
            return true
        }
    }

    class override var defaultMenu: NSMenu? {
        let menu = NSMenu()

        menu.addItem(withTitle: "Cut", action: #selector(cut(_ :)), keyEquivalent: "")
        menu.addItem(withTitle: "Copy", action: #selector(copy(_ :)), keyEquivalent: "")
        menu.addItem(withTitle: "Paste", action: #selector(paste(_ :)), keyEquivalent: "")

        return menu
    }

    private var hasSelectedText: Bool {
        guard let textLayoutManager = textLayoutManager else {
            return false
        }

        for textSelection in textLayoutManager.textSelections {
            for textRange in textSelection.textRanges {
                if !textRange.isEmpty {
                    return true
                }
            }
        }

        return false
    }

    @objc func cut(_ sender: Any) {
    }

    @objc func copy(_ sender: Any) {
        guard let textLayoutManager = textLayoutManager, let textContentStorage = textContentStorage, let textStorage = textStorage else {
            return
        }

        let textRanges = textLayoutManager.textSelections.flatMap { $0.textRanges }.filter { !$0.isEmpty }
        let nsRanges = textRanges.compactMap { NSRange($0, in: textContentStorage) }
        let attributedStrings = nsRanges.map { textStorage.attributedSubstring(from: $0) }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(attributedStrings)
    }

    @objc func paste(_ sender: Any) {
    }

    @objc override func selectAll(_ sender: Any?) {
        guard isSelectable else { return }

        guard let textLayoutManager = textLayoutManager else {
            return
        }

        textLayoutManager.textSelections = [NSTextSelection(range: textLayoutManager.documentRange, affinity: .downstream, granularity: .character)]
        
        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
    }
}
