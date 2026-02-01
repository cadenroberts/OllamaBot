import SwiftUI

// MARK: - Performance Dashboard View
// Comprehensive benchmarks, cost savings, and model performance metrics

struct PerformanceDashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: DashboardTab = .overview
    @State private var refreshTrigger = false
    
    enum DashboardTab: String, CaseIterable {
        case overview = "Overview"
        case models = "Models"
        case savings = "Savings"
        case history = "History"
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
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    switch selectedTab {
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
            // Refresh periodically
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                refreshTrigger.toggle()
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
                Text("Cost Savings This Session")
                    .font(DS.Typography.callout.weight(.semibold))
                Spacer()
                Text(PerformanceTrackingService.formatCurrency(savings.gpt4Savings))
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
                
                Text("Total Savings This Session")
                    .font(DS.Typography.callout)
                    .foregroundStyle(DS.Colors.secondaryText)
                
                Text(PerformanceTrackingService.formatCurrency(savings.gpt4Savings))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Colors.success)
                
                Text("vs GPT-4 API pricing")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(DS.Spacing.xl)
            .background(DS.Colors.success.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            
            // Comparison grid
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("API Cost Comparison")
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
                    Text("OllamaBot (Local)")
                        .font(DS.Typography.callout.weight(.semibold))
                    Spacer()
                    Text("$0.00")
                        .font(DS.Typography.mono(16).weight(.bold))
                        .foregroundStyle(DS.Colors.success)
                }
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            
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
            
            Text(PerformanceTrackingService.formatCurrency(savings.monthlyProjection) + "/month")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.accent)
            
            Text("Compared to cloud API costs")
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.tertiaryText)
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
    let cost: Double
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            
            Text(provider)
                .font(DS.Typography.caption)
            
            Spacer()
            
            Text(PerformanceTrackingService.formatCurrency(cost))
                .font(DS.Typography.mono(12))
                .foregroundStyle(DS.Colors.secondaryText)
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
            
            // Model name
            Text(inference.model)
                .font(DS.Typography.caption.weight(.medium))
                .frame(width: 100, alignment: .leading)
            
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
