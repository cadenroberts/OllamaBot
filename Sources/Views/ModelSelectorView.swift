import SwiftUI

struct ModelSelectorView: View {
    @Environment(AppState.self) private var appState
    
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
                        .font(.caption)
                } else {
                    Image(systemName: "sparkles")
                        .foregroundStyle(DS.Colors.secondaryText)
                    Text("Auto")
                        .font(.caption)
                }
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
            )
        }
        .menuStyle(.borderlessButton)
    }
}
