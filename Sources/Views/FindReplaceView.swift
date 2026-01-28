import SwiftUI

// MARK: - Find Bar (Inline)

struct FindBarView: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool
    @State private var searchText: String = ""
    @State private var replaceText: String = ""
    @State private var showReplace: Bool = false
    @State private var matchCase: Bool = false
    @State private var wholeWord: Bool = false
    @State private var useRegex: Bool = false
    @State private var currentMatch: Int = 0
    @State private var totalMatches: Int = 0
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Find row
            HStack(spacing: 8) {
                // Search field
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(DS.Colors.secondaryText)
                    
                    TextField("Find", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundStyle(DS.Colors.text)
                        .focused($isSearchFocused)
                        .onChange(of: searchText) { _, _ in
                            updateMatches()
                        }
                        .onSubmit {
                            findNext()
                        }
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .frame(width: 200)
                
                // Match count
                if totalMatches > 0 {
                    Text("\(currentMatch) of \(totalMatches)")
                        .font(.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                        .frame(width: 60)
                } else if !searchText.isEmpty {
                    Text("No results")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(width: 60)
                }
                
                // Options
                HStack(spacing: 4) {
                    Toggle(isOn: $matchCase) {
                        Image(systemName: "textformat")
                    }
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)
                    .help("Match Case")
                    
                    Toggle(isOn: $wholeWord) {
                        Image(systemName: "text.word.spacing")
                    }
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)
                    .help("Whole Word")
                    
                    Toggle(isOn: $useRegex) {
                        Image(systemName: "asterisk")
                    }
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)
                    .help("Use Regex")
                }
                
                Spacer()
                
                // Navigation
                HStack(spacing: 4) {
                    Button(action: findPrevious) {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.bordered)
                    .disabled(totalMatches == 0)
                    
                    Button(action: findNext) {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.bordered)
                    .disabled(totalMatches == 0)
                }
                
                // Toggle replace
                Button(action: { showReplace.toggle() }) {
                    Image(systemName: showReplace ? "chevron.up.chevron.down" : "arrow.left.arrow.right")
                }
                .buttonStyle(.bordered)
                
                // Close
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.bordered)
            }
            
            // Replace row
            if showReplace {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.arrow.right")
                            .foregroundStyle(DS.Colors.secondaryText)
                        
                        TextField("Replace", text: $replaceText)
                            .textFieldStyle(.plain)
                            .foregroundStyle(DS.Colors.text)
                            .onSubmit {
                                replaceOne()
                            }
                    }
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .frame(width: 200)
                    
                    Button("Replace") {
                        replaceOne()
                    }
                    .buttonStyle(.bordered)
                    .disabled(totalMatches == 0)
                    
                    Button("Replace All") {
                        replaceAll()
                    }
                    .buttonStyle(.bordered)
                    .disabled(totalMatches == 0)
                    
                    Spacer()
                }
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear {
            isSearchFocused = true
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
    }
    
    private func updateMatches() {
        guard !searchText.isEmpty else {
            totalMatches = 0
            currentMatch = 0
            return
        }
        
        let content = appState.editorContent
        let searchOptions: String.CompareOptions = matchCase ? [] : .caseInsensitive
        
        var count = 0
        var searchRange = content.startIndex..<content.endIndex
        
        while let range = content.range(of: searchText, options: searchOptions, range: searchRange) {
            count += 1
            searchRange = range.upperBound..<content.endIndex
        }
        
        totalMatches = count
        if currentMatch == 0 && count > 0 {
            currentMatch = 1
        } else if currentMatch > count {
            currentMatch = count
        }
    }
    
    private func findNext() {
        guard totalMatches > 0 else { return }
        currentMatch = currentMatch < totalMatches ? currentMatch + 1 : 1
    }
    
    private func findPrevious() {
        guard totalMatches > 0 else { return }
        currentMatch = currentMatch > 1 ? currentMatch - 1 : totalMatches
    }
    
    private func replaceOne() {
        guard !searchText.isEmpty else { return }
        let searchOptions: String.CompareOptions = matchCase ? [] : .caseInsensitive
        
        if let range = appState.editorContent.range(of: searchText, options: searchOptions) {
            appState.editorContent.replaceSubrange(range, with: replaceText)
            updateMatches()
        }
    }
    
    private func replaceAll() {
        guard !searchText.isEmpty else { return }
        
        if matchCase {
            appState.editorContent = appState.editorContent.replacingOccurrences(of: searchText, with: replaceText)
        } else {
            appState.editorContent = appState.editorContent.replacingOccurrences(
                of: searchText,
                with: replaceText,
                options: .caseInsensitive
            )
        }
        updateMatches()
    }
}
