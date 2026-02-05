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
                    
                    ZStack(alignment: .leading) {
                        if searchText.isEmpty {
                            Text("Find")
                                .foregroundStyle(DS.Colors.tertiaryText)
                        }
                        TextField("", text: $searchText)
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
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(DS.Colors.tertiaryBackground)
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
                            .font(.caption2)
                    }
                    .toggleStyle(.button)
                    .buttonStyle(.plain)
                    .padding(4)
                    .background(matchCase ? DS.Colors.accent.opacity(0.2) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                    .help("Match Case")
                    
                    Toggle(isOn: $wholeWord) {
                        Image(systemName: "text.word.spacing")
                            .font(.caption2)
                    }
                    .toggleStyle(.button)
                    .buttonStyle(.plain)
                    .padding(4)
                    .background(wholeWord ? DS.Colors.accent.opacity(0.2) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                    .help("Whole Word")
                    
                    Toggle(isOn: $useRegex) {
                        Image(systemName: "asterisk")
                            .font(.caption2)
                    }
                    .toggleStyle(.button)
                    .buttonStyle(.plain)
                    .padding(4)
                    .background(useRegex ? DS.Colors.accent.opacity(0.2) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                    .help("Use Regex")
                }
                
                Spacer()
                
                // Navigation
                HStack(spacing: 4) {
                    DSIconButton(icon: "chevron.up", size: 18) {
                        findPrevious()
                    }
                    .disabled(totalMatches == 0)
                    .opacity(totalMatches == 0 ? 0.4 : 1)
                    
                    DSIconButton(icon: "chevron.down", size: 18) {
                        findNext()
                    }
                    .disabled(totalMatches == 0)
                    .opacity(totalMatches == 0 ? 0.4 : 1)
                }
                
                // Toggle replace
                DSIconButton(icon: showReplace ? "chevron.up.chevron.down" : "arrow.left.arrow.right", size: 18) {
                    showReplace.toggle()
                }
                
                // Close
                DSIconButton(icon: "xmark", size: 18) {
                    isPresented = false
                }
            }
            
            // Replace row
            if showReplace {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.arrow.right")
                            .foregroundStyle(DS.Colors.secondaryText)
                        
                        ZStack(alignment: .leading) {
                            if replaceText.isEmpty {
                                Text("Replace")
                                    .foregroundStyle(DS.Colors.tertiaryText)
                            }
                            TextField("", text: $replaceText)
                                .textFieldStyle(.plain)
                                .foregroundStyle(DS.Colors.text)
                                .onSubmit {
                                    replaceOne()
                                }
                        }
                    }
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(DS.Colors.tertiaryBackground)
                    )
                    .frame(width: 200)
                    
                    DSButton("Replace", style: .secondary, size: .sm) {
                        replaceOne()
                    }
                    .disabled(totalMatches == 0)
                    .opacity(totalMatches == 0 ? 0.6 : 1)
                    
                    DSButton("Replace All", style: .secondary, size: .sm) {
                        replaceAll()
                    }
                    .disabled(totalMatches == 0)
                    .opacity(totalMatches == 0 ? 0.6 : 1)
                    
                    Spacer()
                }
            }
        }
        .padding(8)
        .background(DS.Colors.secondaryBackground)
        .onAppear {
            isSearchFocused = true
        }
        .onChange(of: matchCase) { _, _ in
            updateMatches()
        }
        .onChange(of: wholeWord) { _, _ in
            updateMatches()
        }
        .onChange(of: useRegex) { _, _ in
            updateMatches()
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
