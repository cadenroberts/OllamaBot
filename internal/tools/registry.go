// Package tools implements the Unified Tool Registry (UTR).
// Validates agent tool calls against the shared registry.
package tools

// ToolID is the canonical tool identifier.
type ToolID string

// Tool categories
const (
	CategoryCore       = "core"
	CategoryFile       = "file"
	CategorySystem     = "system"
	CategoryDelegation = "delegation"
	CategoryWeb        = "web"
	CategoryGit        = "git"
	CategorySession    = "session"
)

// Tier 1 (Executor) tools -- existing CLI capabilities
const (
	ToolFileWrite  ToolID = "file.write"
	ToolFileEdit   ToolID = "file.edit"
	ToolFileDelete ToolID = "file.delete"
	ToolFileRename ToolID = "file.rename"
	ToolFileMove   ToolID = "file.move"
	ToolFileCopy   ToolID = "file.copy"
	ToolDirCreate  ToolID = "dir.create"
	ToolDirDelete  ToolID = "dir.delete"
	ToolSystemRun  ToolID = "system.run"
)

// Tier 2 (Autonomous) tools -- new capabilities
const (
	ToolThink              ToolID = "think"
	ToolComplete           ToolID = "complete"
	ToolAskUser            ToolID = "ask_user"
	ToolFileRead           ToolID = "file.read"
	ToolFileSearch         ToolID = "file.search"
	ToolFileList           ToolID = "file.list"
	ToolFileEditRange      ToolID = "file.edit_range"
	ToolDelegateCoder      ToolID = "ai.delegate.coder"
	ToolDelegateResearcher ToolID = "ai.delegate.researcher"
	ToolDelegateVision     ToolID = "ai.delegate.vision"
	ToolWebSearch          ToolID = "web.search"
	ToolWebFetch           ToolID = "web.fetch"
	ToolGitStatus          ToolID = "git.status"
	ToolGitDiff            ToolID = "git.diff"
	ToolGitCommit          ToolID = "git.commit"
	ToolCheckpointSave     ToolID = "checkpoint.save"
	ToolCheckpointRestore  ToolID = "checkpoint.restore"
	ToolCheckpointList     ToolID = "checkpoint.list"
)

// ToolDef defines a tool in the registry.
type ToolDef struct {
	ID          ToolID
	Category    string
	Description string
	Tier        int    // 1 = executor, 2 = autonomous
	CLIAlias    string // legacy CLI action name
	IDEAlias    string // legacy IDE tool name
	Available   bool   // whether this tool is implemented
}

// Registry holds all tool definitions.
type Registry struct {
	tools map[ToolID]*ToolDef
}

// NewRegistry creates the default unified tool registry.
func NewRegistry() *Registry {
	r := &Registry{
		tools: make(map[ToolID]*ToolDef),
	}

	// Tier 1: Executor tools (existing)
	r.register(ToolFileWrite, CategoryFile, "Create or overwrite a file", 1, "CreateFile", "write_file", true)
	r.register(ToolFileEdit, CategoryFile, "Edit a file with search/replace", 1, "EditFile", "edit_file", true)
	r.register(ToolFileDelete, CategoryFile, "Delete a file", 1, "DeleteFile", "delete_file", true)
	r.register(ToolFileRename, CategoryFile, "Rename a file", 1, "RenameFile", "rename_file", true)
	r.register(ToolFileMove, CategoryFile, "Move a file", 1, "MoveFile", "move_file", true)
	r.register(ToolFileCopy, CategoryFile, "Copy a file", 1, "CopyFile", "copy_file", true)
	r.register(ToolDirCreate, CategoryFile, "Create a directory", 1, "CreateDir", "create_directory", true)
	r.register(ToolDirDelete, CategoryFile, "Delete a directory", 1, "DeleteDir", "delete_directory", true)
	r.register(ToolSystemRun, CategorySystem, "Execute a shell command", 1, "RunCommand", "run_command", true)

	// Tier 2: Autonomous tools (new)
	r.register(ToolThink, CategoryCore, "Internal reasoning step", 2, "", "think", true)
	r.register(ToolComplete, CategoryCore, "Signal task completion", 2, "", "complete", true)
	r.register(ToolAskUser, CategoryCore, "Request human consultation", 2, "", "ask_user", true)
	r.register(ToolFileRead, CategoryFile, "Read file contents", 2, "ReadFile", "read_file", true)
	r.register(ToolFileSearch, CategoryFile, "Search file contents", 2, "SearchFiles", "search_files", true)
	r.register(ToolFileList, CategoryFile, "List directory contents", 2, "ListDirectory", "list_directory", true)
	r.register(ToolFileEditRange, CategoryFile, "Edit specific line range", 2, "", "edit_file_range", true)
	r.register(ToolDelegateCoder, CategoryDelegation, "Delegate to coding model", 2, "DelegateToCoder", "delegate_to_coder", true)
	r.register(ToolDelegateResearcher, CategoryDelegation, "Delegate to research model", 2, "DelegateToResearcher", "delegate_to_researcher", true)
	r.register(ToolDelegateVision, CategoryDelegation, "Delegate to vision model", 2, "DelegateToVision", "delegate_to_vision", true)
	r.register(ToolWebSearch, CategoryWeb, "Search the web", 2, "", "web_search", true)
	r.register(ToolWebFetch, CategoryWeb, "Fetch URL content", 2, "", "fetch_url", true)
	r.register(ToolGitStatus, CategoryGit, "Get git status", 2, "", "git_status", true)
	r.register(ToolGitDiff, CategoryGit, "Get git diff", 2, "", "git_diff", true)
	r.register(ToolGitCommit, CategoryGit, "Create git commit", 2, "", "git_commit", true)
	r.register(ToolCheckpointSave, CategorySession, "Save checkpoint", 2, "", "checkpoint_save", true)
	r.register(ToolCheckpointRestore, CategorySession, "Restore checkpoint", 2, "", "checkpoint_restore", true)
	r.register(ToolCheckpointList, CategorySession, "List checkpoints", 2, "", "checkpoint_list", true)

	return r
}

func (r *Registry) register(id ToolID, category, description string, tier int, cliAlias, ideAlias string, available bool) {
	r.tools[id] = &ToolDef{
		ID:          id,
		Category:    category,
		Description: description,
		Tier:        tier,
		CLIAlias:    cliAlias,
		IDEAlias:    ideAlias,
		Available:   available,
	}
}

// Get returns a tool definition by ID.
func (r *Registry) Get(id ToolID) *ToolDef {
	return r.tools[id]
}

// GetByCLIAlias resolves a legacy CLI action name to a tool.
func (r *Registry) GetByCLIAlias(alias string) *ToolDef {
	for _, t := range r.tools {
		if t.CLIAlias == alias {
			return t
		}
	}
	return nil
}

// GetByIDEAlias resolves a legacy IDE tool name to a tool.
func (r *Registry) GetByIDEAlias(alias string) *ToolDef {
	for _, t := range r.tools {
		if t.IDEAlias == alias {
			return t
		}
	}
	return nil
}

// IsValid checks if a tool ID exists and is available.
func (r *Registry) IsValid(id ToolID) bool {
	t, ok := r.tools[id]
	return ok && t.Available
}

// ListByCategory returns all tools in a category.
func (r *Registry) ListByCategory(category string) []*ToolDef {
	result := make([]*ToolDef, 0)
	for _, t := range r.tools {
		if t.Category == category {
			result = append(result, t)
		}
	}
	return result
}

// ListByTier returns all tools of a given tier.
func (r *Registry) ListByTier(tier int) []*ToolDef {
	result := make([]*ToolDef, 0)
	for _, t := range r.tools {
		if t.Tier == tier {
			result = append(result, t)
		}
	}
	return result
}

// All returns all registered tools.
func (r *Registry) All() []*ToolDef {
	result := make([]*ToolDef, 0, len(r.tools))
	for _, t := range r.tools {
		result = append(result, t)
	}
	return result
}
