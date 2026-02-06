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
            
            // Memory usage indicator
            memoryIndicator
            
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
                
            Text(PerformanceTrackingService.formatCurrency(savings.netSavings))
                    .font(DS.Typography.mono(10))
                    .foregroundStyle(DS.Colors.success)
                
            Text("net")
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
    
    private var memoryIndicator: some View {
        let memory = getMemoryUsage()
        let usagePercent = memory.usedGB / memory.totalGB
        let color: Color = usagePercent > 0.9 ? DS.Colors.error : (usagePercent > 0.7 ? DS.Colors.warning : DS.Colors.secondaryText)
        
        return Button(action: { appState.showPerformanceDashboard = true }) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "memorychip")
                    .font(.caption2)
                    .foregroundStyle(color)
                
                Text(String(format: "%.1f/%.0fGB", memory.usedGB, memory.totalGB))
                    .font(DS.Typography.mono(10))
                    .foregroundStyle(color)
            }
        }
        .buttonStyle(.plain)
        .help("Memory: \(String(format: "%.1f", usagePercent * 100))% used")
    }
    
    private func getMemoryUsage() -> (usedGB: Double, totalGB: Double) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let hostPort = mach_host_self()
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return (0, 0)
        }
        
        let pageSize = Double(vm_kernel_page_size)
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
        let freeMemory = Double(stats.free_count) * pageSize
        let usedMemory = totalMemory - freeMemory
        
        return (usedMemory / 1_073_741_824, totalMemory / 1_073_741_824)
    }
}
