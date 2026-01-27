import Foundation
import AppKit
import os.log

// MARK: - Benchmark Suite for OllamaBot

/// Comprehensive benchmarking for performance-critical components
/// Run with: BenchmarkRunner.runAll()
enum BenchmarkRunner {
    
    private static let benchLog = OSLog(subsystem: "com.ollamabot", category: "benchmarks")
    
    // MARK: - Public API
    
    @MainActor
    static func runAll() async -> BenchmarkReport {
        print("🔬 Starting OllamaBot Benchmark Suite...")
        print("=" * 60)
        
        var report = BenchmarkReport()
        
        // 1. LRU Cache benchmarks
        report.cacheResults = benchmarkLRUCache()
        
        // 2. Syntax Highlighter benchmarks
        report.syntaxResults = await benchmarkSyntaxHighlighter()
        
        // 3. File operations benchmarks
        report.fileResults = benchmarkFileOperations()
        
        // 4. String processing benchmarks
        report.stringResults = benchmarkStringProcessing()
        
        // 5. Parallel processing benchmarks
        report.parallelResults = await benchmarkParallelProcessing()
        
        // 6. Memory efficiency benchmarks
        report.memoryResults = benchmarkMemory()
        
        print("\n" + "=" * 60)
        print("📊 BENCHMARK SUMMARY")
        print("=" * 60)
        report.printSummary()
        
        return report
    }
    
    // MARK: - LRU Cache Benchmarks
    
    static func benchmarkLRUCache() -> [BenchmarkResult] {
        print("\n📦 LRU Cache Benchmarks")
        print("-" * 40)
        
        var results: [BenchmarkResult] = []
        
        // Test 1: Sequential writes
        let cache = LRUCache<Int, String>(capacity: 1000)
        let writeTime = measureTime {
            for i in 0..<10000 {
                cache.set(i, "value_\(i)")
            }
        }
        results.append(BenchmarkResult(
            name: "Cache Sequential Writes (10K)",
            timeMs: writeTime,
            opsPerSecond: 10000.0 / (writeTime / 1000.0)
        ))
        
        // Test 2: Sequential reads (with eviction)
        let readTime = measureTime {
            for i in 0..<10000 {
                _ = cache.get(i)
            }
        }
        results.append(BenchmarkResult(
            name: "Cache Sequential Reads (10K)",
            timeMs: readTime,
            opsPerSecond: 10000.0 / (readTime / 1000.0)
        ))
        
        // Test 3: Random access pattern
        let randomTime = measureTime {
            for _ in 0..<10000 {
                let key = Int.random(in: 0..<10000)
                if Int.random(in: 0..<10) < 7 {
                    _ = cache.get(key)
                } else {
                    cache.set(key, "random_\(key)")
                }
            }
        }
        results.append(BenchmarkResult(
            name: "Cache Random Access (10K)",
            timeMs: randomTime,
            opsPerSecond: 10000.0 / (randomTime / 1000.0)
        ))
        
        // Test 4: String keys (realistic)
        let stringCache = LRUCache<String, NSAttributedString>(capacity: 100)
        let stringWriteTime = measureTime {
            for i in 0..<1000 {
                let key = "swift:hash_\(i)"
                let value = NSMutableAttributedString(string: String(repeating: "x", count: 100))
                stringCache.set(key, value, size: 1)
            }
        }
        results.append(BenchmarkResult(
            name: "Cache String Keys (1K)",
            timeMs: stringWriteTime,
            opsPerSecond: 1000.0 / (stringWriteTime / 1000.0)
        ))
        
        for result in results {
            print("  \(result.name): \(String(format: "%.2f", result.timeMs))ms (\(Int(result.opsPerSecond)) ops/sec)")
        }
        
        return results
    }
    
    // MARK: - Syntax Highlighter Benchmarks
    
    static func benchmarkSyntaxHighlighter() async -> [BenchmarkResult] {
        print("\n🎨 Syntax Highlighter Benchmarks")
        print("-" * 40)
        
        var results: [BenchmarkResult] = []
        let highlighter = SyntaxHighlighter(theme: .dark)
        
        // Generate test code of various sizes
        let smallCode = generateSwiftCode(lines: 50)
        let mediumCode = generateSwiftCode(lines: 500)
        let largeCode = generateSwiftCode(lines: 2000)
        
        // Test 1: Small file highlighting
        let smallTime = measureTime {
            for _ in 0..<100 {
                _ = highlighter.highlight(smallCode, language: "swift")
            }
        }
        results.append(BenchmarkResult(
            name: "Highlight Small (50 lines, 100x)",
            timeMs: smallTime,
            opsPerSecond: 100.0 / (smallTime / 1000.0)
        ))
        
        // Test 2: Medium file highlighting
        let mediumTime = measureTime {
            for _ in 0..<10 {
                _ = highlighter.highlight(mediumCode, language: "swift")
            }
        }
        results.append(BenchmarkResult(
            name: "Highlight Medium (500 lines, 10x)",
            timeMs: mediumTime,
            opsPerSecond: 10.0 / (mediumTime / 1000.0)
        ))
        
        // Test 3: Large file highlighting
        let largeTime = measureTime {
            _ = highlighter.highlight(largeCode, language: "swift")
        }
        results.append(BenchmarkResult(
            name: "Highlight Large (2K lines)",
            timeMs: largeTime,
            opsPerSecond: 1.0 / (largeTime / 1000.0)
        ))
        
        // Test 4: Cache hit performance
        _ = highlighter.highlight(mediumCode, language: "swift") // Prime cache
        let cacheHitTime = measureTime {
            for _ in 0..<100 {
                _ = highlighter.highlight(mediumCode, language: "swift")
            }
        }
        results.append(BenchmarkResult(
            name: "Cache Hit (500 lines, 100x)",
            timeMs: cacheHitTime,
            opsPerSecond: 100.0 / (cacheHitTime / 1000.0)
        ))
        
        // Test 5: Different languages
        let jsCode = generateJSCode(lines: 200)
        let pyCode = generatePythonCode(lines: 200)
        
        let langTime = measureTime {
            for _ in 0..<10 {
                _ = highlighter.highlight(smallCode, language: "swift")
                _ = highlighter.highlight(jsCode, language: "js")
                _ = highlighter.highlight(pyCode, language: "python")
            }
        }
        results.append(BenchmarkResult(
            name: "Multi-language (3 langs, 10x)",
            timeMs: langTime,
            opsPerSecond: 30.0 / (langTime / 1000.0)
        ))
        
        for result in results {
            print("  \(result.name): \(String(format: "%.2f", result.timeMs))ms")
        }
        
        return results
    }
    
    // MARK: - File Operations Benchmarks
    
    static func benchmarkFileOperations() -> [BenchmarkResult] {
        print("\n📁 File Operations Benchmarks")
        print("-" * 40)
        
        var results: [BenchmarkResult] = []
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // Create test files
        let smallContent = String(repeating: "Hello, World!\n", count: 100)
        let mediumContent = String(repeating: "x", count: 100_000)
        let largeContent = String(repeating: "y", count: 1_000_000)
        
        let smallFile = tempDir.appendingPathComponent("small.txt")
        let mediumFile = tempDir.appendingPathComponent("medium.txt")
        let largeFile = tempDir.appendingPathComponent("large.txt")
        
        try? smallContent.write(to: smallFile, atomically: true, encoding: .utf8)
        try? mediumContent.write(to: mediumFile, atomically: true, encoding: .utf8)
        try? largeContent.write(to: largeFile, atomically: true, encoding: .utf8)
        
        // Test 1: Small file reads (standard)
        let smallReadTime = measureTime {
            for _ in 0..<100 {
                _ = try? String(contentsOf: smallFile, encoding: .utf8)
            }
        }
        results.append(BenchmarkResult(
            name: "Small File Read (~1KB, 100x)",
            timeMs: smallReadTime,
            opsPerSecond: 100.0 / (smallReadTime / 1000.0)
        ))
        
        // Test 2: Medium file reads (standard)
        let mediumReadTime = measureTime {
            for _ in 0..<10 {
                _ = try? String(contentsOf: mediumFile, encoding: .utf8)
            }
        }
        results.append(BenchmarkResult(
            name: "Medium File Read (~100KB, 10x)",
            timeMs: mediumReadTime,
            opsPerSecond: 10.0 / (mediumReadTime / 1000.0)
        ))
        
        // Test 3: Large file with memory mapping
        let mappedReadTime = measureTime {
            for _ in 0..<5 {
                let reader = MappedFileReader(url: largeFile)
                _ = try? reader.read()
            }
        }
        results.append(BenchmarkResult(
            name: "Large File Mapped (~1MB, 5x)",
            timeMs: mappedReadTime,
            opsPerSecond: 5.0 / (mappedReadTime / 1000.0)
        ))
        
        // Test 4: Large file without memory mapping
        let unmappedReadTime = measureTime {
            for _ in 0..<5 {
                _ = try? String(contentsOf: largeFile, encoding: .utf8)
            }
        }
        results.append(BenchmarkResult(
            name: "Large File Standard (~1MB, 5x)",
            timeMs: unmappedReadTime,
            opsPerSecond: 5.0 / (unmappedReadTime / 1000.0)
        ))
        
        // Test 5: Directory enumeration
        // Create 100 files
        for i in 0..<100 {
            let file = tempDir.appendingPathComponent("file_\(i).txt")
            try? "content".write(to: file, atomically: true, encoding: .utf8)
        }
        
        let enumTime = measureTime {
            for _ in 0..<10 {
                _ = try? FileManager.default.contentsOfDirectory(
                    at: tempDir,
                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey]
                )
            }
        }
        results.append(BenchmarkResult(
            name: "Directory Enum (100 files, 10x)",
            timeMs: enumTime,
            opsPerSecond: 10.0 / (enumTime / 1000.0)
        ))
        
        for result in results {
            print("  \(result.name): \(String(format: "%.2f", result.timeMs))ms")
        }
        
        return results
    }
    
    // MARK: - String Processing Benchmarks
    
    static func benchmarkStringProcessing() -> [BenchmarkResult] {
        print("\n📝 String Processing Benchmarks")
        print("-" * 40)
        
        var results: [BenchmarkResult] = []
        
        let testCode = generateSwiftCode(lines: 500)
        
        // Test 1: Regex word extraction (current method)
        let regexExtractTime = measureTime {
            for _ in 0..<10 {
                _ = extractWordsRegex(testCode)
            }
        }
        results.append(BenchmarkResult(
            name: "Word Extract Regex (10x)",
            timeMs: regexExtractTime,
            opsPerSecond: 10.0 / (regexExtractTime / 1000.0)
        ))
        
        // Test 2: Character-based word extraction
        let charExtractTime = measureTime {
            for _ in 0..<10 {
                _ = extractWordsCharacter(testCode)
            }
        }
        results.append(BenchmarkResult(
            name: "Word Extract Char-based (10x)",
            timeMs: charExtractTime,
            opsPerSecond: 10.0 / (charExtractTime / 1000.0)
        ))
        
        // Test 3: Trigram extraction
        let trigramTime = measureTime {
            for _ in 0..<10 {
                _ = extractTrigrams(testCode)
            }
        }
        results.append(BenchmarkResult(
            name: "Trigram Extract (10x)",
            timeMs: trigramTime,
            opsPerSecond: 10.0 / (trigramTime / 1000.0)
        ))
        
        // Test 4: Line counting
        let lineCountTime = measureTime {
            for _ in 0..<100 {
                _ = testCode.components(separatedBy: .newlines).count
            }
        }
        results.append(BenchmarkResult(
            name: "Line Count (100x)",
            timeMs: lineCountTime,
            opsPerSecond: 100.0 / (lineCountTime / 1000.0)
        ))
        
        // Test 5: Optimized line counting
        let optLineCountTime = measureTime {
            for _ in 0..<100 {
                _ = countLines(testCode)
            }
        }
        results.append(BenchmarkResult(
            name: "Line Count Optimized (100x)",
            timeMs: optLineCountTime,
            opsPerSecond: 100.0 / (optLineCountTime / 1000.0)
        ))
        
        // Test 6: Fuzzy matching
        let fuzzyTime = measureTime {
            let targets = (0..<100).map { "SomeClassName\($0)WithLongName.swift" }
            for _ in 0..<100 {
                for target in targets {
                    _ = fuzzyMatch(query: "scln", target: target)
                }
            }
        }
        results.append(BenchmarkResult(
            name: "Fuzzy Match (10K comparisons)",
            timeMs: fuzzyTime,
            opsPerSecond: 10000.0 / (fuzzyTime / 1000.0)
        ))
        
        for result in results {
            print("  \(result.name): \(String(format: "%.2f", result.timeMs))ms")
        }
        
        return results
    }
    
    // MARK: - Parallel Processing Benchmarks
    
    static func benchmarkParallelProcessing() async -> [BenchmarkResult] {
        print("\n⚡️ Parallel Processing Benchmarks")
        print("-" * 40)
        
        var results: [BenchmarkResult] = []
        let items = Array(0..<1000)
        
        // Test 1: Sequential processing
        let sequentialTime = measureTime {
            var sum = 0
            for i in items {
                sum += expensiveComputation(i)
            }
        }
        results.append(BenchmarkResult(
            name: "Sequential (1K items)",
            timeMs: sequentialTime,
            opsPerSecond: 1000.0 / (sequentialTime / 1000.0)
        ))
        
        // Test 2: Parallel with TaskGroup
        let parallelTime = await measureTimeAsync {
            await withTaskGroup(of: Int.self) { group in
                for i in items {
                    group.addTask { expensiveComputation(i) }
                }
                var sum = 0
                for await result in group { sum += result }
            }
        }
        results.append(BenchmarkResult(
            name: "Parallel TaskGroup (1K items)",
            timeMs: parallelTime,
            opsPerSecond: 1000.0 / (parallelTime / 1000.0)
        ))
        
        // Test 3: Parallel with controlled concurrency
        let controlledTime = await measureTimeAsync {
            await items.parallelForEach(maxConcurrency: ProcessInfo.processInfo.activeProcessorCount) { i in
                _ = expensiveComputation(i)
            }
        }
        results.append(BenchmarkResult(
            name: "Parallel Controlled (1K items)",
            timeMs: controlledTime,
            opsPerSecond: 1000.0 / (controlledTime / 1000.0)
        ))
        
        // Test 4: Chunked parallel
        let cores = ProcessInfo.processInfo.activeProcessorCount
        let chunkSize = max(1, items.count / cores)
        let chunkedTime = await measureTimeAsync {
            await withTaskGroup(of: Int.self) { group in
                for chunk in items.chunked(into: chunkSize) {
                    group.addTask {
                        var sum = 0
                        for i in chunk { sum += expensiveComputation(i) }
                        return sum
                    }
                }
                var total = 0
                for await result in group { total += result }
            }
        }
        results.append(BenchmarkResult(
            name: "Parallel Chunked (1K items)",
            timeMs: chunkedTime,
            opsPerSecond: 1000.0 / (chunkedTime / 1000.0)
        ))
        
        print("  CPU cores: \(cores)")
        for result in results {
            print("  \(result.name): \(String(format: "%.2f", result.timeMs))ms")
        }
        
        // Calculate speedup
        let maxSpeedup = sequentialTime / min(parallelTime, controlledTime, chunkedTime)
        print("  Max speedup: \(String(format: "%.1fx", maxSpeedup))")
        
        return results
    }
    
    // MARK: - Memory Benchmarks
    
    static func benchmarkMemory() -> [BenchmarkResult] {
        print("\n🧠 Memory Efficiency Benchmarks")
        print("-" * 40)
        
        var results: [BenchmarkResult] = []
        
        // Test 1: Array pre-allocation
        let preallocTime = measureTime {
            for _ in 0..<100 {
                var arr = [Int]()
                arr.reserveCapacity(10000)
                for i in 0..<10000 { arr.append(i) }
            }
        }
        results.append(BenchmarkResult(
            name: "Array Pre-allocated (100x)",
            timeMs: preallocTime,
            opsPerSecond: 100.0 / (preallocTime / 1000.0)
        ))
        
        // Test 2: Array without pre-allocation
        let noPeallocTime = measureTime {
            for _ in 0..<100 {
                var arr = [Int]()
                for i in 0..<10000 { arr.append(i) }
            }
        }
        results.append(BenchmarkResult(
            name: "Array Non-allocated (100x)",
            timeMs: noPeallocTime,
            opsPerSecond: 100.0 / (noPeallocTime / 1000.0)
        ))
        
        // Test 3: Set insertion with capacity
        let setPreallocTime = measureTime {
            for _ in 0..<100 {
                var set = Set<String>()
                set.reserveCapacity(1000)
                for i in 0..<1000 { set.insert("item_\(i)") }
            }
        }
        results.append(BenchmarkResult(
            name: "Set Pre-allocated (100x)",
            timeMs: setPreallocTime,
            opsPerSecond: 100.0 / (setPreallocTime / 1000.0)
        ))
        
        // Test 4: String building
        let stringBuildTime = measureTime {
            for _ in 0..<100 {
                var s = ""
                s.reserveCapacity(10000)
                for i in 0..<1000 { s.append("item\(i)") }
            }
        }
        results.append(BenchmarkResult(
            name: "String Building (100x)",
            timeMs: stringBuildTime,
            opsPerSecond: 100.0 / (stringBuildTime / 1000.0)
        ))
        
        // Test 5: Ring buffer vs Array
        let ringBuffer = RingBuffer<Int>(capacity: 1000)
        let ringTime = measureTime {
            for _ in 0..<100 {
                for i in 0..<10000 {
                    _ = ringBuffer.write(i)
                    _ = ringBuffer.read()
                }
            }
        }
        results.append(BenchmarkResult(
            name: "Ring Buffer (1M ops)",
            timeMs: ringTime,
            opsPerSecond: 1_000_000.0 / (ringTime / 1000.0)
        ))
        
        for result in results {
            print("  \(result.name): \(String(format: "%.2f", result.timeMs))ms")
        }
        
        return results
    }
    
    // MARK: - Helper Functions
    
    private static func measureTime(_ block: () -> Void) -> Double {
        let start = CFAbsoluteTimeGetCurrent()
        block()
        return (CFAbsoluteTimeGetCurrent() - start) * 1000
    }
    
    private static func measureTimeAsync(_ block: () async -> Void) async -> Double {
        let start = CFAbsoluteTimeGetCurrent()
        await block()
        return (CFAbsoluteTimeGetCurrent() - start) * 1000
    }
    
    private static func generateSwiftCode(lines: Int) -> String {
        var code = "import Foundation\nimport SwiftUI\n\n"
        for i in 0..<lines {
            code += """
            // Line \(i) - This is a comment
            func function\(i)(_ param: String, value: Int = 42) -> Bool {
                let localVar = "string literal with \\(param)"
                guard value > 0 else { return false }
                return localVar.count > 10
            }
            
            struct Model\(i): Codable {
                let id: UUID
                var name: String
                var count: Int = 0
            }
            
            """
        }
        return code
    }
    
    private static func generateJSCode(lines: Int) -> String {
        var code = "// JavaScript code\n'use strict';\n\n"
        for i in 0..<lines {
            code += """
            // Function \(i)
            async function func\(i)(param) {
                const result = await fetch(`/api/\(i)`);
                return result.json();
            }
            
            """
        }
        return code
    }
    
    private static func generatePythonCode(lines: Int) -> String {
        var code = "# Python code\nimport os\nfrom typing import List\n\n"
        for i in 0..<lines {
            code += """
            # Function \(i)
            def function_\(i)(param: str) -> bool:
                '''Docstring for function \(i)'''
                result = f"value: {param}"
                return len(result) > 10
            
            """
        }
        return code
    }
    
    private static func extractWordsRegex(_ text: String) -> Set<String> {
        var words = Set<String>()
        guard let regex = try? NSRegularExpression(pattern: "[a-zA-Z_][a-zA-Z0-9_]*") else { return words }
        let range = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: range) {
            if let wordRange = Range(match.range, in: text) {
                words.insert(String(text[wordRange]).lowercased())
            }
        }
        return words
    }
    
    private static func extractWordsCharacter(_ text: String) -> Set<String> {
        var words = Set<String>()
        var currentWord = ""
        
        for char in text {
            if char.isLetter || char == "_" || (char.isNumber && !currentWord.isEmpty) {
                currentWord.append(char)
            } else {
                if currentWord.count >= 2 {
                    words.insert(currentWord.lowercased())
                }
                currentWord = ""
            }
        }
        
        if currentWord.count >= 2 {
            words.insert(currentWord.lowercased())
        }
        
        return words
    }
    
    private static func extractTrigrams(_ text: String) -> Set<String> {
        var trigrams = Set<String>()
        let chars = Array(text.lowercased())
        guard chars.count >= 3 else { return trigrams }
        
        for i in 0..<(chars.count - 2) {
            let trigram = String(chars[i...i+2])
            if trigram.allSatisfy({ $0.isLetter || $0.isNumber }) {
                trigrams.insert(trigram)
            }
        }
        return trigrams
    }
    
    private static func countLines(_ text: String) -> Int {
        var count = 1
        for char in text where char == "\n" {
            count += 1
        }
        return count
    }
    
    private static func fuzzyMatch(query: String, target: String) -> Bool {
        var queryIndex = query.startIndex
        for char in target.lowercased() {
            if queryIndex < query.endIndex && char == query[queryIndex] {
                queryIndex = query.index(after: queryIndex)
            }
        }
        return queryIndex == query.endIndex
    }
    
    private static func expensiveComputation(_ n: Int) -> Int {
        // Simulate CPU work
        var result = n
        for _ in 0..<100 {
            result = (result * 17 + 31) % 1000
        }
        return result
    }
}

// MARK: - Benchmark Result Types

struct BenchmarkResult {
    let name: String
    let timeMs: Double
    let opsPerSecond: Double
}

struct BenchmarkReport {
    var cacheResults: [BenchmarkResult] = []
    var syntaxResults: [BenchmarkResult] = []
    var fileResults: [BenchmarkResult] = []
    var stringResults: [BenchmarkResult] = []
    var parallelResults: [BenchmarkResult] = []
    var memoryResults: [BenchmarkResult] = []
    
    func printSummary() {
        print("\nCache Performance:")
        for r in cacheResults { print("  • \(r.name): \(Int(r.opsPerSecond)) ops/sec") }
        
        print("\nSyntax Highlighting:")
        for r in syntaxResults { print("  • \(r.name): \(String(format: "%.2f", r.timeMs))ms") }
        
        print("\nFile Operations:")
        for r in fileResults { print("  • \(r.name): \(String(format: "%.2f", r.timeMs))ms") }
        
        print("\nString Processing:")
        for r in stringResults { print("  • \(r.name): \(String(format: "%.2f", r.timeMs))ms") }
        
        print("\nParallel Processing:")
        for r in parallelResults { print("  • \(r.name): \(String(format: "%.2f", r.timeMs))ms") }
        
        print("\nMemory Efficiency:")
        for r in memoryResults { print("  • \(r.name): \(String(format: "%.2f", r.timeMs))ms") }
    }
    
    var recommendations: [String] {
        var recs: [String] = []
        
        // Check cache effectiveness
        if let cacheHit = syntaxResults.first(where: { $0.name.contains("Cache Hit") }),
           let noCache = syntaxResults.first(where: { $0.name.contains("Medium") }) {
            if cacheHit.timeMs < noCache.timeMs * 0.5 {
                recs.append("✓ Syntax highlighting cache is effective (\(Int(noCache.timeMs / cacheHit.timeMs))x faster)")
            }
        }
        
        // Check parallel speedup
        if let seq = parallelResults.first(where: { $0.name.contains("Sequential") }),
           let par = parallelResults.first(where: { $0.name.contains("Parallel") }) {
            let speedup = seq.timeMs / par.timeMs
            if speedup > 1.5 {
                recs.append("✓ Parallel processing shows \(String(format: "%.1f", speedup))x speedup")
            } else {
                recs.append("⚠ Parallel overhead may be too high for small tasks")
            }
        }
        
        // Check memory mapping benefit
        if let mapped = fileResults.first(where: { $0.name.contains("Mapped") }),
           let standard = fileResults.first(where: { $0.name.contains("Standard") }) {
            if mapped.timeMs < standard.timeMs {
                recs.append("✓ Memory mapping is faster for large files")
            } else {
                recs.append("⚠ Memory mapping has overhead for this file size")
            }
        }
        
        // Check word extraction
        if let regex = stringResults.first(where: { $0.name.contains("Regex") }),
           let charBased = stringResults.first(where: { $0.name.contains("Char-based") }) {
            if charBased.timeMs < regex.timeMs {
                recs.append("✓ Character-based word extraction is \(String(format: "%.1f", regex.timeMs / charBased.timeMs))x faster than regex")
            }
        }
        
        // Check pre-allocation
        if let prealloc = memoryResults.first(where: { $0.name.contains("Pre-allocated") }),
           let noPrealloc = memoryResults.first(where: { $0.name.contains("Non-allocated") }) {
            if prealloc.timeMs < noPrealloc.timeMs {
                recs.append("✓ Pre-allocation saves \(String(format: "%.1f", (1 - prealloc.timeMs / noPrealloc.timeMs) * 100))% time")
            }
        }
        
        return recs
    }
}

// MARK: - String Repeat Helper

extension String {
    static func * (left: String, right: Int) -> String {
        String(repeating: left, count: right)
    }
}

// MARK: - Benchmark Command

extension AppState {
    @MainActor
    func runBenchmarks() async {
        showToast(.info, "Running benchmarks...")
        
        let report = await BenchmarkRunner.runAll()
        
        print("\n🎯 RECOMMENDATIONS:")
        for rec in report.recommendations {
            print("  \(rec)")
        }
        
        showSuccess("Benchmarks complete - see console")
    }
}
