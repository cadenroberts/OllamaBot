import SwiftUI
import AppKit

// MARK: - Custom Scrollbar

final class DSScroller: NSScroller {
    private let knobColor = NSColor(calibratedRed: 0.49, green: 0.81, blue: 1.0, alpha: 0.9) // #7DCFFF
    private let trackColor = NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.25, alpha: 0.6) // #292E42
    
    override class var isCompatibleWithOverlayScrollers: Bool { true }
    
    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {
        let path = NSBezierPath(roundedRect: slotRect.insetBy(dx: 1, dy: 1), xRadius: 3, yRadius: 3)
        trackColor.setFill()
        path.fill()
    }
    
    override func drawKnob() {
        let knobRect = self.rect(for: .knob).insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: knobRect, xRadius: 3, yRadius: 3)
        knobColor.setFill()
        path.fill()
    }
}

// MARK: - DS Scroll View (Custom Scrollbars)

struct DSScrollView<Content: View>: NSViewRepresentable {
    let showsVertical: Bool
    let showsHorizontal: Bool
    let content: Content
    
    init(
        showsVertical: Bool = true,
        showsHorizontal: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.showsVertical = showsVertical
        self.showsHorizontal = showsHorizontal
        self.content = content()
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = showsVertical
        scrollView.hasHorizontalScroller = showsHorizontal
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        
        if showsVertical {
            scrollView.verticalScroller = DSScroller()
        }
        if showsHorizontal {
            scrollView.horizontalScroller = DSScroller()
        }
        
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = hostingView
        
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            hostingView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let hostingView = nsView.documentView as? NSHostingView<Content> {
            hostingView.rootView = content
        }
    }
}

// MARK: - Auto-Scrolling Scroll View (for chat logs)

struct DSAutoScrollView<Content: View>: NSViewRepresentable {
    @Binding var scrollTrigger: Int
    let content: Content
    
    init(scrollTrigger: Binding<Int>, @ViewBuilder content: () -> Content) {
        self._scrollTrigger = scrollTrigger
        self.content = content()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.verticalScroller = DSScroller()
        
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = hostingView
        
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            hostingView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let hostingView = nsView.documentView as? NSHostingView<Content> {
            hostingView.rootView = content
        }
        
        if context.coordinator.lastTrigger != scrollTrigger {
            context.coordinator.lastTrigger = scrollTrigger
            scrollToBottom(nsView)
        }
    }
    
    private func scrollToBottom(_ scrollView: NSScrollView) {
        guard let documentView = scrollView.documentView else { return }
        let clipView = scrollView.contentView
        let maxY = max(0, documentView.bounds.height - clipView.bounds.height)
        clipView.scroll(to: NSPoint(x: 0, y: maxY))
        scrollView.reflectScrolledClipView(clipView)
    }
    
    final class Coordinator {
        var lastTrigger: Int = 0
    }
}

// MARK: - ScrollView Styling for SwiftUI ScrollView

struct DSScrollViewConfigurator: NSViewRepresentable {
    var showsVertical: Bool = true
    var showsHorizontal: Bool = false
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configureScrollView(for: view)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureScrollView(for: nsView)
        }
    }
    
    private func configureScrollView(for view: NSView) {
        guard let scrollView = view.enclosingScrollView else { return }
        scrollView.hasVerticalScroller = showsVertical
        scrollView.hasHorizontalScroller = showsHorizontal
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        
        if showsVertical {
            scrollView.verticalScroller = DSScroller()
        }
        if showsHorizontal {
            scrollView.horizontalScroller = DSScroller()
        }
    }
}

extension View {
    func dsScrollbars(showsVertical: Bool = true, showsHorizontal: Bool = false) -> some View {
        background(
            DSScrollViewConfigurator(showsVertical: showsVertical, showsHorizontal: showsHorizontal)
                .frame(width: 0, height: 0)
        )
    }
}
