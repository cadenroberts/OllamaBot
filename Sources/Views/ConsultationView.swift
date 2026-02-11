import SwiftUI

// MARK: - Consultation View
// Modal dialog with countdown timer when the agent requests user input.
// AI fallback on timeout. Works with both orchestration and agent modes.

struct ConsultationView: View {
    let question: String
    let timeout: Int
    let isMandatory: Bool
    let onRespond: (String) -> Void
    let onSkip: () -> Void

    @State private var response: String = ""
    @State private var remainingSeconds: Int
    @State private var timerActive: Bool = true
    @Environment(\.dismiss) private var dismiss

    init(
        question: String,
        timeout: Int = 60,
        isMandatory: Bool = false,
        onRespond: @escaping (String) -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.question = question
        self.timeout = timeout
        self.isMandatory = isMandatory
        self.onRespond = onRespond
        self.onSkip = onSkip
        self._remainingSeconds = State(initialValue: timeout)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "person.wave.2.fill")
                    .font(.system(size: DS.IconSize.lg))
                    .foregroundStyle(DS.Colors.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Human Consultation")
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Colors.text)
                    Text(isMandatory ? "Required — must respond" : "Optional — will auto-skip on timeout")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }

                Spacer()

                // Timer
                timerBadge
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.surface)

            DSDivider()

            // Question
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Question")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
                    .textCase(.uppercase)

                Text(question)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.text)
                    .padding(DS.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Colors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            }
            .padding(DS.Spacing.lg)

            // Response area
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Your Response")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
                    .textCase(.uppercase)

                TextEditor(text: $response)
                    .font(DS.Typography.body)
                    .scrollContentBackground(.hidden)
                    .padding(DS.Spacing.sm)
                    .frame(minHeight: 80, maxHeight: 200)
                    .background(DS.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .strokeBorder(DS.Colors.border, lineWidth: 1)
                    )
            }
            .padding(.horizontal, DS.Spacing.lg)

            Spacer()

            // Actions
            DSDivider()

            HStack {
                if !isMandatory {
                    DSButton("Skip", icon: "forward.fill", style: .ghost, size: .md) {
                        timerActive = false
                        onSkip()
                        dismiss()
                    }
                }

                Spacer()

                DSButton("Respond", icon: "arrow.up.circle.fill", style: .accent, size: .md) {
                    timerActive = false
                    onRespond(response)
                    dismiss()
                }
                .disabled(response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(DS.Spacing.lg)
        }
        .frame(width: 500, minHeight: 400)
        .background(DS.Colors.background)
        .onAppear {
            startTimer()
        }
    }

    // MARK: - Timer

    private var timerBadge: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "timer")
                .font(.system(size: 12))
            Text(timeString)
                .font(DS.Typography.monoBold(14))
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(timerColor.opacity(0.15))
        .foregroundStyle(timerColor)
        .clipShape(Capsule())
    }

    private var timeString: String {
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var timerColor: Color {
        if remainingSeconds <= 10 { return DS.Colors.error }
        if remainingSeconds <= 30 { return DS.Colors.warning }
        return DS.Colors.accent
    }

    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            guard timerActive else {
                timer.invalidate()
                return
            }
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                timer.invalidate()
                // Auto-skip on timeout (AI fallback)
                if !isMandatory {
                    onSkip()
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Consultation Inline Banner (for embedding in chat)

struct ConsultationBanner: View {
    let question: String
    let timeout: Int
    let isMandatory: Bool
    @State private var showModal: Bool = false
    let onRespond: (String) -> Void
    let onSkip: () -> Void

    var body: some View {
        DSCard {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "person.wave.2")
                    .font(.system(size: DS.IconSize.lg))
                    .foregroundStyle(DS.Colors.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Agent needs your input")
                        .font(DS.Typography.callout.weight(.medium))
                        .foregroundStyle(DS.Colors.text)
                    Text(question)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                        .lineLimit(2)
                }

                Spacer()

                DSButton("Respond", icon: "bubble.left", style: .accent, size: .sm) {
                    showModal = true
                }
            }
        }
        .sheet(isPresented: $showModal) {
            ConsultationView(
                question: question,
                timeout: timeout,
                isMandatory: isMandatory,
                onRespond: onRespond,
                onSkip: onSkip
            )
        }
    }
}
