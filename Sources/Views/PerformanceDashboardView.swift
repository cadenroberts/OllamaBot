import SwiftUI

// MARK: - Performance Dashboard View
// Comprehensive benchmarks, cost savings, and model performance metrics

struct PerformanceDashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: DashboardTab = .memory
    @State private var refreshTrigger = false
    @State private var processToKill: SystemMonitorService.ProcessInfo? = nil
    @State private var showKillConfirmation = false
    
    enum DashboardTab: String, CaseIterable {
        case memory = "Memory"
        case overview = "Overview"
        case models = "Models"
        case savings = "Savings"
        case history = "History"
    }
    
    private var systemMonitor: SystemMonitorService {
        appState.systemMonitor
    }
    
    private var tracker: PerformanceTrackingService {
        appState.performanceTracker
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            DSDivider()
            
            // Tab bar
            tabBar
            
            DSDivider()
            
            // Content
            DSScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    switch selectedTab {
                    case .memory:
                        memorySection
                    case .overview:
                        overviewSection
                    case .models:
                        modelsSection
                    case .savings:
                        savingsSection
                    case .history:
                        historySection
                    }
                }
                .padding(DS.Spacing.md)
            }
        }
        .background(DS.Colors.background)
        .onAppear {
            // Start system monitoring when dashboard opens
            systemMonitor.startMonitoring()
            // Refresh periodically
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                refreshTrigger.toggle()
            }
        }
        .alert("Force Quit Process?", isPresented: $showKillConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Force Quit", role: .destructive) {
                if let process = processToKill {
                    _ = systemMonitor.forceQuitProcess(pid: process.id)
                }
                processToKill = nil
            }
        } message: {
            if let process = processToKill {
                Text("Are you sure you want to force quit \"\(process.name)\"? Any unsaved changes will be lost.")
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "chart.bar.fill")
                .font(.title2)
                .foregroundStyle(DS.Colors.accent)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Performance Dashboard")
                    .font(DS.Typography.headline)
                Text("Benchmarks & Cost Savings")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            
            Spacer()
            
            // Live indicator
            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(DS.Colors.success)
                    .frame(width: 8, height: 8)
                Text("Live")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            
            // Reset button - positioned before the X button area
            DSIconButton(icon: "arrow.clockwise", size: 14) {
                tracker.resetSession()
            }
            .help("Reset Session Stats")
            
            // Spacer for the X button that's added via overlay in MainView
            Spacer()
                .frame(width: 32) // Leave room for close button overlay
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
    }
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(DS.Animation.fast) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(DS.Typography.caption.weight(selectedTab == tab ? .semibold : .regular))
                        .foregroundStyle(selectedTab == tab ? DS.Colors.accent : DS.Colors.secondaryText)
                        .padding(.vertical, DS.Spacing.sm)
                        .padding(.horizontal, DS.Spacing.md)
                        .background(selectedTab == tab ? DS.Colors.accent.opacity(0.1) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .background(DS.Colors.surface)
    }
    
    // MARK: - Overview Section
    
    private var overviewSection: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Quick stats row
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DS.Spacing.md) {
                StatCard(
                    title: "Total Tokens",
                    value: PerformanceTrackingService.formatNumber(tracker.sessionStats.totalTokens),
                    icon: "text.word.spacing",
                    color: DS.Colors.accent
                )
                
                StatCard(
                    title: "Avg TPS",
                    value: String(format: "%.1f", tracker.averageTPS),
                    subtitle: "tok/sec",
                    icon: "speedometer",
                    color: DS.Colors.success
                )
                
                StatCard(
                    title: "Avg TTFT",
                    value: String(format: "%.2f", tracker.averageTTFT),
                    subtitle: "seconds",
                    icon: "timer",
                    color: DS.Colors.warning
                )
                
                StatCard(
                    title: "Cache Hit",
                    value: String(format: "%.0f%%", tracker.cacheHitRate),
                    icon: "memorychip",
                    color: DS.Colors.coder
                )
            }
            
            // Session info
            sessionInfoCard
            
            // Cost savings highlight
            costSavingsHighlight
            
            // Best performing model
            if let best = tracker.bestPerformingModel {
                bestModelCard(model: best.name, tps: best.tps)
            }
        }
        .id(refreshTrigger) // Force refresh
    }
    
    private var sessionInfoCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundStyle(DS.Colors.accent)
                Text("Session Statistics")
                    .font(DS.Typography.callout.weight(.semibold))
                Spacer()
                Text(PerformanceTrackingService.formatDuration(tracker.sessionStats.sessionDuration))
                    .font(DS.Typography.mono(12))
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            
            DSDivider()
            
            Grid(alignment: .leading, horizontalSpacing: DS.Spacing.xl, verticalSpacing: DS.Spacing.sm) {
                GridRow {
                    StatLabel(label: "Inferences", value: "\(tracker.sessionStats.totalInferences)")
                    StatLabel(label: "Tasks Completed", value: "\(tracker.sessionStats.tasksCompleted)")
                }
                GridRow {
                    StatLabel(label: "File Operations", value: "\(tracker.sessionStats.fileOperations)")
                    StatLabel(label: "Model Switches", value: "\(tracker.sessionStats.totalModelSwitches)")
                }
                GridRow {
                    StatLabel(label: "Input Tokens", value: PerformanceTrackingService.formatNumber(tracker.sessionStats.totalInputTokens))
                    StatLabel(label: "Output Tokens", value: PerformanceTrackingService.formatNumber(tracker.sessionStats.totalOutputTokens))
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    private var costSavingsHighlight: some View {
        let savings = tracker.getCostSavingsSummary()
        
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(DS.Colors.success)
                Text("Net Savings This Session")
                    .font(DS.Typography.callout.weight(.semibold))
                Spacer()
                Text(PerformanceTrackingService.formatCurrency(savings.netSavings))
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.success)
            }
            
            DSDivider()
            
            HStack(spacing: DS.Spacing.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GPT-4 equivalent")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                    Text(PerformanceTrackingService.formatCurrency(savings.gpt4Savings))
                        .font(DS.Typography.mono(14))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("GPT-4o equivalent")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                    Text(PerformanceTrackingService.formatCurrency(savings.gpt4oSavings))
                        .font(DS.Typography.mono(14))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Claude 3 equivalent")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                    Text(PerformanceTrackingService.formatCurrency(savings.claude3Savings))
                        .font(DS.Typography.mono(14))
                }
                
                Spacer()
            }
            
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(.caption)
                    .foregroundStyle(DS.Colors.accent)
                Text("Data kept local: \(PerformanceTrackingService.formatBytes(savings.dataKeptLocal))")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.success.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.success.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func bestModelCard(model: String, tps: Double) -> some View {
        HStack {
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundStyle(DS.Colors.warning)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Fastest Model")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                Text(model)
                    .font(DS.Typography.callout.weight(.semibold))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", tps))
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.accent)
                Text("tok/sec")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    // MARK: - Models Section
    
    private var modelsSection: some View {
        VStack(spacing: DS.Spacing.md) {
            // Model comparison header
            HStack {
                Text("Model Performance Comparison")
                    .font(DS.Typography.callout.weight(.semibold))
                Spacer()
                Text("Sorted by TPS")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            
            // Model cards
            let ranking = tracker.getModelPerformanceRanking()
            
            if ranking.isEmpty {
                emptyModelState
            } else {
                ForEach(Array(ranking.enumerated()), id: \.offset) { index, item in
                    ModelPerformanceCard(
                        rank: index + 1,
                        model: item.model,
                        tps: item.tps,
                        ttft: item.ttft,
                        inferences: item.inferences
                    )
                }
            }
            
            // Apple Silicon note
            applesSiliconNote
        }
        .id(refreshTrigger)
    }
    
    private var emptyModelState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "cpu")
                .font(.system(size: 40))
                .foregroundStyle(DS.Colors.tertiaryText)
            
            Text("No model data yet")
                .font(DS.Typography.callout)
                .foregroundStyle(DS.Colors.secondaryText)
            
            Text("Start chatting to see model performance metrics")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.xl)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    private var applesSiliconNote: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "apple.logo")
                .foregroundStyle(DS.Colors.secondaryText)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Silicon Optimized")
                    .font(DS.Typography.caption.weight(.medium))
                Text("Running local 32B+ parameter models with unified memory architecture")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
            
            Spacer()
            
            // Memory usage
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f GB", tracker.currentMemoryUsageGB))
                    .font(DS.Typography.mono(12))
                Text("Memory")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    // MARK: - Savings Section
    
    private var savingsSection: some View {
        let savings = tracker.getCostSavingsSummary()
        
        return VStack(spacing: DS.Spacing.lg) {
            // Main savings card
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "banknote.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(DS.Colors.success)
                
                Text("Net Savings This Session")
                    .font(DS.Typography.callout)
                    .foregroundStyle(DS.Colors.secondaryText)
                
                Text(PerformanceTrackingService.formatCurrency(savings.netSavings))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Colors.success)
                
                Text("Local savings minus external spend")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(DS.Spacing.xl)
            .background(DS.Colors.success.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))

            // Local vs external totals
            HStack(spacing: DS.Spacing.md) {
                summaryPill(title: "Local Savings", value: savings.gpt4Savings, color: DS.Colors.success)
                summaryPill(title: "External Spend", value: savings.externalSpend, color: DS.Colors.warning)
            }
            
            // Comparison grid
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Local Savings vs APIs")
                    .font(DS.Typography.callout.weight(.semibold))
                
                DSDivider()
                
                ComparisonRow(
                    provider: "GPT-4 Turbo",
                    icon: "sparkles",
                    cost: savings.gpt4Savings,
                    color: .green
                )
                ComparisonRow(
                    provider: "GPT-4o",
                    icon: "bolt.fill",
                    cost: savings.gpt4oSavings,
                    color: .cyan
                )
                ComparisonRow(
                    provider: "Claude 3 Opus",
                    icon: "brain",
                    cost: savings.claude3Savings,
                    color: .orange
                )
                ComparisonRow(
                    provider: "Claude 3.5 Sonnet",
                    icon: "wand.and.stars",
                    cost: savings.claudeSonnetSavings,
                    color: .purple
                )
                
                DSDivider()
                
                HStack {
                    Text("External API Spend")
                        .font(DS.Typography.callout.weight(.semibold))
                    Spacer()
                    Text(PerformanceTrackingService.formatCurrency(savings.externalSpend))
                        .font(DS.Typography.mono(16).weight(.bold))
                        .foregroundStyle(DS.Colors.warning)
                }
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))

            if !savings.baselineMissingPricing.isEmpty {
                Text("Pricing unavailable for: \(savings.baselineMissingPricing.joined(separator: ", "))")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }

            // External provider spend
            externalSpendCard(savings: savings)
            
            // Monthly projection
            monthlyProjectionCard(savings: savings)
            
            // Privacy card
            privacyCard(dataKeptLocal: savings.dataKeptLocal)
        }
        .id(refreshTrigger)
    }
    
    private func monthlyProjectionCard(savings: CostSavingsSummary) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(DS.Colors.accent)
                Text("Monthly Projection")
                    .font(DS.Typography.callout.weight(.semibold))
                Spacer()
            }
            
            DSDivider()
            
            Text("At current usage rate, you could save:")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
            
            if let projection = savings.monthlyProjection {
                Text(PerformanceTrackingService.formatCurrency(projection) + "/month")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.accent)
                
                Text("Compared to cloud API costs")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
            } else {
                Text("Pricing data unavailable")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func summaryPill(title: String, value: Double?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
            
            Text(PerformanceTrackingService.formatCurrency(value))
                .font(DS.Typography.mono(14).weight(.semibold))
                .foregroundStyle(value == nil ? DS.Colors.tertiaryText : color)
        }
        .padding(DS.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func externalSpendCard(savings: CostSavingsSummary) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundStyle(DS.Colors.warning)
                Text("External Provider Spend")
                    .font(DS.Typography.callout.weight(.semibold))
                Spacer()
                Text(PerformanceTrackingService.formatCurrency(savings.externalSpend))
                    .font(DS.Typography.mono(12))
                    .foregroundStyle(DS.Colors.warning)
            }
            
            DSDivider()
            
            if savings.providerCosts.isEmpty {
                Text("No external API usage yet")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            } else {
                ForEach(savings.providerCosts) { provider in
                    HStack {
                        Text(provider.provider)
                            .font(DS.Typography.caption)
                        Spacer()
                        Text(PerformanceTrackingService.formatCurrency(provider.cost))
                            .font(DS.Typography.mono(11))
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                    .padding(.vertical, 2)
                }
            }
            
            if !savings.providersMissingPricing.isEmpty {
                DSDivider()
                Text("Pricing not configured for: \(savings.providersMissingPricing.joined(separator: ", "))")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    private func privacyCard(dataKeptLocal: Int) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "lock.shield.fill")
                .font(.title)
                .foregroundStyle(DS.Colors.accent)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("100% Private")
                    .font(DS.Typography.callout.weight(.semibold))
                Text("All data processed locally on your Mac")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(PerformanceTrackingService.formatBytes(dataKeptLocal))
                    .font(DS.Typography.mono(14))
                    .foregroundStyle(DS.Colors.success)
                Text("kept local")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.accent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    // MARK: - History Section
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Recent Inferences")
                .font(DS.Typography.callout.weight(.semibold))
            
            if tracker.recentInferences.isEmpty {
                emptyHistoryState
            } else {
                ForEach(tracker.recentInferences.suffix(20).reversed()) { inference in
                    InferenceHistoryRow(inference: inference)
                }
            }
        }
        .id(refreshTrigger)
    }
    
    private var emptyHistoryState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(DS.Colors.tertiaryText)
            
            Text("No inference history yet")
                .font(DS.Typography.callout)
                .foregroundStyle(DS.Colors.secondaryText)
            
            Text("Your AI interactions will appear here")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.xl)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    // MARK: - Memory Section
    
    private var memorySection: some View {
        VStack(spacing: DS.Spacing.lg) {
            // System memory overview
            memoryOverviewCard
            
            // Memory pressure indicator
            memoryPressureCard
            
            // Ollama processes (highlighted)
            if !systemMonitor.ollamaProcesses.isEmpty {
                ollamaProcessesCard
            }
            
            // All processes breakdown
            processListCard
        }
        .id(refreshTrigger)
    }
    
    private var memoryOverviewCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Image(systemName: "memorychip.fill")
                    .font(.title2)
                    .foregroundStyle(DS.Colors.accent)
                
                Text("System Memory")
                    .font(DS.Typography.headline)
                
                Spacer()
                
                if let lastUpdate = systemMonitor.lastUpdate {
                    Text("Updated \(timeAgoShort(lastUpdate))")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                }
                
                DSIconButton(icon: "arrow.clockwise", size: 14) {
                    systemMonitor.refresh()
                }
                .help("Refresh")
            }
            
            if let info = systemMonitor.memoryInfo {
                // Memory bar
                GeometryReader { geometry in
                    let usedWidth = geometry.size.width * CGFloat(info.usedPercent / 100)
                    
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(DS.Colors.tertiaryBackground)
                        
                        // Used portion
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(pressureColor(info.pressureLevel))
                            .frame(width: max(0, usedWidth))
                    }
                }
                .frame(height: 24)
                
                // Stats grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: DS.Spacing.md) {
                    MemoryStatBox(
                        title: "Total",
                        value: info.formattedTotal,
                        color: DS.Colors.secondaryText
                    )
                    MemoryStatBox(
                        title: "Used",
                        value: info.formattedUsed,
                        subtitle: String(format: "%.1f%%", info.usedPercent),
                        color: pressureColor(info.pressureLevel)
                    )
                    MemoryStatBox(
                        title: "Free",
                        value: info.formattedFree,
                        color: DS.Colors.success
                    )
                    MemoryStatBox(
                        title: "Wired",
                        value: ByteCountFormatter.string(fromByteCount: Int64(info.wiredRAM), countStyle: .memory),
                        color: DS.Colors.warning
                    )
                }
                
                // Detailed breakdown
                DSDivider()
                
                HStack(spacing: DS.Spacing.lg) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Active")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                        Text(ByteCountFormatter.string(fromByteCount: Int64(info.activeRAM), countStyle: .memory))
                            .font(DS.Typography.mono(12))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Inactive")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                        Text(ByteCountFormatter.string(fromByteCount: Int64(info.inactiveRAM), countStyle: .memory))
                            .font(DS.Typography.mono(12))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Compressed")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                        Text(ByteCountFormatter.string(fromByteCount: Int64(info.compressedRAM), countStyle: .memory))
                            .font(DS.Typography.mono(12))
                    }
                    
                    Spacer()
                }
            } else {
                Text("Loading memory info...")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    private var memoryPressureCard: some View {
        guard let info = systemMonitor.memoryInfo else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            HStack(spacing: DS.Spacing.md) {
                // Pressure indicator
                Circle()
                    .fill(pressureColor(info.pressureLevel))
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Memory Pressure: \(info.pressureLevel.rawValue)")
                        .font(DS.Typography.callout.weight(.medium))
                    
                    Text(pressureDescription(info.pressureLevel))
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                
                Spacer()
                
                // Recommendation
                if info.pressureLevel == .high || info.pressureLevel == .critical {
                    Button {
                        // Could trigger cache cleanup or suggest closing apps
                    } label: {
                        Text("Free Memory")
                            .font(DS.Typography.caption.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(pressureColor(info.pressureLevel))
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DS.Spacing.md)
            .background(pressureColor(info.pressureLevel).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(pressureColor(info.pressureLevel).opacity(0.3), lineWidth: 1)
            )
        )
    }
    
    private var ollamaProcessesCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(DS.Colors.accent)
                Text("Ollama Processes")
                    .font(DS.Typography.callout.weight(.semibold))
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: Int64(systemMonitor.ollamaMemoryUsage), countStyle: .memory))
                    .font(DS.Typography.mono(14))
                    .foregroundStyle(DS.Colors.accent)
            }
            
            DSDivider()
            
            ForEach(systemMonitor.ollamaProcesses) { process in
                MemoryProcessRow(
                    process: process,
                    isHighlighted: true,
                    onKill: {
                        processToKill = process
                        showKillConfirmation = true
                    }
                )
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.accent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    private var processListCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(DS.Colors.secondaryText)
                Text("All Processes by Memory")
                    .font(DS.Typography.callout.weight(.semibold))
                Spacer()
                Text("\(systemMonitor.topProcesses.count) processes")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
            
            DSDivider()
            
            // Header row
            HStack(spacing: DS.Spacing.md) {
                Text("Process")
                    .font(DS.Typography.caption.weight(.medium))
                    .foregroundStyle(DS.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Memory")
                    .font(DS.Typography.caption.weight(.medium))
                    .foregroundStyle(DS.Colors.secondaryText)
                    .frame(width: 70, alignment: .trailing)
                
                Text("CPU")
                    .font(DS.Typography.caption.weight(.medium))
                    .foregroundStyle(DS.Colors.secondaryText)
                    .frame(width: 50, alignment: .trailing)
                
                Text("User")
                    .font(DS.Typography.caption.weight(.medium))
                    .foregroundStyle(DS.Colors.secondaryText)
                    .frame(width: 60, alignment: .leading)
                
                // Space for kill button
                Spacer()
                    .frame(width: 28)
            }
            .padding(.horizontal, DS.Spacing.xs)
            
            // Process rows (exclude Ollama processes since they're shown separately)
            let nonOllamaProcesses = systemMonitor.topProcesses.filter { !$0.isOllamaRelated }
            
            ForEach(nonOllamaProcesses.prefix(15)) { process in
                MemoryProcessRow(
                    process: process,
                    isHighlighted: false,
                    onKill: {
                        processToKill = process
                        showKillConfirmation = true
                    }
                )
            }
            
            if nonOllamaProcesses.count > 15 {
                Text("+ \(nonOllamaProcesses.count - 15) more processes")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.tertiaryText)
                    .padding(.top, DS.Spacing.xs)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    // MARK: - Memory Helpers
    
    private func pressureColor(_ level: SystemMonitorService.MemoryPressureLevel) -> Color {
        switch level {
        case .normal: return DS.Colors.success
        case .moderate: return DS.Colors.accent
        case .high: return DS.Colors.warning
        case .critical: return DS.Colors.error
        }
    }
    
    private func pressureDescription(_ level: SystemMonitorService.MemoryPressureLevel) -> String {
        switch level {
        case .normal:
            return "System has plenty of memory available"
        case .moderate:
            return "Memory usage is moderate, system running smoothly"
        case .high:
            return "Consider closing unused applications to free memory"
        case .critical:
            return "System may become slow. Close applications to free memory"
        }
    }
    
    private func timeAgoShort(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 5 { return "now" }
        if seconds < 60 { return "\(Int(seconds))s ago" }
        return "\(Int(seconds/60))m ago"
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(DS.Typography.headline)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
            
            Text(title)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}

struct StatLabel: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
            Text(value)
                .font(DS.Typography.mono(13))
        }
    }
}

struct ModelPerformanceCard: View {
    let rank: Int
    let model: String
    let tps: Double
    let ttft: Double
    let inferences: Int
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                Text("\(rank)")
                    .font(DS.Typography.callout.weight(.bold))
                    .foregroundStyle(rankColor)
            }
            
            // Model info
            VStack(alignment: .leading, spacing: 2) {
                Text(model)
                    .font(DS.Typography.callout.weight(.medium))
                Text("\(inferences) inferences")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            
            Spacer()
            
            // Metrics
            HStack(spacing: DS.Spacing.lg) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f", tps))
                        .font(DS.Typography.mono(14))
                        .foregroundStyle(DS.Colors.success)
                    Text("tok/s")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                }
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.2f", ttft))
                        .font(DS.Typography.mono(14))
                    Text("TTFT")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return DS.Colors.secondaryText
        }
    }
}

struct ComparisonRow: View {
    let provider: String
    let icon: String
    let cost: Double?
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(cost == nil ? DS.Colors.tertiaryText : color)
                .frame(width: 20)
            
            Text(provider)
                .font(DS.Typography.caption)
            
            Spacer()
            
            Text(PerformanceTrackingService.formatCurrency(cost))
                .font(DS.Typography.mono(12))
                .foregroundStyle(cost == nil ? DS.Colors.tertiaryText : DS.Colors.secondaryText)
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}

struct InferenceHistoryRow: View {
    let inference: PerformanceTrackingService.InferenceMetrics
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Model indicator
            Circle()
                .fill(inference.wasWarmStart ? DS.Colors.success : DS.Colors.warning)
                .frame(width: 8, height: 8)
            
            // Model name + provider
            VStack(alignment: .leading, spacing: 2) {
                Text(inference.model)
                    .font(DS.Typography.caption.weight(.medium))
                Text(inference.provider)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
            .frame(width: 140, alignment: .leading)
            
            // Tokens
            Text("\(inference.totalTokens) tok")
                .font(DS.Typography.mono(11))
                .foregroundStyle(DS.Colors.secondaryText)
                .frame(width: 60, alignment: .trailing)
            
            // TPS
            Text(String(format: "%.1f/s", inference.tokensPerSecond))
                .font(DS.Typography.mono(11))
                .foregroundStyle(DS.Colors.success)
                .frame(width: 50, alignment: .trailing)
            
            // TTFT
            Text(String(format: "%.2fs", inference.timeToFirstToken))
                .font(DS.Typography.mono(11))
                .frame(width: 50, alignment: .trailing)
            
            Spacer()
            
            // Time
            Text(timeAgo(inference.endTime))
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.tertiaryText)
        }
        .padding(.vertical, DS.Spacing.xs)
        .padding(.horizontal, DS.Spacing.sm)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
    }
    
    private func timeAgo(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(Int(seconds/60))m ago" }
        return "\(Int(seconds/3600))h ago"
    }
}

// Type alias for convenience
typealias CostSavingsSummary = PerformanceTrackingService.CostSavingsSummary

// MARK: - Memory Tab Supporting Views

struct MemoryStatBox: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
            
            Text(value)
                .font(DS.Typography.mono(14).weight(.semibold))
                .foregroundStyle(color)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.sm)
        .background(DS.Colors.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}

struct MemoryProcessRow: View {
    let process: SystemMonitorService.ProcessInfo
    let isHighlighted: Bool
    let onKill: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Process name with icon
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: processIcon)
                    .font(.caption)
                    .foregroundStyle(isHighlighted ? DS.Colors.accent : DS.Colors.secondaryText)
                    .frame(width: 14)
                
                Text(process.name)
                    .font(DS.Typography.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Memory usage
            Text(process.formattedMemory)
                .font(DS.Typography.mono(11))
                .foregroundStyle(memoryColor)
                .frame(width: 70, alignment: .trailing)
            
            // CPU usage
            Text(String(format: "%.1f%%", process.cpuUsage))
                .font(DS.Typography.mono(11))
                .foregroundStyle(cpuColor)
                .frame(width: 50, alignment: .trailing)
            
            // User
            Text(process.user)
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.tertiaryText)
                .frame(width: 60, alignment: .leading)
                .lineLimit(1)
            
            // Kill button (show on hover)
            Button {
                onKill()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(isHovered ? DS.Colors.error : DS.Colors.tertiaryText)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.3)
            .help("Force Quit \(process.name)")
        }
        .padding(.vertical, DS.Spacing.xs)
        .padding(.horizontal, DS.Spacing.xs)
        .background(isHovered ? DS.Colors.tertiaryBackground : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var processIcon: String {
        let name = process.name.lowercased()
        if name.contains("ollama") { return "brain.head.profile" }
        if name.contains("chrome") || name.contains("safari") || name.contains("firefox") { return "globe" }
        if name.contains("code") || name.contains("cursor") || name.contains("xcode") { return "chevron.left.forwardslash.chevron.right" }
        if name.contains("slack") || name.contains("discord") || name.contains("teams") { return "message" }
        if name.contains("finder") { return "folder" }
        if name.contains("terminal") || name.contains("iterm") { return "terminal" }
        if name.contains("kernel") || name.contains("launchd") { return "gear" }
        if name.contains("dock") { return "dock.rectangle" }
        return "app"
    }
    
    private var memoryColor: Color {
        let bytes = process.memoryUsage
        if bytes > 2_000_000_000 { return DS.Colors.error }        // > 2GB
        if bytes > 500_000_000 { return DS.Colors.warning }        // > 500MB
        if bytes > 100_000_000 { return DS.Colors.accent }         // > 100MB
        return DS.Colors.secondaryText
    }
    
    private var cpuColor: Color {
        if process.cpuUsage > 80 { return DS.Colors.error }
        if process.cpuUsage > 30 { return DS.Colors.warning }
        if process.cpuUsage > 5 { return DS.Colors.accent }
        return DS.Colors.secondaryText
    }
}
