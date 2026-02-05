import SwiftUI

struct ModelSelectorView: View {
    @Environment(AppState.self) private var appState
    @State private var isHovering = false
    @State private var showMenu = false
    
    var body: some View {
        Button {
            showMenu.toggle()
        } label: {
            HStack(spacing: 4) {
                if let model = appState.selectedModel {
                    Image(systemName: model.icon)
                        .foregroundStyle(model.color)
                    Text(model.displayName)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.text)
                } else {
                    Image(systemName: "sparkles")
                        .foregroundStyle(DS.Colors.accent)
                    Text("Auto")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.text)
                }
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isHovering ? DS.Colors.tertiaryBackground : DS.Colors.surface)
                    .overlay(
                        Capsule()
                            .strokeBorder(DS.Colors.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .popover(isPresented: $showMenu, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                ModelMenuRow(
                    title: "Auto (Smart Routing)",
                    subtitle: nil,
                    icon: "sparkles",
                    iconColor: DS.Colors.accent,
                    isSelected: appState.selectedModel == nil
                ) {
                    showMenu = false
                    appState.selectAndPreloadModel(nil)
                }
                
                DSDivider()
                
                ForEach(OllamaModel.allCases) { model in
                    ModelMenuRow(
                        title: model.displayName,
                        subtitle: model.purpose,
                        icon: model.icon,
                        iconColor: model.color,
                        isSelected: appState.selectedModel == model
                    ) {
                        showMenu = false
                        appState.selectAndPreloadModel(model)
                    }
                }
            }
            .padding(DS.Spacing.sm)
            .background(DS.Colors.surface)
        }
    }
}

private struct ModelMenuRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let iconColor: Color
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .frame(width: 18)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DS.Typography.callout)
                        .foregroundStyle(DS.Colors.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(DS.Colors.accent)
                        .font(.caption)
                }
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(isHovered ? DS.Colors.tertiaryBackground : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
