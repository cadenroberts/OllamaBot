import SwiftUI

// MARK: - OllamaBot Design System
// A cohesive, distinctive visual language inspired by terminal aesthetics and neural networks

enum DS {
    
    // MARK: - Brand Identity
    
    enum Brand {
        static let name = "OllamaBot"
        static let tagline = "Local AI, Infinite Possibilities"
        
        // Primary brand gradient - deep space / neural aesthetic
        static let gradient = LinearGradient(
            colors: [Color("BrandPrimary"), Color("BrandSecondary")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // Fallback gradient if assets not loaded
        static let fallbackGradient = LinearGradient(
            colors: [Color(hex: "1a1b26"), Color(hex: "24283b")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Color Palette (Tokyo Night inspired - distinctive, not generic)
    
    enum Colors {
        // Core backgrounds - deep, rich darks
        static let background = Color(hex: "1a1b26")
        static let secondaryBackground = Color(hex: "24283b")
        static let tertiaryBackground = Color(hex: "414868")
        static let surface = Color(hex: "1f2335")
        
        // Text hierarchy
        static let text = Color(hex: "c0caf5")
        static let secondaryText = Color(hex: "9aa5ce")
        static let tertiaryText = Color(hex: "565f89")
        static let mutedText = Color(hex: "3b4261")
        
        // Brand accent - vibrant cyan/teal (distinctive, not purple)
        static let accent = Color(hex: "7dcfff")
        static let accentAlt = Color(hex: "2ac3de")
        
        // Semantic colors
        static let success = Color(hex: "9ece6a")
        static let warning = Color(hex: "e0af68")
        static let error = Color(hex: "f7768e")
        static let info = Color(hex: "7aa2f7")
        
        // Model colors - each AI has a distinct personality
        static let orchestrator = Color(hex: "bb9af7")  // Qwen3 - purple, the thinker
        static let researcher = Color(hex: "7aa2f7")    // Command-R - blue, analytical
        static let coder = Color(hex: "ff9e64")         // Qwen-Coder - orange, creative
        static let vision = Color(hex: "9ece6a")        // Qwen-VL - green, perceptive
        
        // Syntax highlighting (editor)
        static let codeBackground = Color(hex: "1a1b26")
        static let codeBorder = Color(hex: "3b4261")
        static let lineNumbers = Color(hex: "3b4261")
        static let currentLine = Color(hex: "292e42")
        
        // Syntax tokens
        static let keyword = Color(hex: "bb9af7")
        static let string = Color(hex: "9ece6a")
        static let number = Color(hex: "ff9e64")
        static let comment = Color(hex: "565f89")
        static let function = Color(hex: "7aa2f7")
        static let type = Color(hex: "2ac3de")
        static let variable = Color(hex: "c0caf5")
        static let constant = Color(hex: "ff9e64")
        
        // UI Elements
        static let border = Color(hex: "3b4261")
        static let divider = Color(hex: "292e42")
        static let selection = Color(hex: "33467c")
        static let hover = Color(hex: "292e42")
        
        // Gradients
        static let infinityGradient = LinearGradient(
            colors: [orchestrator, accentAlt],
            startPoint: .leading,
            endPoint: .trailing
        )
        
        static let headerGradient = LinearGradient(
            colors: [surface, background],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Typography (System fonts, well-tuned)
    
    enum Typography {
        // Display
        static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let title2 = Font.system(size: 17, weight: .semibold, design: .default)
        static let title3 = Font.system(size: 15, weight: .medium, design: .default)
        
        // Body
        static let headline = Font.system(size: 14, weight: .semibold, design: .default)
        static let body = Font.system(size: 13, weight: .regular, design: .default)
        static let callout = Font.system(size: 12, weight: .regular, design: .default)
        
        // Supporting
        static let caption = Font.system(size: 11, weight: .regular, design: .default)
        static let caption2 = Font.system(size: 10, weight: .medium, design: .default)
        
        // Monospace for code
        static func mono(_ size: CGFloat = 12) -> Font {
            .system(size: size, weight: .regular, design: .monospaced)
        }
        
        static func monoBold(_ size: CGFloat = 12) -> Font {
            .system(size: size, weight: .semibold, design: .monospaced)
        }
    }
    
    // MARK: - Spacing (8pt grid system)
    
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    
    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 20
        static let pill: CGFloat = 999
    }
    
    // MARK: - Shadows
    
    enum Shadow {
        static let sm = Color.black.opacity(0.15)
        static let md = Color.black.opacity(0.25)
        static let lg = Color.black.opacity(0.35)
        static let glow = Colors.accent.opacity(0.3)
    }
    
    // MARK: - Animation (Snappy, responsive)
    
    enum Animation {
        static let instant = SwiftUI.Animation.easeOut(duration: 0.1)
        static let fast = SwiftUI.Animation.easeOut(duration: 0.15)
        static let medium = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.4)
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let bouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
        
        // Micro-interactions
        static let hover = SwiftUI.Animation.easeOut(duration: 0.12)
        static let press = SwiftUI.Animation.easeOut(duration: 0.08)
    }
    
    // MARK: - Icon Sizes
    
    enum IconSize {
        static let xs: CGFloat = 12
        static let sm: CGFloat = 14
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - App Logo

struct DSLogo: View {
    var size: CGFloat = 32
    var animated: Bool = false
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .strokeBorder(
                    DS.Colors.infinityGradient,
                    lineWidth: size * 0.08
                )
                .frame(width: size, height: size)
            
            // Infinity symbol
            Image(systemName: "infinity")
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(DS.Colors.infinityGradient)
                .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            if animated {
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
        }
    }
}

// MARK: - Reusable Components

struct DSButton: View {
    enum Style { case primary, secondary, destructive, ghost, accent }
    enum Size { case sm, md, lg }
    
    let title: String
    let icon: String?
    let style: Style
    let size: Size
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    init(_ title: String, icon: String? = nil, style: Style = .primary, size: Size = .md, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .medium))
                }
                Text(title)
                    .font(font)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.97 : 1)
            .brightness(isHovered ? 0.05 : 0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(DS.Animation.press) { isPressed = true } }
                .onEnded { _ in withAnimation(DS.Animation.press) { isPressed = false } }
        )
    }
    
    private var font: Font {
        switch size {
        case .sm: return DS.Typography.caption
        case .md: return DS.Typography.callout
        case .lg: return DS.Typography.body
        }
    }
    
    private var iconSize: CGFloat {
        switch size {
        case .sm: return DS.IconSize.xs
        case .md: return DS.IconSize.sm
        case .lg: return DS.IconSize.md
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch size {
        case .sm: return DS.Spacing.sm
        case .md: return DS.Spacing.md
        case .lg: return DS.Spacing.lg
        }
    }
    
    private var verticalPadding: CGFloat {
        switch size {
        case .sm: return DS.Spacing.xs
        case .md: return DS.Spacing.sm
        case .lg: return DS.Spacing.md
        }
    }
    
    private var background: some ShapeStyle {
        switch style {
        case .primary: return AnyShapeStyle(DS.Colors.accent)
        case .secondary: return AnyShapeStyle(DS.Colors.secondaryBackground)
        case .destructive: return AnyShapeStyle(DS.Colors.error)
        case .ghost: return AnyShapeStyle(Color.clear)
        case .accent: return AnyShapeStyle(DS.Colors.infinityGradient)
        }
    }
    
    private var foreground: Color {
        switch style {
        case .primary, .destructive, .accent: return DS.Colors.background
        case .secondary: return DS.Colors.text
        case .ghost: return DS.Colors.accent
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .ghost: return DS.Colors.border
        default: return .clear
        }
    }
}

struct DSTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var onSubmit: (() -> Void)? = nil
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: DS.IconSize.sm))
                    .foregroundStyle(isFocused ? DS.Colors.accent : DS.Colors.tertiaryText)
                    .animation(DS.Animation.fast, value: isFocused)
            }
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.text)
                .focused($isFocused)
                .onSubmit { onSubmit?() }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(isFocused ? DS.Colors.accent : DS.Colors.border, lineWidth: 1)
                .animation(DS.Animation.fast, value: isFocused)
        )
    }
}

struct DSCard<Content: View>: View {
    var padding: CGFloat = DS.Spacing.md
    let content: Content
    
    init(padding: CGFloat = DS.Spacing.md, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .strokeBorder(DS.Colors.border, lineWidth: 1)
            )
    }
}

struct DSBadge: View {
    let text: String
    var color: Color = DS.Colors.accent
    var size: DSButton.Size = .sm
    
    var body: some View {
        Text(text)
            .font(size == .sm ? DS.Typography.caption2 : DS.Typography.caption)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct DSIconButton: View {
    let icon: String
    var size: CGFloat = 28
    var iconSize: CGFloat? = nil
    var color: Color = DS.Colors.secondaryText
    var hoverColor: Color? = nil
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize ?? size * 0.5, weight: .medium))
                .frame(width: size, height: size)
                .foregroundStyle(isHovered ? (hoverColor ?? DS.Colors.accent) : color)
                .background(isHovered ? DS.Colors.hover : .clear)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                .scaleEffect(isPressed ? 0.9 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DS.Animation.hover) { isHovered = hovering }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(DS.Animation.press) { isPressed = true } }
                .onEnded { _ in withAnimation(DS.Animation.press) { isPressed = false } }
        )
    }
}

struct DSDivider: View {
    var vertical: Bool = false
    
    var body: some View {
        Rectangle()
            .fill(DS.Colors.divider)
            .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
    }
}

// MARK: - View Modifiers

extension View {
    func dsCard(padding: CGFloat = DS.Spacing.md) -> some View {
        self
            .padding(padding)
            .background(DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .strokeBorder(DS.Colors.border, lineWidth: 1)
            )
    }
    
    func dsOverlay() -> some View {
        self
            .background(DS.Colors.surface.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .strokeBorder(DS.Colors.border, lineWidth: 1)
            )
            .shadow(color: DS.Shadow.lg, radius: 30, y: 10)
    }
    
    func dsHoverEffect() -> some View {
        self.modifier(HoverEffectModifier())
    }
}

struct HoverEffectModifier: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .brightness(isHovered ? 0.03 : 0)
            .animation(DS.Animation.hover, value: isHovered)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Loading States

struct DSLoadingSpinner: View {
    var size: CGFloat = 20
    var color: Color = DS.Colors.accent
    
    @State private var rotation: Double = 0
    
    var body: some View {
        Circle()
            .trim(from: 0.2, to: 1)
            .stroke(color, style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

struct DSPulse: View {
    @State private var isPulsing = false
    var color: Color = DS.Colors.accent
    var size: CGFloat = 8
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .fill(color)
                    .scaleEffect(isPulsing ? 2 : 1)
                    .opacity(isPulsing ? 0 : 0.5)
            )
            .onAppear {
                withAnimation(.easeOut(duration: 1).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
    }
}

struct DSShimmer: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        LinearGradient(
            colors: [
                DS.Colors.surface,
                DS.Colors.tertiaryBackground,
                DS.Colors.surface
            ],
            startPoint: .init(x: phase - 0.5, y: 0.5),
            endPoint: .init(x: phase + 0.5, y: 0.5)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 1.5
            }
        }
    }
}

// MARK: - Toast Notifications

enum ToastType {
    case success, error, warning, info
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return DS.Colors.success
        case .error: return DS.Colors.error
        case .warning: return DS.Colors.warning
        case .info: return DS.Colors.info
        }
    }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let type: ToastType
    let message: String
    var duration: Double = 3.0
    
    static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id
    }
}

struct DSToastView: View {
    let toast: Toast
    @State private var appear = false
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: toast.type.icon)
                .font(.system(size: DS.IconSize.md))
                .foregroundStyle(toast.type.color)
            
            Text(toast.message)
                .font(DS.Typography.callout)
                .foregroundStyle(DS.Colors.text)
            
            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(toast.type.color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: DS.Shadow.md, radius: 15, y: 5)
        .scaleEffect(appear ? 1 : 0.9)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(DS.Animation.spring) { appear = true }
        }
    }
}

struct DSToastContainer: View {
    @Binding var toasts: [Toast]
    
    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(toasts) { toast in
                DSToastView(toast: toast)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                            withAnimation(DS.Animation.medium) {
                                toasts.removeAll { $0.id == toast.id }
                            }
                        }
                    }
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: 360)
    }
}

// MARK: - Connection Status

struct DSConnectionStatus: View {
    let isConnected: Bool
    let modelCount: Int
    
    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            DSPulse(color: isConnected ? DS.Colors.success : DS.Colors.error, size: 6)
            
            Text(isConnected ? "Connected" : "Disconnected")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
            
            if isConnected && modelCount > 0 {
                Text("•")
                    .foregroundStyle(DS.Colors.tertiaryText)
                Text("\(modelCount) models")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(DS.Colors.surface)
        .clipShape(Capsule())
    }
}

// MARK: - Empty & Error States

struct DSEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)?
    var actionTitle: String = "Get Started"
    
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(DS.Colors.surface)
                    .frame(width: 80, height: 80)
                
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
            
            VStack(spacing: DS.Spacing.sm) {
                Text(title)
                    .font(DS.Typography.title2)
                    .foregroundStyle(DS.Colors.text)
                
                Text(message)
                    .font(DS.Typography.callout)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            
            if let action = action {
                DSButton(actionTitle, icon: "arrow.right", style: .accent, action: action)
                    .padding(.top, DS.Spacing.sm)
            }
        }
        .padding(DS.Spacing.xxl)
    }
}

struct DSErrorView: View {
    let title: String
    let message: String
    var retryAction: (() -> Void)?
    
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(DS.Colors.error.opacity(0.1))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(DS.Colors.error)
            }
            
            VStack(spacing: DS.Spacing.sm) {
                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.text)
                
                Text(message)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            if let retry = retryAction {
                DSButton("Retry", icon: "arrow.clockwise", style: .secondary, action: retry)
            }
        }
        .padding(DS.Spacing.xl)
    }
}

// MARK: - Keyboard Shortcut Badge

struct DSShortcutBadge: View {
    let keys: String
    
    var body: some View {
        Text(keys)
            .font(DS.Typography.mono(10))
            .foregroundStyle(DS.Colors.tertiaryText)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xs)
                    .strokeBorder(DS.Colors.border, lineWidth: 1)
            )
    }
}

// MARK: - Progress Bar

struct DSProgressBar: View {
    let progress: Double
    var showPercentage: Bool = false
    var color: Color = DS.Colors.accent
    var height: CGFloat = 4
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(DS.Colors.surface)
                    
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(color)
                        .frame(width: geo.size.width * min(max(progress, 0), 1))
                        .animation(DS.Animation.medium, value: progress)
                }
            }
            .frame(height: height)
            
            if showPercentage {
                Text("\(Int(progress * 100))%")
                    .font(DS.Typography.mono(10))
                    .foregroundStyle(DS.Colors.secondaryText)
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }
}

// MARK: - Model Badge

struct DSModelBadge: View {
    let model: OllamaModel
    var isActive: Bool = false
    var showName: Bool = true
    
    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: model.icon)
                .font(.system(size: DS.IconSize.xs, weight: .medium))
            
            if showName {
                Text(model.displayName)
                    .font(DS.Typography.caption2)
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(
            isActive
                ? model.color.opacity(0.2)
                : DS.Colors.surface
        )
        .foregroundStyle(model.color)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(model.color.opacity(isActive ? 0.5 : 0.2), lineWidth: 1)
        )
        .animation(DS.Animation.fast, value: isActive)
    }
}

// MARK: - Section Header

struct DSSectionHeader: View {
    let title: String
    var action: (() -> Void)?
    var actionIcon: String = "plus"
    
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.tertiaryText)
                .tracking(0.5)
            
            Spacer()
            
            if let action = action {
                DSIconButton(icon: actionIcon, size: 20, color: DS.Colors.tertiaryText) {
                    action()
                }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }
}

// MARK: - Toolbar Item

struct DSToolbarItem: View {
    let icon: String
    var label: String? = nil
    var isActive: Bool = false
    var badge: Int? = nil
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: DS.IconSize.md, weight: .medium))
                    
                    if let badge = badge, badge > 0 {
                        Text("\(badge)")
                            .font(DS.Typography.mono(8))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(DS.Colors.error)
                            .clipShape(Capsule())
                            .offset(x: 8, y: -4)
                    }
                }
                
                if let label = label {
                    Text(label)
                        .font(DS.Typography.caption2)
                }
            }
            .foregroundStyle(isActive ? DS.Colors.accent : (isHovered ? DS.Colors.text : DS.Colors.secondaryText))
            .frame(width: 44, height: label != nil ? 44 : 32)
            .background(isActive ? DS.Colors.accent.opacity(0.1) : (isHovered ? DS.Colors.hover : .clear))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(DS.Animation.hover) { isHovered = hovering } }
    }
}
