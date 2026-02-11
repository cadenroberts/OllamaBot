import Foundation

// MARK: - Unified Session Service (USF)
// Reads/writes Unified Session Format JSON for cross-platform session portability.
// Sessions are stored in ~/.config/ollamabot/sessions/

@Observable
final class UnifiedSessionService {

    // MARK: - USF Types

    struct UnifiedSession: Codable, Identifiable {
        var version: String = "1.0"
        var sessionId: String = UUID().uuidString
        var createdAt: String = ISO8601DateFormatter().string(from: Date())
        var platformOrigin: String = "ide"
        var task: TaskInfo = TaskInfo()
        var orchestration: OrchestrationInfo?
        var steps: [StepEntry] = []
        var checkpoints: [CheckpointEntry] = []
        var stats: SessionStatsEntry = SessionStatsEntry()

        var id: String { sessionId }

        enum CodingKeys: String, CodingKey {
            case version
            case sessionId = "session_id"
            case createdAt = "created_at"
            case platformOrigin = "platform_origin"
            case task, orchestration, steps, checkpoints, stats
        }
    }

    struct TaskInfo: Codable {
        var original: String = ""
        var status: String = "pending"
    }

    struct OrchestrationInfo: Codable {
        var currentSchedule: Int = 1
        var flowCode: String = ""

        enum CodingKeys: String, CodingKey {
            case currentSchedule = "current_schedule"
            case flowCode = "flow_code"
        }
    }

    struct StepEntry: Codable, Identifiable {
        var stepNumber: Int = 0
        var toolId: String = ""
        var input: String?
        var output: String?
        var success: Bool = true
        var timestamp: String?

        var id: Int { stepNumber }

        enum CodingKeys: String, CodingKey {
            case stepNumber = "step_number"
            case toolId = "tool_id"
            case input, output, success, timestamp
        }
    }

    struct CheckpointEntry: Codable, Identifiable {
        var checkpointId: String = ""
        var gitCommit: String?
        var timestamp: String?

        var id: String { checkpointId }

        enum CodingKeys: String, CodingKey {
            case checkpointId = "id"
            case gitCommit = "git_commit"
            case timestamp
        }
    }

    struct SessionStatsEntry: Codable {
        var totalTokens: Int = 0
        var filesModified: Int = 0
        var duration: Double = 0

        enum CodingKeys: String, CodingKey {
            case totalTokens = "total_tokens"
            case filesModified = "files_modified"
            case duration
        }
    }

    // MARK: - State

    private(set) var currentSession: UnifiedSession?
    private(set) var savedSessions: [UnifiedSession] = []
    private var stepCounter: Int = 0

    static let sessionsDirectory: URL = {
        SharedConfigService.configDirectory.appendingPathComponent("sessions")
    }()

    init() {
        ensureDirectoryExists()
        loadSessionList()
    }

    // MARK: - Session Lifecycle

    func startSession(task: String) {
        var session = UnifiedSession()
        session.task = TaskInfo(original: task, status: "in_progress")
        currentSession = session
        stepCounter = 0
        print("UnifiedSessionService: Started session \(session.sessionId)")
    }

    func endSession() {
        guard var session = currentSession else { return }
        session.task.status = "completed"
        session.stats.duration = sessionDuration(session)
        currentSession = session
        saveCurrentSession()
        currentSession = nil
    }

    func cancelSession() {
        guard var session = currentSession else { return }
        session.task.status = "cancelled"
        currentSession = session
        saveCurrentSession()
        currentSession = nil
    }

    // MARK: - Recording

    func recordStep(toolId: String, input: String?, output: String?, success: Bool) {
        guard currentSession != nil else { return }
        stepCounter += 1
        let step = StepEntry(
            stepNumber: stepCounter,
            toolId: toolId,
            input: input.map { String($0.prefix(500)) },
            output: output.map { String($0.prefix(500)) },
            success: success,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        currentSession?.steps.append(step)
    }

    func recordCheckpoint(id: String, gitCommit: String?) {
        guard currentSession != nil else { return }
        let entry = CheckpointEntry(
            checkpointId: id,
            gitCommit: gitCommit,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        currentSession?.checkpoints.append(entry)
    }

    func updateOrchestration(schedule: Int, flowCode: String) {
        currentSession?.orchestration = OrchestrationInfo(
            currentSchedule: schedule,
            flowCode: flowCode
        )
    }

    func updateStats(totalTokens: Int, filesModified: Int) {
        currentSession?.stats.totalTokens = totalTokens
        currentSession?.stats.filesModified = filesModified
    }

    // MARK: - Export / Import

    func saveCurrentSession() {
        guard let session = currentSession else { return }
        save(session)
    }

    func save(_ session: UnifiedSession) {
        ensureDirectoryExists()
        let fileURL = Self.sessionsDirectory.appendingPathComponent("\(session.sessionId).json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(session)
            try data.write(to: fileURL)
            loadSessionList()
            print("UnifiedSessionService: Saved session \(session.sessionId)")
        } catch {
            print("UnifiedSessionService: Failed to save session: \(error)")
        }
    }

    func loadSession(id: String) -> UnifiedSession? {
        let fileURL = Self.sessionsDirectory.appendingPathComponent("\(id).json")
        guard let data = try? Data(contentsOf: fileURL),
              let session = try? JSONDecoder().decode(UnifiedSession.self, from: data) else {
            return nil
        }
        return session
    }

    func importSession(from url: URL) -> UnifiedSession? {
        guard let data = try? Data(contentsOf: url),
              let session = try? JSONDecoder().decode(UnifiedSession.self, from: data) else {
            return nil
        }
        save(session)
        return session
    }

    func deleteSession(id: String) {
        let fileURL = Self.sessionsDirectory.appendingPathComponent("\(id).json")
        try? FileManager.default.removeItem(at: fileURL)
        loadSessionList()
    }

    func resumeSession(_ session: UnifiedSession) {
        var resumed = session
        resumed.task.status = "in_progress"
        currentSession = resumed
        stepCounter = session.steps.count
    }

    // MARK: - Private

    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: Self.sessionsDirectory, withIntermediateDirectories: true)
    }

    private func loadSessionList() {
        let dir = Self.sessionsDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            savedSessions = []
            return
        }

        savedSessions = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> UnifiedSession? in
                guard let data = try? Data(contentsOf: url),
                      let session = try? JSONDecoder().decode(UnifiedSession.self, from: data) else {
                    return nil
                }
                return session
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func sessionDuration(_ session: UnifiedSession) -> Double {
        let formatter = ISO8601DateFormatter()
        guard let start = formatter.date(from: session.createdAt) else { return 0 }
        return Date().timeIntervalSince(start)
    }
}
