import SwiftUI

// MARK: - Design System (Installer Version)

enum InstallerDS {
    enum Colors {
        static let background = Color(hex: "1a1b26")
        static let surface = Color(hex: "1f2335")
        static let secondaryBg = Color(hex: "24283b")
        static let text = Color(hex: "c0caf5")
        static let secondaryText = Color(hex: "9aa5ce")
        static let tertiaryText = Color(hex: "565f89")
        static let accent = Color(hex: "7dcfff")
        static let accentAlt = Color(hex: "2ac3de")
        static let success = Color(hex: "73c0ff")
        static let error = Color(hex: "5a8fd4")
        static let border = Color(hex: "3b4261")
    }
    
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
    
    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - Main Content View

struct InstallerContentView: View {
    @Environment(InstallerState.self) private var state
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with logo and progress
            installerHeader
            
            Divider()
                .background(InstallerDS.Colors.border)
            
            // Content area
            contentArea
            
            Divider()
                .background(InstallerDS.Colors.border)
            
            // Footer with navigation
            installerFooter
        }
        .background(InstallerDS.Colors.background)
        .preferredColorScheme(.dark)
    }
    
    private var installerHeader: some View {
        VStack(spacing: InstallerDS.Spacing.md) {
            HStack {
                // Logo
                ZStack {
                    Circle()
                        .strokeBorder(
                            LinearGradient(colors: [InstallerDS.Colors.accent, InstallerDS.Colors.accentAlt], startPoint: .leading, endPoint: .trailing),
                            lineWidth: 3
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "infinity")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(InstallerDS.Colors.accent)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("OllamaBot Installer")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(InstallerDS.Colors.text)
                    
                    Text("Local AI, Infinite Possibilities")
                        .font(.caption)
                        .foregroundStyle(InstallerDS.Colors.secondaryText)
                }
                
                Spacer()
                
                // Step indicator
                Text("Step \(state.currentStep.rawValue + 1) of \(InstallerState.Step.allCases.count)")
                    .font(.caption)
                    .foregroundStyle(InstallerDS.Colors.tertiaryText)
            }
            
            // Progress bar
            progressBar
        }
        .padding(InstallerDS.Spacing.lg)
        .background(InstallerDS.Colors.surface)
    }
    
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(InstallerDS.Colors.secondaryBg)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(colors: [InstallerDS.Colors.accent, InstallerDS.Colors.accentAlt], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * progressPercent)
                    .animation(.easeInOut(duration: 0.3), value: state.currentStep)
            }
        }
        .frame(height: 6)
    }
    
    private var progressPercent: Double {
        Double(state.currentStep.rawValue) / Double(InstallerState.Step.allCases.count - 1)
    }
    
    @ViewBuilder
    private var contentArea: some View {
        ScrollView {
            switch state.currentStep {
            case .welcome:
                WelcomeView()
            case .requirements:
                RequirementsView()
            case .tierSelection:
                TierSelectionView()
            case .modelCustomization:
                ModelCustomizationView()
            case .download:
                DownloadProgressView()
            case .installation:
                InstallationView()
            case .complete:
                CompletionView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var installerFooter: some View {
        HStack {
            if state.currentStep.rawValue > 0 && state.currentStep != .download && state.currentStep != .installation {
                Button("Back") {
                    state.previousStep()
                }
                .buttonStyle(.plain)
                .foregroundStyle(InstallerDS.Colors.secondaryText)
            }
            
            Spacer()
            
            if state.currentStep == .complete {
                Button("Launch OllamaBot") {
                    launchApp()
                }
                .buttonStyle(InstallerButtonStyle())
            } else if state.currentStep != .download && state.currentStep != .installation {
                Button(state.currentStep == .modelCustomization ? "Install" : "Continue") {
                    state.nextStep()
                }
                .buttonStyle(InstallerButtonStyle())
                .disabled(!state.canContinue)
            }
        }
        .padding(InstallerDS.Spacing.lg)
        .background(InstallerDS.Colors.surface)
    }
    
    private func launchApp() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/OllamaBot.app"))
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: InstallerDS.Spacing.xl) {
            Spacer()
            
            // Large logo
            ZStack {
                Circle()
                    .strokeBorder(
                        LinearGradient(colors: [InstallerDS.Colors.accent, InstallerDS.Colors.accentAlt], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 4
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "infinity")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [InstallerDS.Colors.accent, InstallerDS.Colors.accentAlt], startPoint: .leading, endPoint: .trailing))
            }
            
            VStack(spacing: InstallerDS.Spacing.sm) {
                Text("Welcome to OllamaBot")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(InstallerDS.Colors.text)
                
                Text("The local AI IDE with multi-model orchestration")
                    .font(.title3)
                    .foregroundStyle(InstallerDS.Colors.secondaryText)
            }
            
            // Features
            VStack(alignment: .leading, spacing: InstallerDS.Spacing.md) {
                featureRow(icon: "infinity", text: "Infinite Mode - autonomous AI agent")
                featureRow(icon: "brain", text: "Multi-Model Orchestration - 4 specialized AIs")
                featureRow(icon: "lock.shield", text: "100% Local - your code never leaves your Mac")
                featureRow(icon: "bolt.fill", text: "Apple Silicon Optimized - native performance")
            }
            .padding(InstallerDS.Spacing.xl)
            .background(InstallerDS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: InstallerDS.Radius.lg))
            
            Spacer()
        }
        .padding(InstallerDS.Spacing.xxl)
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: InstallerDS.Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(InstallerDS.Colors.accent)
                .frame(width: 24)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(InstallerDS.Colors.text)
        }
    }
}

// MARK: - Requirements View

struct RequirementsView: View {
    @Environment(InstallerState.self) private var state
    
    var body: some View {
        VStack(spacing: InstallerDS.Spacing.xl) {
            Text("System Requirements")
                .font(.title2.weight(.semibold))
                .foregroundStyle(InstallerDS.Colors.text)
            
            VStack(spacing: InstallerDS.Spacing.md) {
                requirementRow(
                    title: "macOS Version",
                    value: state.macOSVersion,
                    requirement: "14.0+",
                    passed: true
                )
                
                requirementRow(
                    title: "System RAM",
                    value: "\(state.systemRAM) GB",
                    requirement: "16 GB+ recommended",
                    passed: state.systemRAM >= 16
                )
                
                requirementRow(
                    title: "Available Disk",
                    value: String(format: "%.0f GB", state.diskSpaceGB),
                    requirement: "50 GB+ for models",
                    passed: state.diskSpaceGB >= 50
                )
                
                requirementRow(
                    title: "Processor",
                    value: state.isAppleSilicon ? "Apple Silicon" : "Intel",
                    requirement: "Apple Silicon recommended",
                    passed: state.isAppleSilicon
                )
                
                Divider()
                    .background(InstallerDS.Colors.border)
                
                requirementRow(
                    title: "Ollama",
                    value: state.ollamaInstalled ? (state.ollamaRunning ? "Running" : "Installed") : "Not Found",
                    requirement: "Required",
                    passed: state.ollamaInstalled
                )
            }
            .padding(InstallerDS.Spacing.lg)
            .background(InstallerDS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: InstallerDS.Radius.lg))
            
            if !state.ollamaInstalled {
                VStack(spacing: InstallerDS.Spacing.sm) {
                    Text("Ollama is required to run local AI models")
                        .font(.caption)
                        .foregroundStyle(InstallerDS.Colors.secondaryText)
                    
                    Button("Install Ollama") {
                        Task {
                            _ = await state.installOllama()
                        }
                    }
                    .buttonStyle(InstallerButtonStyle())
                }
            }
        }
        .padding(InstallerDS.Spacing.xxl)
        .task {
            await state.checkOllama()
        }
    }
    
    private func requirementRow(title: String, value: String, requirement: String, passed: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(InstallerDS.Colors.text)
                
                Text(requirement)
                    .font(.caption)
                    .foregroundStyle(InstallerDS.Colors.tertiaryText)
            }
            
            Spacer()
            
            HStack(spacing: InstallerDS.Spacing.sm) {
                Text(value)
                    .font(.callout)
                    .foregroundStyle(InstallerDS.Colors.secondaryText)
                
                Image(systemName: passed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(passed ? InstallerDS.Colors.success : InstallerDS.Colors.error)
            }
        }
    }
}

// MARK: - Tier Selection View

struct TierSelectionView: View {
    @Environment(InstallerState.self) private var state
    
    var body: some View {
        @Bindable var bindableState = state
        
        VStack(spacing: InstallerDS.Spacing.xl) {
            VStack(spacing: InstallerDS.Spacing.sm) {
                Text("Select Model Tier")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(InstallerDS.Colors.text)
                
                Text("Based on your \(state.systemRAM)GB RAM, we recommend \(state.selectedTier.rawValue)")
                    .font(.caption)
                    .foregroundStyle(InstallerDS.Colors.secondaryText)
            }
            
            VStack(spacing: InstallerDS.Spacing.sm) {
                ForEach(ModelTier.allCases) { tier in
                    TierCard(
                        tier: tier,
                        isSelected: state.selectedTier == tier,
                        isAvailable: state.systemRAM >= tier.minRAM,
                        isRecommended: tier.minRAM <= state.systemRAM && tier.minRAM > (ModelTier.allCases.first(where: { $0.minRAM > state.systemRAM })?.minRAM ?? 0)
                    ) {
                        bindableState.selectedTier = tier
                    }
                }
            }
        }
        .padding(InstallerDS.Spacing.xxl)
    }
}

struct TierCard: View {
    let tier: ModelTier
    let isSelected: Bool
    let isAvailable: Bool
    let isRecommended: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(tier.rawValue)
                            .font(.callout.weight(.medium))
                        
                        if isRecommended {
                            Text("RECOMMENDED")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(InstallerDS.Colors.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(InstallerDS.Colors.accent.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(tier.description)
                        .font(.caption)
                        .foregroundStyle(InstallerDS.Colors.tertiaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(tier.minRAM)GB+ RAM")
                        .font(.caption)
                    Text(tier.diskRequired)
                        .font(.caption)
                        .foregroundStyle(InstallerDS.Colors.tertiaryText)
                }
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? InstallerDS.Colors.accent : InstallerDS.Colors.tertiaryText)
                    .font(.title3)
            }
            .padding(InstallerDS.Spacing.md)
            .background(isSelected ? InstallerDS.Colors.accent.opacity(0.1) : InstallerDS.Colors.surface)
            .foregroundStyle(isAvailable ? InstallerDS.Colors.text : InstallerDS.Colors.tertiaryText)
            .clipShape(RoundedRectangle(cornerRadius: InstallerDS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: InstallerDS.Radius.md)
                    .strokeBorder(isSelected ? InstallerDS.Colors.accent : InstallerDS.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1.0 : 0.5)
    }
}

// MARK: - Model Customization View

struct ModelCustomizationView: View {
    @Environment(InstallerState.self) private var state
    
    var body: some View {
        @Bindable var bindableState = state
        
        VStack(spacing: InstallerDS.Spacing.xl) {
            VStack(spacing: InstallerDS.Spacing.sm) {
                Text("Customize Models")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(InstallerDS.Colors.text)
                
                Text("Select which AI models to install (1-4)")
                    .font(.caption)
                    .foregroundStyle(InstallerDS.Colors.secondaryText)
            }
            
            VStack(spacing: InstallerDS.Spacing.md) {
                ModelToggleRow(
                    icon: "brain",
                    name: "Orchestrator",
                    model: state.customConfig.orchestrator.name,
                    isEnabled: $bindableState.customConfig.orchestrator.enabled,
                    description: "Plans and delegates tasks"
                )
                
                ModelToggleRow(
                    icon: "chevron.left.forwardslash.chevron.right",
                    name: "Coder",
                    model: state.customConfig.coder.name,
                    isEnabled: $bindableState.customConfig.coder.enabled,
                    description: "Writes and reviews code"
                )
                
                ModelToggleRow(
                    icon: "magnifyingglass.circle",
                    name: "Researcher",
                    model: state.customConfig.researcher.name,
                    isEnabled: $bindableState.customConfig.researcher.enabled,
                    description: "Searches and analyzes"
                )
                
                ModelToggleRow(
                    icon: "eye",
                    name: "Vision",
                    model: state.customConfig.vision.name,
                    isEnabled: $bindableState.customConfig.vision.enabled,
                    description: "Analyzes images"
                )
            }
            .padding(InstallerDS.Spacing.lg)
            .background(InstallerDS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: InstallerDS.Radius.lg))
            
            // Summary
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(state.customConfig.enabledCount) models selected")
                        .font(.callout.weight(.medium))
                    Text(String(format: "~%.0f GB disk space required", state.customConfig.totalDiskRequired))
                        .font(.caption)
                        .foregroundStyle(InstallerDS.Colors.tertiaryText)
                }
                
                Spacer()
                
                if state.customConfig.enabledCount == 0 {
                    Text("Select at least 1 model")
                        .font(.caption)
                        .foregroundStyle(InstallerDS.Colors.error)
                }
            }
            .padding(InstallerDS.Spacing.md)
            .background(InstallerDS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: InstallerDS.Radius.md))
        }
        .padding(InstallerDS.Spacing.xxl)
        .onChange(of: state.customConfig.enabledCount) { _, count in
            state.canContinue = count > 0
        }
    }
}

struct ModelToggleRow: View {
    let icon: String
    let name: String
    let model: String
    @Binding var isEnabled: Bool
    let description: String
    
    var body: some View {
        HStack {
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.checkbox)
            
            Image(systemName: icon)
                .foregroundStyle(isEnabled ? InstallerDS.Colors.accent : InstallerDS.Colors.tertiaryText)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(isEnabled ? InstallerDS.Colors.text : InstallerDS.Colors.tertiaryText)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(InstallerDS.Colors.tertiaryText)
            }
            
            Spacer()
            
            Text(model)
                .font(.caption)
                .foregroundStyle(InstallerDS.Colors.secondaryText)
        }
        .padding(InstallerDS.Spacing.sm)
        .background(isEnabled ? InstallerDS.Colors.accent.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: InstallerDS.Radius.sm))
    }
}

// MARK: - Download Progress View

struct DownloadProgressView: View {
    @Environment(InstallerState.self) private var state
    
    var body: some View {
        VStack(spacing: InstallerDS.Spacing.xl) {
            Spacer()
            
            // Progress indicator
            ZStack {
                Circle()
                    .stroke(InstallerDS.Colors.secondaryBg, lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: state.downloadProgress)
                    .stroke(
                        LinearGradient(colors: [InstallerDS.Colors.accent, InstallerDS.Colors.accentAlt], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: state.downloadProgress)
                
                Text("\(Int(state.downloadProgress * 100))%")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(InstallerDS.Colors.text)
            }
            
            VStack(spacing: InstallerDS.Spacing.sm) {
                Text("Downloading Models")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(InstallerDS.Colors.text)
                
                Text(state.currentDownload)
                    .font(.callout)
                    .foregroundStyle(InstallerDS.Colors.secondaryText)
            }
            
            if let error = state.downloadError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(InstallerDS.Colors.error)
                    .padding()
                    .background(InstallerDS.Colors.error.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: InstallerDS.Radius.sm))
            }
            
            Spacer()
        }
        .padding(InstallerDS.Spacing.xxl)
        .task {
            await state.downloadModels()
            if state.downloadError == nil {
                state.nextStep()
            }
        }
    }
}

// MARK: - Installation View

struct InstallationView: View {
    @Environment(InstallerState.self) private var state
    
    var body: some View {
        VStack(spacing: InstallerDS.Spacing.xl) {
            Spacer()
            
            ProgressView()
                .scaleEffect(2)
                .tint(InstallerDS.Colors.accent)
            
            VStack(spacing: InstallerDS.Spacing.sm) {
                Text("Installing OllamaBot")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(InstallerDS.Colors.text)
                
                Text(state.installStatus)
                    .font(.callout)
                    .foregroundStyle(InstallerDS.Colors.secondaryText)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(InstallerDS.Colors.secondaryBg)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [InstallerDS.Colors.accent, InstallerDS.Colors.accentAlt], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * state.installProgress)
                        .animation(.easeInOut(duration: 0.3), value: state.installProgress)
                }
            }
            .frame(height: 8)
            .frame(maxWidth: 300)
            
            Spacer()
        }
        .padding(InstallerDS.Spacing.xxl)
        .task {
            await state.installApp()
            state.nextStep()
        }
    }
}

// MARK: - Completion View

struct CompletionView: View {
    @Environment(InstallerState.self) private var state
    
    var body: some View {
        VStack(spacing: InstallerDS.Spacing.xl) {
            Spacer()
            
            // Success checkmark
            ZStack {
                Circle()
                    .fill(InstallerDS.Colors.success.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(InstallerDS.Colors.success)
            }
            
            VStack(spacing: InstallerDS.Spacing.sm) {
                Text("Installation Complete!")
                    .font(.title.weight(.bold))
                    .foregroundStyle(InstallerDS.Colors.text)
                
                Text("OllamaBot is ready to use")
                    .font(.title3)
                    .foregroundStyle(InstallerDS.Colors.secondaryText)
            }
            
            // Summary
            VStack(alignment: .leading, spacing: InstallerDS.Spacing.md) {
                summaryRow(icon: "checkmark.circle.fill", text: "Tier: \(state.selectedTier.rawValue)")
                summaryRow(icon: "checkmark.circle.fill", text: "\(state.customConfig.enabledCount) models installed")
                summaryRow(icon: "checkmark.circle.fill", text: "Configuration saved")
            }
            .padding(InstallerDS.Spacing.lg)
            .background(InstallerDS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: InstallerDS.Radius.lg))
            
            Spacer()
        }
        .padding(InstallerDS.Spacing.xxl)
    }
    
    private func summaryRow(icon: String, text: String) -> some View {
        HStack(spacing: InstallerDS.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(InstallerDS.Colors.success)
            Text(text)
                .font(.callout)
                .foregroundStyle(InstallerDS.Colors.text)
        }
    }
}

// MARK: - Button Style

struct InstallerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .foregroundStyle(InstallerDS.Colors.background)
            .padding(.horizontal, InstallerDS.Spacing.lg)
            .padding(.vertical, InstallerDS.Spacing.sm)
            .background(
                LinearGradient(colors: [InstallerDS.Colors.accent, InstallerDS.Colors.accentAlt], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: InstallerDS.Radius.md))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
