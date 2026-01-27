import SwiftUI
import SwiftTerm
import AppKit

// MARK: - Terminal View

struct TerminalView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "terminal")
                    .foregroundStyle(DS.Colors.secondaryText)
                
                Text("Terminal")
                    .font(DS.Typography.caption.weight(.medium))
                
                Spacer()
                
                // Terminal actions
                HStack(spacing: DS.Spacing.xs) {
                    DSIconButton(icon: "trash", size: 14) {
                        // Clear handled by terminal
                    }
                    .help("Clear Terminal")
                    
                    DSIconButton(icon: "xmark", size: 14) {
                        appState.showTerminal = false
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.secondaryBackground)
            
            DSDivider()
            
            // Terminal content
            SwiftTermWrapper(workingDirectory: appState.rootFolder)
        }
    }
}

// MARK: - SwiftTerm Wrapper

struct SwiftTermWrapper: NSViewRepresentable {
    let workingDirectory: URL?
    
    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 400))
        
        // Set font
        let fontSize = CGFloat(ConfigurationManager.shared.terminalFontSize)
        terminalView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        
        // Colors
        terminalView.nativeBackgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)
        terminalView.nativeForegroundColor = NSColor.white
        
        // Terminal options
        terminalView.optionAsMetaKey = true
        
        // Start shell
        let shell = ConfigurationManager.shared.terminalShell
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        
        terminalView.startProcess(
            executable: shell,
            args: [],
            environment: Array(env.map { "\($0.key)=\($0.value)" }),
            execName: shell.components(separatedBy: "/").last ?? "zsh"
        )
        
        // Change to working directory
        if let cwd = workingDirectory?.path {
            let command = "cd \"\(cwd)\" && clear\n"
            let bytes = Array(command.utf8)
            terminalView.send(data: bytes[...])
        }
        
        return terminalView
    }
    
    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Update font size if changed
        let fontSize = CGFloat(ConfigurationManager.shared.terminalFontSize)
        nsView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }
}
