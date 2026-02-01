import SwiftUI

struct StatusBarView: View {
    @Environment(AppState.self) private var appState
    
    private var lineCount: Int {
        appState.editorContent.components(separatedBy: .newlines).count
    }
    
    private var charCount: Int {
        appState.editorContent.count
    }
    
    var body: some View {
        HStack(spacing: DS.Spacing.lg) {
            // Left: Git branch & status (uses GitService)
            if appState.rootFolder != nil && appState.gitService.isGitRepo {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.caption2)
                    Text(appState.gitService.currentBranch.isEmpty ? "HEAD" : appState.gitService.currentBranch)
                        .font(DS.Typography.caption2)
                    
                    // Show count of changes
                    if let status = appState.gitService.status,
                       status.totalChanges > 0 {
                        Text("•")
                        Text("\(status.totalChanges)")
                            .foregroundStyle(DS.Colors.warning)
                    }
                }
                .foregroundStyle(DS.Colors.secondaryText)
                
                statusDivider
            }
            
            // File info
            if let file = appState.selectedFile {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: file.icon)
                        .font(.caption2)
                        .foregroundStyle(file.iconColor)
                    
                    Text(file.name)
                        .font(DS.Typography.caption2)
                    
                    if file.isModified {
                        Circle()
                            .fill(DS.Colors.warning)
                            .frame(width: 6, height: 6)
                    }
                }
                
                statusDivider
                
                // Language (uses centralized ContextManager.languageName)
                if let ext = file.fileExtension {
                    Text(ContextManager.languageName(for: ext))
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.secondaryText)
                    
                    statusDivider
                }
            }
            
            Spacer()
            
            // Right side: Editor info
            if appState.selectedFile != nil {
                // Line & column
                HStack(spacing: DS.Spacing.xs) {
                    Text("Ln \(appState.goToLine ?? 1), Col 1")
                        .font(DS.Typography.mono(10))
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                .onTapGesture {
                    appState.showGoToLine = true
                }
                
                statusDivider
                
                // Lines & chars
                Text("\(lineCount) lines, \(charCount) chars")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
                
                statusDivider
            }
            
            // Model indicator
            modelIndicator
            
            statusDivider
            
            // Savings indicator (opens Performance Dashboard)
            savingsIndicator
            
            statusDivider
            
            // Ollama status
            connectionStatus
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .background(DS.Colors.surface)
    }
    
    private var statusDivider: some View {
        Rectangle()
            .fill(DS.Colors.border)
            .frame(width: 1, height: 12)
    }
    
    private var modelIndicator: some View {
        Button(action: { appState.showCommandPalette = true }) {
            HStack(spacing: DS.Spacing.xs) {
                if let model = appState.selectedModel {
                    Image(systemName: model.icon)
                        .foregroundStyle(model.color)
                    Text(model.displayName)
                } else {
                    Image(systemName: "sparkles")
                        .foregroundStyle(DS.Colors.accent)
                    Text("Auto")
                }
            }
            .font(DS.Typography.caption2)
            .foregroundStyle(DS.Colors.secondaryText)
        }
        .buttonStyle(.plain)
    }
    
    private var savingsIndicator: some View {
        Button(action: { appState.showPerformanceDashboard = true }) {
            let savings = appState.performanceTracker.getCostSavingsSummary()
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(DS.Colors.success)
                
                Text(PerformanceTrackingService.formatCurrency(savings.gpt4Savings))
                    .font(DS.Typography.mono(10))
                    .foregroundStyle(DS.Colors.success)
                
                Text("saved")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
        }
        .buttonStyle(.plain)
        .help("View Performance Dashboard (⌘⇧D)")
    }
    
    private var connectionStatus: some View {
        HStack(spacing: DS.Spacing.xs) {
            Circle()
                .fill(appState.ollamaService.isConnected ? DS.Colors.success : DS.Colors.error)
                .frame(width: 6, height: 6)
            
            Text(appState.ollamaService.isConnected ? "Ollama" : "Offline")
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.tertiaryText)
        }
    }
    
    // REMOVED: languageName() - now unified in ContextManager.languageName(for:)
}
