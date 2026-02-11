# Session Format Duality Fix - Documentation

## Problem Summary

The codebase had two incompatible session formats both claiming to be "USF v1.0":
- **USFSession** (`internal/session/usf.go`) - Legacy directory-based format
- **UnifiedSession** (`internal/session/unified.go`) - Current flat-file format

This caused:
- `obot session` commands to see only USFSession format
- `obot checkpoint` commands to see only UnifiedSession format  
- Cross-command invisibility of sessions
- User confusion and broken workflows

## Solution Approach

Implemented a **backwards-compatible unified loader** that:
1. Transparently handles both formats
2. Auto-migrates legacy sessions on first save
3. Provides single API for both CLI commands
4. Preserves all existing session data

## Implementation

### New Files

**`internal/session/unified_loader.go`** - Unified session loading infrastructure
- `LoadAnySession()` - Load session in either format, returns UnifiedSession
- `ListAllSessions()` - List sessions from both formats
- `SaveAnySession()` - Save in UnifiedSession format, auto-migrate legacy
- `GetSessionFormat()` - Detect which format a session uses
- `GetSessionInfo()` - Get metadata regardless of format
- `MigrateAllSessions()` - Batch migrate all legacy sessions
- `convertUSFToUnified()` - Format conversion logic

**`internal/session/unified_loader_test.go`** - Comprehensive test suite
- Tests for loading both formats
- Tests for listing mixed formats
- Tests for auto-migration on save
- Tests for format detection
- Tests for batch migration

### Modified Files

**`internal/cli/session_cmd.go`**
- `sessionListCmd` now uses `ListAllSessions()` + `GetSessionInfo()`
- Shows format indicator for legacy sessions
- `sessionExportCmd` uses `LoadAnySession()` + `SaveAnySession()`
- `sessionShowCmd` uses `LoadAnySession()` and displays format warning
- Added `sessionMigrateCmd` for explicit batch migration

**`internal/cli/checkpoint.go`**
- `checkpointSaveCmd` uses `LoadAnySession()` + `SaveAnySession()`
- `checkpointListCmd` uses `ListAllSessions()` + `LoadAnySession()`
- `checkpointRestoreCmd` uses `ListAllSessions()` + `LoadAnySession()` + `SaveAnySession()`

## Migration Strategy

### Transparent Migration
Sessions are migrated automatically when:
1. User saves a legacy session via `obot checkpoint save`
2. User exports a legacy session via `obot session export`
3. User modifies and saves any loaded session

When migration occurs:
- New file created: `~/.config/ollamabot/sessions/<sessionID>.json`
- Old directory renamed: `~/.config/ollamabot/sessions/.migrated_<sessionID>/`
- User can safely delete `.migrated_*` directories after verifying

### Explicit Migration
Users can migrate all at once:
```bash
obot session migrate
```

This command:
- Scans for all legacy USFSession format sessions
- Converts each to UnifiedSession format
- Renames legacy directories to `.migrated_*`
- Reports count of migrated sessions

## File Format Comparison

### Legacy USFSession Format
```
~/.config/ollamabot/sessions/
└── <sessionID>/
    ├── session.usf          # Main session data (JSON)
    ├── states/              # State history
    ├── checkpoints/         # Checkpoint data
    └── notes/               # Session notes
```

Loaded via: `LoadUSFSession(baseDir, sessionID)`
Listed via: `ListUSFSessionIDs(baseDir)`

### Current UnifiedSession Format
```
~/.config/ollamabot/sessions/
└── <sessionID>.json         # All session data in single file
```

Loaded via: `LoadUSF(sessionID)`
Listed via: `ListUSFSessions()`

## Field Mapping

| USFSession | UnifiedSession | Notes |
|------------|----------------|-------|
| `Platform` | `PlatformOrigin` | Renamed field |
| `OrchestrationState` | `Orchestration` | Renamed field |
| `OrchestrationState.FlowCode` | `Orchestration.FlowCode` | Preserved |
| `OrchestrationState.Schedule` | `Orchestration.CurrentSchedule` | Type: ScheduleID → int |
| `OrchestrationState.Process` | `Orchestration.CurrentProcess` | Type: ProcessID → int |
| `History[]` | `Steps[]` | Renamed array |
| `History[].Sequence` | `Steps[].StepNumber` | Renamed field |
| `History[].Schedule/Process` | `Steps[].ToolID` | Converted to string "S1P2" |
| `Task.Prompt` | `Task.Description` | Renamed field |
| `Task.Status` | `Task.Status` | Preserved |
| `Checkpoints[]` | `Checkpoints[]` | Preserved, structure differs |
| `Stats` | `Stats` | Preserved, some fields differ |

## Testing

### Unit Tests
```bash
go test ./internal/session/... -v
```

All tests pass:
- `TestLoadAnySession` - Load both formats
- `TestListAllSessions` - List mixed formats
- `TestSaveAnySession` - Save with auto-migration
- `TestConvertUSFToUnified` - Format conversion
- `TestGetSessionFormat` - Format detection
- `TestGetSessionInfo` - Metadata extraction
- `TestMigrateAllSessions` - Batch migration

### Integration Testing
```bash
go build ./cmd/obot
./obot session list       # Should see both formats
./obot checkpoint list    # Should see checkpoints from both
./obot session migrate    # Migrate all legacy sessions
```

## CLI Command Behavior

### Before Fix
```bash
# Create session via checkpoint
$ obot checkpoint save test

# Try to list sessions
$ obot session list
No sessions found.           # ✗ Doesn't see checkpoint session

# Create session via session cmd
$ obot session save

# Try to list checkpoints
$ obot checkpoint list
No checkpoints found.        # ✗ Doesn't see session checkpoints
```

### After Fix
```bash
# Create session via checkpoint
$ obot checkpoint save test

# List sessions - sees both formats
$ obot session list
📋 Sessions:

  ✓ sess_20260211_001234
    Task: Current task
    Platform: cli | Steps: 5

  ⚠ legacy-sess-1 [legacy format]
    Task: Legacy task
    Platform: cli | Steps: 3
```

```bash
# List checkpoints - sees all
$ obot checkpoint list

ID    SESSION              TIMESTAMP        NAME
────────────────────────────────────────────────
cp-1  sess_20260211_001234 02-11 00:12     test
cp-2  legacy-sess-1        02-10 15:30     before-change
```

```bash
# Migrate legacy sessions
$ obot session migrate
Scanning for legacy format sessions...
✓ Successfully migrated 3 session(s) to unified format.

Legacy session directories have been renamed to .migrated_<sessionID>
You can safely delete them after verifying the migration.
```

## Backwards Compatibility

The fix maintains full backwards compatibility:

1. **Existing legacy sessions continue to work**
   - Can be loaded, viewed, and modified
   - Automatically migrated on save
   - Original data preserved during conversion

2. **No breaking changes to API**
   - Old functions still exist and work
   - New functions provide unified interface
   - CLI commands updated to use unified interface

3. **Data integrity preserved**
   - All session data converted accurately
   - Checkpoints preserved
   - History/steps preserved
   - Stats preserved

4. **Rollback possible**
   - Legacy directories renamed, not deleted
   - Can manually restore from `.migrated_*` if needed
   - New format is JSON, easily inspectable

## Performance Impact

- **Minimal overhead**: Format detection is fast (single file stat)
- **No duplicate storage**: Migration removes legacy directory
- **Efficient listing**: Both list operations run in parallel
- **Lazy conversion**: Only converts when actually saving

## Future Work

### Phase 3: Deprecation (Future Release)
- Mark `USFSession` and related functions as deprecated
- Add deprecation warnings in code
- Update all internal code to use UnifiedSession exclusively

### Phase 4: Removal (Breaking Change Release)
- Remove `usf.go` entirely (keep only for import tool)
- Remove all USFSession type references
- Keep only UnifiedSession as the single format

## Verification Checklist

- [x] All unit tests pass
- [x] CLI commands compile successfully
- [x] Integration test demonstrates fix working
- [x] Legacy sessions can be loaded
- [x] New sessions can be created
- [x] Mixed format sessions are listed correctly
- [x] Checkpoints work across both formats
- [x] Auto-migration works on save
- [x] Batch migration command works
- [x] Documentation complete

## Related Files

- `internal/session/unified_loader.go` - New unified loading infrastructure
- `internal/session/unified_loader_test.go` - Test suite
- `internal/session/usf.go` - Legacy format (still used for backwards compat)
- `internal/session/unified.go` - Current format
- `internal/session/converter.go` - Format conversion utilities
- `internal/cli/session_cmd.go` - Session CLI commands
- `internal/cli/checkpoint.go` - Checkpoint CLI commands
- `docs/migration/SESSIONS.md` - User-facing migration guide

## Conclusion

The fix successfully resolves the session format duality issue while maintaining full backwards compatibility. Users can now use `obot session` and `obot checkpoint` commands interchangeably, and legacy sessions are transparently migrated to the new format on first save.
