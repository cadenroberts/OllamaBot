import Foundation
import Combine

// MARK: - System Monitor Service
// Tracks RAM usage, processes, and system health for intelligent resource management

@Observable
final class SystemMonitorService {
    
    // MARK: - Memory Info
    
    struct MemoryInfo {
        let totalRAM: UInt64           // Total physical RAM in bytes
        let usedRAM: UInt64            // Currently used RAM
        let freeRAM: UInt64            // Free RAM available
        let wiredRAM: UInt64           // Wired (kernel) memory
        let activeRAM: UInt64          // Active memory
        let inactiveRAM: UInt64        // Inactive (cached) memory
        let compressedRAM: UInt64      // Compressed memory
        let appMemory: UInt64          // App memory (active + inactive)
        
        var usedPercent: Double {
            Double(usedRAM) / Double(totalRAM) * 100
        }
        
        var freePercent: Double {
            Double(freeRAM) / Double(totalRAM) * 100
        }
        
        var formattedTotal: String {
            ByteCountFormatter.string(fromByteCount: Int64(totalRAM), countStyle: .memory)
        }
        
        var formattedUsed: String {
            ByteCountFormatter.string(fromByteCount: Int64(usedRAM), countStyle: .memory)
        }
        
        var formattedFree: String {
            ByteCountFormatter.string(fromByteCount: Int64(freeRAM), countStyle: .memory)
        }
        
        var pressureLevel: MemoryPressureLevel {
            if usedPercent > 90 { return .critical }
            if usedPercent > 80 { return .high }
            if usedPercent > 60 { return .moderate }
            return .normal
        }
    }
    
    enum MemoryPressureLevel: String {
        case normal = "Normal"
        case moderate = "Moderate"
        case high = "High"
        case critical = "Critical"
        
        var color: String {
            switch self {
            case .normal: return "success"
            case .moderate: return "accent"
            case .high: return "warning"
            case .critical: return "error"
            }
        }
    }
    
    // MARK: - Process Info
    
    struct ProcessInfo: Identifiable {
        let id: Int32                  // PID
        let name: String               // Process name
        let memoryUsage: UInt64        // Memory in bytes
        let cpuUsage: Double           // CPU percentage
        let user: String               // User running the process
        
        var formattedMemory: String {
            ByteCountFormatter.string(fromByteCount: Int64(memoryUsage), countStyle: .memory)
        }
        
        var isOllamaRelated: Bool {
            name.lowercased().contains("ollama")
        }
    }
    
    // MARK: - State
    
    private(set) var memoryInfo: MemoryInfo?
    private(set) var topProcesses: [ProcessInfo] = []
    private(set) var isMonitoring: Bool = false
    private(set) var lastUpdate: Date?
    
    private var monitorTimer: Timer?
    private let updateInterval: TimeInterval = 2.0
    
    // MARK: - Initialization
    
    init() {
        // Initial fetch
        refresh()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring Control
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        refresh() // Initial update
        
        monitorTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }
    
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        isMonitoring = false
    }
    
    func refresh() {
        Task {
            await MainActor.run {
                self.memoryInfo = getMemoryInfo()
                self.topProcesses = getTopProcesses(limit: 20)
                self.lastUpdate = Date()
            }
        }
    }
    
    // MARK: - Memory Info
    
    private func getMemoryInfo() -> MemoryInfo {
        // Get total physical memory
        let totalRAM = ProcessInfo.processInfo.physicalMemory
        
        // Get VM statistics
        var vmStats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            // Return basic info if VM stats fail
            return MemoryInfo(
                totalRAM: totalRAM,
                usedRAM: 0,
                freeRAM: totalRAM,
                wiredRAM: 0,
                activeRAM: 0,
                inactiveRAM: 0,
                compressedRAM: 0,
                appMemory: 0
            )
        }
        
        let pageSize = UInt64(vm_kernel_page_size)
        
        let free = UInt64(vmStats.free_count) * pageSize
        let active = UInt64(vmStats.active_count) * pageSize
        let inactive = UInt64(vmStats.inactive_count) * pageSize
        let wired = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count) * pageSize
        
        // Calculate used RAM (excluding free and inactive which can be reclaimed)
        let used = active + wired + compressed
        let appMemory = active + inactive
        
        return MemoryInfo(
            totalRAM: totalRAM,
            usedRAM: used,
            freeRAM: free + inactive,  // Include inactive as it can be reclaimed
            wiredRAM: wired,
            activeRAM: active,
            inactiveRAM: inactive,
            compressedRAM: compressed,
            appMemory: appMemory
        )
    }
    
    // MARK: - Process Info
    
    private func getTopProcesses(limit: Int) -> [ProcessInfo] {
        // Use ps command to get process list with memory info
        let output = runCommand("ps -axo pid,rss,pcpu,user,comm | tail -n +2 | sort -k2 -rn | head -n \(limit)")
        
        var processes: [ProcessInfo] = []
        
        for line in output.components(separatedBy: "\n") {
            let parts = line.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            
            guard parts.count >= 5,
                  let pid = Int32(parts[0]),
                  let rss = UInt64(parts[1]),  // RSS is in KB
                  let cpu = Double(parts[2]) else {
                continue
            }
            
            let user = parts[3]
            let name = parts[4...].joined(separator: " ")
                .components(separatedBy: "/").last ?? parts[4]
            
            processes.append(ProcessInfo(
                id: pid,
                name: name,
                memoryUsage: rss * 1024,  // Convert KB to bytes
                cpuUsage: cpu,
                user: user
            ))
        }
        
        return processes
    }
    
    // MARK: - Process Control
    
    /// Force quit a process by PID
    func forceQuitProcess(pid: Int32) -> Bool {
        let result = kill(pid, SIGKILL)
        if result == 0 {
            // Refresh after kill
            refresh()
            return true
        }
        return false
    }
    
    /// Force quit a process by name (all matching processes)
    func forceQuitProcess(named name: String) -> Int {
        var killed = 0
        for process in topProcesses where process.name.lowercased().contains(name.lowercased()) {
            if forceQuitProcess(pid: process.id) {
                killed += 1
            }
        }
        return killed
    }
    
    /// Get Ollama-related processes
    var ollamaProcesses: [ProcessInfo] {
        topProcesses.filter { $0.isOllamaRelated }
    }
    
    /// Total memory used by Ollama
    var ollamaMemoryUsage: UInt64 {
        ollamaProcesses.reduce(0) { $0 + $1.memoryUsage }
    }
    
    /// Check if memory pressure is high enough to affect model loading
    var isMemoryConstrained: Bool {
        guard let info = memoryInfo else { return false }
        return info.pressureLevel == .high || info.pressureLevel == .critical
    }
    
    /// Estimate if a model of given size can be loaded
    func canLoadModel(sizeGB: Double) -> Bool {
        guard let info = memoryInfo else { return false }
        let requiredBytes = UInt64(sizeGB * 1_073_741_824)
        // Need ~1.5x model size for loading + overhead
        let needed = UInt64(Double(requiredBytes) * 1.5)
        return info.freeRAM >= needed
    }
    
    // MARK: - Helper
    
    private func runCommand(_ command: String) -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}

// MARK: - Memory Pressure Monitor (Enhanced for System Monitor)

class SystemMemoryPressureMonitor {
    private var source: DispatchSourceMemoryPressure?
    var onHighPressure: (() -> Void)?
    var onNormalPressure: (() -> Void)?
    
    init() {
        startMonitoring()
    }
    
    deinit {
        source?.cancel()
    }
    
    private func startMonitoring() {
        source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        
        source?.setEventHandler { [weak self] in
            let event = self?.source?.data ?? []
            
            if event.contains(.critical) {
                print("🔴 CRITICAL memory pressure")
                self?.onHighPressure?()
            } else if event.contains(.warning) {
                print("🟡 Warning memory pressure")
                self?.onHighPressure?()
            }
        }
        
        source?.setCancelHandler { [weak self] in
            self?.source = nil
        }
        
        source?.resume()
    }
}
