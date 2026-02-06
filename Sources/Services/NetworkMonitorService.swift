import Foundation
import Network

// MARK: - Network Monitor Service
// Monitors network connectivity, WiFi/Ethernet status, and connection quality

@Observable
final class NetworkMonitorService {
    
    // MARK: - Connection State
    
    enum ConnectionType: String {
        case wifi = "WiFi"
        case ethernet = "Ethernet"
        case cellular = "Cellular"
        case none = "None"
        
        var icon: String {
            switch self {
            case .wifi: return "wifi"
            case .ethernet: return "cable.connector"
            case .cellular: return "antenna.radiowaves.left.and.right"
            case .none: return "wifi.slash"
            }
        }
    }
    
    enum ConnectionQuality: String {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
        case offline = "Offline"
        
        var color: String {
            switch self {
            case .excellent: return "success"
            case .good: return "success"
            case .fair: return "accent"
            case .poor: return "warning"
            case .offline: return "error"
            }
        }
    }
    
    struct NetworkStatus {
        var isConnected: Bool
        var connectionType: ConnectionType
        var quality: ConnectionQuality
        var ssid: String?
        var lastChecked: Date
        var latencyMs: Int?
        var downloadSpeedMbps: Double?
        
        static var offline: NetworkStatus {
            NetworkStatus(
                isConnected: false,
                connectionType: .none,
                quality: .offline,
                ssid: nil,
                lastChecked: Date(),
                latencyMs: nil,
                downloadSpeedMbps: nil
            )
        }
    }
    
    // MARK: - State
    
    private(set) var status: NetworkStatus = .offline
    private(set) var isMonitoring = false
    
    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.ollamabot.networkmonitor")
    
    // Callbacks
    var onConnectionLost: (() -> Void)?
    var onConnectionRestored: (() -> Void)?
    var onQualityChange: ((ConnectionQuality) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        // Initial check
        checkConnection()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring Control
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
        pathMonitor?.start(queue: monitorQueue)
    }
    
    func stopMonitoring() {
        pathMonitor?.cancel()
        pathMonitor = nil
        isMonitoring = false
    }
    
    func checkConnection() {
        let monitor = NWPathMonitor()
        let semaphore = DispatchSemaphore(value: 0)
        
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
            semaphore.signal()
        }
        
        monitor.start(queue: monitorQueue)
        _ = semaphore.wait(timeout: .now() + 2)
        monitor.cancel()
    }
    
    // MARK: - Path Handling
    
    private func handlePathUpdate(_ path: NWPath) {
        let wasConnected = status.isConnected
        
        // Determine connection type
        let connectionType: ConnectionType
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else {
            connectionType = .none
        }
        
        // Determine quality
        let quality: ConnectionQuality
        let isConnected = path.status == .satisfied
        
        if !isConnected {
            quality = .offline
        } else if path.isExpensive {
            quality = .fair
        } else if path.isConstrained {
            quality = .poor
        } else if connectionType == .ethernet {
            quality = .excellent
        } else {
            quality = .good
        }
        
        // Get SSID for WiFi
        var ssid: String?
        if connectionType == .wifi {
            ssid = getCurrentSSID()
        }
        
        // Update status
        status = NetworkStatus(
            isConnected: isConnected,
            connectionType: connectionType,
            quality: quality,
            ssid: ssid,
            lastChecked: Date(),
            latencyMs: nil,
            downloadSpeedMbps: nil
        )
        
        // Fire callbacks
        if wasConnected && !isConnected {
            onConnectionLost?()
        } else if !wasConnected && isConnected {
            onConnectionRestored?()
        }
        
        onQualityChange?(quality)
        
        // Test latency if connected
        if isConnected {
            Task {
                await measureLatency()
            }
        }
    }
    
    // MARK: - WiFi SSID
    
    private func getCurrentSSID() -> String? {
        // Use CoreWLAN (would need import)
        // For now, return nil - actual implementation would use CWWiFiClient
        return nil
    }
    
    // MARK: - Latency Measurement
    
    private func measureLatency() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Ping Ollama server (local)
        if let url = URL(string: "http://localhost:11434/api/tags") {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 5
            
            do {
                _ = try await URLSession.shared.data(for: request)
                let latencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                
                await MainActor.run {
                    status.latencyMs = latencyMs
                    
                    // Update quality based on latency
                    if latencyMs < 50 {
                        status.quality = .excellent
                    } else if latencyMs < 200 {
                        status.quality = .good
                    } else if latencyMs < 500 {
                        status.quality = .fair
                    } else {
                        status.quality = .poor
                    }
                }
            } catch {
                // Ollama not responding - still connected to network though
            }
        }
    }
    
    // MARK: - Capabilities
    
    /// Check if we can perform web-dependent operations
    var canPerformWebOperations: Bool {
        status.isConnected && status.quality != .poor
    }
    
    /// Check if Ollama should work (local, doesn't need internet)
    var canUseOllama: Bool {
        // Ollama is local, works even offline
        true
    }
    
    /// Check if RAG can work
    var canUseRAG: Bool {
        // RAG with local vector store works offline
        // RAG with web search needs internet
        true  // Local RAG always works
    }
}
