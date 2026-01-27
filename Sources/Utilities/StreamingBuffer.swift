import Foundation
import QuartzCore

// MARK: - High-Performance Streaming Text Buffer
// 
// Problem: Updating @Observable state on every streaming token causes:
// 1. 60+ SwiftUI view diffs per second
// 2. Main thread contention
// 3. Memory pressure from string reallocations
// 4. "Blocky" feeling as UI can't keep up
//
// Solution: Coalesce updates to display refresh rate with triple buffering

@MainActor
final class StreamingTextBuffer {
    // Triple buffer pattern - one writing, one ready, one displaying
    private var writeBuffer: String = ""
    private var pendingFlush: Bool = false
    
    // Frame timing
    private var displayLink: CVDisplayLink?
    private var lastUpdateTime: CFTimeInterval = 0
    private let minUpdateInterval: CFTimeInterval = 1.0 / 60.0 // 60fps cap
    
    // Callback when content should be pushed to UI
    var onFlush: ((String) -> Void)?
    
    // Accumulated content (read-only view)
    private(set) var totalContent: String = ""
    
    // Statistics
    private(set) var chunkCount: Int = 0
    private(set) var flushCount: Int = 0
    
    init() {
        writeBuffer.reserveCapacity(4096) // Pre-allocate for fewer reallocations
        totalContent.reserveCapacity(16384)
    }
    
    // MARK: - Public API
    
    /// Append incoming chunk (called from stream)
    func append(_ chunk: String) {
        writeBuffer.append(chunk)
        totalContent.append(chunk)
        chunkCount += 1
        
        scheduleFlushIfNeeded()
    }
    
    /// Force immediate flush (call on stream end)
    func flush() {
        guard !writeBuffer.isEmpty else { return }
        
        let content = writeBuffer
        writeBuffer.removeAll(keepingCapacity: true)
        flushCount += 1
        
        onFlush?(content)
    }
    
    /// Reset for new stream
    func reset() {
        writeBuffer.removeAll(keepingCapacity: true)
        totalContent.removeAll(keepingCapacity: true)
        pendingFlush = false
        chunkCount = 0
        flushCount = 0
    }
    
    // MARK: - Private
    
    private func scheduleFlushIfNeeded() {
        guard !pendingFlush else { return }
        
        let now = CACurrentMediaTime()
        let elapsed = now - lastUpdateTime
        
        if elapsed >= minUpdateInterval {
            // Enough time has passed, flush immediately
            performFlush()
        } else {
            // Schedule flush for next frame
            pendingFlush = true
            let delay = minUpdateInterval - elapsed
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.performFlush()
            }
        }
    }
    
    private func performFlush() {
        pendingFlush = false
        lastUpdateTime = CACurrentMediaTime()
        flush()
    }
}

// MARK: - Optimized Message Accumulator
// 
// For chat messages, we want even less frequent updates
// since rendering markdown/code blocks is expensive

@MainActor
final class MessageAccumulator {
    private var buffer: String = ""
    private var updateTimer: DispatchSourceTimer?
    private let updateInterval: TimeInterval
    
    var onUpdate: ((String) -> Void)?
    
    init(updateInterval: TimeInterval = 0.05) { // 20fps for heavy content
        self.updateInterval = updateInterval
        buffer.reserveCapacity(8192)
    }
    
    func append(_ text: String) {
        buffer.append(text)
        scheduleUpdate()
    }
    
    func finalize() -> String {
        updateTimer?.cancel()
        updateTimer = nil
        
        let final = buffer
        onUpdate?(final)
        buffer.removeAll(keepingCapacity: true)
        return final
    }
    
    func reset() {
        updateTimer?.cancel()
        updateTimer = nil
        buffer.removeAll(keepingCapacity: true)
    }
    
    private func scheduleUpdate() {
        guard updateTimer == nil else { return }
        
        updateTimer = DispatchSource.makeTimerSource(queue: .main)
        updateTimer?.schedule(deadline: .now() + updateInterval)
        updateTimer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.updateTimer = nil
            
            if !self.buffer.isEmpty {
                self.onUpdate?(self.buffer)
            }
        }
        updateTimer?.resume()
    }
}

// MARK: - Batch State Updater
//
// For updating multiple @Observable properties efficiently

@MainActor
final class BatchStateUpdater {
    private var pendingUpdates: [() -> Void] = []
    private var isScheduled = false
    
    /// Queue an update to be executed in the next batch
    func queue(_ update: @escaping () -> Void) {
        pendingUpdates.append(update)
        scheduleFlush()
    }
    
    /// Execute all pending updates immediately
    func flushNow() {
        guard !pendingUpdates.isEmpty else { return }
        
        let updates = pendingUpdates
        pendingUpdates.removeAll(keepingCapacity: true)
        isScheduled = false
        
        // Execute all updates in a single transaction
        for update in updates {
            update()
        }
    }
    
    private func scheduleFlush() {
        guard !isScheduled else { return }
        isScheduled = true
        
        // Use RunLoop to batch with other UI updates
        Task { @MainActor [weak self] in
            self?.flushNow()
        }
    }
}

// MARK: - Debouncer
//
// For expensive operations like search or syntax highlighting

final class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    private let queue: DispatchQueue
    
    init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }
    
    func debounce(_ action: @escaping () -> Void) {
        workItem?.cancel()
        
        let item = DispatchWorkItem(block: action)
        workItem = item
        
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }
    
    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}

// MARK: - Throttler
//
// For rate-limiting frequent events (scroll, resize, etc.)

final class Throttler {
    private let interval: TimeInterval
    private var lastExecution: CFTimeInterval = 0
    private var pendingAction: (() -> Void)?
    private var timer: DispatchSourceTimer?
    private let queue: DispatchQueue
    
    init(interval: TimeInterval, queue: DispatchQueue = .main) {
        self.interval = interval
        self.queue = queue
    }
    
    func throttle(_ action: @escaping () -> Void) {
        let now = CACurrentMediaTime()
        let elapsed = now - lastExecution
        
        if elapsed >= interval {
            // Execute immediately
            lastExecution = now
            action()
        } else {
            // Store for later execution
            pendingAction = action
            scheduleDelayedExecution(delay: interval - elapsed)
        }
    }
    
    private func scheduleDelayedExecution(delay: TimeInterval) {
        guard timer == nil else { return }
        
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now() + delay)
        timer?.setEventHandler { [weak self] in
            guard let self = self, let action = self.pendingAction else { return }
            
            self.lastExecution = CACurrentMediaTime()
            self.pendingAction = nil
            self.timer = nil
            
            action()
        }
        timer?.resume()
    }
    
    func cancel() {
        timer?.cancel()
        timer = nil
        pendingAction = nil
    }
}
