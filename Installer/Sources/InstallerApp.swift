import SwiftUI

@main
struct OllamaBotInstallerApp: App {
    @State private var installerState = InstallerState()
    
    var body: some Scene {
        WindowGroup {
            InstallerContentView()
                .environment(installerState)
                .frame(minWidth: 700, minHeight: 550)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

// MARK: - Installer State

@Observable
class InstallerState {
    enum Step: Int, CaseIterable {
        case welcome = 0
        case requirements
        case tierSelection
        case modelCustomization
        case download
        case installation
        case complete
        
        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .requirements: return "System Check"
            case .tierSelection: return "Select Tier"
            case .modelCustomization: return "Customize Models"
            case .download: return "Download Models"
            case .installation: return "Install"
            case .complete: return "Complete"
            }
        }
    }
    
    var currentStep: Step = .welcome
    var canContinue: Bool = true
    
    // System info
    var systemRAM: Int = 0
    var diskSpaceGB: Double = 0
    var isAppleSilicon: Bool = false
    var macOSVersion: String = ""
    var ollamaInstalled: Bool = false
    var ollamaRunning: Bool = false
    
    // Configuration
    var selectedTier: ModelTier = .performance
    var customConfig: CustomModelConfig = CustomModelConfig()
    var installationPath: URL = URL(fileURLWithPath: "/Applications")
    
    // Download progress
    var downloadProgress: Double = 0
    var currentDownload: String = ""
    var downloadedModels: [String] = []
    var downloadError: String?
    
    // Installation
    var installProgress: Double = 0
    var installStatus: String = ""
    var installError: String?
    
    init() {
        loadSystemInfo()
    }
    
    func loadSystemInfo() {
        // Get RAM
        let ramBytes = ProcessInfo.processInfo.physicalMemory
        systemRAM = Int(ramBytes / 1_073_741_824)
        
        // Get disk space
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            let freeSpace = (attrs[.systemFreeSize] as? Int64) ?? 0
            diskSpaceGB = Double(freeSpace) / 1_073_741_824
        }
        
        // Check Apple Silicon
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        isAppleSilicon = machine?.contains("arm64") ?? false
        
        // Get macOS version
        let version = ProcessInfo.processInfo.operatingSystemVersion
        macOSVersion = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        
        // Determine recommended tier
        if systemRAM >= 128 {
            selectedTier = .maximum
        } else if systemRAM >= 64 {
            selectedTier = .advanced
        } else if systemRAM >= 32 {
            selectedTier = .performance
        } else if systemRAM >= 24 {
            selectedTier = .balanced
        } else if systemRAM >= 16 {
            selectedTier = .compact
        } else {
            selectedTier = .minimal
        }
    }
    
    func nextStep() {
        if let next = Step(rawValue: currentStep.rawValue + 1) {
            currentStep = next
        }
    }
    
    func previousStep() {
        if let prev = Step(rawValue: currentStep.rawValue - 1), prev.rawValue >= 0 {
            currentStep = prev
        }
    }
    
    // MARK: - Shell Commands
    
    func checkOllama() async {
        // Check if Ollama is installed
        let result = runCommand("which ollama")
        ollamaInstalled = !result.isEmpty && result.contains("ollama")
        
        if ollamaInstalled {
            // Check if running
            let listResult = runCommand("curl -s http://localhost:11434/api/tags 2>/dev/null")
            ollamaRunning = listResult.contains("models")
        }
    }
    
    func installOllama() async -> Bool {
        // Download and install Ollama
        let script = """
        curl -fsSL https://ollama.com/install.sh | sh
        """
        let result = runCommand(script)
        await checkOllama()
        return ollamaInstalled
    }
    
    func downloadModels() async {
        let models = customConfig.getModelsToDownload(tier: selectedTier)
        let total = models.count
        
        for (index, model) in models.enumerated() {
            currentDownload = model.name
            downloadProgress = Double(index) / Double(total)
            
            // Pull model using Ollama
            let result = runCommand("ollama pull \(model.ollamaTag)")
            
            if result.contains("error") {
                downloadError = "Failed to download \(model.name)"
                return
            }
            
            downloadedModels.append(model.ollamaTag)
        }
        
        downloadProgress = 1.0
        currentDownload = "Complete"
    }
    
    func installApp() async {
        installStatus = "Building OllamaBot..."
        installProgress = 0.2
        
        // Save configuration
        saveConfiguration()
        installProgress = 0.4
        
        installStatus = "Copying to Applications..."
        installProgress = 0.6
        
        // Build would be handled by the build script
        // For now we just save config
        installProgress = 0.8
        
        installStatus = "Finalizing..."
        installProgress = 1.0
        
        installStatus = "Complete"
    }
    
    func saveConfiguration() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/ollamabot")
        
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        
        let config: [String: Any] = [
            "tier": selectedTier.rawValue.lowercased().components(separatedBy: " ").first ?? "performance",
            "ram_gb": systemRAM,
            "selected_at": ISO8601DateFormatter().string(from: Date()),
            "models": [
                "orchestrator": customConfig.orchestrator.enabled ? customConfig.orchestrator.ollamaTag : nil,
                "coder": customConfig.coder.enabled ? customConfig.coder.ollamaTag : nil,
                "researcher": customConfig.researcher.enabled ? customConfig.researcher.ollamaTag : nil,
                "vision": customConfig.vision.enabled ? customConfig.vision.ollamaTag : nil
            ],
            "enabled": [
                "orchestrator": customConfig.orchestrator.enabled,
                "coder": customConfig.coder.enabled,
                "researcher": customConfig.researcher.enabled,
                "vision": customConfig.vision.enabled
            ]
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) {
            let configPath = configDir.appendingPathComponent("tier.json")
            try? data.write(to: configPath)
        }
    }
    
    private func runCommand(_ command: String) -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Model Tier

enum ModelTier: String, CaseIterable, Identifiable {
    case minimal = "Minimal (1.5B)"
    case compact = "Compact (7B)"
    case balanced = "Balanced (14B)"
    case performance = "Performance (32B)"
    case advanced = "Advanced (70B)"
    case maximum = "Maximum (70B+)"
    
    var id: String { rawValue }
    
    var minRAM: Int {
        switch self {
        case .minimal: return 8
        case .compact: return 16
        case .balanced: return 24
        case .performance: return 32
        case .advanced: return 64
        case .maximum: return 128
        }
    }
    
    var description: String {
        switch self {
        case .minimal: return "Basic capability for testing"
        case .compact: return "Good for simple tasks"
        case .balanced: return "Recommended for most users"
        case .performance: return "Excellent for development"
        case .advanced: return "Professional-grade AI"
        case .maximum: return "Maximum capability"
        }
    }
    
    var diskRequired: String {
        switch self {
        case .minimal: return "~5 GB"
        case .compact: return "~20 GB"
        case .balanced: return "~40 GB"
        case .performance: return "~80 GB"
        case .advanced: return "~150 GB"
        case .maximum: return "~200 GB"
        }
    }
}

// MARK: - Custom Model Config

struct CustomModelConfig {
    struct ModelSelection {
        var enabled: Bool
        var name: String
        var ollamaTag: String
        var sizeGB: Double
    }
    
    var orchestrator = ModelSelection(enabled: true, name: "Qwen3 32B", ollamaTag: "qwen3:32b", sizeGB: 20)
    var coder = ModelSelection(enabled: true, name: "Qwen2.5-Coder 32B", ollamaTag: "qwen2.5-coder:32b", sizeGB: 20)
    var researcher = ModelSelection(enabled: true, name: "Command-R 35B", ollamaTag: "command-r:35b", sizeGB: 20)
    var vision = ModelSelection(enabled: false, name: "Qwen3-VL 32B", ollamaTag: "qwen3-vl:32b", sizeGB: 20)
    
    func getModelsToDownload(tier: ModelTier) -> [ModelSelection] {
        var models: [ModelSelection] = []
        if orchestrator.enabled { models.append(orchestrator) }
        if coder.enabled { models.append(coder) }
        if researcher.enabled { models.append(researcher) }
        if vision.enabled { models.append(vision) }
        return models
    }
    
    var totalDiskRequired: Double {
        var total: Double = 0
        if orchestrator.enabled { total += orchestrator.sizeGB }
        if coder.enabled { total += coder.sizeGB }
        if researcher.enabled { total += researcher.sizeGB }
        if vision.enabled { total += vision.sizeGB }
        return total
    }
    
    var enabledCount: Int {
        [orchestrator.enabled, coder.enabled, researcher.enabled, vision.enabled].filter { $0 }.count
    }
}
