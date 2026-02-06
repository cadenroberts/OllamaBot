import Foundation
import AppKit

// MARK: - Resilience Service
// Handles power loss, app closure, and state persistence for "safely infinite" operation

@Observable
final class ResilienceService {
    
    // MARK: - Recovery State
    
    struct RecoveryState: Codable {
        var timestamp: Date
        var agentState: AgentRecoveryState?
        var exploreState: ExploreRecoveryState?
        var unsavedFiles: [UnsavedFile]
        var lastCheckpoint: String?
        
        struct AgentRecoveryState: Codable {
            var taskDescription: String
            var stepCount: Int
            var lastToolUsed: String?
            var workingDirectory: String?
            var wasRunning: Bool
        }
        
        struct ExploreRecoveryState: Codable {
            var originalGoal: String
            var currentPhase: String
            var cycleCount: Int
            var totalChanges: Int
            var wasRunning: Bool
        }
        
        struct UnsavedFile: Codable {
            var path: String
            var content: String
            var modifiedAt: Date
        }
    }
    
    // MARK: - Configuration
    
    private let recoveryDirectory: URL
    private let autosaveInterval: TimeInterval = 30.0
    private let maxRecoveryFiles: Int = 10
    
    // MARK: - State
    
    private(set) var hasRecoveryData = false
    private(set) var lastAutosave: Date?
    private(set) var isRecovering = false
    
    private var autosaveTimer: Timer?
    private var terminationObserver: NSObjectProtocol?
    
    // References to services we need to save state from
    weak var agentExecutor: AgentExecutor?
    weak var exploreExecutor: ExploreAgentExecutor?
    
    // Callback for when recovery is available
    var onRecoveryAvailable: ((RecoveryState) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        // Setup recovery directory
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/ollamabot")
        recoveryDirectory = configDir.appendingPathComponent("recovery")
        
        try? FileManager.default.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)
        
        // Check for existing recovery data
        checkForRecoveryData()
        
        // Setup termination observer
        setupTerminationObserver()
    }
    
    deinit {
        stopAutosave()
        if let observer = terminationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Autosave Control
    
    func startAutosave() {
        guard autosaveTimer == nil else { return }
        
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: autosaveInterval, repeats: true) { [weak self] _ in
            self?.performAutosave()
        }
        
        // Initial save
        performAutosave()
    }
    
    func stopAutosave() {
        autosaveTimer?.invalidate()
        autosaveTimer = nil
    }
    
    // MARK: - Save State
    
    func performAutosave() {
        Task {
            await saveCurrentState()
        }
    }
    
    func saveCurrentState() async {
        var state = RecoveryState(
            timestamp: Date(),
            agentState: nil,
            exploreState: nil,
            unsavedFiles: [],
            lastCheckpoint: nil
        )
        
        // Save agent state if running
        if let agent = agentExecutor, agent.isRunning {
            state.agentState = RecoveryState.AgentRecoveryState(
                taskDescription: agent.currentTask,
                stepCount: agent.steps.count,
                lastToolUsed: nil,
                workingDirectory: nil,
                wasRunning: true
            )
        }
        
        // Save explore state if running
        if let explore = exploreExecutor, explore.isRunning {
            state.exploreState = RecoveryState.ExploreRecoveryState(
                originalGoal: explore.originalGoal,
                currentPhase: explore.currentPhase.rawValue,
                cycleCount: explore.cycleCount,
                totalChanges: explore.totalChanges,
                wasRunning: true
            )
        }
        
        // Write state to file
        let filename = "recovery_\(Int(Date().timeIntervalSince1970)).json"
        let fileURL = recoveryDirectory.appendingPathComponent(filename)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        if let data = try? encoder.encode(state) {
            try? data.write(to: fileURL)
            
            await MainActor.run {
                self.lastAutosave = Date()
            }
        }
        
        // Cleanup old recovery files
        cleanupOldRecoveryFiles()
    }
    
    // MARK: - Recovery
    
    func checkForRecoveryData() {
        guard let latestRecovery = getLatestRecoveryFile() else {
            hasRecoveryData = false
            return
        }
        
        // Check if it's recent (within last hour)
        let fileDate = (try? FileManager.default.attributesOfItem(atPath: latestRecovery.path)[.modificationDate] as? Date) ?? Date.distantPast
        
        if Date().timeIntervalSince(fileDate) < 3600 {
            hasRecoveryData = true
            
            // Load and notify
            if let state = loadRecoveryState(from: latestRecovery) {
                // Check if there was active work
                if state.agentState?.wasRunning == true || state.exploreState?.wasRunning == true {
                    onRecoveryAvailable?(state)
                }
            }
        } else {
            hasRecoveryData = false
        }
    }
    
    func loadRecoveryState(from url: URL) -> RecoveryState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try? decoder.decode(RecoveryState.self, from: data)
    }
    
    func getLatestRecoveryFile() -> URL? {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: recoveryDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return nil }
        
        let recoveryFiles = files.filter { $0.lastPathComponent.hasPrefix("recovery_") }
        
        return recoveryFiles.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            return date1 > date2
        }.first
    }
    
    func clearRecoveryData() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: recoveryDirectory, includingPropertiesForKeys: nil) else { return }
        
        for file in files where file.lastPathComponent.hasPrefix("recovery_") {
            try? FileManager.default.removeItem(at: file)
        }
        
        hasRecoveryData = false
    }
    
    // MARK: - Cleanup
    
    private func cleanupOldRecoveryFiles() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: recoveryDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        
        let recoveryFiles = files
            .filter { $0.lastPathComponent.hasPrefix("recovery_") }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                return date1 > date2
            }
        
        // Keep only the most recent files
        if recoveryFiles.count > maxRecoveryFiles {
            for file in recoveryFiles.dropFirst(maxRecoveryFiles) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
    
    // MARK: - Termination Handling
    
    private func setupTerminationObserver() {
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Synchronously save state before termination
            self?.saveStateSync()
        }
    }
    
    private func saveStateSync() {
        var state = RecoveryState(
            timestamp: Date(),
            agentState: nil,
            exploreState: nil,
            unsavedFiles: [],
            lastCheckpoint: nil
        )
        
        // Save agent state
        if let agent = agentExecutor, agent.isRunning {
            state.agentState = RecoveryState.AgentRecoveryState(
                taskDescription: agent.currentTask,
                stepCount: agent.steps.count,
                lastToolUsed: nil,
                workingDirectory: nil,
                wasRunning: true
            )
        }
        
        // Save explore state
        if let explore = exploreExecutor, explore.isRunning {
            state.exploreState = RecoveryState.ExploreRecoveryState(
                originalGoal: explore.originalGoal,
                currentPhase: explore.currentPhase.rawValue,
                cycleCount: explore.cycleCount,
                totalChanges: explore.totalChanges,
                wasRunning: true
            )
        }
        
        // Write synchronously
        let filename = "recovery_termination_\(Int(Date().timeIntervalSince1970)).json"
        let fileURL = recoveryDirectory.appendingPathComponent(filename)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(state) {
            try? data.write(to: fileURL)
        }
    }
    
    // MARK: - Safe Operation Helpers
    
    /// Wrap an operation to ensure it can recover from interruption
    func withRecovery<T>(_ operation: () async throws -> T, context: String) async throws -> T {
        // Save state before risky operation
        await saveCurrentState()
        
        do {
            let result = try await operation()
            return result
        } catch {
            // Save error state
            await saveCurrentState()
            throw error
        }
    }
    
    /// Check if it's safe to perform a destructive operation
    func canPerformDestructiveOperation() -> Bool {
        // Always safe if autosave is running
        return autosaveTimer != nil
    }
}

// MARK: - Recovery Alert View

import SwiftUI

struct RecoveryAlertView: View {
    let state: ResilienceService.RecoveryState
    let onRecover: () -> Void
    let onDiscard: () -> Void
    
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(DS.Colors.warning.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "arrow.clockwise")
                    .font(.title)
                    .foregroundStyle(DS.Colors.warning)
            }
            
            // Title
            Text("Recover Previous Session?")
                .font(DS.Typography.title2)
            
            // Description
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                if let agentState = state.agentState {
                    recoveryItem(
                        icon: "infinity",
                        title: "Infinite Mode Task",
                        detail: agentState.taskDescription
                    )
                }
                
                if let exploreState = state.exploreState {
                    recoveryItem(
                        icon: "sparkles",
                        title: "Explore Mode",
                        detail: "\(exploreState.originalGoal) (Cycle \(exploreState.cycleCount))"
                    )
                }
                
                Text("Last saved: \(state.timestamp.formatted())")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            
            // Actions
            HStack(spacing: DS.Spacing.md) {
                DSButton("Discard", style: .secondary) {
                    onDiscard()
                }
                
                DSButton("Recover", icon: "arrow.clockwise", style: .primary) {
                    onRecover()
                }
            }
        }
        .padding(DS.Spacing.xl)
        .frame(width: 400)
        .background(DS.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }
    
    private func recoveryItem(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(DS.Colors.accent)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Typography.callout.weight(.medium))
                Text(detail)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .lineLimit(1)
            }
        }
    }
}
