import SwiftUI

// MARK: - Cost Dashboard View
// Token usage tracking per model per session.
// Estimated savings vs commercial API pricing.
// Session and lifetime totals displayed in dashboard widget.

// Per-model stats
// Provider costs
//
// PROOF:
// - ZERO-HIT: No existing CostDashboardView implementation.
// - POSITIVE-HIT: Complete CostDashboardView with metrics grid, savings breakdown, and lifetime totals in Sources/Views/CostDashboardView.swift.

struct CostDashboardView: View {
    @Environment(AppState.self) private var appState

    private var tracker: PerformanceTrackingService {
        appState.performanceTracker
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                // Header
                headerSection

                // Key metrics
                keyMetricsGrid

                // Savings breakdown
                savingsSection

                // Lifetime totals
                lifetimeTotalsSection

                // Per-model stats
                modelStatsSection

                // Provider costs
                providerCostsSection
            }
            .padding(DS.Spacing.lg)
        }
        .background(DS.Colors.background)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Cost Dashboard")
                    .font(DS.Typography.title)
                    .foregroundStyle(DS.Colors.text)
                Text("Session: \(PerformanceTrackingService.formatDuration(tracker.sessionStats.sessionDuration))")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }

            Spacer()

            DSButton("Reset", icon: "arrow.counterclockwise", style: .ghost, size: .sm) {
                tracker.resetSession()
            }
        }
    }

    // MARK: - Key Metrics

    private var keyMetricsGrid: some View {
        let summary = tracker.getCostSavingsSummary()

        return LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: DS.Spacing.md) {
            MetricCard(
                title: "Total Tokens",
                value: PerformanceTrackingService.formatNumber(summary.totalTokens),
                subtitle: "\(PerformanceTrackingService.formatNumber(summary.inputTokens)) in / \(PerformanceTrackingService.formatNumber(summary.outputTokens)) out",
                icon: "number",
                color: DS.Colors.accent
            )

            MetricCard(
                title: "Local Tokens",
                value: PerformanceTrackingService.formatNumber(summary.localTokens),
                subtitle: "Data kept local",
                icon: "lock.shield",
                color: DS.Colors.success
            )

            MetricCard(
                title: "External Spend",
                value: PerformanceTrackingService.formatCurrency(summary.externalSpend),
                subtitle: "\(PerformanceTrackingService.formatNumber(summary.externalTokens)) tokens",
                icon: "creditcard",
                color: summary.externalSpend > 0 ? DS.Colors.warning : DS.Colors.success
            )

            MetricCard(
                title: "Net Savings",
                value: PerformanceTrackingService.formatCurrency(summary.netSavings),
                subtitle: "vs GPT-4 Turbo",
                icon: "arrow.down.circle",
                color: DS.Colors.success
            )
        }
    }

    // MARK: - Savings Breakdown

    private var savingsSection: some View {
        let summary = tracker.getCostSavingsSummary()

        return DSCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                DSSectionHeader(title: "Savings vs Commercial APIs")

                VStack(spacing: DS.Spacing.sm) {
                    SavingsRow(label: "GPT-4 Turbo", amount: summary.gpt4Savings)
                    SavingsRow(label: "GPT-4o", amount: summary.gpt4oSavings)
                    SavingsRow(label: "Claude 3 Opus", amount: summary.claude3Savings)
                    SavingsRow(label: "Claude 3.5 Sonnet", amount: summary.claudeSonnetSavings)
                }

                DSDivider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monthly Projection")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                        Text(PerformanceTrackingService.formatCurrency(summary.monthlyProjection))
                            .font(DS.Typography.title2)
                            .foregroundStyle(DS.Colors.success)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Data Privacy")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                        Text(PerformanceTrackingService.formatBytes(summary.dataKeptLocal))
                            .font(DS.Typography.title2)
                            .foregroundStyle(DS.Colors.accent)
                    }
                }

                if !summary.baselineMissingPricing.isEmpty {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                        Text("Missing pricing data for: \(summary.baselineMissingPricing.joined(separator: ", "))")
                            .font(DS.Typography.caption)
                    }
                    .foregroundStyle(DS.Colors.tertiaryText)
                }
            }
        }
    }

    // MARK: - Lifetime Totals

    private var lifetimeTotalsSection: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                DSSectionHeader(title: "Lifetime Savings (All Sessions)")

                let lifetime = tracker.lifetimeStats
                
                HStack(spacing: DS.Spacing.xl) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Tokens")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                        Text(PerformanceTrackingService.formatNumber(lifetime.totalTokens))
                            .font(DS.Typography.title3.bold())
                            .foregroundStyle(DS.Colors.text)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Savings")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                        Text(PerformanceTrackingService.formatCurrency(lifetime.estimatedSavings))
                            .font(DS.Typography.title3.bold())
                            .foregroundStyle(DS.Colors.success)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sessions")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                        Text("\(lifetime.sessionCount)")
                            .font(DS.Typography.title3.bold())
                            .foregroundStyle(DS.Colors.accent)
                    }
                }
                .padding(.vertical, DS.Spacing.sm)
            }
        }
    }

    // MARK: - Per-Model Stats

    private var modelStatsSection: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                DSSectionHeader(title: "Model Performance")

                let ranking = tracker.getModelPerformanceRanking()

                if ranking.isEmpty {
                    Text("No inference data yet")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.tertiaryText)
                        .frame(maxWidth: .infinity)
                        .padding(DS.Spacing.lg)
                } else {
                    ForEach(ranking, id: \.model) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.model)
                                    .font(DS.Typography.mono(12))
                                    .foregroundStyle(DS.Colors.text)
                                Text("\(entry.inferences) inferences")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Colors.tertiaryText)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.1f tok/s", entry.tps))
                                    .font(DS.Typography.monoBold(12))
                                    .foregroundStyle(DS.Colors.accent)
                                Text(String(format: "TTFT: %.2fs", entry.ttft))
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Colors.secondaryText)
                            }
                        }
                        .padding(.vertical, DS.Spacing.xs)

                        if entry.model != ranking.last?.model {
                            DSDivider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Provider Costs

    private var providerCostsSection: some View {
        let summary = tracker.getCostSavingsSummary()

        return Group {
            if !summary.providerCosts.isEmpty {
                DSCard {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        DSSectionHeader(title: "External Provider Costs")

                        ForEach(summary.providerCosts) { cost in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cost.provider)
                                        .font(DS.Typography.callout.weight(.medium))
                                        .foregroundStyle(DS.Colors.text)
                                    Text("\(PerformanceTrackingService.formatNumber(cost.inputTokens + cost.outputTokens)) tokens")
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(DS.Colors.tertiaryText)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(PerformanceTrackingService.formatCurrency(cost.cost))
                                        .font(DS.Typography.monoBold(13))
                                        .foregroundStyle(DS.Colors.warning)
                                    if !cost.pricingConfigured {
                                        Text("Pricing not configured")
                                            .font(DS.Typography.caption)
                                            .foregroundStyle(DS.Colors.error)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Metric Card

private struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: DS.IconSize.sm))
                        .foregroundStyle(color)
                    Text(title)
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                }

                Text(value)
                    .font(DS.Typography.title2)
                    .foregroundStyle(DS.Colors.text)

                Text(subtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Savings Row

private struct SavingsRow: View {
    let label: String
    let amount: Double?

    var body: some View {
        HStack {
            Text(label)
                .font(DS.Typography.callout)
                .foregroundStyle(DS.Colors.secondaryText)

            Spacer()

            Text(PerformanceTrackingService.formatCurrency(amount))
                .font(DS.Typography.monoBold(13))
                .foregroundStyle(amount != nil ? DS.Colors.success : DS.Colors.tertiaryText)
        }
    }
}

// MARK: - Compact Cost Badge (for status bar)

struct CostBadge: View {
    let totalTokens: Int
    let savings: Double?

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 11))
                .foregroundStyle(DS.Colors.success)

            Text(PerformanceTrackingService.formatNumber(totalTokens))
                .font(DS.Typography.mono(10))
                .foregroundStyle(DS.Colors.secondaryText)

            if let savings, savings > 0 {
                Text("(\(PerformanceTrackingService.formatCurrency(savings)) saved)")
                    .font(DS.Typography.mono(10))
                    .foregroundStyle(DS.Colors.success)
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .background(DS.Colors.surface)
        .clipShape(Capsule())
    }
}
