//
//  TextView.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 5/11/22.
//

import Cocoa

class TextView: NSView, NSTextContentStorageDelegate {
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

    override var isFlipped: Bool {
        true
    }

    override var isOpaque: Bool {
        true
    }

    internal var textLayoutManager = NSTextLayoutManager()
    internal var textStorage = NSTextStorage()
    internal var textContentStorage = NSTextContentStorage()
    internal var textContainer = NSTextContainer()

    internal var textViewportLayoutController: NSTextViewportLayoutController {
        textLayoutManager.textViewportLayoutController
    }

    internal var textBackgroundLayer: CALayer = NonAnimatingLayer()
    internal var selectionLayer: CALayer = NonAnimatingLayer()
    internal var textLayer: CALayer = NonAnimatingLayer()
    internal var insertionPointLayer: CALayer = NonAnimatingLayer()

    internal lazy var textBackgroundLayout = TextBackgroundLayout(textView: self, layer: textBackgroundLayer)
    internal lazy var selectionLayout = SelectionLayout(textView: self)
    internal lazy var textLayout = TextLayout(textView: self)
    internal lazy var insertionPointLayout = InsertionPointLayout(textView: self)

    var typingAttributes: [NSAttributedString.Key : Any] = [.foregroundColor: NSColor.black]

    @Invalidating(.display) var backgroundColor: NSColor = .white {
        // TODO: Maybe enforce the invariant that no text has a background color that the document has. All that text should have a transparent background color.
        didSet {
            enclosingScrollView?.backgroundColor = backgroundColor
        }
    }

    @Invalidating(.textDisplay) var textColor: NSColor = .black {
        didSet {
            typingAttributes[.foregroundColor] = textColor

            setAttributesForDocumentRange([.foregroundColor: textColor])
        }
    }

    @Invalidating(.insertionPointDisplay) var insertionPointColor: NSColor = .black

    @Invalidating(.layout) public var isRichText: Bool = true {
        didSet {
            if isRichText {
                backgroundColor = .white
                textColor = .black
                insertionPointColor = .black
            } else {
                backgroundColor = .textBackgroundColor
                textColor = .textColor
                insertionPointColor = .textColor
                removeAttributeForDocumentRange(.backgroundColor)
            }
        }
    }

    var string: String {
        get {
            textStorage.string
        }
        set {
            textStorage.setAttributedString(NSAttributedString(string: newValue))
            createInsertionPointIfNecessary()
        }
    }

    public var isSelectable: Bool = true {
        didSet {
            if !isSelectable {
                isEditable = false
                textSelections = []
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

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func commonInit() {
        textContentStorage.textStorage = textStorage
        textViewportLayoutController.delegate = self
        textContainer.size.width = bounds.width
        textContainer.size.height = 0

        textContentStorage.addTextLayoutManager(textLayoutManager)
        textContentStorage.primaryTextLayoutManager = textLayoutManager

        textLayoutManager.textContainer = textContainer

        let trackingArea = NSTrackingArea(rect: .zero, options: [.inVisibleRect, .cursorUpdate, .activeInKeyWindow], owner: self)
        addTrackingArea(trackingArea)

        createInsertionPointIfNecessary()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)

        if (textContainer.size.width != bounds.width) {
            textContainer.size = CGSize(width: frame.width, height: 0)
        }
    }

    // MARK: - Scrolling

    override class var isCompatibleWithResponsiveScrolling: Bool {
        true
    }

    override func prepareContent(in rect: NSRect) {
        textLayer.setNeedsLayout()
        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()

        super.prepareContent(in: rect)
    }

    func enumerateBackgroundColorFrames(in textLayoutFragment: NSTextLayoutFragment, using block: (CGRect, NSColor) -> Void) {
        guard let textParagraph = textLayoutFragment.textElement as? NSTextParagraph else {
            return
        }

        let attributedString = textParagraph.attributedString
        let stringRange = NSRange(location: 0, length: attributedString.length)

        attributedString.enumerateAttribute(.undrawnBackgroundColor, in: stringRange) { color, range, _ in
            guard let color = color as? NSColor else {
                return
            }

            let documentLocation = textContentStorage.documentRange.location
            let fragmentLocation = textLayoutFragment.rangeInElement.location
            let fragmentOffset = textContentStorage.offset(from: documentLocation, to: fragmentLocation)

            guard let rangeInDocument = range.offset(by: fragmentOffset) else { return }
            guard let textRange = NSTextRange(rangeInDocument, in: textContentStorage) else { return }

            textLayoutManager.enumerateTextSegments(in: textRange, type: .highlight, options: .rangeNotRequired) { _, frame, _, _ in
                block(frame.pixelAligned, color)
                return true
            }
        }
    }

    internal var insertionPointTimer: Timer?

    internal func updateFrameHeightIfNeeded() {
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

    private var finalLayoutFragment: NSTextLayoutFragment? {
        var layoutFragment: NSTextLayoutFragment? = nil

        textLayoutManager.enumerateTextLayoutFragments(from: textLayoutManager.documentRange.endLocation, options: [.ensuresLayout, .reverse]) { fragment in
            layoutFragment = fragment
            return false
        }

        return layoutFragment
    }

    // MARK: - NSTextContentStorageDelegate

    func textContentStorage(_ textContentStorage: NSTextContentStorage, textParagraphWith range: NSRange) -> NSTextParagraph? {
        if textStorage.containsAttribute(.backgroundColor, in: range) {
            let attributedString = textStorage.attributedSubstring(from: range).replacingAttribute(.backgroundColor, with: .undrawnBackgroundColor)

            return NSTextParagraph(attributedString: attributedString)
        } else {
            return nil
        }
    }

    // MARK: - View lifecycle callbacks

    private var didBecomeKeyObserver: Any?
    private var didResignKeyObserver: Any?

    override func viewDidMoveToWindow() {
        if let didBecomeKeyObserver = didBecomeKeyObserver {
            NotificationCenter.default.removeObserver(didBecomeKeyObserver)
        }

        if let didResignKeyObserver = didResignKeyObserver {
            NotificationCenter.default.removeObserver(didResignKeyObserver)
        }

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

    override func viewDidChangeEffectiveAppearance() {
        setSelectionNeedsDisplay()
        setTextNeedsDisplay()
        setInsertionPointNeedsDisplay()
    }

    // MARK: - Character manipulation

    func replaceCharacters(in textRanges: [NSTextRange], with string: String) {
        replaceCharacters(in: textRanges, with: NSAttributedString(string: string))
    }

    func replaceCharacters(in textRanges: [NSTextRange], with attributedString: NSAttributedString) {
        textContentStorage.performEditingTransaction {
            for textRange in textRanges {
                replaceCharacters(in: textRange, with: attributedString)
            }
        }
    }

    func replaceCharacters(in textRange: NSTextRange, with string: String) {
        replaceCharacters(in: textRange, with: NSAttributedString(string: string))
    }

    func replaceCharacters(in textRange: NSTextRange, with attributedString: NSAttributedString) {
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
        setAttributes(attrs, textRange: textContentStorage.documentRange)
    }

    internal func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, textRange: NSTextRange) {
        textContentStorage.performEditingTransaction {
            textStorage.setAttributes(attrs, range: NSRange(textRange, in: textContentStorage))
        }
    }

    internal func removeAttributeForDocumentRange(_ name: NSAttributedString.Key) {
        removeAttribute(name, textRange: textContentStorage.documentRange)
    }

    internal func removeAttribute(_ name: NSAttributedString.Key, textRange: NSTextRange) {
        textContentStorage.performEditingTransaction {
            textStorage.removeAttribute(name, range: NSRange(textRange, in: textContentStorage))
        }
    }
}
