import SwiftUI
import SwiftTerm
import AppKit

// MARK: - Terminal View

struct TerminalView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        // Terminal content fills entire pane - tab bar already shows "Terminal" label
        SwiftTermWrapper(workingDirectory: appState.rootFolder)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - SwiftTerm Wrapper

struct SwiftTermWrapper: NSViewRepresentable {
    let workingDirectory: URL?
    
    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 400))
        terminalView.autoresizingMask = [.width, .height]
        
        // Set font
        let fontSize = CGFloat(ConfigurationManager.shared.terminalFontSize)
        terminalView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        
        // Colors - match OllamaBot primary background (#1a1b26)
        let backgroundColor = NSColor(calibratedRed: 0.102, green: 0.106, blue: 0.149, alpha: 1.0) // #1a1b26
        terminalView.nativeBackgroundColor = backgroundColor
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
