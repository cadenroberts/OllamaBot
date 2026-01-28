import SwiftUI

// MARK: - Process Manager View
// Activity Monitor-like interface for managing system processes

struct ProcessManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var monitor = SystemMonitorService()
    @State private var sortBy: SortOption = .memory
    @State private var showOnlyOllama = false
    @State private var selectedProcess: SystemMonitorService.ProcessInfo?
    @State private var showKillConfirmation = false
    
    enum SortOption: String, CaseIterable {
        case memory = "Memory"
        case cpu = "CPU"
        case name = "Name"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            DSDivider()
            
            // Memory overview
            memoryOverview
            
            DSDivider()
            
            // Process list
            processList
        }
        .frame(width: 600, height: 500)
        .background(DS.Colors.background)
        .onAppear {
            monitor.startMonitoring()
        }
        .onDisappear {
            monitor.stopMonitoring()
        }
        .alert("Force Quit Process?", isPresented: $showKillConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Force Quit", role: .destructive) {
                if let process = selectedProcess {
                    _ = monitor.forceQuitProcess(pid: process.id)
                    selectedProcess = nil
                }
            }
        } message: {
            if let process = selectedProcess {
                Text("Force quit \"\(process.name)\"? This may cause data loss.")
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Process Manager")
                    .font(DS.Typography.title2)
                    .foregroundStyle(DS.Colors.text)
                
                if let lastUpdate = monitor.lastUpdate {
                    Text("Updated \(lastUpdate.formatted(date: .omitted, time: .shortened))")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.tertiaryText)
                }
            }
            
            Spacer()
            
            // Filter toggle
            Toggle(isOn: $showOnlyOllama) {
                Text("Ollama Only")
                    .font(DS.Typography.caption)
            }
            .toggleStyle(.checkbox)
            
            // Refresh button
            DSIconButton(icon: "arrow.clockwise", size: 20) {
                monitor.refresh()
            }
            
            // Close button
            DSIconButton(icon: "xmark", size: 20) {
                dismiss()
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
    }
    
    // MARK: - Memory Overview
    
    private var memoryOverview: some View {
        HStack(spacing: DS.Spacing.xl) {
            if let info = monitor.memoryInfo {
                // Memory bar
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack {
                        Text("Memory Pressure")
                            .font(DS.Typography.caption.weight(.medium))
                        
                        Spacer()
                        
                        Text(info.pressureLevel.rawValue)
                            .font(DS.Typography.caption)
                            .foregroundStyle(pressureColor(info.pressureLevel))
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DS.Colors.tertiaryBackground)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(pressureColor(info.pressureLevel))
                                .frame(width: geo.size.width * (info.usedPercent / 100))
                        }
                    }
                    .frame(height: 8)
                    
                    HStack {
                        Text("\(info.formattedUsed) used")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                        
                        Spacer()
                        
                        Text("\(info.formattedFree) available")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Stats
                VStack(spacing: DS.Spacing.sm) {
                    statItem(label: "Total", value: info.formattedTotal)
                    statItem(label: "Active", value: ByteCountFormatter.string(fromByteCount: Int64(info.activeRAM), countStyle: .memory))
                    statItem(label: "Wired", value: ByteCountFormatter.string(fromByteCount: Int64(info.wiredRAM), countStyle: .memory))
                }
                
                // Ollama specific
                if !monitor.ollamaProcesses.isEmpty {
                    VStack(spacing: DS.Spacing.sm) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "brain")
                                .foregroundStyle(DS.Colors.accent)
                            Text("Ollama")
                                .font(DS.Typography.caption.weight(.medium))
                        }
                        
                        Text(ByteCountFormatter.string(fromByteCount: Int64(monitor.ollamaMemoryUsage), countStyle: .memory))
                            .font(DS.Typography.headline)
                            .foregroundStyle(DS.Colors.accent)
                        
                        Text("\(monitor.ollamaProcesses.count) process(es)")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.tertiaryText)
                    }
                    .padding(DS.Spacing.sm)
                    .background(DS.Colors.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                }
            } else {
                Text("Loading memory info...")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.secondaryBackground)
    }
    
    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(DS.Typography.caption2)
                .foregroundStyle(DS.Colors.tertiaryText)
            Text(value)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.text)
        }
    }
    
    private func pressureColor(_ level: SystemMonitorService.MemoryPressureLevel) -> Color {
        switch level {
        case .normal: return DS.Colors.success
        case .moderate: return DS.Colors.accent
        case .high: return DS.Colors.warning
        case .critical: return DS.Colors.error
        }
    }
    
    // MARK: - Process List
    
    private var processList: some View {
        VStack(spacing: 0) {
            // Sort header
            HStack(spacing: DS.Spacing.md) {
                Text("PROCESS")
                    .frame(width: 200, alignment: .leading)
                
                Spacer()
                
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button(action: { sortBy = option }) {
                        HStack(spacing: DS.Spacing.xxs) {
                            Text(option.rawValue.uppercased())
                            if sortBy == option {
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                        }
                        .foregroundStyle(sortBy == option ? DS.Colors.accent : DS.Colors.tertiaryText)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 80)
                }
                
                Text("") // Placeholder for action button
                    .frame(width: 30)
            }
            .font(DS.Typography.caption2)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.surface)
            
            DSDivider()
            
            // Process rows
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sortedProcesses) { process in
                        ProcessRow(
                            process: process,
                            onKill: {
                                selectedProcess = process
                                showKillConfirmation = true
                            }
                        )
                    }
                }
            }
        }
    }
    
    private var sortedProcesses: [SystemMonitorService.ProcessInfo] {
        let processes = showOnlyOllama ? monitor.ollamaProcesses : monitor.topProcesses
        
        switch sortBy {
        case .memory:
            return processes.sorted { $0.memoryUsage > $1.memoryUsage }
        case .cpu:
            return processes.sorted { $0.cpuUsage > $1.cpuUsage }
        case .name:
            return processes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }
}

// MARK: - Process Row

struct ProcessRow: View {
    let process: SystemMonitorService.ProcessInfo
    let onKill: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Process name
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: process.isOllamaRelated ? "brain" : "gearshape")
                    .font(.caption)
                    .foregroundStyle(process.isOllamaRelated ? DS.Colors.accent : DS.Colors.tertiaryText)
                    .frame(width: 16)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(process.name)
                        .font(DS.Typography.callout)
                        .lineLimit(1)
                    
                    Text("PID: \(process.id)")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                }
            }
            .frame(width: 200, alignment: .leading)
            
            Spacer()
            
            // Memory
            Text(process.formattedMemory)
                .font(DS.Typography.mono(11))
                .foregroundStyle(memoryColor)
                .frame(width: 80)
            
            // CPU
            Text(String(format: "%.1f%%", process.cpuUsage))
                .font(DS.Typography.mono(11))
                .foregroundStyle(cpuColor)
                .frame(width: 80)
            
            // Name (user)
            Text(process.user)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.tertiaryText)
                .frame(width: 80)
            
            // Kill button
            if isHovered {
                DSIconButton(icon: "xmark.circle", size: 20, color: DS.Colors.error) {
                    onKill()
                }
                .frame(width: 30)
            } else {
                Color.clear.frame(width: 30)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(isHovered ? DS.Colors.hover : Color.clear)
        .onHover { isHovered = $0 }
    }
    
    private var memoryColor: Color {
        if process.memoryUsage > 4_000_000_000 {  // > 4GB
            return DS.Colors.error
        } else if process.memoryUsage > 1_000_000_000 {  // > 1GB
            return DS.Colors.warning
        }
        return DS.Colors.secondaryText
    }
    
    private var cpuColor: Color {
        if process.cpuUsage > 80 {
            return DS.Colors.error
        } else if process.cpuUsage > 50 {
            return DS.Colors.warning
        }
        return DS.Colors.secondaryText
    }
}

// MARK: - RAM Status Indicator (for StatusBar)

struct RAMStatusIndicator: View {
    @State private var monitor = SystemMonitorService()
    @State private var showPopover = false
    
    var body: some View {
        Button(action: { showPopover.toggle() }) {
            HStack(spacing: DS.Spacing.xs) {
                // Memory bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(DS.Colors.tertiaryBackground)
                        
                        if let info = monitor.memoryInfo {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(pressureColor(info.pressureLevel))
                                .frame(width: geo.size.width * (info.usedPercent / 100))
                        }
                    }
                }
                .frame(width: 40, height: 4)
                
                // Percentage
                if let info = monitor.memoryInfo {
                    Text("\(Int(info.usedPercent))%")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.tertiaryText)
                }
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .top) {
            RAMPopover(monitor: monitor)
        }
        .onAppear {
            monitor.startMonitoring()
        }
        .onDisappear {
            monitor.stopMonitoring()
        }
    }
    
    private func pressureColor(_ level: SystemMonitorService.MemoryPressureLevel) -> Color {
        switch level {
        case .normal: return DS.Colors.success
        case .moderate: return DS.Colors.accent
        case .high: return DS.Colors.warning
        case .critical: return DS.Colors.error
        }
    }
}

struct RAMPopover: View {
    let monitor: SystemMonitorService
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Memory Usage")
                .font(DS.Typography.headline)
            
            if let info = monitor.memoryInfo {
                VStack(spacing: DS.Spacing.sm) {
                    infoRow("Used", info.formattedUsed)
                    infoRow("Free", info.formattedFree)
                    infoRow("Total", info.formattedTotal)
                    
                    DSDivider()
                    
                    infoRow("Ollama", ByteCountFormatter.string(fromByteCount: Int64(monitor.ollamaMemoryUsage), countStyle: .memory))
                }
            }
        }
        .padding(DS.Spacing.md)
        .frame(width: 200)
        .background(DS.Colors.surface)
    }
    
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
            Spacer()
            Text(value)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.text)
        }
    }
}

#Preview {
    ProcessManagerView()
}
