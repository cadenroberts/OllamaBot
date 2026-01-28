import SwiftUI

struct ModelSelectorView: View {
    @Environment(AppState.self) private var appState
    @State private var isHovering = false
    
    var body: some View {
        Menu {
            // Auto option
            Button(action: { appState.selectedModel = nil }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Auto (Smart Routing)")
                    if appState.selectedModel == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Divider()
            
            // Model options
            ForEach(OllamaModel.allCases) { model in
                Button(action: { appState.selectedModel = model }) {
                    HStack {
                        Image(systemName: model.icon)
                        VStack(alignment: .leading) {
                            Text(model.displayName)
                            Text(model.purpose)
                                .font(.caption)
                        }
                        if appState.selectedModel == model {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
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
    }
}
