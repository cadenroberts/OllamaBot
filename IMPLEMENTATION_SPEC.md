# OllamaBot Consolidated Implementation Plan
**Generated:** 2026-02-10  
**Source Documents:** ORCHESTRATION_PLAN.md (2,948 lines), ORCHESTRATION_PLAN_PART2.md (2,519 lines), plan.md (1,076 lines)  
**Total Items Combined:** 307 unique implementation items (from ~600+ original items after deduplication)

---

## SECTION 1: ARCHITECTURE & CORE INFRASTRUCTURE

### 1.1 System Architecture (ORCH §1.1-1.3)
**Status:** Documentation only (diagrams and event flows defined)  
**Source:** ORCHESTRATION_PLAN.md lines 34-180

**Items:**
1. **System Diagram** - Terminal UI → Orchestrator → Agent → Model Coordinator → Persistence Layer architecture (ORCH §1.1)
2. **Component Dependencies** - OrchestratorApp struct with 11 injected dependencies (ORCH §1.2)
3. **Event Flow** - User Input → Input Handler → Orchestrator Loop → Summary → Persistence (ORCH §1.3)

---

### 1.2 Data Structures (ORCH §2)
**Status:** Complete type definitions needed  
**Source:** ORCHESTRATION_PLAN.md lines 184-661  
**Files to Create:** `internal/orchestrate/types.go` (~300 LOC), `internal/agent/actions.go` (~150 LOC), `internal/session/state.go` (~400 LOC), `internal/session/recurrence.go` (~300 LOC)

**Items:**
4. **Core Types** (ORCH §2.1) - ScheduleID (1-5), ProcessID (1-3), OrchestratorState enum, Schedule struct, Process struct, ConsultationType enum, ModelType enum
5. **Agent Action Types** (ORCH §2.2) - 13 ActionType constants (create/delete/rename/move/copy for files/dirs, run_command, edit_file, complete)
6. **Action Struct** - Timestamp, Path, NewPath, LineRanges, DiffSummary, Command output, Metadata
7. **Session State** (ORCH §2.3) - Session, State (with ID format "0001_S1P1"), Note (with Source), SessionStats (schedules, processes, actions, tokens, resources, timing, consultation)
8. **SuspendError** - Code, Message, Component, Rule, State, Timestamp, Solutions, Recoverable
9. **Recurrence Relations** (ORCH §2.4) - StateRelation with Prev/Next pointers, FilesHash, Actions, RestoreFromPrev/Next scripts
10. **PathStep** - Direction (forward/reverse), DiffFile for state restoration
11. **FindPath BFS** - Bidirectional graph search for state restoration paths

---

### 1.3 Orchestrator Core (ORCH §3)
**Status:** Complete implementation needed  
**Source:** ORCHESTRATION_PLAN.md lines 665-1027  
**Files to Create:** `internal/orchestrate/orchestrator.go` (~400 LOC), `internal/orchestrate/navigator.go` (~300 LOC)

**Items:**
12. **Orchestrator Struct** (ORCH §3.1) - State machine with mutex, currentSchedule, currentProcess, tracking (scheduleHistory, processHistory, scheduleCounts), notes, callbacks
13. **Run Loop** - `while (!promptTerminated) { selectSchedule(); runSchedule(); }`
14. **Schedule Selection** - LLM-based via orchestrator model, validates against history
15. **Process Execution** - Delegates to agent with model selection
16. **Navigation Validator** (ORCH §3.2) - Enforces P1↔P2↔P3 rule, validates from/to transitions
17. **isValidNavigation()** - Initial→P1, P1→{P1,P2}, P2→{P1,P2,P3}, P3→{P2,P3,0}
18. **NavigationError** - Structured error for invalid P1→P3 or P3→P1 attempts
19. **canTerminatePrompt()** - Requires all 5 schedules run ≥1 time + last schedule = Production
20. **Prompt Termination** - LLM decision with context (history, stats, notes)
21. **selectProcess()** - LLM-based with valid options filtered by current state
22. **System Prompts** - scheduleSelectionSystemPrompt (TOOLER not agent), processSelectionSystemPrompt (navigation rules)

---

### 1.4 Schedule Implementation (ORCH §4)
**Status:** Complete implementation needed  
**Source:** ORCHESTRATION_PLAN.md lines 1031-1489  
**Files to Create:** `internal/schedule/factory.go` (~100 LOC), `internal/schedule/knowledge.go` (~150 LOC), `internal/schedule/plan.go` (~200 LOC), `internal/schedule/implement.go` (~250 LOC), `internal/schedule/scale.go` (~150 LOC), `internal/schedule/production.go` (~200 LOC)

**Items:**
23. **Schedule Factory** (ORCH §4.1) - NewSchedule() creates schedule with 3 processes, sets model type, consultation requirements
24. **Knowledge Schedule** (ORCH §4.2) - Research (identify gaps), Crawl (extract content), Retrieve (structure info)
25. **Plan Schedule** (ORCH §4.3) - Brainstorm (generate approaches), Clarify (optional human consultation if ambiguities exist), Plan (synthesize into concrete steps)
26. **Implement Schedule** (ORCH §4.4) - Implement (execute plan steps), Verify (tests/lint/build), Feedback (mandatory human consultation with demonstration)
27. **Scale Schedule** (ORCH §4.5) - Scale (identify concerns, refactor), Benchmark (run benchmarks, collect metrics), Optimize (analyze results, apply optimizations)
28. **Production Schedule** (ORCH §4.6) - Analyze (code/security/deps review), Systemize (patterns, docs, config), Harmonize (integration tests, UI polish via vision model if hasUI)
29. **Consultation Integration** - Plan.Clarify (optional), Implement.Feedback (mandatory), timeout with AI substitute

---

### 1.5 Process Implementation (ORCH §5)
**Status:** Complete implementation needed  
**Source:** ORCHESTRATION_PLAN.md lines 1493-1583  
**Files to Create:** `internal/process/process.go` (~200 LOC)

**Items:**
30. **Process Interface** (ORCH §5.1) - ID(), Name(), Schedule(), Execute(), RequiresHumanConsultation(), ConsultationType(), ValidateEntry()
31. **BaseProcess** - Common functionality for all 15 processes
32. **ValidateEntry()** - Navigation validation per 1↔2↔3 rule
33. **InvalidNavigationError** - Process-level navigation error

---

## SECTION 2: AGENT & TOOLS

### 2.1 Agent Core (ORCH §6.1)
**Status:** Complete implementation needed  
**Source:** ORCHESTRATION_PLAN.md lines 1587-1719  
**Files to Create:** `internal/agent/agent.go` (~300 LOC)

**Items:**
34. **Agent Struct** - models (ModelCoordinator), currentModel, actions tracker, sessionCtx, notes, callbacks (onAction, onComplete)
35. **Execute()** - Selects model for schedule/process, builds prompt, executes with model
36. **selectModel()** - Knowledge→Researcher, Production+P3→Coder (vision separate), default→Coder
37. **executeWithModel()** - Streams LLM response, parses actions incrementally, executes via executeAction()
38. **agentSystemPrompt** - Lists 13 allowed actions with exact formats, states CANNOT do (select schedules, navigate, terminate, make orchestration decisions), requires COMPLETE signal

---

### 2.2 Action Executor (ORCH §6.2)
**Status:** Complete implementation needed  
**Source:** ORCHESTRATION_PLAN.md lines 1721-1936  
**Files to Create:** `internal/agent/executor.go` (~500 LOC)

**Items:**
39. **executeAction()** - Validates action type, sets metadata (ID, timestamp), routes to handler, records duration
40. **File Operations** - createFile (with MkdirAll), deleteFile, createDir, deleteDir
41. **Rename/Move** - renameFile, renameDir, moveFile (ensures dest dir), moveDir
42. **Copy** - copyFile (ReadFile→WriteFile), copyDir (filepath.Walk)
43. **runCommand()** - exec.CommandContext with combined output, exit code capture
44. **editFile()** - Read original, compute diff/line ranges, write new content
45. **ActionComplete** - Triggers onComplete callback to signal process completion
46. **nextActionID()** - Thread-safe counter for action IDs (A0001, A0002, ...)
47. **InvalidActionError** - Error for undefined action types

---

### 2.3 Diff Generation (ORCH §6.3)
**Status:** Complete implementation needed  
**Source:** ORCHESTRATION_PLAN.md lines 1938-2099  
**Files to Create:** `internal/agent/diff.go` (~400 LOC)

**Items:**
48. **computeDiff()** - Uses go-difflib for unified diff, converts to obot style
49. **formatDiffObot()** - Green + lines, Red - lines, line numbers, ANSI colors
50. **computeLineRanges()** - Extract modified line ranges from hunks
51. **mergeRanges()** - Merge overlapping/adjacent line ranges using max-overlap algorithm
52. **FormatLineRanges()** - "10-15, 20, 34-40" display format

---

### 2.4 Tool Registry (PLAN §2 items)
**Status:** Partial (12 write-only tools exist in CLI)  
**Source:** plan.md lines 40-87 (CLUSTER 2)  
**Files to Create:** `internal/agent/tools_read.go` (~150 LOC), `internal/delegation/handler.go` (~250 LOC), `internal/agent/tools_delegate.go` (~250 LOC), `internal/tools/web.go` (~200 LOC), `internal/tools/git.go` (~150 LOC), `internal/tools/core.go` (~150 LOC), `internal/tools/screenshot.go` (~100 LOC)

**Items:**
53. **Read Tools** (PLAN CLUSTER 1 item 1) - ReadFile, SearchFiles (ripgrep wrapper), ListDirectory, FileExists
54. **Delegation Tools** (PLAN CLUSTER 2 item 1) - delegate.coder, delegate.researcher, delegate.vision (requires multi-model coordinator)
55. **Web Tools** (PLAN CLUSTER 2 item 2) - web.search (DuckDuckGo API), web.fetch (HTTP + goquery HTML extraction)
56. **Git Tools** (PLAN CLUSTER 2 item 3) - git.status, git.diff, git.commit, git.push (wrap exec.Command with structured parsing)
57. **Core Control Tools** (PLAN CLUSTER 2 item 4) - core.think, core.complete, core.ask_user (interactive prompt), core.note
58. **Screenshot Tool** (PLAN CLUSTER 2 item 5) - Platform-specific (macOS: screencapture, Linux: scrot/import)

---

## SECTION 3: MODEL COORDINATION

### 3.1 Model Coordinator (ORCH §7)
**Status:** Complete implementation needed  
**Source:** ORCHESTRATION_PLAN.md lines 2103-2201  
**Files to Create:** `internal/model/coordinator.go` (~300 LOC)

**Items:**
59. **Coordinator Struct** (ORCH §7.1) - clients map (4 model types), config (model names per role, Ollama URL)
60. **NewCoordinator()** - Initialize 4 clients: orchestrator, coder, researcher, vision
61. **Get()** - Return client by ModelType
62. **GetModelForSchedule()** - Knowledge→Researcher, default→Coder
63. **GetOrchestratorModel()** - Return orchestrator client
64. **ValidateModels()** - Check all 4 models available in Ollama

---

### 3.2 Multi-Model System (PLAN §3)
**Status:** Needs implementation  
**Source:** plan.md lines 130-275 (CLUSTER 3)  
**Files to Create:** `internal/intent/router.go` (~300 LOC), enhanced `internal/model/coordinator.go` (+100 LOC), `internal/ollama/vision.go` (~200 LOC)

**Items:**
65. **Intent Router** (PLAN CLUSTER 3 item 2) - Keyword classification: Coding (implement, fix, refactor), Research (explain, analyze), Writing (document, draft), Vision (image, screenshot)
66. **Intent-Based Model Selection** (PLAN CLUSTER 3 item 1) - Map (Intent, RAM tier) → optimal model role, fallback to orchestrator if role unavailable
67. **Vision Model Integration** (PLAN CLUSTER 3 item 3) - Extend Ollama client for multimodal API (image + text payloads)
68. **Fallback Chains** - If role-specific model unavailable, use orchestrator as universal fallback

---

## SECTION 4: DISPLAY & UI

### 4.1 Status Display (ORCH §8.1)
**Status:** Complete implementation needed  
**Source:** ORCHESTRATION_PLAN.md lines 2205-2367  
**Files to Create:** `internal/ui/display.go` (~400 LOC)

**Items:**
69. **StatusDisplay Struct** - 4-line panel: Orchestrator state, Schedule name, Process name, Agent action
70. **Dot Animations** - Independent 3-phase animations (..., .., .) for each line while undefined
71. **SetOrchestrator/Schedule/Process/Agent()** - Update display, stop animation for that line
72. **render()** - ANSI color rendering (blue theme), move cursor up 4 lines
73. **animationLoop()** - 250ms ticker, cycle dot phases, conditional rendering

---

### 4.2 ANSI Helpers (ORCH §8.2)
**Status:** Complete implementation needed  
**Source:** ORCHESTRATION_PLAN.md lines 2369-2467  
**Files to Create:** `internal/ui/ansi.go` (~150 LOC)

**Items:**
74. **Color Constants** - ANSIReset, ANSIBold, 8 colors, 5 bold colors, cursor control, clear codes
75. **Color()** - Wrap text with color code + reset
76. **Blue/BoldBlue()** - Obot theme colors
77. **Green/Red/Yellow/White/BoldWhite()** - Semantic colors (additions, deletions, warnings, etc.)
78. **ClearLine/MoveCursorUp/MoveCursorDown/ClearToEnd()** - Terminal manipulation

---

### 4.3 Memory Visualization (ORCH §9)
**Status:** Complete implementation needed  
**Source:** ORCHESTRATION_PLAN.md lines 2470-2707  
**Files to Create:** `internal/ui/memory.go` (~500 LOC)

**Items:**
79. **MemoryVisualization Struct** (ORCH §9.1) - Tracks current/peak/predict memory, predictLabel, predictBasis, history (last 5 min samples)
80. **3 Memory Bars** - Current (heap+stack), Peak (max observed), Predict (next process estimate)
81. **monitorLoop()** - 100ms sampling via runtime.ReadMemStats, trim old history (5 min window)
82. **renderBar()** - ASCII progress bars (█ filled, ░ empty, width=40)
83. **PredictForProcess()** - LRU cache + historical average or default (Knowledge:2GB, Production:6GB, default:4GB)
84. **formatBytes()** - KB/MB/GB formatting
85. **getTotalMemory()** - Platform-specific (defaults to 8GB)

---

### 4.4 Terminal UI App (ORCH §15)
**Status:** Complete implementation needed  
**Source:** ORCH_PART2.md lines 1636-1897  
**Files to Create:** `internal/ui/app.go` (~600 LOC)

**Items:**
86. **App Struct** (ORCH §15.1) - stdin/stdout/stderr, display (StatusDisplay), memoryViz, inputHandler, noteDestination toggle
87. **Run()** - Initialize components, render UI, start display/memory loops, start input loop
88. **renderUI()** - Clear screen, header (logo/icon), status panel (4 lines), memory panel (4 lines), output area, input area with Send/Stop buttons
89. **renderHeader()** - OllamaBot logo (no prompt) or 🧠/</> icon toggle (orchestrator vs coder)
90. **renderInputArea()** - Text input box, Send/Stop buttons, note destination toggle (🧠 Orchestrator / </> Coder)
91. **inputLoop()** - Read lines, handle special commands (/toggle, /stop), route to prompt or note
92. **toggleNoteDestination()** - Switch between DestinationOrchestrator and DestinationAgent
93. **SetGenerating()** - Update UI for generating state (gray Send, red Stop)
94. **UpdateDisplay()** - Forward to StatusDisplay setters
95. **WriteOutput()** - Append to scrollable output area

---

## SECTION 5: HUMAN CONSULTATION

### 5.1 Consultation Handler (ORCH §10)
**Status:** Complete implementation needed  
**Source:** ORCH_PART2.md lines 2710-2931  
**Files to Create:** `internal/consultation/handler.go` (~500 LOC)

**Items:**
96. **Handler Struct** (ORCH §10.1) - reader, writer, aiModel, timeout (60s default), countdown (15s default), allowAISub
97. **Request()** - Display consultation UI, start input reader, create timeout timer, countdown timer
98. **Response Selection** - Wait for human input OR timeout → AI substitute OR error if !allowAISub
99. **displayConsultation()** - Box UI with question, input area, timeout remaining, "AI will respond on your behalf" warning
100. **displayCountdown()** - "⚠ AI RESPONSE IN: 15... 14... 13..." yellow text
101. **generateAISubstitute()** - Prompt: "Act as human-in-the-loop, human did not respond, provide reasonable response. If approval, approve if reasonable. If preference, choose standard approach."
102. **readInput()** - 4096 byte buffer read from stdin
103. **formatDuration()** - MM:SS countdown display
104. **ResponseSource** - Enum: human, ai_substitute

---

## SECTION 6: ERROR HANDLING & SUSPENSION

### 6.1 Error Types (ORCH §11.1)
**Status:** Complete implementation needed  
**Source:** ORCH_PART2.md lines 10-118  
**Files to Create:** `internal/error/types.go` (~300 LOC)

**Items:**
105. **ErrorCode Constants** (ORCH §11.1) - E001-E009 (navigation violations), E010-E015 (system errors)
106. **ErrorSeverity** - critical, system, warning
107. **OrchestrationError Struct** - Code, Severity, Component, Message, Rule, Timestamp, State (Schedule, Process, LastAction, FlowCode), Solutions, Recoverable
108. **NewNavigationError()** - Factory for P1→P3 violations
109. **NewOrchestratorViolationError()** - Factory for orchestrator performing agent actions (TOOLER violation)
110. **NewAgentViolationError()** - Factory for agent performing orchestration (EXECUTOR violation)

---

### 6.2 Hardcoded Messages (ORCH §11.2)
**Status:** Complete implementation needed  
**Source:** ORCH_PART2.md lines 120-150  
**Files to Create:** `internal/error/hardcoded.go` (~50 LOC)

**Items:**
111. **HardcodedMessages Map** (ORCH §11.2) - E010: "Ollama is not running. Start Ollama with: ollama serve", E013: "Disk space exhausted. Free space required: %s"
112. **GetHardcodedMessage()** - Return hardcoded message with optional sprintf args
113. **IsHardcoded()** - Check if error has hardcoded message

---

### 6.3 Suspension Handler (ORCH §11.3)
**Status:** Complete implementation needed  
**Source:** ORCH_PART2.md lines 153-394  
**Files to Create:** `internal/error/suspension.go` (~600 LOC)

**Items:**
114. **SuspensionHandler Struct** (ORCH §11.3) - writer, reader, aiModel, session
115. **Handle()** - Freeze state (FreezeState), display suspension UI, perform LLM analysis (if not hardcoded), display solutions, wait for user action
116. **displaySuspension()** - Box UI: "Orchestrator • Suspended", error code + message, frozen state (schedule, process, last action, flow code with red X)
117. **analyzeError()** - If hardcoded: return pre-defined analysis. Else: LLM-as-judge analysis prompt → parse WHAT_HAPPENED, ROOT_CAUSE, FACTORS, SOLUTION_1/2/3
118. **displayAnalysis()** - Box sections: What happened, Which component violated, Rule violated
119. **displaySolutions()** - List solutions 1-3, then safe continuation options: [R]etry, [S]kip, [A]bort, [I]nvestigate
120. **waitForAction()** - Read R/S/A/I from stdin, return SuspensionAction enum
121. **formatFlowCodeWithError()** - Append red X to flow code
122. **wrapAndPrint()** - Word-wrap text to fit box width

---

## SECTION 7: SESSION PERSISTENCE

### 7.1 Session Manager (ORCH §12.1)
**Status:** Complete implementation needed  
**Source:** ORCH_PART2.md lines 399-798  
**Files to Create:** `internal/session/manager.go` (~700 LOC)

**Items:**
123. **Manager Struct** (ORCH §12.1) - baseDir (~/.obot/sessions), currentID, session
124. **Create()** - Generate session ID, create directory structure (states/, checkpoints/, notes/, actions/, actions/diffs/), initialize Session struct, save metadata
125. **Save()** - Update timestamp, save metadata, flow code, recurrence relations, generate restore script
126. **saveMetadata()** - Write meta.json with full Session struct
127. **saveFlowCode()** - Write flow.code file (S1P123S2P12...)
128. **saveRecurrence()** - Build StateRelation array, write states/recurrence.json
129. **generateRestoreScript()** - Create restore.sh bash script with usage(), list_states(), restore_state(), compute_files_hash(), apply_diffs_to_target(), find_path_jq()
130. **AddState()** - Create state with ID "SSSS_SsPp", compute files hash, link prev/next states, update flow code (append S# on schedule change, always append P#), save state file
131. **FreezeState()** - Mark error in flow code (append X), save immediately
132. **computeFilesHash()** - SHA256 of tracked files (git-tracked or project files)
133. **generateSessionID()** - Unix nanosecond timestamp

---

### 7.2 Session Notes (ORCH §12.2)
**Status:** Complete implementation needed  
**Source:** ORCH_PART2.md lines 800-942  
**Files to Create:** `internal/session/notes.go` (~200 LOC)

**Items:**
134. **NotesManager Struct** (ORCH §12.2) - baseDir, sessionID
135. **NoteDestination** - Enum: orchestrator, agent, human
136. **Add()** - Generate note ID, load existing notes, append new note, save
137. **Load()** - Read notes/{orchestrator|agent|human}.md, parse JSON array
138. **GetUnreviewed()** - Filter notes with Reviewed=false
139. **MarkReviewed()** - Set Reviewed=true for given note IDs, save
140. **save()** - Write JSON array to notes file
141. **generateNoteID()** - "N" + Unix nanosecond timestamp

---

### 7.3 Session Portability (PLAN §4)
**Status:** Needs USF implementation  
**Source:** plan.md lines 303-381 (CLUSTER 4)  
**Files to Create:** `internal/session/usf.go` (~350 LOC), enhanced `internal/session/manager.go` (+250 LOC), `internal/session/converter.go` (~200 LOC), `internal/cli/session_cmd.go` (~300 LOC), `internal/cli/checkpoint.go` (~250 LOC)

**Items:**
142. **USF Serialization** (PLAN CLUSTER 4 item 1) - USFSession struct with Version, SessionID, CreatedAt, Platform, Task, Workspace, OrchestrationState, History, FilesModified, Checkpoints, Stats
143. **ExportUSF()** - Convert internal session to USF JSON format
144. **ImportUSF()** - Convert USF JSON to internal session, preserve bash restoration scripts for backward compat
145. **Session Commands** (PLAN CLUSTER 4 item 2) - `obot session save/load/list/export/import`
146. **Checkpoint System** (PLAN CLUSTER 4 item 3) - Save/restore code state at arbitrary points

---

## SECTION 8: GIT INTEGRATION

### 8.1 Git Manager (ORCH §13.1)
**Status:** Complete implementation needed  
**Source:** ORCH_PART2.md lines 947-1174  
**Files to Create:** `internal/git/manager.go` (~500 LOC)

**Items:**
147. **Manager Struct** (ORCH §13.1) - workDir, github (GitHubClient), gitlab (GitLabClient), config (GitHub/GitLab enabled, tokens, auto-push, commit signing)
148. **Init()** - git init
149. **CreateRepository()** - GitHub.CreateRepository + add remote "github", GitLab.CreateRepository + add remote "gitlab"
150. **CommitSession()** - git add ., build commit message, git commit -m (with -S if signing enabled)
151. **buildCommitMessage()** - Format: "[obot] {summary}\n\nSession: {id}\nFlow: {code}\nSchedules: {count}\nProcesses: {count}\n\nChanges:\n  Created: {files}, {dirs}\n  Edited: {files}\n  Deleted: {files}, {dirs}\n\nHuman Prompts:\n  Initial: {truncated}\n  Clarifications: {count}\n  Feedback: {count}\n\nSigned-off-by: obot <obot@local>"
152. **PushAll()** - Iterate remotes, git push -u {remote} main (log failures but continue)
153. **summarizeChanges()** - "{created} created, {edited} edited, {deleted} deleted"
154. **run()** - exec.Command("git", args...)
155. **getRemotes()** - git remote, parse lines

---

### 8.2 GitHub Client (ORCH §13.2)
**Status:** Complete implementation needed  
**Source:** ORCH_PART2.md lines 1176-1261  
**Files to Create:** `internal/git/github.go` (~200 LOC)

**Items:**
156. **GitHubClient Struct** (ORCH §13.2) - token (from file), baseURL (api.github.com), http.Client
157. **NewGitHubClient()** - Read token from expandPath(tokenPath)
158. **CreateRepository()** - POST /user/repos with name, private=false, auto_init=false, description="Created by obot orchestration"
159. **Future methods** - CreatePullRequest, CreateIssue, ListBranches, CreateRelease (follow same pattern)

---

### 8.3 GitLab Client (ORCH §13.3)
**Status:** Complete implementation needed  
**Source:** ORCH_PART2.md lines 1263-1345  
**Files to Create:** `internal/git/gitlab.go` (~200 LOC)

**Items:**
160. **GitLabClient Struct** (ORCH §13.3) - token (from file), baseURL (gitlab.com/api/v4), http.Client
161. **NewGitLabClient()** - Read token from expandPath(tokenPath)
162. **CreateRepository()** - POST /projects with name, visibility=public, description="Created by obot orchestration"
163. **Future methods** - CreateMergeRequest, CreateIssue, ListBranches, CreateRelease

---

## SECTION 9: RESOURCE MANAGEMENT

### 9.1 Resource Monitor (ORCH §14)
**Status:** Complete implementation needed  
**Source:** ORCH_PART2.md lines 1349-1632  
**Files to Create:** `internal/resource/monitor.go` (~600 LOC)

**Items:**
164. **Monitor Struct** (ORCH §14.1) - memCurrent/memPeak/memTotal, diskWritten/diskDeleted, tokensUsed, startTime, limits (memLimit, diskLimit, tokenLimit, timeout), warnings
165. **NewMonitor()** - Initialize with optional limits from Config
166. **Start()** - Launch monitorLoop() goroutine
167. **monitorLoop()** - 500ms ticker, call sample()
168. **sample()** - ReadMemStats, update current/peak, append to history, checkLimits()
169. **checkLimits()** - Memory ratio >80% → append warning
170. **RecordDiskWrite/Delete/Tokens()** - Thread-safe counters
171. **CheckMemoryLimit()** - Return LimitExceededError if current > limit
172. **CheckTokenLimit()** - Return LimitExceededError if tokens > limit
173. **GetSummary()** - Return ResourceSummary with Memory/Disk/Tokens/Time summaries
174. **LimitExceededError** - Resource, Limit, Current
175. **ResourceSummary** - MemorySummary (Peak, Current, Total, Limit, Warnings), DiskSummary (Written, Deleted, Net, Limit), TokenSummary (Used, Limit), TimeSummary (Elapsed, Timeout)

---

## SECTION 10: PROMPT SUMMARY & LLM-AS-JUDGE

### 10.1 Summary Generator (ORCH §16)
**Status:** Complete implementation needed  
**Source:** ORCH_PART2.md lines 1900-2126  
**Files to Create:** `internal/summary/generator.go` (~500 LOC)

**Items:**
176. **Generator Struct** (ORCH §16.1) - session
177. **Generate()** - Build complete summary: header, flow code, schedule summary, process summary, action breakdown, resources, tokens, generation flow, TLDR placeholder
178. **formatFlowCode()** - S# in white, P# in blue, X in red
179. **generateScheduleSummary()** - Total schedulings, per-schedule counts with percentages
180. **generateProcessSummary()** - Total processes, per-schedule breakdown, per-process counts and percentages, average processes per scheduling
181. **generateActionSummary()** - Files/dirs created/deleted, commands ran, files edited
182. **generateResourceSummary()** - Memory/disk/token stats
183. **generateTokenSummary()** - Total, Inference (%), Input (%), Output (%), Context (%)
184. **generateGenerationFlow()** - Process-by-process flow with token recount
185. **pct()** - Helper for percentage calculation
186. **padRight()** - Helper for text padding

---

### 10.2 LLM-as-Judge (ORCH §17)
**Status:** Complete implementation needed  
**Source:** ORCH_PART2.md lines 2128-2390  
**Files to Create:** `internal/judge/coordinator.go` (~700 LOC)

**Items:**
187. **Coordinator Struct** (ORCH §17.1) - orchestratorModel, coderModel, researcherModel, visionModel
188. **Analysis Struct** - Experts map (expert name → ExpertAnalysis), Synthesis (SynthesisAnalysis), Failures (unresponsive experts)
189. **ExpertAnalysis** - Expert, PromptAdherence (0-100), ProjectQuality (0-100), ActionsCount, ErrorsCount, Observations, Recommendations
190. **SynthesisAnalysis** - PromptGoal, Implementation, ExpertConsensus (scores), Discoveries, Issues (IssueResolution), QualityAssessment (ACCEPTABLE/NEEDS_IMPROVEMENT/EXCEPTIONAL), Justification, Recommendations
191. **Analyze()** - Get expert analyses (Coder, Researcher, Vision) with retry (1x), orchestrator synthesis
192. **getExpertAnalysis()** - Prompt: "Analyze session from {expert} perspective. Provide PROMPT_ADHERENCE, PROJECT_QUALITY, ACTIONS, ERRORS, OBSERVATIONS (3), RECOMMENDATIONS (2)". Parse structured response.
193. **synthesize()** - Orchestrator prompt: "Create TLDR synthesis: PROMPT_GOAL, IMPLEMENTATION, EXPERT_CONSENSUS, DISCOVERIES (2-3), ISSUES, QUALITY_ASSESSMENT, JUSTIFICATION, RECOMMENDATIONS (3)". Parse structured response.
194. **parseExpertAnalysis()** - Parse PROMPT_ADHERENCE: {score}, etc.
195. **parseSynthesis()** - Parse synthesis fields
196. **RenderTLDR()** - Format final TLDR with box formatting: PROMPT GOAL, IMPLEMENTATION SUMMARY, EXPERT CONSENSUS, DISCOVERIES & LEARNINGS, QUALITY ASSESSMENT (with justification), ACTIONABLE RECOMMENDATIONS

---

## SECTION 11: TESTING (PLAN §11)

### 11.1 Test Categories (ORCH §18)
**Status:** Comprehensive test suite needed  
**Source:** ORCH_PART2.md lines 2393-2456, plan.md lines 871-938 (CLUSTER 11)

**Items:**
197. **Unit Tests** - Individual component tests
198. **Integration Tests** - Component interaction tests
199. **Golden Tests** - Prompt and output snapshot tests
200. **Navigation Tests** - Schedule/process navigation rule tests (ORCH §18.2)
201. **Suspension Tests** - Error handling and recovery tests
202. **Session Tests** - Persistence and restoration tests
203. **Schema Compliance Tests** (PLAN CLUSTER 11 item 3) - Validate USF/UCP/UOP outputs conform to JSON schemas
204. **Cross-Platform Session Tests** (PLAN CLUSTER 11 item 4) - Create session in CLI → Load in IDE (no data loss), Create in IDE → Resume in CLI (no data loss)
205. **Performance Benchmarks** (PLAN CLUSTER 11 item 5) - Baseline metrics, <5% regression threshold, config load time, context build time, session save/load time

---

### 11.2 Test Coverage Targets (PLAN §11)
**Status:** Need to achieve 75% coverage  
**Source:** plan.md lines 879-897

**Items:**
206. **CLI Test Coverage** (PLAN CLUSTER 11 item 1) - Agent execution: 90%, Tools: 85%, Context: 80%, Orchestration: 80%, Fixer: 85%, Sessions: 75%
207. **IDE Test Coverage** (PLAN CLUSTER 11 item 2) - Agent execution: 90%, Tools: 85%, Context: 80%, Orchestration: 80%, Sessions: 75%, UI: 60%

---

### 11.3 Navigation Rule Tests (ORCH §18.2)
**Status:** Implementation needed  
**Source:** ORCH_PART2.md lines 2407-2456

**Items:**
208. **TestNavigationRules()** - Test matrix: Initial→{P1 valid, P2/P3 invalid}, P1→{P1 valid, P2 valid, P3 invalid}, P2→{P1/P2/P3 all valid}, P3→{P1 invalid, P2 valid, P3 valid, 0 valid}

---

## SECTION 12: CONTEXT MANAGEMENT (PLAN §1)

### 12.1 Context Manager (PLAN §1 item 2)
**Status:** Needs Go port of IDE implementation  
**Source:** plan.md lines 46-52  
**Files to Create:** `internal/context/manager.go` (~700 LOC), `internal/context/budget.go` (~300 LOC), `internal/context/compression.go` (~200 LOC), `internal/context/tokens.go` (~150 LOC), `internal/context/memory.go` (~200 LOC), `internal/context/errors.go` (~150 LOC)

**Items:**
209. **Context Manager** (PLAN CLUSTER 1 item 2) - Port IDE's sophisticated ContextManager with token budgeting (System 15%, Files 35%, History 12%, Memory 12%, Errors 6%)
210. **Token Counting** - Via tiktoken-go library
211. **Budget Allocation** - Per UCP schema percentages
212. **Semantic Compression** - Preserve imports/exports
213. **LRU Cache** - For frequently accessed files
214. **Error Pattern Learning** - Track and learn from error patterns

---

### 12.2 Agent Read Capability (PLAN §1 item 1)
**Status:** Need to add read tools  
**Source:** plan.md lines 39-45  
**Files to Create:** `internal/agent/tools_read.go` (~150 LOC)

**Items:**
215. **ReadFile()** (PLAN CLUSTER 1 item 1) - os.ReadFile wrapper
216. **SearchFiles()** - ripgrep wrapper or filepath.Walk
217. **ListDirectory()** - os.ReadDir wrapper
218. **FileExists()** - os.Stat check

---

## SECTION 13: CONFIG & MIGRATION (PLAN §1 & §7)

### 13.1 Config Migration to YAML (PLAN §1 item 4)
**Status:** Needs implementation  
**Source:** plan.md lines 66-71  
**Files to Create:** `internal/config/migrate.go` (~250 LOC)  
**Files to Modify:** `internal/config/config.go` (complete rewrite)

**Items:**
219. **YAML Config** (PLAN CLUSTER 1 item 4) - Current: ~/.config/obot/config.json, Target: ~/.config/ollamabot/config.yaml with backward-compat symlink
220. **Config Migration** - Auto-migration on first run with backup of old config
221. **Dependency** - gopkg.in/yaml.v3

---

### 13.2 Unified Config Integration (PLAN §7)
**Status:** Partial (CLI has unified.go found)  
**Source:** plan.md lines 560-635 (CLUSTER 7)  
**Files to Create:** enhanced `internal/config/unified.go` (~300 LOC), `Sources/Services/SharedConfigService.swift` (~300 LOC)

**Items:**
222. **CLI Config Service** (PLAN CLUSTER 7 item 1) - YAML parsing, validation against UC schema, backward-compat migration (already has partial implementation)
223. **IDE Config Service** (PLAN CLUSTER 7 item 2) - Swift YAML parser (Yams dependency), merge with ConfigurationService.swift (keep UserDefaults for IDE-specific UI prefs only)
224. **Config Migration Tools** (PLAN CLUSTER 7 item 3) - CLI: `obot config migrate`, IDE: auto-migration on first launch, backups before migration

---

### 13.3 Package Consolidation (PLAN §1 item 3)
**Status:** Major refactoring needed  
**Source:** plan.md lines 53-65  
**Estimated:** ~800 LOC refactoring, 60+ import path updates

**Items:**
225. **Package Merges** (PLAN CLUSTER 1 item 3) - actions + agent + analyzer + oberror + recorder → agent, config + tier + model → config, context + summary → context, fixer + review + quality → fixer, session + stats → session, ui + display + memory + ansi → ui

---

## SECTION 14: IDE ORCHESTRATION (PLAN §5)

### 14.1 OrchestrationService (PLAN §5 item 1)
**Status:** Complete implementation needed  
**Source:** plan.md lines 382-401  
**Files to Create:** `Sources/Services/OrchestrationService.swift` (~700 LOC)

**Items:**
226. **OrchestrationService.swift** (PLAN CLUSTER 5 item 1) - Native Swift implementation of UOP state machine: 5 schedules (Knowledge, Plan, Implement, Scale, Production), 3 processes per schedule, Navigation (P1↔P2↔P3 within schedule, any_P3→any_P1 between schedules), Flow code generation (S1P123S2P12...), Human consultation with timeout
227. **Schedule Enum** - knowledge, plan, implement, scale, production
228. **Process Enum** - p1, p2, p3
229. **navigate(to:)** - Enforce P1↔P2↔P3 rule, throw NavigationError if invalid
230. **advanceSchedule()** - Require currentProcess == .p3, advance to next schedule, reset to .p1
231. **updateFlowCode()** - Generate S1P123S2P12 format

---

### 14.2 Orchestration UI (PLAN §5 item 2)
**Status:** Complete implementation needed  
**Source:** plan.md lines 402-409  
**Files to Create:** `Sources/Views/OrchestrationView.swift` (~450 LOC), `Sources/Views/FlowCodeView.swift` (~150 LOC)

**Items:**
232. **OrchestrationView.swift** (PLAN CLUSTER 5 item 2) - Visual schedule timeline, Process state indicators (P1/P2/P3), Flow code display, Navigation controls

---

### 14.3 AgentExecutor Refactoring (PLAN §5 item 3)
**Status:** Major refactoring needed  
**Source:** plan.md lines 410-419  
**Files to Create:** Split `AgentExecutor.swift` (1,069 lines) into 5 files

**Items:**
233. **AgentExecutor.swift** (PLAN CLUSTER 5 item 3) - Coordination only (~200 LOC)
234. **ToolExecutor.swift** - Tool dispatch (~150 LOC)
235. **VerificationEngine.swift** - Quality checks (~100 LOC)
236. **DelegationHandler.swift** - Multi-model routing (~150 LOC)
237. **ErrorRecovery.swift** - Error handling (~100 LOC)

---

## SECTION 15: IDE FEATURE PARITY (PLAN §6)

### 15.1 Quality Presets (PLAN §6 item 1)
**Status:** Complete implementation needed  
**Source:** plan.md lines 492-508  
**Files to Create:** `Sources/Views/QualityPresetView.swift` (~100 LOC), `Sources/Services/QualityPresetService.swift` (~200 LOC)

**Items:**
238. **Quality Presets** (PLAN CLUSTER 6 item 1) - Fast (single pass, no verification, ~30s target), Balanced (plan → execute → review, LLM verification, ~180s target), Thorough (plan → execute → review → revise, expert judge, ~600s target)
239. **QualityPreset Enum** - fast, balanced, thorough
240. **pipeline** - Array of Stage (execute / plan+execute+review / plan+execute+review+revise)
241. **verificationLevel** - none / llmReview / expertJudge

---

### 15.2 Cost Tracking (PLAN §6 item 2)
**Status:** Complete implementation needed  
**Source:** plan.md lines 509-510  
**Files to Create:** `Sources/Services/CostTrackingService.swift` (~250 LOC), `Sources/Views/CostDashboardView.swift` (~300 LOC)

**Items:**
242. **Cost Tracking** (PLAN CLUSTER 6 item 2) - Token usage per session, savings vs Claude/GPT-4, cost per feature

---

### 15.3 Human Consultation Modal (PLAN §6 item 3)
**Status:** Complete implementation needed  
**Source:** plan.md lines 511-512  
**Files to Create:** `Sources/Views/ConsultationView.swift` (~200 LOC)

**Items:**
243. **Consultation Modal** (PLAN CLUSTER 6 item 3) - 60s countdown timer, AI fallback on timeout, note recording

---

### 15.4 Dry-Run / Diff Preview (PLAN §6 item 4)
**Status:** Complete implementation needed  
**Source:** plan.md lines 513-514  
**Files to Create:** `Sources/Services/PreviewService.swift` (~300 LOC), `Sources/Views/PreviewView.swift` (~250 LOC)

**Items:**
244. **Diff Preview** (PLAN CLUSTER 6 item 4) - Show proposed file changes in diff view before applying

---

### 15.5 Line-Range Editing (PLAN §6 item 5)
**Status:** Enhancement needed  
**Source:** plan.md lines 515-516  
**Files to Modify:** `Sources/Agent/AgentExecutor.swift`, tool definitions

**Items:**
245. **Line-Range Editing** (PLAN CLUSTER 6 item 5) - Targeted edits via -start +end syntax

---

## SECTION 16: OBOTRULES & MENTIONS (PLAN §8)

### 16.1 OBotRules Parser (PLAN §8 item 1)
**Status:** Complete implementation needed  
**Source:** plan.md lines 645-696  
**Files to Create:** `internal/obotrules/parser.go` (~300 LOC)

**Items:**
246. **.obotrules Parser** (PLAN CLUSTER 8 item 1) - Parse .obot/rules.obotrules markdown files, inject rules into system prompts
247. **Rules Struct** - SystemRules, FileRules (map), GlobalRules
248. **ParseOBotRules()** - Optional file, parse markdown sections (## System Rules → SystemRules, ## File-Specific Rules → FileRules, ## Global Rules → GlobalRules)

---

### 16.2 @mention Parser (PLAN §8 item 2)
**Status:** Complete implementation needed  
**Source:** plan.md lines 697-722  
**Files to Create:** `internal/mention/parser.go` (~200 LOC)

**Items:**
249. **@mention Parser** (PLAN CLUSTER 8 item 2) - Mention types: @file:path, @bot:name, @context:id, @codebase, @selection, @clipboard, @recent, @git:branch, @url:address, @package:name
250. **ParseMentions()** - Regex: @(\w+):(.+?)(?:\s|$), extract type and value
251. **ResolveMention()** - @file→ReadFile, @codebase→buildCodebaseContext, @git→git show, etc.

---

### 16.3 IDE OBot System (PLAN §8 item 3)
**Status:** Already implemented  
**Source:** plan.md lines 659-662

**Items:**
252. **IDE OBot System** (PLAN CLUSTER 8 item 3) - Sources/Services/OBotService.swift handles .obotrules, bots, context snippets, templates. Action: Document existing implementation, ensure alignment with planned CLI implementation.

---

## SECTION 17: MIGRATION PATH (ORCH §19)

### 17.1 Phase 1: Core Infrastructure (ORCH §19.1)
**Status:** Planning phase  
**Source:** ORCH_PART2.md lines 2462-2468

**Items:**
253. **Phase 1: Core Infrastructure** (ORCH §19.1) - Create internal/orchestrate/ directory structure, Implement core types and interfaces, Implement orchestrator state machine, Implement navigation logic with validation

---

### 17.2 Phase 2: Schedule and Process (ORCH §19.2)
**Status:** Planning phase  
**Source:** ORCH_PART2.md lines 2469-2475

**Items:**
254. **Phase 2: Schedule and Process** (ORCH §19.2) - Implement schedule factory, Implement all 15 processes, Integrate model coordination, Add human consultation handling

---

### 17.3 Phase 3: UI and Display (ORCH §19.3)
**Status:** Planning phase  
**Source:** ORCH_PART2.md lines 2476-2481

**Items:**
255. **Phase 3: UI and Display** (ORCH §19.3) - Implement ANSI display system, Implement memory visualization, Implement terminal UI application, Add input handling

---

### 17.4 Phase 4: Persistence and Git (ORCH §19.4)
**Status:** Planning phase  
**Source:** ORCH_PART2.md lines 2482-2488

**Items:**
256. **Phase 4: Persistence and Git** (ORCH §19.4) - Implement session manager, Implement recurrence relations, Implement restore script generation, Implement GitHub/GitLab integration

---

### 17.5 Phase 5: Analysis and Summary (ORCH §19.5)
**Status:** Planning phase  
**Source:** ORCH_PART2.md lines 2489-2495

**Items:**
257. **Phase 5: Analysis and Summary** (ORCH §19.5) - Implement resource monitoring, Implement prompt summary generation, Implement LLM-as-judge, Implement flow code generation

---

## SECTION 18: OPEN QUESTIONS (ORCH §20)

### 18.1 Implementation Questions (ORCH §20)
**Status:** Need decisions  
**Source:** ORCH_PART2.md lines 2497-2518

**Items:**
258. **Model Loading** - How to handle model loading/unloading to manage memory?
259. **Checkpoint Granularity** - After every process or only after schedule termination?
260. **Concurrent Operations** - Allow any concurrent operations (e.g., background indexing)?
261. **External Tool Integration** - See [docs/External_Tool_Integration.md](docs/External_Tool_Integration.md) for integration guide. Status: Implemented.
262. **Custom Schedule Definitions** - Should users define custom schedules/processes?
263. **Distributed Execution** - Considerations for future distributed execution across machines? [See docs/code_runtime/distributed.md]
264. **Telemetry** - Add telemetry for usage analytics (opt-in)?
265. **Plugin System** - Hooks for plugins/extensions?

---

## SECTION 19: DEFERRED FEATURES (PLAN §9 & §10)
[See docs/V2_ROADMAP.md for detailed roadmap]

### 19.1 Rust Core + FFI (PLAN §9)
**Status:** Deferred to v2.0  
**Source:** plan.md lines 727-776  
**Decision:** Deferred due to timeline risk (12-16 weeks), regression risk, bottleneck is Ollama inference not context management

**Items:**
266. **Rust Core (v2.0)** (PLAN CLUSTER 9) - core-ollama (~800 LOC), core-models (~600 LOC), core-context (~900 LOC), core-orchestration (~700 LOC), core-tools (~500 LOC), core-session (~400 LOC), FFI bindings (~1,500 LOC). Estimated: 12 weeks, 2 developers.

---

### 19.2 CLI-as-Server / JSON-RPC (PLAN §10)
**Status:** Deferred to v2.0  
**Source:** plan.md lines 778-867  
**Blocker:** Orchestrator uses Go closure-injected callbacks, not serializable request/response interfaces. Requires major architectural refactoring.

**Items:**
267. **JSON-RPC Server (v2.0)** (PLAN CLUSTER 10) - Refactor callbacks into serializable RPC methods, State serialization after every step, RPC server (session.start/step/state, context.build, models.list), IDE RPC client. Estimated: 6 weeks, 2 developers, ~2,500 LOC.

---

## SECTION 20: IMPLEMENTATION PRIORITY (PLAN)

### 20.1 Recommended Implementation Order (PLAN)
**Status:** Strategic roadmap  
**Source:** plan.md lines 992-1018

**Items:**
268. **Phase 1: Foundation (Weeks 1-4)** - CLUSTER 7 (Shared Config, 3 weeks), CLUSTER 4 (Session Portability, 3 weeks parallel), CLUSTER 1 (CLI Core Refactoring, 4 weeks starts Week 2)
269. **Phase 2: Core Features (Weeks 5-9)** - CLUSTER 2 (CLI Tool Parity, 4 weeks), CLUSTER 3 (Multi-Model Coordination, 3 weeks parallel), CLUSTER 8 (OBotRules & Mentions, 3 weeks parallel)
270. **Phase 3: Platform-Specific (Weeks 10-16)** - CLUSTER 5 (IDE Orchestration, 6 weeks), CLUSTER 6 (IDE Feature Parity, 4 weeks starts Week 13)
271. **Phase 4: Quality & Release (Weeks 17-23)** - CLUSTER 11 (Testing Infrastructure, 6 weeks), CLUSTER 12 (Documentation & Polish, 5 weeks parallel)
272. **Phase 5: v2.0 (Post-March)** - CLUSTER 10 (CLI-as-Server, 6 weeks), CLUSTER 9 (Rust Core, 12 weeks optional)

---

## SECTION 21: DOCUMENTATION (PLAN §12)

### 21.1 Protocol Specifications (PLAN §12 item 1)
**Status:** Formal specs needed  
**Source:** plan.md lines 945-949

**Items:**
273. **Protocol Docs** (PLAN CLUSTER 12 item 1) - docs/protocols/UOP.md (Unified Orchestration Protocol), docs/protocols/UTR.md (Unified Tool Registry), docs/protocols/UCP.md (Unified Context Protocol), docs/protocols/UMC.md (Unified Model Coordination), docs/protocols/UC.md (Unified Configuration), docs/protocols/USF.md (Unified Session Format)

---

### 21.2 Migration Guides (PLAN §12 item 2)
**Status:** User guides created [See docs/MIGRATION_GUIDE.md]
**Source:** plan.md lines 950-953

**Items:**
274. **Migration Guides** (PLAN CLUSTER 12 item 2) - CLI: old JSON → new YAML config, IDE: UserDefaults → shared config, Sessions: old sessions → USF format [COMPLETED]

---

### 21.3 User Documentation (PLAN §12 item 3)
**Status:** Update READMEs  
**Source:** plan.md lines 954-956

**Items:**
275. **User Docs** (PLAN CLUSTER 12 item 3) - CLI: updated README with new commands, quality presets, session management. IDE: in-app help, feature guides, orchestration explanation.

---

### 21.4 Developer Documentation (PLAN §12 item 4)
**Status:** Dev guides needed  
**Source:** plan.md lines 957-960

**Items:**
276. **Developer Docs** (PLAN CLUSTER 12 item 4) - Contributing guide, Architecture diagrams, Protocol implementation guide

---

### 21.5 Release Prep (PLAN §12 item 5)
**Status:** Release materials needed  
**Source:** plan.md lines 961-965

**Items:**
277. **Release Materials** (PLAN CLUSTER 12 item 5) - Changelog, Release notes, Upgrade instructions, Known issues

---

## SECTION 22: ADVANCED CLI FEATURES (SCALING PLAN)

### 22.1 Repository Index System
**Status:** New feature  
**Source:** SCALING_PLAN.md lines 37-39  
**Estimated LOC:** ~500  
**Priority:** P1

**Items:**
278. **Index Builder** - Fast file index on demand, language detection, file statistics, build time <10s for 2k files
279. **Symbol Search** - Search for functions, classes, types across project
280. **Semantic Search** - Optional embedding-based semantic search (requires local embedding model)
281. **Language Map** - Per-language file counts and statistics

**Files to Create:**
- `internal/index/builder.go` (~200 LOC)
- `internal/index/search.go` (~150 LOC)
- `internal/index/embeddings.go` (~100 LOC)
- `internal/index/language.go` (~50 LOC)

**Commands:**
- `obot index build` - Build/rebuild index
- `obot search "query"` - Search indexed files
- `obot search --symbols "FunctionName"` - Symbol search

**Testing:**
- Unit test: Index builds correctly
- Unit test: Search finds matches
- Performance test: Index build <10s for 2k files
- Integration test: Search integrates with agent

---

### 22.2 Pre-Orchestration Planner
**Status:** New feature  
**Source:** SCALING_PLAN.md line 40  
**Estimated LOC:** ~400  
**Priority:** P1

**Items:**
282. **Task Decomposer** - Break complex prompts into subtasks before orchestration starts
283. **Change Sequencer** - Determine optimal order for multi-file changes
284. **Risk Labeler** - Label changes as safe/moderate/high risk

**Files to Create:**
- `internal/planner/decompose.go` (~150 LOC)
- `internal/planner/sequence.go` (~150 LOC)
- `internal/planner/risk.go` (~100 LOC)

**Integration:**
- Runs BEFORE orchestration starts (pre-schedule phase)
- Outputs: subtasks list, execution sequence, risk labels
- Feeds into Knowledge → Plan schedules

**Testing:**
- Unit test: Task decomposition works
- Unit test: Sequencing handles dependencies
- Unit test: Risk labeling accurate
- Integration test: Planner improves orchestration quality

---

### 22.3 Patch Engine with Safety
**Status:** Enhancement of existing diff system  
**Source:** SCALING_PLAN.md lines 63-68  
**Estimated LOC:** ~600  
**Priority:** P0 (Critical)

**Items:**
285. **Atomic Patch Apply** - Apply patches transactionally (all or nothing)
286. **Pre-Apply Backup** - Create backup before any patch at `~/.config/ollamabot/backups/{timestamp}/`
287. **Rollback on Failure** - Automatic rollback if patch fails or checksum mismatch
288. **Patch Validation** - Checksum verification, conflict detection, file existence checks
289. **Dry-Run Mode** - Show what would change without applying (--dry-run flag)

**Files to Create:**
- `internal/patch/apply.go` (~200 LOC)
- `internal/patch/backup.go` (~150 LOC)
- `internal/patch/rollback.go` (~150 LOC)
- `internal/patch/validate.go` (~100 LOC)

**Flags:**
- `--dry-run` - Show changes without applying
- `--no-backup` - Skip backup creation (power user)
- `--force` - Apply even if validation warnings

**Testing:**
- Unit test: Atomic apply works
- Unit test: Backup created before changes
- Unit test: Rollback restores original
- Unit test: Validation catches conflicts
- Integration test: Full patch workflow

---

### 22.4 Interactive TUI Mode
**Status:** New UX mode  
**Source:** SCALING_PLAN.md lines 14-17, 119-122  
**Estimated LOC:** ~800  
**Priority:** P2

**Items:**
290. **Interactive Chat Mode** - Chat-style interface with history, distinct from orchestrate mode
291. **Diff Preview Widget** - Show diffs before applying with syntax highlighting
292. **Quick Apply/Discard** - Keyboard shortcuts (a=apply, d=discard, u=undo)
293. **Command History** - Navigate previous commands and edits with ↑/↓
294. **Session Resume** - Resume from any point in history

**Files to Create:**
- `internal/cli/interactive.go` (~300 LOC)
- `internal/ui/chat.go` (~200 LOC)
- `internal/ui/preview.go` (~150 LOC)
- `internal/ui/history.go` (~150 LOC)

**Commands:**
- `obot interactive` or `obot -i` - Start interactive mode
- Within TUI: `/apply`, `/discard`, `/history`, `/undo`, `/exit`

**Testing:**
- UI test: Chat interface responsive
- UI test: Diff preview displays correctly
- UI test: History navigation works
- Integration test: Apply/discard workflow

---

### 22.5 Project Health Scanner
**Status:** New feature  
**Source:** SCALING_PLAN.md line 17  
**Estimated LOC:** ~400  
**Priority:** P2

**Items:**
295. **Health Scanner** - Scan repo for issues: unused imports, TODO comments, test coverage gaps, security issues, deprecated APIs
296. **Issue Prioritizer** - Rank issues by severity (critical/high/medium/low) and estimated fix cost
297. **Fix Suggester** - Generate fix suggestions for detected issues with confidence scores
298. **Report Generator** - HTML/markdown health report with charts

**Files to Create:**
- `internal/scan/health.go` (~150 LOC)
- `internal/scan/issues.go` (~150 LOC)
- `internal/scan/suggest.go` (~100 LOC)

**Commands:**
- `obot scan` - Run health scan on current project
- `obot scan --report health.html` - Generate visual report
- `obot fix --from-scan` - Fix issues from scan in priority order

**Testing:**
- Unit test: Scanner detects known issues
- Unit test: Prioritization ranks correctly
- Unit test: Suggestions are valid
- Integration test: Scan → fix workflow

---

### 22.6 Unified Telemetry System
**Status:** Merge of existing resource monitoring + cost tracking  
**Source:** SCALING_PLAN.md line 45, integrates items #164-175, #242  
**Estimated LOC:** ~300  
**Priority:** P1

**Items:**
299. **Unified Telemetry Service** - Cross-platform stats collection (CLI + IDE), local-only storage
300. **Cost Savings Calculator** - Compare Ollama vs commercial API costs (GPT-4, Claude, Gemini)
301. **Performance Metrics** - Track: median time to fix, first-token latency, patch success rate, user acceptance rate
302. **Local-Only Storage** - All telemetry stored at `~/.config/ollamabot/telemetry/stats.json`, no external reporting

**Files to Create:**
- `internal/telemetry/service.go` (~150 LOC)
- `internal/telemetry/savings.go` (~100 LOC)
- `internal/telemetry/metrics.go` (~50 LOC)

**Integrates With:**
- Items #164-175 (Resource Monitor) - provides data source
- Item #242 (IDE Cost Tracking) - unified calculator

**Commands:**
- `obot stats` - Show telemetry summary (replaces resource summary)
- `obot stats --savings` - Show cost savings vs commercial APIs
- `obot stats --reset` - Reset telemetry data

**Testing:**
- Unit test: Stats accumulate correctly
- Unit test: Savings calculated accurately
- Unit test: Metrics tracked properly
- Integration test: Cross-platform compatibility

---

## SECTION 23: ENHANCED CLI COMMANDS (SCALING PLAN)

### 23.1 Enhanced CLI Surface
**Status:** New commands and flags  
**Source:** SCALING_PLAN.md lines 48-54  
**Estimated LOC:** ~200  
**Priority:** P1

**Items:**
303. **Line Range Syntax** - `obot file.go [-start +end] [instruction]` for targeted edits
304. **Scoped Fix** - `obot fix [path] --scope repo|dir|file --plan --apply` with scope control
305. **Review Command** - `obot review [path] --diff --tests` runs verification without execution
306. **Search Command** - `obot search "query" --files --symbols` (uses Repository Index from item #278)
307. **Init Command** - `obot init` scaffolds config, cache paths, .obotrules template

**Files to Create:**
- `internal/cli/fix.go` - Enhanced with --scope flag (~50 LOC addition)
- `internal/cli/review.go` - New review command (~50 LOC)
- `internal/cli/search.go` - New search command (~50 LOC)
- `internal/cli/init.go` - New init command (~50 LOC)

**Testing:**
- CLI test: Line range parsing works
- CLI test: Scope flag filters correctly
- CLI test: Review runs without mutations
- CLI test: Search integrates with index
- CLI test: Init creates proper structure

---

## SUMMARY STATISTICS (UPDATED)

### Total Items by Category

| Category | Items | Estimated LOC | Weeks | Developers |
|----------|-------|---------------|-------|------------|
| Architecture & Core | 33 items (#1-33) | ~1,550 | 4 | 2 |
| Agent & Tools | 25 items (#34-58) | ~2,400 | 5 | 2 |
| Model Coordination | 6 items (#59-64) | ~600 | 2 | 1 |
| Display & UI | 20 items (#65-85, #86-95) | ~1,650 | 3 | 2 |
| Human Consultation | 8 items (#96-104) | ~500 | 1 | 1 |
| Error & Suspension | 18 items (#105-122) | ~950 | 2 | 1 |
| Session Persistence | 19 items (#123-146) | ~1,650 | 3 | 1 |
| Git Integration | 18 items (#147-163) | ~900 | 2 | 1 |
| Resource Management | 12 items (#164-175) | ~600 | 2 | 1 |
| Summary & Judge | 20 items (#176-196) | ~1,200 | 3 | 1 |
| Testing | 12 items (#197-208) | ~8,000 | 6 | 2 |
| Context Management | 7 items (#209-217) | ~1,700 | 3 | 2 |
| Config & Migration | 7 items (#218-225) | ~550 | 2 | 1 |
| IDE Orchestration | 12 items (#226-237) | ~1,900 | 6 | 2 |
| IDE Feature Parity | 8 items (#238-245) | ~1,400 | 4 | 1 |
| OBotRules & Mentions | 7 items (#246-252) | ~500 | 2 | 1 |
| Migration Path | 5 items (#253-257) | N/A (planning) | - | - |
| Open Questions | 8 items (#258-265) | N/A (decisions) | - | - |
| Deferred Features | 2 items (#266-267) | ~6,400 | 18 | 2 |
| Implementation Priority | 5 items (#268-272) | N/A (roadmap) | - | - |
| Documentation | 5 items (#273-277) | ~20,000 words | 5 | 2 |
| **Advanced CLI Features** | **23 items (#278-300)** | **~3,000** | **4** | **2** |
| **Enhanced CLI Commands** | **7 items (#301-307)** | **~200** | **1** | **1** |

### Grand Totals (Updated)

- **Immediate Implementation:** 255 items (#1-255, #278-307), ~21,950 LOC, 25 weeks, 4-6 developers
- **Testing:** 12 items (#197-208), ~8,000 LOC, 6 weeks, 2 developers
- **Documentation:** 5 items (#273-277), ~20,000 words, 5 weeks, 2 developers
- **Deferred to v2.0:** 2 items (#266-267), ~6,400 LOC, 18 weeks, 2 developers
- **Planning/Decisions:** 18 items (#253-265, #268-272), N/A

**Total Unique Items:** 307 (+30 from SCALING_PLAN.md)  
**Total Estimated Code:** ~36,350 LOC (+3,000) + ~20,000 words documentation  
**Total Timeline:** 25 weeks (+2 weeks) immediate + 18 weeks (v2.0 optional)

| Category | Items | Estimated LOC | Weeks | Developers |
|----------|-------|---------------|-------|------------|
| Architecture & Core | 33 items (#1-33) | ~1,550 | 4 | 2 |
| Agent & Tools | 25 items (#34-58) | ~2,400 | 5 | 2 |
| Model Coordination | 6 items (#59-64) | ~600 | 2 | 1 |
| Display & UI | 20 items (#65-85, #86-95) | ~1,650 | 3 | 2 |
| Human Consultation | 8 items (#96-104) | ~500 | 1 | 1 |
| Error & Suspension | 18 items (#105-122) | ~950 | 2 | 1 |
| Session Persistence | 19 items (#123-146) | ~1,650 | 3 | 1 |
| Git Integration | 18 items (#147-163) | ~900 | 2 | 1 |
| Resource Management | 12 items (#164-175) | ~600 | 2 | 1 |
| Summary & Judge | 20 items (#176-196) | ~1,200 | 3 | 1 |
| Testing | 12 items (#197-208) | ~8,000 | 6 | 2 |
| Context Management | 7 items (#209-217) | ~1,700 | 3 | 2 |
| Config & Migration | 7 items (#218-225) | ~550 | 2 | 1 |
| IDE Orchestration | 12 items (#226-237) | ~1,900 | 6 | 2 |
| IDE Feature Parity | 8 items (#238-245) | ~1,400 | 4 | 1 |
| OBotRules & Mentions | 7 items (#246-252) | ~500 | 2 | 1 |
| Migration Path | 5 items (#253-257) | N/A (planning) | - | - |
| Open Questions | 8 items (#258-265) | N/A (decisions) | - | - |
| Deferred Features | 2 items (#266-267) | ~6,400 | 18 | 2 |
| Implementation Priority | 5 items (#268-272) | N/A (roadmap) | - | - |
| Documentation | 5 items (#273-277) | ~20,000 words | 5 | 2 |

### Grand Totals

- **Immediate Implementation:** 225 items (#1-225), ~18,950 LOC, 23 weeks, 4-6 developers
- **Testing:** 12 items (#197-208), ~8,000 LOC, 6 weeks, 2 developers
- **Documentation:** 5 items (#273-277), ~20,000 words, 5 weeks, 2 developers
- **Deferred to v2.0:** 2 items (#266-267), ~6,400 LOC, 18 weeks, 2 developers
- **Planning/Decisions:** 18 items (#253-265, #268-272), N/A

**Total Unique Items:** 277 (after deduplication from ~600+ original items)  
**Total Estimated Code:** ~33,350 LOC + ~20,000 words documentation  
**Total Timeline:** 23 weeks (immediate) + 18 weeks (v2.0 optional)

---

## NEXT STEPS

1. **Validate Priorities** - Review with stakeholders
2. **Resource Allocation** - Assign 4-6 developers
3. **Phase 1 Start** - Begin Foundation (CLUSTER 7, 4, 1)
4. **Phase 2 Enhancement** - Add Patch Engine (item #285-289, P0)
5. **CI/CD Setup** - Schema compliance validation
6. **Test Framework** - Cross-product integration testing

---

## DOCUMENT RECOMMENDATIONS

### Archive These Documents ✅

1. **UNIFIED_IMPLEMENTATION_PLAN.md** - 100% redundant with plan.md (was a source document for consolidation)
2. **SCALING_PLAN.md** - All unique items (#278-307) extracted and added to plan.md

### Keep These Documents ✅

1. **plan.md** - Master consolidated plan (this document)
2. **CLI_RULES.md** - CLI-specific rules and constraints
3. **README.md** - User-facing documentation
4. **ADDITIONS_ANALYSIS.md** - Analysis of SCALING_PLAN.md extraction (reference)

---

## UPDATED IMPLEMENTATION PHASES

### Phase 1: Foundation (Weeks 1-4) - NO CHANGE
Same as before: CLUSTER 7 (Config & Migration), CLUSTER 4 (Context Management), CLUSTER 1 (Agent Read Tools)

### Phase 2: Core Features + Safety (Weeks 5-10) - EXTENDED +1 WEEK
- Original Phase 2 items (existing core features)
- **NEW:** Patch Engine with Safety (items #285-289, P0 Critical)
- **NEW:** Repository Index System (items #278-281, P1)

### Phase 3: Platform-Specific (Weeks 11-17) - NO CHANGE
Same as before: Orchestration, IDE features, multi-model coordination

### Phase 3.5: Advanced CLI Features (Weeks 18-19) - NEW
- **Pre-Orchestration Planner** (items #282-284, P1)
- **Interactive TUI Mode** (items #290-294, P2)
- **Enhanced CLI Commands** (items #303-307, P1)

### Phase 4: Quality, Observability & Release (Weeks 20-25) - ADJUSTED
- **Unified Telemetry System** (items #299-302, P1) - Merges existing items #164-175 + #242
- **Project Health Scanner** (items #295-298, P2)
- Testing Infrastructure (items #197-208)
- Documentation (items #273-277)
- Polish & Release

---

**Document Consolidation Completed:** 2026-02-10  
**Source Documents Processed:** 5 (ORCHESTRATION_PLAN.md, ORCHESTRATION_PLAN_PART2.md, original plan.md, UNIFIED_IMPLEMENTATION_PLAN.md, SCALING_PLAN.md)  
**Total Original Lines:** ~9,200  
**Deduplication Rate:** ~63% (from ~600+ original items to 307 unique items)  
**Cohesion Analysis:** Complete across all 12 implementation clusters + 2 new advanced feature clusters  
**Final Unique Items:** 307  
**Final Estimated LOC:** ~36,350  
**Final Timeline:** 25 weeks for v1.0
