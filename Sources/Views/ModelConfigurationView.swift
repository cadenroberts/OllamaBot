import SwiftUI

// MARK: - Model Configuration View
// Interactive UI for selecting 1-4 models with real-time performance analysis

struct ModelConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var config: ModelTierManager.CustomConfiguration
    @State private var analysis: ModelTierManager.ConfigurationAnalysis?
    @State private var showAdvancedOptions = false
    
    let tierManager: ModelTierManager
    let onSave: (ModelTierManager.CustomConfiguration) -> Void
    
    init(tierManager: ModelTierManager, onSave: @escaping (ModelTierManager.CustomConfiguration) -> Void) {
        self.tierManager = tierManager
        self.onSave = onSave
        _config = State(initialValue: tierManager.loadCustomConfiguration() ?? tierManager.createDefaultCustomConfiguration())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            DSDivider()
            
            // Content
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    // System info
                    systemInfoCard
                    
                    // Model selection
                    modelSelectionSection
                    
                    // Performance analysis
                    if let analysis = analysis {
                        performanceAnalysisCard(analysis)
                    }
                    
                    // Advanced options
                    advancedOptionsSection
                }
                .padding(DS.Spacing.lg)
            }
            
            DSDivider()
            
            // Footer
            footer
        }
        .frame(width: 600, height: 700)
        .background(DS.Colors.background)
        .onAppear {
            updateAnalysis()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Model Configuration")
                    .font(DS.Typography.title)
                    .foregroundStyle(DS.Colors.text)
                
                Text("Select 1-4 models for your workflow")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            
            Spacer()
            
            DSIconButton(icon: "xmark", size: 20) {
                dismiss()
            }
        }
        .padding(DS.Spacing.lg)
        .background(DS.Colors.surface)
    }
    
    // MARK: - System Info Card
    
    private var systemInfoCard: some View {
        HStack(spacing: DS.Spacing.lg) {
            // RAM indicator
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: "memorychip")
                    .font(.title2)
                    .foregroundStyle(DS.Colors.accent)
                
                Text("\(tierManager.systemRAM) GB")
                    .font(DS.Typography.headline)
                
                Text("System RAM")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity)
            
            DSDivider(vertical: true)
                .frame(height: 60)
            
            // Recommended tier
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(DS.Colors.accentAlt)
                
                Text(tierManager.recommendedTier.rawValue.components(separatedBy: " ").first ?? "")
                    .font(DS.Typography.headline)
                
                Text("Recommended Tier")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity)
            
            DSDivider(vertical: true)
                .frame(height: 60)
            
            // Selected models count
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: "square.stack.3d.up")
                    .font(.title2)
                    .foregroundStyle(DS.Colors.coder)
                
                Text("\(config.enabledModelCount)")
                    .font(DS.Typography.headline)
                
                Text("Models Selected")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(DS.Spacing.lg)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }
    
    // MARK: - Model Selection
    
    private var modelSelectionSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("SELECT MODELS")
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.tertiaryText)
                .tracking(0.5)
            
            ForEach($config.selectedModels) { $selection in
                ModelSelectionRow(
                    selection: $selection,
                    tierManager: tierManager,
                    onUpdate: { updateAnalysis() }
                )
            }
        }
    }
    
    // MARK: - Performance Analysis
    
    private func performanceAnalysisCard(_ analysis: ModelTierManager.ConfigurationAnalysis) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("PERFORMANCE ANALYSIS")
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.tertiaryText)
                .tracking(0.5)
            
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Status indicator
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: analysis.canFit ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(analysis.canFit ? DS.Colors.success : DS.Colors.error)
                    
                    Text(analysis.canFit ? "Configuration is valid" : "May not fit in memory")
                        .font(DS.Typography.callout.weight(.medium))
                }
                
                // Description
                Text(analysis.performanceDescription)
                    .font(DS.Typography.callout)
                    .foregroundStyle(DS.Colors.text)
                
                // Recommendation
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(DS.Colors.accent)
                    Text(analysis.recommendation)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                
                DSDivider()
                
                // Stats
                HStack(spacing: DS.Spacing.xl) {
                    // Speed rating
                    VStack(spacing: DS.Spacing.xs) {
                        Text("Speed")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                        
                        HStack(spacing: 2) {
                            ForEach(0..<10) { i in
                                Rectangle()
                                    .fill(i < analysis.speedRating ? DS.Colors.accent : DS.Colors.tertiaryBackground)
                                    .frame(width: 8, height: 16)
                                    .clipShape(RoundedRectangle(cornerRadius: 2))
                            }
                        }
                    }
                    
                    // Quality rating
                    VStack(spacing: DS.Spacing.xs) {
                        Text("Quality")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                        
                        HStack(spacing: 2) {
                            ForEach(0..<10) { i in
                                Rectangle()
                                    .fill(i < analysis.qualityRating ? DS.Colors.accentAlt : DS.Colors.tertiaryBackground)
                                    .frame(width: 8, height: 16)
                                    .clipShape(RoundedRectangle(cornerRadius: 2))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Disk space
                    VStack(spacing: DS.Spacing.xs) {
                        Text("Disk Required")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                        Text(String(format: "%.1f GB", analysis.totalDisk))
                            .font(DS.Typography.headline)
                    }
                    
                    // RAM usage
                    VStack(spacing: DS.Spacing.xs) {
                        Text("RAM Usage")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                        Text(String(format: "~%.0f GB", analysis.estimatedRAM))
                            .font(DS.Typography.headline)
                            .foregroundStyle(analysis.canFit ? DS.Colors.text : DS.Colors.error)
                    }
                }
                
                // Model list
                if !analysis.modelDescriptions.isEmpty {
                    DSDivider()
                    
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("Selected Models:")
                            .font(DS.Typography.caption.weight(.medium))
                            .foregroundStyle(DS.Colors.secondaryText)
                        
                        ForEach(analysis.modelDescriptions, id: \.self) { desc in
                            HStack(spacing: DS.Spacing.sm) {
                                Circle()
                                    .fill(DS.Colors.accent)
                                    .frame(width: 6, height: 6)
                                Text(desc)
                                    .font(DS.Typography.caption)
                            }
                        }
                    }
                }
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        }
    }
    
    // MARK: - Advanced Options
    
    private var advancedOptionsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Button(action: { withAnimation { showAdvancedOptions.toggle() } }) {
                HStack {
                    Text("Advanced Options")
                        .font(DS.Typography.caption.weight(.medium))
                    Spacer()
                    Image(systemName: showAdvancedOptions ? "chevron.up" : "chevron.down")
                }
                .foregroundStyle(DS.Colors.secondaryText)
            }
            .buttonStyle(.plain)
            
            if showAdvancedOptions {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Context Window")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                    
                    let settings = tierManager.getMemorySettings()
                    Text("\(settings.contextWindow) tokens")
                        .font(DS.Typography.mono(12))
                    
                    Text("Keep Alive")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                        .padding(.top, DS.Spacing.sm)
                    
                    Text(settings.keepAlive)
                        .font(DS.Typography.mono(12))
                }
                .padding(DS.Spacing.md)
                .background(DS.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            }
        }
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            DSButton("Reset to Default", style: .ghost) {
                config = tierManager.createDefaultCustomConfiguration()
                updateAnalysis()
            }
            
            Spacer()
            
            DSButton("Cancel", style: .secondary) {
                dismiss()
            }
            
            DSButton("Save Configuration", icon: "checkmark", style: .primary) {
                onSave(config)
                dismiss()
            }
            .disabled(!(analysis?.canFit ?? false))
        }
        .padding(DS.Spacing.lg)
        .background(DS.Colors.surface)
    }
    
    // MARK: - Helpers
    
    private func updateAnalysis() {
        analysis = tierManager.analyzeConfiguration(config)
    }
}

// MARK: - Model Selection Row

struct ModelSelectionRow: View {
    @Binding var selection: ModelTierManager.CustomConfiguration.ModelSelection
    let tierManager: ModelTierManager
    let onUpdate: () -> Void
    
    @State private var showTierPicker = false
    
    private var currentVariant: ModelTierManager.ModelVariant? {
        guard let tier = selection.tierEnum else { return nil }
        
        switch selection.role {
        case .orchestrator: return ModelTierManager.orchestratorVariants[tier]
        case .coder: return ModelTierManager.coderVariants[tier]
        case .researcher: return ModelTierManager.researcherVariants[tier]
        case .vision: return ModelTierManager.visionVariants[tier]
        }
    }
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Enable toggle
            Toggle("", isOn: $selection.enabled)
                .toggleStyle(.checkbox)
                .onChange(of: selection.enabled) { _, _ in onUpdate() }
            
            // Role icon
            Image(systemName: selection.role.icon)
                .font(.title3)
                .foregroundStyle(selection.enabled ? DS.Colors.accent : DS.Colors.tertiaryText)
                .frame(width: 24)
            
            // Role info
            VStack(alignment: .leading, spacing: 2) {
                Text(selection.role.rawValue)
                    .font(DS.Typography.callout.weight(.medium))
                    .foregroundStyle(selection.enabled ? DS.Colors.text : DS.Colors.tertiaryText)
                
                if let variant = currentVariant {
                    Text("\(variant.name) (\(variant.parameters))")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
            }
            
            Spacer()
            
            // Size indicator
            if let variant = currentVariant, selection.enabled {
                Text(String(format: "%.1f GB", variant.sizeGB))
                    .font(DS.Typography.mono(11))
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
            
            // Tier picker
            Menu {
                ForEach(tierManager.getModelOptions(for: selection.role), id: \.tier) { option in
                    Button {
                        selection.tier = option.tier.rawValue.lowercased().components(separatedBy: " ").first ?? ""
                        onUpdate()
                    } label: {
                        HStack {
                            Text("\(option.variant.name)")
                            Spacer()
                            Text("\(option.variant.parameters)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Text(selection.tier.capitalized)
                        .font(DS.Typography.caption)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(DS.Colors.accent)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(DS.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .disabled(!selection.enabled)
        }
        .padding(DS.Spacing.md)
        .background(selection.enabled ? DS.Colors.surface : DS.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .opacity(selection.enabled ? 1.0 : 0.6)
    }
}

// Preview removed - use Xcode previews instead
