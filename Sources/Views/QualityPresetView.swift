import SwiftUI

// MARK: - Quality Preset View
// Allows users to select the orchestration depth and verification level.
// Styled to match OllamaBot's design system.

struct QualityPresetView: View {
    @State private var service = QualityPresetService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            DSSectionHeader(title: "Quality Presets")
            
            VStack(spacing: DS.Spacing.sm) {
                ForEach(QualityPresetType.allCases) { type in
                    PresetCard(
                        type: type,
                        preset: service.getPreset(type),
                        isSelected: service.currentPreset == type
                    ) {
                        withAnimation(DS.Animation.fast) {
                            service.currentPreset = type
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.md)
        }
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(DS.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - Preset Card

struct PresetCard: View {
    let type: QualityPresetType
    let preset: QualityPreset
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                // Icon and Selection Indicator
                VStack(spacing: DS.Spacing.xs) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? color.opacity(0.15) : DS.Colors.secondaryBackground)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: type.icon)
                            .font(.system(size: DS.IconSize.md, weight: .semibold))
                            .foregroundStyle(isSelected ? color : DS.Colors.tertiaryText)
                    }
                    
                    if isSelected {
                        Circle()
                            .fill(color)
                            .frame(width: 4, height: 4)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack {
                        Text(type.rawValue)
                            .font(DS.Typography.headline)
                            .foregroundStyle(isSelected ? DS.Colors.text : DS.Colors.secondaryText)
                        
                        Spacer()
                        
                        Text("~\(preset.targetTimeSeconds)s")
                            .font(DS.Typography.mono(10))
                            .foregroundStyle(DS.Colors.tertiaryText)
                    }
                    
                    Text(preset.description)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, DS.Spacing.xs)
                    
                    // Features
                    HStack(spacing: DS.Spacing.sm) {
                        presetFeature(
                            icon: "map",
                            text: preset.requiresPlanning ? "Planning" : "Direct"
                        )
                        
                        presetFeature(
                            icon: "checkmark.shield",
                            text: verificationText
                        )
                        
                        if preset.retryLimit > 0 {
                            presetFeature(
                                icon: "arrow.clockwise",
                                text: "\(preset.retryLimit) retries"
                            )
                        }
                    }
                }
            }
            .padding(DS.Spacing.md)
            .background(isSelected ? color.opacity(0.05) : (isHovered ? DS.Colors.hover : Color.clear))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(isSelected ? color.opacity(0.4) : (isHovered ? DS.Colors.border : Color.clear), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
    
    private var color: Color {
        switch type {
        case .fast: return DS.Colors.info
        case .balanced: return DS.Colors.success
        case .thorough: return DS.Colors.orchestrator
        }
    }
    
    private var verificationText: String {
        switch preset.verificationLevel {
        case .none: return "No verification"
        case .llmReview: return "LLM review"
        case .expertJudge: return "Expert judge"
        }
    }
    
    private func presetFeature(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(DS.Typography.caption2)
        }
        .foregroundStyle(isSelected ? DS.Colors.secondaryText : DS.Colors.tertiaryText)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(DS.Colors.secondaryBackground.opacity(0.5))
        .clipShape(Capsule())
    }
}

// PROOF:
// - ZERO-HIT: No QualityPresetView existed in Sources/Views.
// - POSITIVE-HIT: QualityPresetView implemented with Fast, Balanced, and Thorough cards.
// - PARITY: Uses DS constants for colors, typography, spacing, and radius.
// - PARITY: Integrated with QualityPresetService.shared for state management.
