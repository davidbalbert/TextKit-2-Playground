//
//  TextView.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 5/11/22.
//

import Cocoa

class TextView: NSView, NSTextContentStorageDelegate, NSTextViewportLayoutControllerDelegate, NSMenuItemValidation {
    class func scrollableTextView() -> NSScrollView {
        let textView = Self()

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        // It would be nice to be able to set drawsBackground to false, but I need a way to
        // deal with background drawing during elastic scroll
        // scrollView.drawsBackground = false
        scrollView.documentView = textView

        textView.autoresizingMask = [.width, .height]

        return scrollView
    }

    @Invalidating(.layout) var textContentStorage: NSTextContentStorage? = nil {
        willSet {
            textContentStorage?.delegate = nil
        }
        didSet {
            textContentStorage?.delegate = self
        }
    }

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

    var typingAttributes: [NSAttributedString.Key : Any] = [.foregroundColor: NSColor.black]

    @Invalidating(.display) var backgroundColor: NSColor = .white {
        didSet {
            enclosingScrollView?.backgroundColor = backgroundColor

            removeAttributeForDocumentRange(.backgroundColor)
        }
    }

    @Invalidating(.textDisplay) var textColor: NSColor = .black {
        didSet {
            typingAttributes[.foregroundColor] = textColor

            setAttributesForDocumentRange([.foregroundColor: textColor])
        }
    }

    @Invalidating(.insertionPointDisplay) var insertionPointColor: NSColor = .black

    @Invalidating(.layout) var isRichText: Bool = true {
        didSet {
            if isRichText {
                backgroundColor = .white
                textColor = .black
                insertionPointColor = .black
            } else {
                backgroundColor = .textBackgroundColor
                textColor = .textColor
                insertionPointColor = .textColor
            }
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
            let attributedString = NSAttributedString(string: newValue, attributes: typingAttributes)

            if let textStorage = textContentStorage?.textStorage {
                textStorage.setAttributedString(attributedString)
            } else {
                textContentStorage?.textStorage = NSTextStorage(attributedString: attributedString)
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

    public var isSelectable: Bool = true {
        didSet {
            if !isSelectable {
                isEditable = false
                textLayoutManager?.textSelections = []
            }

            selectionLayer.setNeedsLayout()
        }
    }

    public var isEditable: Bool = true {
        didSet {
            if isEditable {
                isSelectable = true
            }

            createInsertionPointIfNecessary()
            updateInsertionPointTimer()
            insertionPointLayer.setNeedsLayout()
        }
    }

    internal var markedRanges: [NSTextRange] = []

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
        textContentStorage?.delegate = self

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
        textLayer.setNeedsLayout()
        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()

        super.prepareContent(in: rect)
    }

    internal var textBackgroundLayer: CALayer = NonAnimatingLayer()
    internal var selectionLayer: CALayer = NonAnimatingLayer()
    internal var textLayer: CALayer = NonAnimatingLayer()
    internal var insertionPointLayer: CALayer = NonAnimatingLayer()

    private lazy var textBackgroundLayout = TextBackgroundLayout(textView: self, layer: textBackgroundLayer)
    private lazy var selectionLayout = SelectionLayout(textView: self)
    private lazy var textLayout = TextLayout(textView: self)
    private lazy var insertionPointLayout = InsertionPointLayout(textView: self)

    override func layout() {
        super.layout()

        guard let layer = layer else { return }

        if textBackgroundLayer.superlayer == nil {
            textBackgroundLayer.anchorPoint = .zero
            textBackgroundLayer.name = "Text backgrounds"
            layer.addSublayer(textBackgroundLayer)
        }

        if selectionLayer.superlayer == nil {
            selectionLayer.layoutManager = selectionLayout

            selectionLayer.anchorPoint = .zero
            selectionLayer.name = "Selections"
            layer.addSublayer(selectionLayer)
        }

        if textLayer.superlayer == nil {
            textLayer.layoutManager = textLayout

            textLayer.anchorPoint = .zero
            textLayer.name = "Text"
            layer.addSublayer(textLayer)
        }

        if insertionPointLayer.superlayer == nil {
            insertionPointLayer.layoutManager = insertionPointLayout

            insertionPointLayer.anchorPoint = .zero
            insertionPointLayer.name = "Insertion points"
            layer.addSublayer(insertionPointLayer)
        }

        // TODO: I think we should be able to do this with an autoresize mask.
        selectionLayer.bounds = layer.bounds
        textLayer.bounds = layer.bounds
        insertionPointLayer.bounds = layer.bounds
    }

    override func updateLayer() {
        layer?.backgroundColor = backgroundColor.cgColor
    }

    func layoutViewport() {
        textViewportLayoutController?.layoutViewport()
    }

    override func viewDidChangeEffectiveAppearance() {
        setSelectionNeedsDisplay()
        setTextNeedsDisplay()
        setInsertionPointNeedsDisplay()
    }

    func setSelectionNeedsDisplay() {
        guard let sublayers = selectionLayer.sublayers else { return }

        for layer in sublayers {
            layer.setNeedsDisplay()
        }
    }

    func setTextNeedsDisplay() {
        guard let sublayers = textLayer.sublayers else { return }

        for layer in sublayers {
            layer.setNeedsDisplay()
        }
    }

    func setInsertionPointNeedsDisplay() {
        guard let sublayers = insertionPointLayer.sublayers else { return }

        for layer in sublayers {
            layer.setNeedsDisplay()
        }
    }

    func enumerateBackgroundColorFrames(in textLayoutFragment: NSTextLayoutFragment, using block: (CGRect, NSColor) -> Void) {
        guard let textContentStorage = textContentStorage, let textLayoutManager = textLayoutManager else {
            return
        }

        print("============")

        for lineFragment in textLayoutFragment.textLineFragments {
            lineFragment.attributedString.enumerateAttribute(.undrawnBackgroundColor, in: lineFragment.characterRange) { color, range, _ in
                guard let color = color as? NSColor else {
                    return
                }

                print(range)

                let documentLocation = textContentStorage.documentRange.location
                let fragmentLocation = textLayoutFragment.rangeInElement.location
                let fragmentOffset = textContentStorage.offset(from: documentLocation, to: fragmentLocation)

                guard let rangeInDocument = range.offset(by: fragmentOffset) else { return }
                guard let textRange = NSTextRange(rangeInDocument, in: textContentStorage) else { return }

                textLayoutManager.enumerateTextSegments(in: textRange, type: .selection, options: .rangeNotRequired) { _, frame, _, _ in
                    print(frame.pixelAligned, color)
                    block(frame.pixelAligned, color)
                    return true
                }
            }
        }
    }

    private var insertionPointTimer: Timer?

    // TODO: split into an onInterval and offInterval and read NSTextInsertionPointBlinkPeriodOn and NSTextInsertionPointBlinkPeriodOff from defaults
    private var insertionPointBlinkInterval: TimeInterval {
        0.5
    }

    var shouldDrawInsertionPoint: Bool {
        isEditable && isFirstResponder && windowIsKey && superview != nil
    }

    func updateInsertionPointTimer() {
        insertionPointTimer?.invalidate()

        if shouldDrawInsertionPoint {
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

    // MARK: - NSTextContentStorageDelegate

    func textContentStorage(_ textContentStorage: NSTextContentStorage, textParagraphWith range: NSRange) -> NSTextParagraph? {
        guard let textStorage = textStorage else {
            return nil
        }

        if textStorage.containsAttribute(.backgroundColor, in: range) {
            let attributedString = textStorage.attributedSubstring(from: range).replacingAttribute(.backgroundColor, with: .undrawnBackgroundColor)

            return NSTextParagraph(attributedString: attributedString)
        } else {
            return nil
        }
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
        textBackgroundLayout.textView(self, textViewportLayoutControllerWillLayout: textViewportLayoutController)
        textLayout.textView(self, textViewportLayoutControllerWillLayout: textViewportLayoutController)
    }

    func textViewportLayoutController(_ textViewportLayoutController: NSTextViewportLayoutController, configureRenderingSurfaceFor textLayoutFragment: NSTextLayoutFragment) {
        textBackgroundLayout.textView(self, textViewportLayoutController: textViewportLayoutController, configureRenderingSurfaceFor: textLayoutFragment)
        textLayout.textView(self, textViewportLayoutController: textViewportLayoutController, configureRenderingSurfaceFor: textLayoutFragment)
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
        setSelectionNeedsDisplay()
        updateInsertionPointTimer()
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        setSelectionNeedsDisplay()
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
            self?.setSelectionNeedsDisplay()
            self?.updateInsertionPointTimer()
        }

        didResignKeyObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: nil) { [weak self] notification in
            self?.setSelectionNeedsDisplay()
            self?.updateInsertionPointTimer()
        }
    }

    override func viewDidMoveToSuperview() {
        updateInsertionPointTimer()
    }

    // MARK: - Character manipulation

    func replaceCharacters(in textRanges: [NSTextRange], with string: String) {
        replaceCharacters(in: textRanges, with: NSAttributedString(string: string))
    }

    func replaceCharacters(in textRanges: [NSTextRange], with attributedString: NSAttributedString) {
        guard let textContentStorage = textContentStorage else {
            return
        }

        textContentStorage.performEditingTransaction {
            for textRange in textRanges {
                replaceCharacters(in: textRange, with: attributedString)
            }
        }
    }

    func replaceCharacters(in textRange: NSTextRange, with string: String) {
        replaceCharacters(in: textRange, with: NSAttributedString(string: string))
    }

    // TODO: Maybe we should work with AttributedStrings instead?
    func replaceCharacters(in textRange: NSTextRange, with attributedString: NSAttributedString) {
        guard let textContentStorage = textContentStorage, let textStorage = textStorage else {
            return
        }

        textContentStorage.performEditingTransaction {
            textStorage.replaceCharacters(in: NSRange(textRange, in: textContentStorage), with: attributedString)
        }

        textLayer.setNeedsLayout()
        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
        inputContext?.invalidateCharacterCoordinates()
    }

    // MARK: - Attribute manipulation

    internal func setAttributesForDocumentRange(_ attrs: [NSAttributedString.Key : Any]?) {
        guard let textContentStorage = textContentStorage else {
            return
        }

        setAttributes(attrs, textRange: textContentStorage.documentRange)
    }

    internal func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, textRange: NSTextRange) {
        guard let textContentStorage = textContentStorage, let textStorage = textStorage else {
            return
        }

        textContentStorage.performEditingTransaction {
            textStorage.setAttributes(attrs, range: NSRange(textRange, in: textContentStorage))
        }
    }

    internal func removeAttributeForDocumentRange(_ name: NSAttributedString.Key) {
        guard let textContentStorage = textContentStorage else {
            return
        }

        removeAttribute(name, textRange: textContentStorage.documentRange)
    }

    internal func removeAttribute(_ name: NSAttributedString.Key, textRange: NSTextRange) {
        guard let textContentStorage = textContentStorage, let textStorage = textStorage else {
            return
        }

        textContentStorage.performEditingTransaction {
            textStorage.removeAttribute(name, range: NSRange(textRange, in: textContentStorage))
        }
    }

    // MARK: - Pasteboard

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(selectAll(_:)):
            return isSelectable
        case #selector(copy(_:)):
            return isSelectable && hasSelectedText
        case #selector(cut(_:)):
            return isEditable && hasSelectedText
        case #selector(paste(_:)):
            return isEditable && NSPasteboard.general.canReadObject(forClasses: pastableTypes)
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
        nonEmptySelectedTextRanges.count > 0
    }

    @objc func cut(_ sender: Any) {
        copy(sender)

        replaceCharacters(in: nonEmptySelectedTextRanges, with: "")
    }

    @objc func copy(_ sender: Any) {
        guard let textContentStorage = textContentStorage, let textStorage = textStorage else {
            return
        }

        let nsRanges = nonEmptySelectedTextRanges.compactMap { NSRange($0, in: textContentStorage) }
        let attributedStrings = nsRanges.map { textStorage.attributedSubstring(from: $0) }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(attributedStrings)
    }

    private var pastableTypes: [AnyClass] = [NSAttributedString.self, NSString.self]

    @objc func paste(_ sender: Any) {
        guard let objects = NSPasteboard.general.readObjects(forClasses: pastableTypes) else { return }

        switch objects.first {
        case let attributedString as NSAttributedString:
            replaceCharacters(in: selectedTextRanges, with: attributedString)
        case let string as String:
            replaceCharacters(in: selectedTextRanges, with: string)
        default:
            break
        }
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
