import Foundation

// MARK: - Orchestration Service
// 5-schedule x 3-process state machine for the IDE.
// Works alongside existing Infinite Mode and Explore Mode.
// Reads schedule definitions from SharedConfigService.

@Observable
final class OrchestrationService {

    // MARK: - Types

    enum Schedule: Int, CaseIterable, Identifiable, Codable {
        case knowledge = 1
        case plan = 2
        case implement = 3
        case scale = 4
        case production = 5

        var id: Int { rawValue }

        var name: String {
            switch self {
            case .knowledge: return "Knowledge"
            case .plan: return "Plan"
            case .implement: return "Implement"
            case .scale: return "Scale"
            case .production: return "Production"
            }
        }

        var icon: String {
            switch self {
            case .knowledge: return "magnifyingglass"
            case .plan: return "list.bullet.clipboard"
            case .implement: return "hammer"
            case .scale: return "chart.bar"
            case .production: return "checkmark.seal"
            }
        }

        var processes: [String] {
            switch self {
            case .knowledge: return ["Research", "Crawl", "Retrieve"]
            case .plan: return ["Brainstorm", "Clarify", "Plan"]
            case .implement: return ["Implement", "Verify", "Feedback"]
            case .scale: return ["Scale", "Benchmark", "Optimize"]
            case .production: return ["Analyze", "Systemize", "Harmonize"]
            }
        }

        var defaultModel: OllamaModel {
            switch self {
            case .knowledge: return .commandR
            case .plan: return .coder
            case .implement: return .coder
            case .scale: return .coder
            case .production: return .coder
            }
        }
    }

    enum Process: Int, CaseIterable, Codable {
        case first = 1
        case second = 2
        case third = 3

        var label: String {
            "P\(rawValue)"
        }
    }

    enum OrchestrationMode {
        case full           // All 5 schedules
        case infiniteMap    // Plan(P2,P3) + Implement(P1,P2,P3) — maps to Infinite Mode
        case exploreMap     // Production(P1,P2,P3) with reflection — maps to Explore Mode
    }

    struct OrchestrationState {
        var currentSchedule: Schedule = .knowledge
        var currentProcess: Process = .first
        var isActive: Bool = false
        var mode: OrchestrationMode = .full
        var history: [(schedule: Schedule, process: Process, timestamp: Date)] = []
        var task: String = ""
        var pendingConsultation: ConsultationRequest?
    }

    struct ConsultationRequest: Identifiable {
        let id = UUID()
        let question: String
        let timeout: Int
        let isMandatory: Bool
        var response: String?
    }

    // MARK: - State

    private(set) var state = OrchestrationState()
    private(set) var completedSchedules: Set<Schedule> = []
    private let sharedConfig: SharedConfigService

    /// Flow code string: e.g. "S1P123S2P12" representing traversed states
    var flowCode: String {
        var code = ""
        var currentSchedule: Schedule?
        for entry in state.history {
            if entry.schedule != currentSchedule {
                code += "S\(entry.schedule.rawValue)"
                currentSchedule = entry.schedule
            }
            code += "P\(entry.process.rawValue)"
        }
        return code.isEmpty ? "—" : code
    }

    /// Process name for current schedule and process
    var currentProcessName: String {
        let processes = state.currentSchedule.processes
        let idx = state.currentProcess.rawValue - 1
        guard idx < processes.count else { return "Unknown" }
        return processes[idx]
    }

    init(sharedConfig: SharedConfigService) {
        self.sharedConfig = sharedConfig
    }

    // MARK: - Navigation

    func startOrchestration(task: String, mode: OrchestrationMode = .full) {
        state = OrchestrationState()
        state.task = task
        state.isActive = true
        state.mode = mode
        completedSchedules = []

        switch mode {
        case .full:
            state.currentSchedule = .knowledge
        case .infiniteMap:
            state.currentSchedule = .plan
            state.currentProcess = .second
        case .exploreMap:
            state.currentSchedule = .production
        }

        recordStep()
        print("OrchestrationService: Started '\(task)' in \(mode) mode at S\(state.currentSchedule.rawValue)P\(state.currentProcess.rawValue)")
    }

    func stop() {
        state.isActive = false
    }

    func navigateToSchedule(_ schedule: Schedule) throws {
        guard state.isActive else { return }
        guard canNavigateTo(schedule) else {
            throw OrchestrationError.cannotNavigate(schedule)
        }
        state.currentSchedule = schedule
        state.currentProcess = .first
        recordStep()
    }

    func advanceProcess() throws {
        guard state.isActive else { return }

        switch state.currentProcess {
        case .first:
            state.currentProcess = .second
        case .second:
            state.currentProcess = .third
        case .third:
            // Complete this schedule, move to next
            completedSchedules.insert(state.currentSchedule)
            if let next = nextSchedule() {
                state.currentSchedule = next
                state.currentProcess = .first
            } else {
                // All schedules complete
                state.isActive = false
                print("OrchestrationService: All schedules complete. Flow: \(flowCode)")
                return
            }
        }

        recordStep()

        // Check if this process requires consultation
        checkConsultationRequirement()
    }

    func canNavigateTo(_ schedule: Schedule) -> Bool {
        switch state.mode {
        case .full:
            // Can navigate to current or any completed schedule, or next uncompleted
            return schedule.rawValue <= (state.currentSchedule.rawValue + 1)
        case .infiniteMap:
            return schedule == .plan || schedule == .implement
        case .exploreMap:
            return schedule == .production
        }
    }

    func resolveConsultation(response: String) {
        state.pendingConsultation?.response = response
        state.pendingConsultation = nil
    }

    func skipConsultation() {
        guard let consultation = state.pendingConsultation, !consultation.isMandatory else { return }
        state.pendingConsultation = nil
    }

    // MARK: - Private

    private func recordStep() {
        state.history.append((
            schedule: state.currentSchedule,
            process: state.currentProcess,
            timestamp: Date()
        ))
    }

    private func nextSchedule() -> Schedule? {
        let all = Schedule.allCases
        switch state.mode {
        case .full:
            guard let idx = all.firstIndex(of: state.currentSchedule),
                  idx + 1 < all.count else { return nil }
            return all[idx + 1]
        case .infiniteMap:
            if state.currentSchedule == .plan { return .implement }
            return nil
        case .exploreMap:
            return nil // Single schedule loop
        }
    }

    private func checkConsultationRequirement() {
        let scheduleId = state.currentSchedule.name.lowercased()
        let processName = currentProcessName.lowercased()

        // Check shared config for consultation requirements
        for sched in sharedConfig.config.orchestration.schedules where sched.id == scheduleId {
            if let consultations = sched.consultation,
               let consultConfig = consultations[processName] {
                state.pendingConsultation = ConsultationRequest(
                    question: "Consultation required at \(state.currentSchedule.name) — \(currentProcessName)",
                    timeout: consultConfig.timeout,
                    isMandatory: consultConfig.type == "mandatory"
                )
            }
        }
    }

    // MARK: - Errors

    enum OrchestrationError: LocalizedError {
        case cannotNavigate(Schedule)

        var errorDescription: String? {
            switch self {
            case .cannotNavigate(let s): return "Cannot navigate to \(s.name) from current state"
            }
        }
    }
}
