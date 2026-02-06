import Foundation

// MARK: - Session State
// Persists session data (open files, project) across app restarts/updates
// Config settings already persist via UserDefaults - this handles runtime state

struct SessionState: Codable {
    var rootFolder: String?
    var openFiles: [String]  // File paths
    var selectedFile: String?
    var timestamp: Date
    
    init(rootFolder: String? = nil, openFiles: [String] = [], selectedFile: String? = nil) {
        self.rootFolder = rootFolder
        self.openFiles = openFiles
        self.selectedFile = selectedFile
        self.timestamp = Date()
    }
}

// MARK: - Session State Service

class SessionStateService {
    static let shared = SessionStateService()
    
    private let stateDirectory: URL
    private let stateFileURL: URL
    
    private init() {
        // Store in ~/.ollamabot/session.json
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        stateDirectory = homeDir.appendingPathComponent(".ollamabot")
        stateFileURL = stateDirectory.appendingPathComponent("session.json")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Save Session
    
    func saveSession(rootFolder: URL?, openFiles: [FileItem], selectedFile: FileItem?) {
        let state = SessionState(
            rootFolder: rootFolder?.path,
            openFiles: openFiles.map { $0.url.path },
            selectedFile: selectedFile?.url.path
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)
            try data.write(to: stateFileURL)
            print("[SessionState] Saved session: \(openFiles.count) files")
        } catch {
            print("[SessionState] Failed to save: \(error)")
        }
    }
    
    // MARK: - Load Session
    
    func loadSession() -> SessionState? {
        guard FileManager.default.fileExists(atPath: stateFileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: stateFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let state = try decoder.decode(SessionState.self, from: data)
            print("[SessionState] Loaded session from \(state.timestamp)")
            return state
        } catch {
            print("[SessionState] Failed to load: \(error)")
            return nil
        }
    }
    
    // MARK: - Clear Session
    
    func clearSession() {
        try? FileManager.default.removeItem(at: stateFileURL)
        print("[SessionState] Cleared session")
    }
    
    // MARK: - Check if Session Exists
    
    var hasSession: Bool {
        FileManager.default.fileExists(atPath: stateFileURL.path)
    }
}
