import SwiftUI

// MARK: - Rules Editor View
// Editor for .obotrules files with syntax highlighting and templates

struct RulesEditorView: View {
    @Environment(AppState.self) private var appState
    @State private var rulesContent: String = ""
    @State private var hasChanges: Bool = false
    @State private var showTemplates: Bool = false
    
    private var rulesURL: URL? {
        appState.rootFolder?.appendingPathComponent(".obotrules")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            DSDivider()
            
            // Editor
            HSplitView {
                // Rules editor
                rulesEditor
                    .frame(minWidth: 400)
                
                // Preview/Help panel
                previewPanel
                    .frame(width: 280)
            }
        }
        .background(DS.Colors.background)
        .onAppear {
            loadRules()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "doc.text")
                        .foregroundStyle(DS.Colors.accent)
                    Text(".obotrules")
                        .font(DS.Typography.headline)
                    
                    if hasChanges {
                        Circle()
                            .fill(DS.Colors.warning)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text("Project-wide AI rules for Infinite and Explore modes")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            
            Spacer()
            
            HStack(spacing: DS.Spacing.md) {
                DSButton("Templates", icon: "doc.on.doc", style: .ghost) {
                    showTemplates.toggle()
                }
                
                DSButton("Save", icon: "checkmark", style: .primary) {
                    saveRules()
                }
                .disabled(!hasChanges)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
    }
    
    // MARK: - Rules Editor
    
    private var rulesEditor: some View {
        VStack(spacing: 0) {
            TextEditor(text: $rulesContent)
                .font(DS.Typography.mono(12))
                .foregroundStyle(DS.Colors.text)
                .scrollContentBackground(.hidden)
                .background(DS.Colors.codeBackground)
                .onChange(of: rulesContent) { _, _ in
                    hasChanges = true
                }
            
            DSDivider()
            
            // Status bar
            HStack {
                Text("\(rulesContent.components(separatedBy: "\n").count) lines")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
                
                Spacer()
                
                if hasChanges {
                    Text("Unsaved changes")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(DS.Colors.warning)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(DS.Colors.surface)
        }
    }
    
    // MARK: - Preview Panel
    
    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(showTemplates ? "Templates" : "Documentation")
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(DS.Colors.secondaryText)
                Spacer()
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.surface)
            
            DSDivider()
            
            if showTemplates {
                templatesView
            } else {
                documentationView
            }
        }
        .background(DS.Colors.secondaryBackground)
    }
    
    private var templatesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                TemplateButton(
                    title: "Basic Rules",
                    description: "Simple project rules",
                    template: basicRulesTemplate
                ) { template in
                    rulesContent = template
                    hasChanges = true
                }
                
                TemplateButton(
                    title: "Infinite Mode Focus",
                    description: "Rules optimized for Infinite Mode",
                    template: infiniteModeTemplate
                ) { template in
                    rulesContent = template
                    hasChanges = true
                }
                
                TemplateButton(
                    title: "Explore Mode Focus",
                    description: "Rules optimized for Explore Mode",
                    template: exploreModeTemplate
                ) { template in
                    rulesContent = template
                    hasChanges = true
                }
                
                TemplateButton(
                    title: "Full Configuration",
                    description: "Complete rules with all options",
                    template: fullConfigTemplate
                ) { template in
                    rulesContent = template
                    hasChanges = true
                }
            }
            .padding(DS.Spacing.md)
        }
    }
    
    private var documentationView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                docSection(
                    title: "General Rules",
                    content: "Rules that apply to all AI interactions.\n\nExample:\n- Always use TypeScript\n- Prefer functional components"
                )
                
                docSection(
                    title: "Infinite Mode Rules",
                    content: "Control behavior of the single-task agent.\n\nOptions:\n- Verify changes compile\n- Create checkpoints\n- Max steps per task"
                )
                
                docSection(
                    title: "Explore Mode Rules",
                    content: "Control the autonomous exploration.\n\nOptions:\n- Max expansion depth\n- Focus areas\n- Exploration style"
                )
            }
            .padding(DS.Spacing.md)
        }
    }
    
    private func docSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(title)
                .font(DS.Typography.callout.weight(.medium))
                .foregroundStyle(DS.Colors.text)
            
            Text(content)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
        }
    }
    
    // MARK: - Actions
    
    private func loadRules() {
        guard let url = rulesURL else { return }
        
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            rulesContent = content
            hasChanges = false
        } else {
            // No rules file - show default template
            rulesContent = basicRulesTemplate
            hasChanges = true
        }
    }
    
    private func saveRules() {
        guard let url = rulesURL else { return }
        
        do {
            try rulesContent.write(to: url, atomically: true, encoding: .utf8)
            hasChanges = false
            appState.showSuccess("Rules saved")
            
            // Reload OBot service
            if let root = appState.rootFolder {
                Task {
                    await appState.obotService.loadProject(root)
                }
            }
        } catch {
            appState.showError("Failed to save rules: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Templates
    
    private var basicRulesTemplate: String {
        """
        # OllamaBot Project Rules
        
        ## General
        - Follow existing code patterns
        - Write clear, self-documenting code
        - Handle errors gracefully
        
        ## Code Style
        - Use consistent naming conventions
        - Keep functions focused and small
        - Add comments for complex logic
        """
    }
    
    private var infiniteModeTemplate: String {
        """
        # OllamaBot Project Rules
        
        ## General
        - Follow existing code patterns
        - Prefer functional approaches
        
        ## Infinite Mode Rules
        - Always verify changes compile before completing
        - Create checkpoint before destructive operations
        - Maximum steps per task: 50
        - Require user approval for destructive changes
        - Preferred tools: [read_file, edit_file, search_files]
        - Disabled tools: [run_command]
        """
    }
    
    private var exploreModeTemplate: String {
        """
        # OllamaBot Project Rules
        
        ## General
        - Focus on code quality and maintainability
        - Add comprehensive error handling
        
        ## Explore Mode Rules
        - Maximum expansion depth: 3 levels
        - Focus areas: [performance, features, testing]
        - Auto-document after: 5 changes
        - Expansion style: balanced
        - Excluded paths: [node_modules, .git, build]
        - Priority areas: [src/components, src/services]
        """
    }
    
    private var fullConfigTemplate: String {
        """
        # OllamaBot Project Rules
        
        ## General
        - Follow existing code patterns and style
        - Prefer functional programming approaches
        - Write comprehensive tests for new features
        - Handle errors gracefully with user-friendly messages
        - Add comments for complex business logic
        
        ## Code Style
        - Use consistent naming conventions (camelCase for variables, PascalCase for types)
        - Keep functions focused and under 50 lines
        - Prefer composition over inheritance
        - Use early returns to reduce nesting
        
        ## Infinite Mode Rules
        - Always verify changes compile before completing
        - Create checkpoint before destructive operations
        - Maximum steps per task: 50
        - Require user approval for file deletions
        - Preferred tools: [read_file, edit_file, search_files, list_directory]
        - Disabled tools: []
        
        ## Explore Mode Rules
        - Maximum expansion depth: 3 levels
        - Focus areas: [performance, features, testing, documentation]
        - Auto-document after: 5 changes
        - Expansion style: balanced
        - Pause between cycles: 2.0 seconds
        - Excluded paths: [node_modules, .git, build, dist]
        - Priority areas: [src/components, src/services, src/utils]
        """
    }
}

// MARK: - Template Button

struct TemplateButton: View {
    let title: String
    let description: String
    let template: String
    let onSelect: (String) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: { onSelect(template) }) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(title)
                    .font(DS.Typography.callout.weight(.medium))
                    .foregroundStyle(DS.Colors.text)
                
                Text(description)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.md)
            .background(isHovered ? DS.Colors.surface : DS.Colors.tertiaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// Preview removed - use Xcode previews instead
