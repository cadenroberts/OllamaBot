import SwiftUI

struct GoToLineView: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool
    @State private var lineInput = ""
    @FocusState private var focused: Bool
    
    private var lineCount: Int {
        appState.editorContent.components(separatedBy: .newlines).count
    }
    
    private var parsedLine: Int? {
        guard let num = Int(lineInput), num > 0, num <= lineCount else { return nil }
        return num
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Input
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "arrow.right.to.line")
                    .foregroundStyle(DS.Colors.secondaryText)
                
                TextField("Go to line (1-\(lineCount))...", text: $lineInput)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.title)
                    .focused($focused)
                    .onSubmit { goToLine() }
                
                if parsedLine != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.Colors.success)
                }
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.secondaryBackground)
            
            DSDivider()
            
            // Info
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                if let file = appState.selectedFile {
                    HStack {
                        Image(systemName: file.icon)
                            .foregroundStyle(file.iconColor)
                        Text(file.name)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(lineCount) lines")
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                    .padding(DS.Spacing.md)
                } else {
                    Text("No file open")
                        .foregroundStyle(DS.Colors.secondaryText)
                        .padding(DS.Spacing.md)
                }
                
                // Quick jump buttons
                HStack(spacing: DS.Spacing.sm) {
                    quickJumpButton("Beginning", line: 1)
                    quickJumpButton("Middle", line: lineCount / 2)
                    quickJumpButton("End", line: lineCount)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.md)
            }
            
            // Footer
            HStack {
                Text("Press Enter to go to line")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                
                Spacer()
                
                Text("ESC to close")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.secondaryBackground)
        }
        .frame(width: 400)
        .background(DS.Colors.background)
        .dsOverlay()
        .onAppear { focused = true }
        .onKeyPress(.escape) { isPresented = false; return .handled }
        .onKeyPress(.return) { goToLine(); return .handled }
    }
    
    private func quickJumpButton(_ title: String, line: Int) -> some View {
        Button(action: {
            lineInput = "\(line)"
            goToLine()
        }) {
            Text(title)
                .font(DS.Typography.caption)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(DS.Colors.tertiaryBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private func goToLine() {
        guard let line = parsedLine else { return }
        appState.goToLine = line
        isPresented = false
    }
}
