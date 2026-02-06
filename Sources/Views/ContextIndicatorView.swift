import SwiftUI

// MARK: - Context Token Indicator
// Shows how much of the context window is being used
// Like Cursor's context usage indicator

struct ContextIndicatorView: View {
    @Environment(AppState.self) private var appState
    
    let usedTokens: Int
    let maxTokens: Int
    
    var percentage: Double {
        guard maxTokens > 0 else { return 0 }
        return Double(usedTokens) / Double(maxTokens)
    }
    
    var statusColor: Color {
        switch percentage {
        case 0..<0.5: return DS.Colors.success
        case 0.5..<0.8: return DS.Colors.warning
        default: return DS.Colors.error
        }
    }
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(DS.Colors.border, lineWidth: 3)
                    .frame(width: 24, height: 24)
                
                Circle()
                    .trim(from: 0, to: percentage)
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(percentage * 100))")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                Text(formatTokens(usedTokens))
                    .font(DS.Typography.mono(11))
                    .foregroundStyle(DS.Colors.text)
                
                Text("of \(formatTokens(maxTokens))")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
        .help("Context window: \(usedTokens) / \(maxTokens) tokens (\(Int(percentage * 100))%)")
    }
    
    private func formatTokens(_ tokens: Int) -> String {
        if tokens >= 1000 {
            return String(format: "%.1fK", Double(tokens) / 1000)
        }
        return "\(tokens)"
    }
}

// MARK: - Context Breakdown View

struct ContextBreakdownView: View {
    let breakdown: ContextBreakdown
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Context Breakdown")
                .font(DS.Typography.headline)
                .padding(.bottom, DS.Spacing.xs)
            
            ForEach(breakdown.items, id: \.name) { item in
                HStack {
                    Circle()
                        .fill(item.color)
                        .frame(width: 8, height: 8)
                    
                    Text(item.name)
                        .font(DS.Typography.caption)
                    
                    Spacer()
                    
                    Text(formatTokens(item.tokens))
                        .font(DS.Typography.mono(11))
                        .foregroundStyle(DS.Colors.secondaryText)
                }
            }
            
            DSDivider()
            
            HStack {
                Text("Total")
                    .font(DS.Typography.caption.weight(.semibold))
                
                Spacer()
                
                Text(formatTokens(breakdown.totalTokens))
                    .font(DS.Typography.mono(11).weight(.semibold))
            }
            
            // Warning if near limit
            if breakdown.percentageUsed > 0.8 {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(DS.Colors.warning)
                    Text("Context nearly full. Older messages may be truncated.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.warning)
                }
                .padding(.top, DS.Spacing.xs)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .frame(width: 280)
    }
    
    private func formatTokens(_ tokens: Int) -> String {
        if tokens >= 1000 {
            return String(format: "%.1fK", Double(tokens) / 1000)
        }
        return "\(tokens)"
    }
}

// MARK: - Context Breakdown Model

struct ContextBreakdown {
    let items: [ContextItem]
    let maxTokens: Int
    
    var totalTokens: Int {
        items.reduce(0) { $0 + $1.tokens }
    }
    
    var percentageUsed: Double {
        guard maxTokens > 0 else { return 0 }
        return Double(totalTokens) / Double(maxTokens)
    }
    
    struct ContextItem {
        let name: String
        let tokens: Int
        let color: Color
    }
    
    static func calculate(
        systemPrompt: String,
        projectRules: String?,
        conversationHistory: [ChatMessage],
        mentionContent: String?,
        userInput: String,
        maxTokens: Int
    ) -> ContextBreakdown {
        var items: [ContextItem] = []
        
        // System prompt
        let systemTokens = estimateTokens(systemPrompt)
        items.append(ContextItem(name: "System", tokens: systemTokens, color: DS.Colors.orchestrator))
        
        // Project rules
        if let rules = projectRules, !rules.isEmpty {
            let rulesTokens = estimateTokens(rules)
            items.append(ContextItem(name: "Project Rules", tokens: rulesTokens, color: DS.Colors.coder))
        }
        
        // Conversation history
        let historyTokens = conversationHistory.reduce(0) { $0 + estimateTokens($1.content) }
        if historyTokens > 0 {
            items.append(ContextItem(name: "Chat History", tokens: historyTokens, color: DS.Colors.accent))
        }
        
        // Mentions (@file, @context, etc.)
        if let mentions = mentionContent, !mentions.isEmpty {
            let mentionTokens = estimateTokens(mentions)
            items.append(ContextItem(name: "Mentions", tokens: mentionTokens, color: DS.Colors.success))
        }
        
        // Current input
        let inputTokens = estimateTokens(userInput)
        if inputTokens > 0 {
            items.append(ContextItem(name: "Your Message", tokens: inputTokens, color: DS.Colors.warning))
        }
        
        return ContextBreakdown(items: items, maxTokens: maxTokens)
    }
    
    private static func estimateTokens(_ text: String) -> Int {
        // Rough estimate: ~4 characters per token for English
        return text.count / 4
    }
}

// MARK: - Chat Input Context Bar

struct ChatContextBar: View {
    @Environment(AppState.self) private var appState
    @State private var showBreakdown = false
    
    let breakdown: ContextBreakdown
    let mentions: [MentionService.Mention]
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Mentions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(mentions) { mention in
                        MentionChipView(mention: mention) {
                            // Remove mention
                        }
                    }
                }
            }
            
            Spacer()
            
            // Context indicator
            Button {
                showBreakdown.toggle()
            } label: {
                ContextIndicatorView(
                    usedTokens: breakdown.totalTokens,
                    maxTokens: breakdown.maxTokens
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showBreakdown, arrowEdge: .top) {
                ContextBreakdownView(breakdown: breakdown)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.secondaryBackground)
    }
}

// MARK: - Compact Context Badge

struct ContextBadge: View {
    let usedTokens: Int
    let maxTokens: Int
    
    var percentage: Double {
        guard maxTokens > 0 else { return 0 }
        return Double(usedTokens) / Double(maxTokens)
    }
    
    var statusColor: Color {
        switch percentage {
        case 0..<0.5: return DS.Colors.success
        case 0.5..<0.8: return DS.Colors.warning
        default: return DS.Colors.error
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "brain")
                .font(.caption2)
            
            Text("\(Int(percentage * 100))%")
                .font(DS.Typography.caption2.weight(.bold))
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, DS.Spacing.xs)
        .padding(.vertical, 2)
        .background(statusColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}
