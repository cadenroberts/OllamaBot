# Plan: OllamaBot Consolidated Implementation
plan_id=ollamabot_consolidated
policy: accrue_all_ideas=true, no_refactor=true

## Metadata (embedded as doc payloads)
- [ ] id=meta.generated lane=1 payload=@doc:Generated 2026-02-10 from ORCHESTRATION_PLAN.md (2948 lines) ORCHESTRATION_PLAN_PART2.md (2519 lines) plan.md (1076 lines)
- [ ] id=meta.items lane=1 payload=@doc:Total 307 unique implementation items after deduplication from ~600+ original items
- [ ] id=meta.loc lane=1 payload=@doc:Estimated 36350 LOC total, 25 weeks for v1.0

## SECTION 1: ARCHITECTURE & CORE INFRASTRUCTURE

### 1.1 System Architecture (ORCH §1.1-1.3)
- [ ] id=arch.diagram lane=1 payload=@doc:System Diagram - Terminal UI → Orchestrator → Agent → Model Coordinator → Persistence Layer architecture (ORCH §1.1)
- [ ] id=arch.components lane=1 deps=arch.diagram payload=@doc:Component Dependencies - OrchestratorApp struct with 11 injected dependencies (ORCH §1.2)
- [ ] id=arch.eventflow lane=1 deps=arch.components payload=@doc:Event Flow - User Input → Input Handler → Orchestrator Loop → Summary → Persistence (ORCH §1.3)

### 1.2 Data Structures (ORCH §2)
- [ ] id=types.core lane=2 deps=arch.eventflow payload=@file:internal/orchestrate/types.go#implement_Core_Types_ScheduleID_1-5_ProcessID_1-3_OrchestratorState_enum_Schedule_struct_Process_struct_ConsultationType_enum_ModelType_enum_~300_LOC
- [ ] id=types.actions lane=2 deps=types.core payload=@file:internal/agent/actions.go#implement_Agent_Action_Types_13_ActionType_constants_create_delete_rename_move_copy_for_files_dirs_run_command_edit_file_complete_~150_LOC
- [ ] id=types.action_struct lane=2 deps=types.actions payload=@file:internal/agent/actions.go#extend_Action_Struct_Timestamp_Path_NewPath_LineRanges_DiffSummary_Command_output_Metadata
- [ ] id=types.session lane=2 deps=types.core payload=@file:internal/session/state.go#implement_Session_State_with_ID_format_0001_S1P1_Note_with_Source_SessionStats_schedules_processes_actions_tokens_resources_timing_consultation_~400_LOC
- [ ] id=types.suspend lane=2 deps=types.session payload=@file:internal/session/state.go#extend_SuspendError_Code_Message_Component_Rule_State_Timestamp_Solutions_Recoverable
- [ ] id=types.recurrence lane=2 deps=types.session payload=@file:internal/session/recurrence.go#implement_Recurrence_Relations_StateRelation_with_Prev_Next_pointers_FilesHash_Actions_RestoreFromPrev_Next_scripts_~300_LOC
- [ ] id=types.pathstep lane=2 deps=types.recurrence payload=@file:internal/session/recurrence.go#extend_PathStep_Direction_forward_reverse_DiffFile_for_state_restoration
- [ ] id=types.findpath lane=2 deps=types.pathstep payload=@file:internal/session/recurrence.go#implement_FindPath_BFS_Bidirectional_graph_search_for_state_restoration_paths

### 1.3 Orchestrator Core (ORCH §3)
- [ ] id=orch.struct lane=2 deps=types.core payload=@file:internal/orchestrate/orchestrator.go#implement_Orchestrator_Struct_State_machine_with_mutex_currentSchedule_currentProcess_tracking_scheduleHistory_processHistory_scheduleCounts_notes_callbacks_~400_LOC
- [ ] id=orch.runloop lane=2 deps=orch.struct payload=@file:internal/orchestrate/orchestrator.go#implement_Run_Loop_while_not_promptTerminated_selectSchedule_runSchedule
- [ ] id=orch.schedule_select lane=2 deps=orch.runloop payload=@file:internal/orchestrate/orchestrator.go#implement_Schedule_Selection_LLM_based_via_orchestrator_model_validates_against_history
- [ ] id=orch.process_exec lane=2 deps=orch.schedule_select payload=@file:internal/orchestrate/orchestrator.go#implement_Process_Execution_Delegates_to_agent_with_model_selection
- [ ] id=nav.validator lane=2 deps=orch.struct payload=@file:internal/orchestrate/navigator.go#implement_Navigation_Validator_Enforces_P1↔P2↔P3_rule_validates_from_to_transitions_~300_LOC
- [ ] id=nav.is_valid lane=2 deps=nav.validator payload=@file:internal/orchestrate/navigator.go#implement_isValidNavigation_Initial→P1_P1→P1_P2_P2→P1_P2_P3_P3→P2_P3_0
- [ ] id=nav.error lane=2 deps=nav.is_valid payload=@file:internal/orchestrate/navigator.go#implement_NavigationError_Structured_error_for_invalid_P1→P3_or_P3→P1_attempts
- [ ] id=nav.terminate lane=2 deps=nav.validator payload=@file:internal/orchestrate/navigator.go#implement_canTerminatePrompt_Requires_all_5_schedules_run_≥1_time_plus_last_schedule_equals_Production
- [ ] id=orch.terminate lane=2 deps=nav.terminate payload=@file:internal/orchestrate/orchestrator.go#implement_Prompt_Termination_LLM_decision_with_context_history_stats_notes
- [ ] id=orch.select_process lane=2 deps=nav.is_valid payload=@file:internal/orchestrate/orchestrator.go#implement_selectProcess_LLM_based_with_valid_options_filtered_by_current_state
- [ ] id=orch.prompts lane=2 deps=orch.select_process payload=@file:internal/orchestrate/orchestrator.go#implement_System_Prompts_scheduleSelectionSystemPrompt_TOOLER_not_agent_processSelectionSystemPrompt_navigation_rules

### 1.4 Schedule Implementation (ORCH §4)
- [ ] id=sched.factory lane=2 deps=types.core payload=@file:internal/schedule/factory.go#implement_Schedule_Factory_NewSchedule_creates_schedule_with_3_processes_sets_model_type_consultation_requirements_~100_LOC
- [ ] id=sched.knowledge lane=2 deps=sched.factory payload=@file:internal/schedule/knowledge.go#implement_Knowledge_Schedule_Research_identify_gaps_Crawl_extract_content_Retrieve_structure_info_~150_LOC
- [ ] id=sched.plan lane=2 deps=sched.factory payload=@file:internal/schedule/plan.go#implement_Plan_Schedule_Brainstorm_generate_approaches_Clarify_optional_human_consultation_if_ambiguities_exist_Plan_synthesize_into_concrete_steps_~200_LOC
- [ ] id=sched.implement lane=2 deps=sched.factory payload=@file:internal/schedule/implement.go#implement_Implement_Schedule_Implement_execute_plan_steps_Verify_tests_lint_build_Feedback_mandatory_human_consultation_with_demonstration_~250_LOC
- [ ] id=sched.scale lane=2 deps=sched.factory payload=@file:internal/schedule/scale.go#implement_Scale_Schedule_Scale_identify_concerns_refactor_Benchmark_run_benchmarks_collect_metrics_Optimize_analyze_results_apply_optimizations_~150_LOC
- [ ] id=sched.production lane=2 deps=sched.factory payload=@file:internal/schedule/production.go#implement_Production_Schedule_Analyze_code_security_deps_review_Systemize_patterns_docs_config_Harmonize_integration_tests_UI_polish_via_vision_model_if_hasUI_~200_LOC
- [ ] id=sched.consult lane=2 deps=sched.plan,sched.implement payload=@file:internal/schedule/plan.go#integrate_Consultation_Integration_Plan_Clarify_optional_Implement_Feedback_mandatory_timeout_with_AI_substitute

### 1.5 Process Implementation (ORCH §5)
- [ ] id=proc.interface lane=2 deps=sched.factory payload=@file:internal/process/process.go#implement_Process_Interface_ID_Name_Schedule_Execute_RequiresHumanConsultation_ConsultationType_ValidateEntry_~200_LOC
- [ ] id=proc.base lane=2 deps=proc.interface payload=@file:internal/process/process.go#implement_BaseProcess_Common_functionality_for_all_15_processes
- [ ] id=proc.validate lane=2 deps=proc.base,nav.validator payload=@file:internal/process/process.go#implement_ValidateEntry_Navigation_validation_per_1↔2↔3_rule
- [ ] id=proc.error lane=2 deps=proc.validate payload=@file:internal/process/process.go#implement_InvalidNavigationError_Process_level_navigation_error

## SECTION 2: AGENT & TOOLS

### 2.1 Agent Core (ORCH §6.1)
- [ ] id=agent.struct lane=2 deps=types.actions payload=@file:internal/agent/agent.go#implement_Agent_Struct_models_ModelCoordinator_currentModel_actions_tracker_sessionCtx_notes_callbacks_onAction_onComplete_~300_LOC
- [ ] id=agent.execute lane=2 deps=agent.struct payload=@file:internal/agent/agent.go#implement_Execute_Selects_model_for_schedule_process_builds_prompt_executes_with_model
- [ ] id=agent.select_model lane=2 deps=agent.execute payload=@file:internal/agent/agent.go#implement_selectModel_Knowledge→Researcher_Production_P3→Coder_vision_separate_default→Coder
- [ ] id=agent.execute_model lane=2 deps=agent.select_model payload=@file:internal/agent/agent.go#implement_executeWithModel_Streams_LLM_response_parses_actions_incrementally_executes_via_executeAction
- [ ] id=agent.prompt lane=2 deps=agent.execute_model payload=@file:internal/agent/agent.go#implement_agentSystemPrompt_Lists_13_allowed_actions_with_exact_formats_states_CANNOT_do_select_schedules_navigate_terminate_make_orchestration_decisions_requires_COMPLETE_signal

### 2.2 Action Executor (ORCH §6.2)
- [ ] id=exec.action lane=2 deps=agent.execute_model payload=@file:internal/agent/executor.go#implement_executeAction_Validates_action_type_sets_metadata_ID_timestamp_routes_to_handler_records_duration_~500_LOC
- [ ] id=exec.file_ops lane=2 deps=exec.action payload=@file:internal/agent/executor.go#implement_File_Operations_createFile_with_MkdirAll_deleteFile_createDir_deleteDir
- [ ] id=exec.rename_move lane=2 deps=exec.file_ops payload=@file:internal/agent/executor.go#implement_Rename_Move_renameFile_renameDir_moveFile_ensures_dest_dir_moveDir
- [ ] id=exec.copy lane=2 deps=exec.file_ops payload=@file:internal/agent/executor.go#implement_Copy_copyFile_ReadFile→WriteFile_copyDir_filepath_Walk
- [ ] id=exec.run_cmd lane=2 deps=exec.action payload=@file:internal/agent/executor.go#implement_runCommand_exec_CommandContext_with_combined_output_exit_code_capture
- [ ] id=exec.edit_file lane=2 deps=exec.action payload=@file:internal/agent/executor.go#implement_editFile_Read_original_compute_diff_line_ranges_write_new_content
- [ ] id=exec.complete lane=2 deps=exec.action payload=@file:internal/agent/executor.go#implement_ActionComplete_Triggers_onComplete_callback_to_signal_process_completion
- [ ] id=exec.action_id lane=2 deps=exec.action payload=@file:internal/agent/executor.go#implement_nextActionID_Thread_safe_counter_for_action_IDs_A0001_A0002
- [ ] id=exec.error lane=2 deps=exec.action payload=@file:internal/agent/executor.go#implement_InvalidActionError_Error_for_undefined_action_types

### 2.3 Diff Generation (ORCH §6.3)
- [ ] id=diff.compute lane=2 deps=exec.edit_file payload=@file:internal/agent/diff.go#implement_computeDiff_Uses_go_difflib_for_unified_diff_converts_to_obot_style_~400_LOC
- [ ] id=diff.format lane=2 deps=diff.compute payload=@file:internal/agent/diff.go#implement_formatDiffObot_Green_plus_lines_Red_minus_lines_line_numbers_ANSI_colors
- [ ] id=diff.line_ranges lane=2 deps=diff.compute payload=@file:internal/agent/diff.go#implement_computeLineRanges_Extract_modified_line_ranges_from_hunks
- [ ] id=diff.merge lane=2 deps=diff.line_ranges payload=@file:internal/agent/diff.go#implement_mergeRanges_Merge_overlapping_adjacent_line_ranges_using_max_overlap_algorithm
- [ ] id=diff.format_ranges lane=2 deps=diff.line_ranges payload=@file:internal/agent/diff.go#implement_FormatLineRanges_10-15_20_34-40_display_format

### 2.4 Tool Registry (PLAN §2 items)
- [ ] id=tools.read lane=2 deps=agent.struct payload=@file:internal/agent/tools_read.go#implement_Read_Tools_ReadFile_SearchFiles_ripgrep_wrapper_ListDirectory_FileExists_~150_LOC
- [ ] id=tools.delegate lane=2 deps=agent.struct payload=@file:internal/delegation/handler.go#implement_Delegation_Tools_delegate_coder_delegate_researcher_delegate_vision_requires_multi_model_coordinator_~250_LOC
- [ ] id=tools.delegate_agent lane=2 deps=tools.delegate payload=@file:internal/agent/tools_delegate.go#implement_agent_side_delegation_tools_~250_LOC
- [ ] id=tools.web lane=2 deps=agent.struct payload=@file:internal/tools/web.go#implement_Web_Tools_web_search_DuckDuckGo_API_web_fetch_HTTP_goquery_HTML_extraction_~200_LOC
- [ ] id=tools.git lane=2 deps=agent.struct payload=@file:internal/tools/git.go#implement_Git_Tools_git_status_git_diff_git_commit_git_push_wrap_exec_Command_with_structured_parsing_~150_LOC
- [ ] id=tools.core lane=2 deps=agent.struct payload=@file:internal/tools/core.go#implement_Core_Control_Tools_core_think_core_complete_core_ask_user_interactive_prompt_core_note_~150_LOC
- [ ] id=tools.screenshot lane=2 deps=agent.struct payload=@file:internal/tools/screenshot.go#implement_Screenshot_Tool_Platform_specific_macOS_screencapture_Linux_scrot_import_~100_LOC

## SECTION 3: MODEL COORDINATION

### 3.1 Model Coordinator (ORCH §7)
- [ ] id=model.coord lane=2 deps=types.core payload=@file:internal/model/coordinator.go#implement_Coordinator_Struct_clients_map_4_model_types_config_model_names_per_role_Ollama_URL_~300_LOC
- [ ] id=model.new lane=2 deps=model.coord payload=@file:internal/model/coordinator.go#implement_NewCoordinator_Initialize_4_clients_orchestrator_coder_researcher_vision
- [ ] id=model.get lane=2 deps=model.coord payload=@file:internal/model/coordinator.go#implement_Get_Return_client_by_ModelType
- [ ] id=model.get_sched lane=2 deps=model.get payload=@file:internal/model/coordinator.go#implement_GetModelForSchedule_Knowledge→Researcher_default→Coder
- [ ] id=model.get_orch lane=2 deps=model.get payload=@file:internal/model/coordinator.go#implement_GetOrchestratorModel_Return_orchestrator_client
- [ ] id=model.validate lane=2 deps=model.coord payload=@file:internal/model/coordinator.go#implement_ValidateModels_Check_all_4_models_available_in_Ollama

### 3.2 Multi-Model System (PLAN §3)
- [ ] id=intent.router lane=2 deps=model.coord payload=@file:internal/intent/router.go#implement_Intent_Router_Keyword_classification_Coding_implement_fix_refactor_Research_explain_analyze_Writing_document_draft_Vision_image_screenshot_~300_LOC
- [ ] id=intent.select lane=2 deps=intent.router,model.coord payload=@file:internal/model/coordinator.go#extend_Intent_Based_Model_Selection_Map_Intent_RAM_tier→optimal_model_role_fallback_to_orchestrator_if_role_unavailable_+100_LOC
- [ ] id=vision.integrate lane=2 deps=model.coord payload=@file:internal/ollama/vision.go#implement_Vision_Model_Integration_Extend_Ollama_client_for_multimodal_API_image_text_payloads_~200_LOC
- [ ] id=model.fallback lane=2 deps=intent.select payload=@doc:Fallback_Chains_If_role_specific_model_unavailable_use_orchestrator_as_universal_fallback

## SECTION 4: DISPLAY & UI

### 4.1 Status Display (ORCH §8.1)
- [ ] id=ui.display lane=2 deps=types.core payload=@file:internal/ui/display.go#implement_StatusDisplay_Struct_4_line_panel_Orchestrator_state_Schedule_name_Process_name_Agent_action_~400_LOC
- [ ] id=ui.anim lane=2 deps=ui.display payload=@file:internal/ui/display.go#implement_Dot_Animations_Independent_3_phase_animations_dot_dot_dot_dot_dot_dot_for_each_line_while_undefined
- [ ] id=ui.setters lane=2 deps=ui.display payload=@file:internal/ui/display.go#implement_SetOrchestrator_Schedule_Process_Agent_Update_display_stop_animation_for_that_line
- [ ] id=ui.render lane=2 deps=ui.display payload=@file:internal/ui/display.go#implement_render_ANSI_color_rendering_blue_theme_move_cursor_up_4_lines
- [ ] id=ui.anim_loop lane=2 deps=ui.anim payload=@file:internal/ui/display.go#implement_animationLoop_250ms_ticker_cycle_dot_phases_conditional_rendering

### 4.2 ANSI Helpers (ORCH §8.2)
- [ ] id=ansi.constants lane=2 payload=@file:internal/ui/ansi.go#implement_Color_Constants_ANSIReset_ANSIBold_8_colors_5_bold_colors_cursor_control_clear_codes_~150_LOC
- [ ] id=ansi.color lane=2 deps=ansi.constants payload=@file:internal/ui/ansi.go#implement_Color_Wrap_text_with_color_code_reset
- [ ] id=ansi.blue lane=2 deps=ansi.color payload=@file:internal/ui/ansi.go#implement_Blue_BoldBlue_Obot_theme_colors
- [ ] id=ansi.semantic lane=2 deps=ansi.color payload=@file:internal/ui/ansi.go#implement_Green_Red_Yellow_White_BoldWhite_Semantic_colors_additions_deletions_warnings_etc
- [ ] id=ansi.control lane=2 deps=ansi.constants payload=@file:internal/ui/ansi.go#implement_ClearLine_MoveCursorUp_MoveCursorDown_ClearToEnd_Terminal_manipulation

### 4.3 Memory Visualization (ORCH §9)
- [ ] id=mem.viz lane=2 payload=@file:internal/ui/memory.go#implement_MemoryVisualization_Struct_Tracks_current_peak_predict_memory_predictLabel_predictBasis_history_last_5_min_samples_~500_LOC
- [ ] id=mem.bars lane=2 deps=mem.viz payload=@file:internal/ui/memory.go#implement_3_Memory_Bars_Current_heap_stack_Peak_max_observed_Predict_next_process_estimate
- [ ] id=mem.monitor lane=2 deps=mem.viz payload=@file:internal/ui/memory.go#implement_monitorLoop_100ms_sampling_via_runtime_ReadMemStats_trim_old_history_5_min_window
- [ ] id=mem.bar lane=2 deps=mem.bars payload=@file:internal/ui/memory.go#implement_renderBar_ASCII_progress_bars_filled_empty_width_40
- [ ] id=mem.predict lane=2 deps=mem.viz payload=@file:internal/ui/memory.go#implement_PredictForProcess_LRU_cache_historical_average_or_default_Knowledge_2GB_Production_6GB_default_4GB
- [ ] id=mem.format lane=2 deps=mem.viz payload=@file:internal/ui/memory.go#implement_formatBytes_KB_MB_GB_formatting
- [ ] id=mem.total lane=2 deps=mem.viz payload=@file:internal/ui/memory.go#implement_getTotalMemory_Platform_specific_defaults_to_8GB

### 4.4 Terminal UI App (ORCH §15)
- [ ] id=app.struct lane=2 deps=ui.display,mem.viz payload=@file:internal/ui/app.go#implement_App_Struct_stdin_stdout_stderr_display_StatusDisplay_memoryViz_inputHandler_noteDestination_toggle_~600_LOC
- [ ] id=app.run lane=2 deps=app.struct payload=@file:internal/ui/app.go#implement_Run_Initialize_components_render_UI_start_display_memory_loops_start_input_loop
- [ ] id=app.render_ui lane=2 deps=app.run payload=@file:internal/ui/app.go#implement_renderUI_Clear_screen_header_logo_icon_status_panel_4_lines_memory_panel_4_lines_output_area_input_area_with_Send_Stop_buttons
- [ ] id=app.header lane=2 deps=app.render_ui payload=@file:internal/ui/app.go#implement_renderHeader_OllamaBot_logo_no_prompt_or_brain_icon_toggle_orchestrator_vs_coder
- [ ] id=app.input_area lane=2 deps=app.render_ui payload=@file:internal/ui/app.go#implement_renderInputArea_Text_input_box_Send_Stop_buttons_note_destination_toggle_brain_Orchestrator_or_coder
- [ ] id=app.input_loop lane=2 deps=app.run payload=@file:internal/ui/app.go#implement_inputLoop_Read_lines_handle_special_commands_toggle_stop_route_to_prompt_or_note
- [ ] id=app.toggle lane=2 deps=app.input_loop payload=@file:internal/ui/app.go#implement_toggleNoteDestination_Switch_between_DestinationOrchestrator_and_DestinationAgent
- [ ] id=app.generating lane=2 deps=app.run payload=@file:internal/ui/app.go#implement_SetGenerating_Update_UI_for_generating_state_gray_Send_red_Stop
- [ ] id=app.update lane=2 deps=app.struct,ui.setters payload=@file:internal/ui/app.go#implement_UpdateDisplay_Forward_to_StatusDisplay_setters
- [ ] id=app.output lane=2 deps=app.render_ui payload=@file:internal/ui/app.go#implement_WriteOutput_Append_to_scrollable_output_area

## SECTION 5: HUMAN CONSULTATION

### 5.1 Consultation Handler (ORCH §10)
- [ ] id=consult.handler lane=2 payload=@file:internal/consultation/handler.go#implement_Handler_Struct_reader_writer_aiModel_timeout_60s_default_countdown_15s_default_allowAISub_~500_LOC
- [ ] id=consult.request lane=2 deps=consult.handler payload=@file:internal/consultation/handler.go#implement_Request_Display_consultation_UI_start_input_reader_create_timeout_timer_countdown_timer
- [ ] id=consult.response lane=2 deps=consult.request payload=@file:internal/consultation/handler.go#implement_Response_Selection_Wait_for_human_input_OR_timeout→AI_substitute_OR_error_if_not_allowAISub
- [ ] id=consult.display lane=2 deps=consult.request payload=@file:internal/consultation/handler.go#implement_displayConsultation_Box_UI_with_question_input_area_timeout_remaining_AI_will_respond_on_your_behalf_warning
- [ ] id=consult.countdown lane=2 deps=consult.request payload=@file:internal/consultation/handler.go#implement_displayCountdown_warning_AI_RESPONSE_IN_15_14_13_yellow_text
- [ ] id=consult.ai_sub lane=2 deps=consult.response payload=@file:internal/consultation/handler.go#implement_generateAISubstitute_Prompt_Act_as_human_in_the_loop_human_did_not_respond_provide_reasonable_response_If_approval_approve_if_reasonable_If_preference_choose_standard_approach
- [ ] id=consult.input lane=2 deps=consult.request payload=@file:internal/consultation/handler.go#implement_readInput_4096_byte_buffer_read_from_stdin
- [ ] id=consult.duration lane=2 deps=consult.countdown payload=@file:internal/consultation/handler.go#implement_formatDuration_MM_SS_countdown_display
- [ ] id=consult.source lane=2 deps=consult.response payload=@file:internal/consultation/handler.go#implement_ResponseSource_Enum_human_ai_substitute

## SECTION 6: ERROR HANDLING & SUSPENSION

### 6.1 Error Types (ORCH §11.1)
- [ ] id=err.codes lane=2 payload=@file:internal/error/types.go#implement_ErrorCode_Constants_E001_E009_navigation_violations_E010_E015_system_errors_~300_LOC
- [ ] id=err.severity lane=2 deps=err.codes payload=@file:internal/error/types.go#implement_ErrorSeverity_critical_system_warning
- [ ] id=err.struct lane=2 deps=err.codes,err.severity payload=@file:internal/error/types.go#implement_OrchestrationError_Struct_Code_Severity_Component_Message_Rule_Timestamp_State_Schedule_Process_LastAction_FlowCode_Solutions_Recoverable
- [ ] id=err.nav lane=2 deps=err.struct payload=@file:internal/error/types.go#implement_NewNavigationError_Factory_for_P1→P3_violations
- [ ] id=err.orch_viol lane=2 deps=err.struct payload=@file:internal/error/types.go#implement_NewOrchestratorViolationError_Factory_for_orchestrator_performing_agent_actions_TOOLER_violation
- [ ] id=err.agent_viol lane=2 deps=err.struct payload=@file:internal/error/types.go#implement_NewAgentViolationError_Factory_for_agent_performing_orchestration_EXECUTOR_violation

### 6.2 Hardcoded Messages (ORCH §11.2)
- [ ] id=err.hardcoded_map lane=2 deps=err.codes payload=@file:internal/error/hardcoded.go#implement_HardcodedMessages_Map_E010_Ollama_is_not_running_Start_Ollama_with_ollama_serve_E013_Disk_space_exhausted_Free_space_required_percent_s_~50_LOC
- [ ] id=err.get_msg lane=2 deps=err.hardcoded_map payload=@file:internal/error/hardcoded.go#implement_GetHardcodedMessage_Return_hardcoded_message_with_optional_sprintf_args
- [ ] id=err.is_hardcoded lane=2 deps=err.hardcoded_map payload=@file:internal/error/hardcoded.go#implement_IsHardcoded_Check_if_error_has_hardcoded_message

### 6.3 Suspension Handler (ORCH §11.3)
- [ ] id=suspend.handler lane=2 deps=err.struct payload=@file:internal/error/suspension.go#implement_SuspensionHandler_Struct_writer_reader_aiModel_session_~600_LOC
- [ ] id=suspend.handle lane=2 deps=suspend.handler payload=@file:internal/error/suspension.go#implement_Handle_Freeze_state_FreezeState_display_suspension_UI_perform_LLM_analysis_if_not_hardcoded_display_solutions_wait_for_user_action
- [ ] id=suspend.display lane=2 deps=suspend.handle payload=@file:internal/error/suspension.go#implement_displaySuspension_Box_UI_Orchestrator_Suspended_error_code_message_frozen_state_schedule_process_last_action_flow_code_with_red_X
- [ ] id=suspend.analyze lane=2 deps=suspend.handle,err.is_hardcoded payload=@file:internal/error/suspension.go#implement_analyzeError_If_hardcoded_return_pre_defined_analysis_Else_LLM_as_judge_analysis_prompt→parse_WHAT_HAPPENED_ROOT_CAUSE_FACTORS_SOLUTION_1_2_3
- [ ] id=suspend.display_analysis lane=2 deps=suspend.analyze payload=@file:internal/error/suspension.go#implement_displayAnalysis_Box_sections_What_happened_Which_component_violated_Rule_violated
- [ ] id=suspend.display_solutions lane=2 deps=suspend.analyze payload=@file:internal/error/suspension.go#implement_displaySolutions_List_solutions_1_3_then_safe_continuation_options_R_etry_S_kip_A_bort_I_nvestigate
- [ ] id=suspend.wait_action lane=2 deps=suspend.display_solutions payload=@file:internal/error/suspension.go#implement_waitForAction_Read_R_S_A_I_from_stdin_return_SuspensionAction_enum
- [ ] id=suspend.format_flow lane=2 deps=suspend.display payload=@file:internal/error/suspension.go#implement_formatFlowCodeWithError_Append_red_X_to_flow_code
- [ ] id=suspend.wrap lane=2 deps=suspend.display_analysis payload=@file:internal/error/suspension.go#implement_wrapAndPrint_Word_wrap_text_to_fit_box_width

## SECTION 7: SESSION PERSISTENCE

### 7.1 Session Manager (ORCH §12.1)
- [ ] id=session.manager lane=2 deps=types.session payload=@file:internal/session/manager.go#implement_Manager_Struct_baseDir_obot_sessions_currentID_session_~700_LOC
- [ ] id=session.create lane=2 deps=session.manager payload=@file:internal/session/manager.go#implement_Create_Generate_session_ID_create_directory_structure_states_checkpoints_notes_actions_actions_diffs_initialize_Session_struct_save_metadata
- [ ] id=session.save lane=2 deps=session.create payload=@file:internal/session/manager.go#implement_Save_Update_timestamp_save_metadata_flow_code_recurrence_relations_generate_restore_script
- [ ] id=session.meta lane=2 deps=session.save payload=@file:internal/session/manager.go#implement_saveMetadata_Write_meta_json_with_full_Session_struct
- [ ] id=session.flow lane=2 deps=session.save payload=@file:internal/session/manager.go#implement_saveFlowCode_Write_flow_code_file_S1P123S2P12
- [ ] id=session.recur lane=2 deps=session.save,types.recurrence payload=@file:internal/session/manager.go#implement_saveRecurrence_Build_StateRelation_array_write_states_recurrence_json
- [ ] id=session.restore_script lane=2 deps=session.save payload=@file:internal/session/manager.go#implement_generateRestoreScript_Create_restore_sh_bash_script_with_usage_list_states_restore_state_compute_files_hash_apply_diffs_to_target_find_path_jq
- [ ] id=session.add_state lane=2 deps=session.manager payload=@file:internal/session/manager.go#implement_AddState_Create_state_with_ID_SSSS_SsPp_compute_files_hash_link_prev_next_states_update_flow_code_append_S_on_schedule_change_always_append_P_save_state_file
- [ ] id=session.freeze lane=2 deps=session.add_state payload=@file:internal/session/manager.go#implement_FreezeState_Mark_error_in_flow_code_append_X_save_immediately
- [ ] id=session.hash lane=2 deps=session.add_state payload=@file:internal/session/manager.go#implement_computeFilesHash_SHA256_of_tracked_files_git_tracked_or_project_files
- [ ] id=session.gen_id lane=2 deps=session.create payload=@file:internal/session/manager.go#implement_generateSessionID_Unix_nanosecond_timestamp

### 7.2 Session Notes (ORCH §12.2)
- [ ] id=notes.manager lane=2 payload=@file:internal/session/notes.go#implement_NotesManager_Struct_baseDir_sessionID_~200_LOC
- [ ] id=notes.dest lane=2 deps=notes.manager payload=@file:internal/session/notes.go#implement_NoteDestination_Enum_orchestrator_agent_human
- [ ] id=notes.add lane=2 deps=notes.manager payload=@file:internal/session/notes.go#implement_Add_Generate_note_ID_load_existing_notes_append_new_note_save
- [ ] id=notes.load lane=2 deps=notes.manager payload=@file:internal/session/notes.go#implement_Load_Read_notes_orchestrator_agent_human_md_parse_JSON_array
- [ ] id=notes.unreviewed lane=2 deps=notes.load payload=@file:internal/session/notes.go#implement_GetUnreviewed_Filter_notes_with_Reviewed_false
- [ ] id=notes.mark lane=2 deps=notes.unreviewed payload=@file:internal/session/notes.go#implement_MarkReviewed_Set_Reviewed_true_for_given_note_IDs_save
- [ ] id=notes.save lane=2 deps=notes.add payload=@file:internal/session/notes.go#implement_save_Write_JSON_array_to_notes_file
- [ ] id=notes.gen_id lane=2 deps=notes.add payload=@file:internal/session/notes.go#implement_generateNoteID_N_Unix_nanosecond_timestamp

### 7.3 Session Portability (PLAN §4)
- [ ] id=usf.serial lane=2 deps=session.manager payload=@file:internal/session/usf.go#implement_USF_Serialization_USFSession_struct_with_Version_SessionID_CreatedAt_Platform_Task_Workspace_OrchestrationState_History_FilesModified_Checkpoints_Stats_~350_LOC
- [ ] id=usf.export lane=2 deps=usf.serial payload=@file:internal/session/usf.go#implement_ExportUSF_Convert_internal_session_to_USF_JSON_format
- [ ] id=usf.import lane=2 deps=usf.serial payload=@file:internal/session/usf.go#implement_ImportUSF_Convert_USF_JSON_to_internal_session_preserve_bash_restoration_scripts_for_backward_compat
- [ ] id=usf.convert lane=2 deps=usf.export,usf.import payload=@file:internal/session/converter.go#implement_session_format_converter_helpers_~200_LOC
- [ ] id=session.cmd lane=2 deps=usf.import,usf.export payload=@file:internal/cli/session_cmd.go#implement_Session_Commands_obot_session_save_load_list_export_import_~300_LOC
- [ ] id=checkpoint.sys lane=2 deps=session.manager payload=@file:internal/cli/checkpoint.go#implement_Checkpoint_System_Save_restore_code_state_at_arbitrary_points_~250_LOC

## SECTION 8: GIT INTEGRATION

### 8.1 Git Manager (ORCH §13.1)
- [ ] id=git.manager lane=2 payload=@file:internal/git/manager.go#implement_Manager_Struct_workDir_github_GitHubClient_gitlab_GitLabClient_config_GitHub_GitLab_enabled_tokens_auto_push_commit_signing_~500_LOC
- [ ] id=git.init lane=2 deps=git.manager payload=@file:internal/git/manager.go#implement_Init_git_init
- [ ] id=git.create_repo lane=2 deps=git.manager payload=@file:internal/git/manager.go#implement_CreateRepository_GitHub_CreateRepository_add_remote_github_GitLab_CreateRepository_add_remote_gitlab
- [ ] id=git.commit lane=2 deps=git.manager payload=@file:internal/git/manager.go#implement_CommitSession_git_add_dot_build_commit_message_git_commit_m_with_S_if_signing_enabled
- [ ] id=git.msg lane=2 deps=git.commit payload=@file:internal/git/manager.go#implement_buildCommitMessage_Format_obot_summary_Session_id_Flow_code_Schedules_count_Processes_count_Changes_Created_files_dirs_Edited_files_Deleted_files_dirs_Human_Prompts_Initial_truncated_Clarifications_count_Feedback_count_Signed_off_by_obot_at_local
- [ ] id=git.push lane=2 deps=git.commit payload=@file:internal/git/manager.go#implement_PushAll_Iterate_remotes_git_push_u_remote_main_log_failures_but_continue
- [ ] id=git.summary lane=2 deps=git.msg payload=@file:internal/git/manager.go#implement_summarizeChanges_created_created_edited_edited_deleted_deleted
- [ ] id=git.run lane=2 deps=git.manager payload=@file:internal/git/manager.go#implement_run_exec_Command_git_args
- [ ] id=git.remotes lane=2 deps=git.run payload=@file:internal/git/manager.go#implement_getRemotes_git_remote_parse_lines

### 8.2 GitHub Client (ORCH §13.2)
- [ ] id=github.client lane=2 payload=@file:internal/git/github.go#implement_GitHubClient_Struct_token_from_file_baseURL_api_github_com_http_Client_~200_LOC
- [ ] id=github.new lane=2 deps=github.client payload=@file:internal/git/github.go#implement_NewGitHubClient_Read_token_from_expandPath_tokenPath
- [ ] id=github.create lane=2 deps=github.client payload=@file:internal/git/github.go#implement_CreateRepository_POST_user_repos_with_name_private_false_auto_init_false_description_Created_by_obot_orchestration
- [ ] id=github.future lane=2 deps=github.client payload=@doc:Future_methods_CreatePullRequest_CreateIssue_ListBranches_CreateRelease_follow_same_pattern

### 8.3 GitLab Client (ORCH §13.3)
- [ ] id=gitlab.client lane=2 payload=@file:internal/git/gitlab.go#implement_GitLabClient_Struct_token_from_file_baseURL_gitlab_com_api_v4_http_Client_~200_LOC
- [ ] id=gitlab.new lane=2 deps=gitlab.client payload=@file:internal/git/gitlab.go#implement_NewGitLabClient_Read_token_from_expandPath_tokenPath
- [ ] id=gitlab.create lane=2 deps=gitlab.client payload=@file:internal/git/gitlab.go#implement_CreateRepository_POST_projects_with_name_visibility_public_description_Created_by_obot_orchestration
- [ ] id=gitlab.future lane=2 deps=gitlab.client payload=@doc:Future_methods_CreateMergeRequest_CreateIssue_ListBranches_CreateRelease

## SECTION 9: RESOURCE MANAGEMENT

### 9.1 Resource Monitor (ORCH §14)
- [ ] id=resource.monitor lane=2 payload=@file:internal/resource/monitor.go#implement_Monitor_Struct_memCurrent_memPeak_memTotal_diskWritten_diskDeleted_tokensUsed_startTime_limits_memLimit_diskLimit_tokenLimit_timeout_warnings_~600_LOC
- [ ] id=resource.new lane=2 deps=resource.monitor payload=@file:internal/resource/monitor.go#implement_NewMonitor_Initialize_with_optional_limits_from_Config
- [ ] id=resource.start lane=2 deps=resource.monitor payload=@file:internal/resource/monitor.go#implement_Start_Launch_monitorLoop_goroutine
- [ ] id=resource.loop lane=2 deps=resource.start payload=@file:internal/resource/monitor.go#implement_monitorLoop_500ms_ticker_call_sample
- [ ] id=resource.sample lane=2 deps=resource.loop payload=@file:internal/resource/monitor.go#implement_sample_ReadMemStats_update_current_peak_append_to_history_checkLimits
- [ ] id=resource.check lane=2 deps=resource.sample payload=@file:internal/resource/monitor.go#implement_checkLimits_Memory_ratio_greater_80_percent_append_warning
- [ ] id=resource.record lane=2 deps=resource.monitor payload=@file:internal/resource/monitor.go#implement_RecordDiskWrite_Delete_Tokens_Thread_safe_counters
- [ ] id=resource.check_mem lane=2 deps=resource.check payload=@file:internal/resource/monitor.go#implement_CheckMemoryLimit_Return_LimitExceededError_if_current_greater_limit
- [ ] id=resource.check_token lane=2 deps=resource.check payload=@file:internal/resource/monitor.go#implement_CheckTokenLimit_Return_LimitExceededError_if_tokens_greater_limit
- [ ] id=resource.summary lane=2 deps=resource.monitor payload=@file:internal/resource/monitor.go#implement_GetSummary_Return_ResourceSummary_with_Memory_Disk_Tokens_Time_summaries
- [ ] id=resource.err lane=2 deps=resource.check_mem payload=@file:internal/resource/monitor.go#implement_LimitExceededError_Resource_Limit_Current
- [ ] id=resource.sum_struct lane=2 deps=resource.summary payload=@file:internal/resource/monitor.go#implement_ResourceSummary_MemorySummary_Peak_Current_Total_Limit_Warnings_DiskSummary_Written_Deleted_Net_Limit_TokenSummary_Used_Limit_TimeSummary_Elapsed_Timeout

## SECTION 10: PROMPT SUMMARY & LLM-AS-JUDGE

### 10.1 Summary Generator (ORCH §16)
- [ ] id=summary.gen lane=2 deps=session.manager payload=@file:internal/summary/generator.go#implement_Generator_Struct_session_~500_LOC
- [ ] id=summary.generate lane=2 deps=summary.gen payload=@file:internal/summary/generator.go#implement_Generate_Build_complete_summary_header_flow_code_schedule_summary_process_summary_action_breakdown_resources_tokens_generation_flow_TLDR_placeholder
- [ ] id=summary.flow lane=2 deps=summary.generate payload=@file:internal/summary/generator.go#implement_formatFlowCode_S_in_white_P_in_blue_X_in_red
- [ ] id=summary.schedule lane=2 deps=summary.generate payload=@file:internal/summary/generator.go#implement_generateScheduleSummary_Total_schedulings_per_schedule_counts_with_percentages
- [ ] id=summary.process lane=2 deps=summary.generate payload=@file:internal/summary/generator.go#implement_generateProcessSummary_Total_processes_per_schedule_breakdown_per_process_counts_and_percentages_average_processes_per_scheduling
- [ ] id=summary.action lane=2 deps=summary.generate payload=@file:internal/summary/generator.go#implement_generateActionSummary_Files_dirs_created_deleted_commands_ran_files_edited
- [ ] id=summary.resource lane=2 deps=summary.generate,resource.summary payload=@file:internal/summary/generator.go#implement_generateResourceSummary_Memory_disk_token_stats
- [ ] id=summary.token lane=2 deps=summary.generate payload=@file:internal/summary/generator.go#implement_generateTokenSummary_Total_Inference_percent_Input_percent_Output_percent_Context_percent
- [ ] id=summary.gen_flow lane=2 deps=summary.generate payload=@file:internal/summary/generator.go#implement_generateGenerationFlow_Process_by_process_flow_with_token_recount
- [ ] id=summary.pct lane=2 deps=summary.generate payload=@file:internal/summary/generator.go#implement_pct_Helper_for_percentage_calculation
- [ ] id=summary.pad lane=2 deps=summary.generate payload=@file:internal/summary/generator.go#implement_padRight_Helper_for_text_padding

### 10.2 LLM-as-Judge (ORCH §17)
- [ ] id=judge.coord lane=2 deps=model.coord payload=@file:internal/judge/coordinator.go#implement_Coordinator_Struct_orchestratorModel_coderModel_researcherModel_visionModel_~700_LOC
- [ ] id=judge.analysis lane=2 deps=judge.coord payload=@file:internal/judge/coordinator.go#implement_Analysis_Struct_Experts_map_expert_name→ExpertAnalysis_Synthesis_SynthesisAnalysis_Failures_unresponsive_experts
- [ ] id=judge.expert lane=2 deps=judge.analysis payload=@file:internal/judge/coordinator.go#implement_ExpertAnalysis_Expert_PromptAdherence_0_100_ProjectQuality_0_100_ActionsCount_ErrorsCount_Observations_Recommendations
- [ ] id=judge.synthesis lane=2 deps=judge.analysis payload=@file:internal/judge/coordinator.go#implement_SynthesisAnalysis_PromptGoal_Implementation_ExpertConsensus_scores_Discoveries_Issues_IssueResolution_QualityAssessment_ACCEPTABLE_NEEDS_IMPROVEMENT_EXCEPTIONAL_Justification_Recommendations
- [ ] id=judge.analyze lane=2 deps=judge.coord payload=@file:internal/judge/coordinator.go#implement_Analyze_Get_expert_analyses_Coder_Researcher_Vision_with_retry_1x_orchestrator_synthesis
- [ ] id=judge.get_expert lane=2 deps=judge.analyze payload=@file:internal/judge/coordinator.go#implement_getExpertAnalysis_Prompt_Analyze_session_from_expert_perspective_Provide_PROMPT_ADHERENCE_PROJECT_QUALITY_ACTIONS_ERRORS_OBSERVATIONS_3_RECOMMENDATIONS_2_Parse_structured_response
- [ ] id=judge.synthesize lane=2 deps=judge.analyze payload=@file:internal/judge/coordinator.go#implement_synthesize_Orchestrator_prompt_Create_TLDR_synthesis_PROMPT_GOAL_IMPLEMENTATION_EXPERT_CONSENSUS_DISCOVERIES_2_3_ISSUES_QUALITY_ASSESSMENT_JUSTIFICATION_RECOMMENDATIONS_3_Parse_structured_response
- [ ] id=judge.parse_expert lane=2 deps=judge.get_expert payload=@file:internal/judge/coordinator.go#implement_parseExpertAnalysis_Parse_PROMPT_ADHERENCE_score_etc
- [ ] id=judge.parse_synth lane=2 deps=judge.synthesize payload=@file:internal/judge/coordinator.go#implement_parseSynthesis_Parse_synthesis_fields
- [ ] id=judge.render lane=2 deps=judge.analysis payload=@file:internal/judge/coordinator.go#implement_RenderTLDR_Format_final_TLDR_with_box_formatting_PROMPT_GOAL_IMPLEMENTATION_SUMMARY_EXPERT_CONSENSUS_DISCOVERIES_LEARNINGS_QUALITY_ASSESSMENT_with_justification_ACTIONABLE_RECOMMENDATIONS

## SECTION 11: TESTING (PLAN §11)

### 11.1 Test Categories (ORCH §18)
- [ ] id=test.unit lane=3 payload=@doc:Unit_Tests_Individual_component_tests
- [ ] id=test.integration lane=3 payload=@doc:Integration_Tests_Component_interaction_tests
- [ ] id=test.golden lane=3 payload=@doc:Golden_Tests_Prompt_and_output_snapshot_tests
- [ ] id=test.navigation lane=3 deps=nav.validator payload=@cmd:go test ./internal/orchestrate/... -run TestNavigationRules
- [ ] id=test.suspension lane=3 deps=suspend.handler payload=@doc:Suspension_Tests_Error_handling_and_recovery_tests
- [ ] id=test.session lane=3 deps=session.manager payload=@doc:Session_Tests_Persistence_and_restoration_tests
- [ ] id=test.schema lane=3 deps=usf.serial payload=@doc:Schema_Compliance_Tests_Validate_USF_UCP_UOP_outputs_conform_to_JSON_schemas
- [ ] id=test.cross_platform lane=3 deps=usf.import,usf.export payload=@doc:Cross_Platform_Session_Tests_Create_session_in_CLI→Load_in_IDE_no_data_loss_Create_in_IDE→Resume_in_CLI_no_data_loss
- [ ] id=test.perf lane=3 payload=@doc:Performance_Benchmarks_Baseline_metrics_less_5_percent_regression_threshold_config_load_time_context_build_time_session_save_load_time

### 11.2 Test Coverage Targets (PLAN §11)
- [ ] id=test.cli_coverage lane=3 payload=@doc:CLI_Test_Coverage_Agent_execution_90_percent_Tools_85_percent_Context_80_percent_Orchestration_80_percent_Fixer_85_percent_Sessions_75_percent
- [ ] id=test.ide_coverage lane=3 payload=@doc:IDE_Test_Coverage_Agent_execution_90_percent_Tools_85_percent_Context_80_percent_Orchestration_80_percent_Sessions_75_percent_UI_60_percent

### 11.3 Navigation Rule Tests (ORCH §18.2)
- [ ] id=test.nav_matrix lane=3 deps=test.navigation payload=@cmd:go test ./internal/orchestrate/... -run TestNavigationRules -v

## SECTION 12: CONTEXT MANAGEMENT (PLAN §1)

### 12.1 Context Manager (PLAN §1 item 2)
- [ ] id=ctx.manager lane=2 payload=@file:internal/context/manager.go#implement_Context_Manager_Port_IDE_sophisticated_ContextManager_with_token_budgeting_System_15_percent_Files_35_percent_History_12_percent_Memory_12_percent_Errors_6_percent_~700_LOC
- [ ] id=ctx.tokens lane=2 deps=ctx.manager payload=@file:internal/context/tokens.go#implement_Token_Counting_Via_tiktoken_go_library_~150_LOC
- [ ] id=ctx.budget lane=2 deps=ctx.manager payload=@file:internal/context/budget.go#implement_Budget_Allocation_Per_UCP_schema_percentages_~300_LOC
- [ ] id=ctx.compress lane=2 deps=ctx.manager payload=@file:internal/context/compression.go#implement_Semantic_Compression_Preserve_imports_exports_~200_LOC
- [ ] id=ctx.cache lane=2 deps=ctx.manager payload=@file:internal/context/memory.go#implement_LRU_Cache_For_frequently_accessed_files_~200_LOC
- [ ] id=ctx.errors lane=2 deps=ctx.manager payload=@file:internal/context/errors.go#implement_Error_Pattern_Learning_Track_and_learn_from_error_patterns_~150_LOC

### 12.2 Agent Read Capability (PLAN §1 item 1)
- [ ] id=read.file lane=2 deps=tools.read payload=@file:internal/agent/tools_read.go#implement_ReadFile_os_ReadFile_wrapper
- [ ] id=read.search lane=2 deps=tools.read payload=@file:internal/agent/tools_read.go#implement_SearchFiles_ripgrep_wrapper_or_filepath_Walk
- [ ] id=read.list lane=2 deps=tools.read payload=@file:internal/agent/tools_read.go#implement_ListDirectory_os_ReadDir_wrapper
- [ ] id=read.exists lane=2 deps=tools.read payload=@file:internal/agent/tools_read.go#implement_FileExists_os_Stat_check

## SECTION 13: CONFIG & MIGRATION (PLAN §1 & §7)

### 13.1 Config Migration to YAML (PLAN §1 item 4)
- [ ] id=cfg.migrate lane=2 payload=@file:internal/config/migrate.go#implement_YAML_Config_Current_config_obot_config_json_Target_config_ollamabot_config_yaml_with_backward_compat_symlink_Auto_migration_on_first_run_with_backup_of_old_config_Dependency_gopkg_in_yaml_v3_~250_LOC
- [ ] id=cfg.rewrite lane=2 deps=cfg.migrate payload=@file:internal/config/config.go#rewrite_complete_Config_struct_for_YAML_format

### 13.2 Unified Config Integration (PLAN §7)
- [ ] id=cfg.cli_service lane=2 deps=cfg.migrate payload=@file:internal/config/unified.go#enhance_CLI_Config_Service_YAML_parsing_validation_against_UC_schema_backward_compat_migration_already_has_partial_implementation_~300_LOC
- [ ] id=cfg.ide_service lane=2 payload=@file:Sources/Services/SharedConfigService.swift#implement_IDE_Config_Service_Swift_YAML_parser_Yams_dependency_merge_with_ConfigurationService_swift_keep_UserDefaults_for_IDE_specific_UI_prefs_only_~300_LOC
- [ ] id=cfg.tools lane=2 deps=cfg.cli_service,cfg.ide_service payload=@doc:Config_Migration_Tools_CLI_obot_config_migrate_IDE_auto_migration_on_first_launch_backups_before_migration

### 13.3 Package Consolidation (PLAN §1 item 3)
- [ ] id=pkg.merge lane=2 payload=@doc:Package_Merges_actions_agent_analyzer_oberror_recorder→agent_config_tier_model→config_context_summary→context_fixer_review_quality→fixer_session_stats→session_ui_display_memory_ansi→ui_Estimated_800_LOC_refactoring_60_plus_import_path_updates

## SECTION 14: IDE ORCHESTRATION (PLAN §5)

### 14.1 OrchestrationService (PLAN §5 item 1)
- [ ] id=ide.orch_service lane=2 payload=@file:Sources/Services/OrchestrationService.swift#implement_OrchestrationService_Native_Swift_implementation_of_UOP_state_machine_5_schedules_Knowledge_Plan_Implement_Scale_Production_3_processes_per_schedule_Navigation_P1↔P2↔P3_within_schedule_any_P3→any_P1_between_schedules_Flow_code_generation_S1P123S2P12_Human_consultation_with_timeout_~700_LOC
- [ ] id=ide.schedule_enum lane=2 deps=ide.orch_service payload=@file:Sources/Services/OrchestrationService.swift#implement_Schedule_Enum_knowledge_plan_implement_scale_production
- [ ] id=ide.process_enum lane=2 deps=ide.orch_service payload=@file:Sources/Services/OrchestrationService.swift#implement_Process_Enum_p1_p2_p3
- [ ] id=ide.navigate lane=2 deps=ide.orch_service payload=@file:Sources/Services/OrchestrationService.swift#implement_navigate_to_Enforce_P1↔P2↔P3_rule_throw_NavigationError_if_invalid
- [ ] id=ide.advance lane=2 deps=ide.orch_service payload=@file:Sources/Services/OrchestrationService.swift#implement_advanceSchedule_Require_currentProcess_equals_p3_advance_to_next_schedule_reset_to_p1
- [ ] id=ide.flow_code lane=2 deps=ide.orch_service payload=@file:Sources/Services/OrchestrationService.swift#implement_updateFlowCode_Generate_S1P123S2P12_format

### 14.2 Orchestration UI (PLAN §5 item 2)
- [ ] id=ide.orch_view lane=2 deps=ide.orch_service payload=@file:Sources/Views/OrchestrationView.swift#implement_OrchestrationView_Visual_schedule_timeline_Process_state_indicators_P1_P2_P3_Flow_code_display_Navigation_controls_~450_LOC
- [ ] id=ide.flow_view lane=2 deps=ide.flow_code payload=@file:Sources/Views/FlowCodeView.swift#implement_FlowCodeView_~150_LOC

### 14.3 AgentExecutor Refactoring (PLAN §5 item 3)
- [ ] id=ide.agent_exec lane=2 payload=@file:Sources/Services/AgentExecutor.swift#refactor_AgentExecutor_Coordination_only_~200_LOC_from_1069_lines
- [ ] id=ide.tool_exec lane=2 deps=ide.agent_exec payload=@file:Sources/Services/ToolExecutor.swift#implement_ToolExecutor_Tool_dispatch_~150_LOC
- [ ] id=ide.verify lane=2 deps=ide.agent_exec payload=@file:Sources/Services/VerificationEngine.swift#implement_VerificationEngine_Quality_checks_~100_LOC
- [ ] id=ide.delegate lane=2 deps=ide.agent_exec payload=@file:Sources/Services/DelegationHandler.swift#implement_DelegationHandler_Multi_model_routing_~150_LOC
- [ ] id=ide.error_recover lane=2 deps=ide.agent_exec payload=@file:Sources/Services/ErrorRecovery.swift#implement_ErrorRecovery_Error_handling_~100_LOC

## SECTION 15: IDE FEATURE PARITY (PLAN §6)

### 15.1 Quality Presets (PLAN §6 item 1)
- [ ] id=ide.preset_view lane=2 payload=@file:Sources/Views/QualityPresetView.swift#implement_QualityPresetView_~100_LOC
- [ ] id=ide.preset_service lane=2 payload=@file:Sources/Services/QualityPresetService.swift#implement_Quality_Presets_Fast_single_pass_no_verification_~30s_target_Balanced_plan→execute→review_LLM_verification_~180s_target_Thorough_plan→execute→review→revise_expert_judge_~600s_target_~200_LOC
- [ ] id=ide.preset_enum lane=2 deps=ide.preset_service payload=@file:Sources/Services/QualityPresetService.swift#implement_QualityPreset_Enum_fast_balanced_thorough
- [ ] id=ide.pipeline lane=2 deps=ide.preset_service payload=@file:Sources/Services/QualityPresetService.swift#implement_pipeline_Array_of_Stage_execute_or_plan_execute_review_or_plan_execute_review_revise
- [ ] id=ide.verify_level lane=2 deps=ide.preset_service payload=@file:Sources/Services/QualityPresetService.swift#implement_verificationLevel_none_or_llmReview_or_expertJudge

### 15.2 Cost Tracking (PLAN §6 item 2)
- [ ] id=ide.cost_service lane=2 payload=@file:Sources/Services/CostTrackingService.swift#implement_Cost_Tracking_Token_usage_per_session_savings_vs_Claude_GPT_4_cost_per_feature_~250_LOC
- [ ] id=ide.cost_view lane=2 deps=ide.cost_service payload=@file:Sources/Views/CostDashboardView.swift#implement_CostDashboardView_~300_LOC

### 15.3 Human Consultation Modal (PLAN §6 item 3)
- [ ] id=ide.consult_view lane=2 deps=consult.handler payload=@file:Sources/Views/ConsultationView.swift#implement_Consultation_Modal_60s_countdown_timer_AI_fallback_on_timeout_note_recording_~200_LOC

### 15.4 Dry-Run / Diff Preview (PLAN §6 item 4)
- [ ] id=ide.preview_service lane=2 payload=@file:Sources/Services/PreviewService.swift#implement_Diff_Preview_Show_proposed_file_changes_in_diff_view_before_applying_~300_LOC
- [ ] id=ide.preview_view lane=2 deps=ide.preview_service payload=@file:Sources/Views/PreviewView.swift#implement_PreviewView_~250_LOC

### 15.5 Line-Range Editing (PLAN §6 item 5)
- [ ] id=ide.line_range lane=2 deps=ide.agent_exec payload=@file:Sources/Services/AgentExecutor.swift#enhance_Line_Range_Editing_Targeted_edits_via_minus_start_plus_end_syntax

## SECTION 16: OBOTRULES & MENTIONS (PLAN §8)

### 16.1 OBotRules Parser (PLAN §8 item 1)
- [ ] id=obot.parser lane=2 payload=@file:internal/obotrules/parser.go#implement_OBotRules_Parser_Parse_obot_rules_obotrules_markdown_files_inject_rules_into_system_prompts_~300_LOC
- [ ] id=obot.struct lane=2 deps=obot.parser payload=@file:internal/obotrules/parser.go#implement_Rules_Struct_SystemRules_FileRules_map_GlobalRules
- [ ] id=obot.parse lane=2 deps=obot.parser payload=@file:internal/obotrules/parser.go#implement_ParseOBotRules_Optional_file_parse_markdown_sections_System_Rules→SystemRules_File_Specific_Rules→FileRules_Global_Rules→GlobalRules

### 16.2 @mention Parser (PLAN §8 item 2)
- [ ] id=mention.parser lane=2 payload=@file:internal/mention/parser.go#implement_mention_Parser_Mention_types_file_path_bot_name_context_id_codebase_selection_clipboard_recent_git_branch_url_address_package_name_~200_LOC
- [ ] id=mention.parse lane=2 deps=mention.parser payload=@file:internal/mention/parser.go#implement_ParseMentions_Regex_at_w_plus_colon_dot_plus_question_s_or_dollar_extract_type_and_value
- [ ] id=mention.resolve lane=2 deps=mention.parse payload=@file:internal/mention/parser.go#implement_ResolveMention_file→ReadFile_codebase→buildCodebaseContext_git→git_show_etc

### 16.3 IDE OBot System (PLAN §8 item 3)
- [ ] id=ide.obot_doc lane=1 payload=@doc:IDE_OBot_System_Sources_Services_OBotService_swift_handles_obotrules_bots_context_snippets_templates_Action_Document_existing_implementation_ensure_alignment_with_planned_CLI_implementation

## SECTION 17: MIGRATION PATH (ORCH §19)

### 17.1 Phase 1: Core Infrastructure (ORCH §19.1)
- [ ] id=phase1.dirs lane=1 payload=@doc:Phase_1_Core_Infrastructure_Create_internal_orchestrate_directory_structure_Implement_core_types_and_interfaces_Implement_orchestrator_state_machine_Implement_navigation_logic_with_validation
- [ ] id=phase1.milestone lane=1 deps=types.core,types.actions,types.session,orch.struct,nav.validator payload=@doc:Phase_1_Milestone_Core_types_orchestrator_state_machine_navigation_complete

### 17.2 Phase 2: Schedule and Process (ORCH §19.2)
- [ ] id=phase2.sched lane=1 payload=@doc:Phase_2_Schedule_and_Process_Implement_schedule_factory_Implement_all_15_processes_Integrate_model_coordination_Add_human_consultation_handling
- [ ] id=phase2.milestone lane=1 deps=sched.factory,sched.knowledge,sched.plan,sched.implement,sched.scale,sched.production,proc.interface,model.coord payload=@doc:Phase_2_Milestone_All_schedules_processes_model_coordination_consultation_complete

### 17.3 Phase 3: UI and Display (ORCH §19.3)
- [ ] id=phase3.ui lane=1 payload=@doc:Phase_3_UI_and_Display_Implement_ANSI_display_system_Implement_memory_visualization_Implement_terminal_UI_application_Add_input_handling
- [ ] id=phase3.milestone lane=1 deps=ui.display,ansi.constants,mem.viz,app.struct payload=@doc:Phase_3_Milestone_Full_terminal_UI_ANSI_display_memory_viz_input_handling_complete

### 17.4 Phase 4: Persistence and Git (ORCH §19.4)
- [ ] id=phase4.persist lane=1 payload=@doc:Phase_4_Persistence_and_Git_Implement_session_manager_Implement_recurrence_relations_Implement_restore_script_generation_Implement_GitHub_GitLab_integration
- [ ] id=phase4.milestone lane=1 deps=session.manager,session.recur,git.manager,github.client,gitlab.client payload=@doc:Phase_4_Milestone_Session_persistence_recurrence_git_integration_complete

### 17.5 Phase 5: Analysis and Summary (ORCH §19.5)
- [ ] id=phase5.analysis lane=1 payload=@doc:Phase_5_Analysis_and_Summary_Implement_resource_monitoring_Implement_prompt_summary_generation_Implement_LLM_as_judge_Implement_flow_code_generation
- [ ] id=phase5.milestone lane=1 deps=resource.monitor,summary.gen,judge.coord payload=@doc:Phase_5_Milestone_Resource_monitoring_summary_generation_LLM_judge_flow_code_complete

## SECTION 18: OPEN QUESTIONS (ORCH §20)

### 18.1 Implementation Questions (ORCH §20)
- [ ] id=q.model_load lane=1 payload=@doc:Model_Loading_How_to_handle_model_loading_unloading_to_manage_memory
- [ ] id=q.checkpoint_gran lane=1 payload=@doc:Checkpoint_Granularity_After_every_process_or_only_after_schedule_termination
- [ ] id=q.concurrent lane=1 payload=@doc:Concurrent_Operations_Allow_any_concurrent_operations_eg_background_indexing
- [ ] id=q.ext_tools lane=1 payload=@doc:External_Tool_Integration_How_to_integrate_linters_formatters_test_runners
- [ ] id=q.custom_sched lane=1 payload=@doc:Custom_Schedule_Definitions_Should_users_define_custom_schedules_processes
- [ ] id=q.distributed lane=1 payload=@doc:Distributed_Execution_Considerations_for_future_distributed_execution_across_machines
- [ ] id=q.telemetry lane=1 payload=@doc:Telemetry_Add_telemetry_for_usage_analytics_opt_in
- [ ] id=q.plugins lane=1 payload=@doc:Plugin_System_Hooks_for_plugins_extensions

## SECTION 19: DEFERRED FEATURES (PLAN §9 & §10)

### 19.1 Rust Core + FFI (PLAN §9)
- [ ] id=defer.rust lane=1 payload=@doc:Rust_Core_v2_0_Deferred_to_v2_0_due_to_timeline_risk_12_16_weeks_regression_risk_bottleneck_is_Ollama_inference_not_context_management_core_ollama_~800_LOC_core_models_~600_LOC_core_context_~900_LOC_core_orchestration_~700_LOC_core_tools_~500_LOC_core_session_~400_LOC_FFI_bindings_~1500_LOC_Estimated_12_weeks_2_developers

### 19.2 CLI-as-Server / JSON-RPC (PLAN §10)
- [ ] id=defer.rpc lane=1 payload=@doc:JSON_RPC_Server_v2_0_Deferred_to_v2_0_Blocker_Orchestrator_uses_Go_closure_injected_callbacks_not_serializable_request_response_interfaces_Requires_major_architectural_refactoring_Refactor_callbacks_into_serializable_RPC_methods_State_serialization_after_every_step_RPC_server_session_start_step_state_context_build_models_list_IDE_RPC_client_Estimated_6_weeks_2_developers_~2500_LOC

## SECTION 20: IMPLEMENTATION PRIORITY (PLAN)

### 20.1 Recommended Implementation Order (PLAN)
- [ ] id=prio.phase1 lane=1 payload=@doc:Phase_1_Foundation_Weeks_1_4_CLUSTER_7_Shared_Config_3_weeks_CLUSTER_4_Session_Portability_3_weeks_parallel_CLUSTER_1_CLI_Core_Refactoring_4_weeks_starts_Week_2
- [ ] id=prio.phase2 lane=1 payload=@doc:Phase_2_Core_Features_Weeks_5_9_CLUSTER_2_CLI_Tool_Parity_4_weeks_CLUSTER_3_Multi_Model_Coordination_3_weeks_parallel_CLUSTER_8_OBotRules_Mentions_3_weeks_parallel
- [ ] id=prio.phase3 lane=1 payload=@doc:Phase_3_Platform_Specific_Weeks_10_16_CLUSTER_5_IDE_Orchestration_6_weeks_CLUSTER_6_IDE_Feature_Parity_4_weeks_starts_Week_13
- [x] id=prio.phase4 lane=1 payload=@doc:Phase_4_Quality_Release_Weeks_17_23_CLUSTER_11_Testing_Infrastructure_6_weeks_CLUSTER_12_Documentation_Polish_5_weeks_parallel
- [ ] id=prio.phase5 lane=1 payload=@doc:Phase_5_v2_0_Post_March_CLUSTER_10_CLI_as_Server_6_weeks_CLUSTER_9_Rust_Core_12_weeks_optional

## SECTION 21: DOCUMENTATION (PLAN §12)

### 21.1 Protocol Specifications (PLAN §12 item 1)
- [ ] id=doc.uop lane=1 payload=@file:docs/protocols/UOP.md#write_Unified_Orchestration_Protocol_specification
- [ ] id=doc.utr lane=1 payload=@file:docs/protocols/UTR.md#write_Unified_Tool_Registry_specification
- [ ] id=doc.ucp lane=1 payload=@file:docs/protocols/UCP.md#write_Unified_Context_Protocol_specification
- [ ] id=doc.umc lane=1 payload=@file:docs/protocols/UMC.md#write_Unified_Model_Coordination_specification
- [ ] id=doc.uc lane=1 payload=@file:docs/protocols/UC.md#write_Unified_Configuration_specification
- [ ] id=doc.usf lane=1 payload=@file:docs/protocols/USF.md#write_Unified_Session_Format_specification

### 21.2 Migration Guides (PLAN §12 item 2)
- [ ] id=doc.mig_cli lane=1 payload=@file:docs/migration/CLI_CONFIG.md#write_CLI_migration_guide_old_JSON→new_YAML_config
- [ ] id=doc.mig_ide lane=1 payload=@file:docs/migration/IDE_CONFIG.md#write_IDE_migration_guide_UserDefaults→shared_config
- [ ] id=doc.mig_session lane=1 payload=@file:docs/migration/SESSIONS.md#write_Sessions_migration_guide_old_sessions→USF_format

### 21.3 User Documentation (PLAN §12 item 3)
- [x] id=doc.cli_readme lane=1 deps=tools.read,tools.delegate,tools.web,tools.git,tools.core payload=@file:README_CLI.md#update_CLI_README_with_new_commands_quality_presets_session_management
- [ ] id=doc.ide_help lane=1 deps=ide.orch_service,ide.preset_service payload=@doc:IDE_in_app_help_feature_guides_orchestration_explanation

### 21.4 Developer Documentation (PLAN §12 item 4)
- [ ] id=doc.contributing lane=1 payload=@file:docs/CONTRIBUTING.md#write_Contributing_guide
- [ ] id=doc.arch_diagrams lane=1 deps=arch.diagram payload=@file:docs/ARCHITECTURE.md#write_Architecture_diagrams
- [ ] id=doc.protocol_impl lane=1 deps=doc.uop,doc.utr,doc.ucp,doc.umc,doc.uc,doc.usf payload=@file:docs/PROTOCOL_IMPLEMENTATION.md#write_Protocol_implementation_guide

### 21.5 Release Prep (PLAN §12 item 5)
- [x] id=doc.changelog lane=1 payload=@file:CHANGELOG.md#write_Changelog
- [ ] id=doc.release_notes lane=1 deps=doc.changelog payload=@file:docs/RELEASE_NOTES.md#write_Release_notes
- [ ] id=doc.upgrade lane=1 deps=doc.mig_cli,doc.mig_ide,doc.mig_session payload=@file:docs/UPGRADE.md#write_Upgrade_instructions
- [ ] id=doc.known_issues lane=1 payload=@file:docs/KNOWN_ISSUES.md#write_Known_issues

## SECTION 22: ADVANCED CLI FEATURES (SCALING PLAN)

### 22.1 Repository Index System
- [ ] id=index.builder lane=2 payload=@file:internal/index/builder.go#implement_Index_Builder_Fast_file_index_on_demand_language_detection_file_statistics_build_time_less_10s_for_2k_files_~200_LOC
- [ ] id=index.search lane=2 deps=index.builder payload=@file:internal/index/search.go#implement_Symbol_Search_Search_for_functions_classes_types_across_project_~150_LOC
- [ ] id=index.semantic lane=2 deps=index.builder payload=@file:internal/index/embeddings.go#implement_Semantic_Search_Optional_embedding_based_semantic_search_requires_local_embedding_model_~100_LOC
- [ ] id=index.lang lane=2 deps=index.builder payload=@file:internal/index/language.go#implement_Language_Map_Per_language_file_counts_and_statistics_~50_LOC
- [ ] id=index.cmd_build lane=3 deps=index.builder payload=@cmd:go build -o bin/obot cmd/obot/main.go && ./bin/obot index build
- [ ] id=index.cmd_search lane=3 deps=index.search payload=@doc:Command_obot_search_query_Search_indexed_files
- [ ] id=index.cmd_symbols lane=3 deps=index.search payload=@doc:Command_obot_search_symbols_FunctionName_Symbol_search
- [ ] id=index.test_build lane=3 deps=index.builder payload=@cmd:go test ./internal/index/... -run TestIndexBuild
- [ ] id=index.test_search lane=3 deps=index.search payload=@cmd:go test ./internal/index/... -run TestSearchFindsMatches
- [ ] id=index.test_perf lane=3 deps=index.builder payload=@cmd:go test ./internal/index/... -bench BenchmarkIndexBuild -benchtime=10s
- [ ] id=index.test_integration lane=3 deps=index.search,agent.struct payload=@cmd:go test ./internal/integration/... -run TestSearchIntegration

### 22.2 Pre-Orchestration Planner
- [ ] id=planner.decompose lane=2 payload=@file:internal/planner/decompose.go#implement_Task_Decomposer_Break_complex_prompts_into_subtasks_before_orchestration_starts_~150_LOC
- [ ] id=planner.sequence lane=2 deps=planner.decompose payload=@file:internal/planner/sequence.go#implement_Change_Sequencer_Determine_optimal_order_for_multi_file_changes_~150_LOC
- [ ] id=planner.risk lane=2 deps=planner.decompose payload=@file:internal/planner/risk.go#implement_Risk_Labeler_Label_changes_as_safe_moderate_high_risk_~100_LOC
- [ ] id=planner.integration lane=2 deps=planner.decompose,planner.sequence,planner.risk,orch.runloop payload=@doc:Planner_Integration_Runs_BEFORE_orchestration_starts_pre_schedule_phase_Outputs_subtasks_list_execution_sequence_risk_labels_Feeds_into_Knowledge→Plan_schedules
- [ ] id=planner.test_decomp lane=3 deps=planner.decompose payload=@cmd:go test ./internal/planner/... -run TestTaskDecomposition
- [ ] id=planner.test_seq lane=3 deps=planner.sequence payload=@cmd:go test ./internal/planner/... -run TestSequencingHandlesDependencies
- [ ] id=planner.test_risk lane=3 deps=planner.risk payload=@cmd:go test ./internal/planner/... -run TestRiskLabelingAccurate
- [ ] id=planner.test_integration lane=3 deps=planner.integration payload=@cmd:go test ./internal/integration/... -run TestPlannerImprovesOrchestration

### 22.3 Patch Engine with Safety
- [ ] id=patch.apply lane=2 payload=@file:internal/patch/apply.go#implement_Atomic_Patch_Apply_Apply_patches_transactionally_all_or_nothing_~200_LOC
- [ ] id=patch.backup lane=2 deps=patch.apply payload=@file:internal/patch/backup.go#implement_Pre_Apply_Backup_Create_backup_before_any_patch_at_config_ollamabot_backups_timestamp_~150_LOC
- [ ] id=patch.rollback lane=2 deps=patch.backup payload=@file:internal/patch/rollback.go#implement_Rollback_on_Failure_Automatic_rollback_if_patch_fails_or_checksum_mismatch_~150_LOC
- [ ] id=patch.validate lane=2 deps=patch.apply payload=@file:internal/patch/validate.go#implement_Patch_Validation_Checksum_verification_conflict_detection_file_existence_checks_~100_LOC
- [ ] id=patch.flags lane=2 deps=patch.apply payload=@doc:Patch_Flags_dry_run_Show_changes_without_applying_no_backup_Skip_backup_creation_power_user_force_Apply_even_if_validation_warnings
- [ ] id=patch.test_atomic lane=3 deps=patch.apply payload=@cmd:go test ./internal/patch/... -run TestAtomicApplyWorks
- [ ] id=patch.test_backup lane=3 deps=patch.backup payload=@cmd:go test ./internal/patch/... -run TestBackupCreatedBeforeChanges
- [ ] id=patch.test_rollback lane=3 deps=patch.rollback payload=@cmd:go test ./internal/patch/... -run TestRollbackRestoresOriginal
- [ ] id=patch.test_validate lane=3 deps=patch.validate payload=@cmd:go test ./internal/patch/... -run TestValidationCatchesConflicts
- [ ] id=patch.test_integration lane=3 deps=patch.apply,patch.backup,patch.rollback,patch.validate payload=@cmd:go test ./internal/integration/... -run TestFullPatchWorkflow

### 22.4 Interactive TUI Mode
- [ ] id=tui.chat lane=2 payload=@file:internal/cli/interactive.go#implement_Interactive_Chat_Mode_Chat_style_interface_with_history_distinct_from_orchestrate_mode_~300_LOC
- [ ] id=tui.preview lane=2 deps=tui.chat payload=@file:internal/ui/preview.go#implement_Diff_Preview_Widget_Show_diffs_before_applying_with_syntax_highlighting_~150_LOC
- [ ] id=tui.shortcuts lane=2 deps=tui.chat payload=@file:internal/ui/chat.go#implement_Quick_Apply_Discard_Keyboard_shortcuts_a_apply_d_discard_u_undo_~200_LOC
- [ ] id=tui.history lane=2 deps=tui.chat payload=@file:internal/ui/history.go#implement_Command_History_Navigate_previous_commands_and_edits_with_up_down_arrow_~150_LOC
- [ ] id=tui.resume lane=2 deps=tui.history payload=@doc:Session_Resume_Resume_from_any_point_in_history
- [ ] id=tui.cmd lane=3 deps=tui.chat payload=@doc:Command_obot_interactive_or_obot_i_Start_interactive_mode
- [ ] id=tui.internal_cmds lane=3 deps=tui.chat,tui.shortcuts,tui.history payload=@doc:Within_TUI_slash_apply_slash_discard_slash_history_slash_undo_slash_exit
- [ ] id=tui.test_ui lane=3 deps=tui.chat payload=@cmd:go test ./internal/ui/... -run TestChatInterfaceResponsive
- [ ] id=tui.test_preview lane=3 deps=tui.preview payload=@cmd:go test ./internal/ui/... -run TestDiffPreviewDisplaysCorrectly
- [ ] id=tui.test_history lane=3 deps=tui.history payload=@cmd:go test ./internal/ui/... -run TestHistoryNavigationWorks
- [ ] id=tui.test_workflow lane=3 deps=tui.shortcuts payload=@cmd:go test ./internal/integration/... -run TestApplyDiscardWorkflow

### 22.5 Project Health Scanner
- [ ] id=scan.health lane=2 payload=@file:internal/scan/health.go#implement_Health_Scanner_Scan_repo_for_issues_unused_imports_TODO_comments_test_coverage_gaps_security_issues_deprecated_APIs_~150_LOC
- [ ] id=scan.prioritize lane=2 deps=scan.health payload=@file:internal/scan/issues.go#implement_Issue_Prioritizer_Rank_issues_by_severity_critical_high_medium_low_and_estimated_fix_cost_~150_LOC
- [ ] id=scan.suggest lane=2 deps=scan.prioritize payload=@file:internal/scan/suggest.go#implement_Fix_Suggester_Generate_fix_suggestions_for_detected_issues_with_confidence_scores_~100_LOC
- [ ] id=scan.cmd lane=3 deps=scan.health payload=@doc:Command_obot_scan_Run_health_scan_on_current_project
- [ ] id=scan.cmd_report lane=3 deps=scan.health payload=@doc:Command_obot_scan_report_health_html_Generate_visual_report
- [ ] id=scan.cmd_fix lane=3 deps=scan.suggest payload=@doc:Command_obot_fix_from_scan_Fix_issues_from_scan_in_priority_order
- [ ] id=scan.test_detect lane=3 deps=scan.health payload=@cmd:go test ./internal/scan/... -run TestScannerDetectsKnownIssues
- [ ] id=scan.test_priority lane=3 deps=scan.prioritize payload=@cmd:go test ./internal/scan/... -run TestPrioritizationRanksCorrectly
- [ ] id=scan.test_suggest lane=3 deps=scan.suggest payload=@cmd:go test ./internal/scan/... -run TestSuggestionsAreValid
- [ ] id=scan.test_workflow lane=3 deps=scan.suggest payload=@cmd:go test ./internal/integration/... -run TestScanFixWorkflow

### 22.6 Unified Telemetry System
- [ ] id=telemetry.service lane=2 deps=resource.monitor payload=@file:internal/telemetry/service.go#implement_Unified_Telemetry_Service_Cross_platform_stats_collection_CLI_IDE_local_only_storage_Merges_items_164_175_resource_monitor_and_242_cost_tracking_~150_LOC
- [ ] id=telemetry.savings lane=2 deps=telemetry.service payload=@file:internal/telemetry/savings.go#implement_Cost_Savings_Calculator_Compare_Ollama_vs_commercial_API_costs_GPT_4_Claude_Gemini_~100_LOC
- [ ] id=telemetry.metrics lane=2 deps=telemetry.service payload=@file:internal/telemetry/metrics.go#implement_Performance_Metrics_Track_median_time_to_fix_first_token_latency_patch_success_rate_user_acceptance_rate_~50_LOC
- [ ] id=telemetry.storage lane=2 deps=telemetry.service payload=@doc:Local_Only_Storage_All_telemetry_stored_at_config_ollamabot_telemetry_stats_json_no_external_reporting
- [ ] id=telemetry.cmd_stats lane=3 deps=telemetry.service payload=@doc:Command_obot_stats_Show_telemetry_summary_replaces_resource_summary
- [ ] id=telemetry.cmd_savings lane=3 deps=telemetry.savings payload=@doc:Command_obot_stats_savings_Show_cost_savings_vs_commercial_APIs
- [ ] id=telemetry.cmd_reset lane=3 deps=telemetry.service payload=@doc:Command_obot_stats_reset_Reset_telemetry_data
- [ ] id=telemetry.test_accumulate lane=3 deps=telemetry.service payload=@cmd:go test ./internal/telemetry/... -run TestStatsAccumulateCorrectly
- [ ] id=telemetry.test_savings lane=3 deps=telemetry.savings payload=@cmd:go test ./internal/telemetry/... -run TestSavingsCalculatedAccurately
- [ ] id=telemetry.test_metrics lane=3 deps=telemetry.metrics payload=@cmd:go test ./internal/telemetry/... -run TestMetricsTrackedProperly
- [ ] id=telemetry.test_cross_platform lane=3 deps=telemetry.service payload=@cmd:go test ./internal/telemetry/... -run TestCrossPlatformCompatibility

## SECTION 23: ENHANCED CLI COMMANDS (SCALING PLAN)

### 23.1 Enhanced CLI Surface
- [ ] id=cli.line_range lane=2 payload=@file:internal/cli/fix.go#enhance_Line_Range_Syntax_obot_file_go_minus_start_plus_end_instruction_for_targeted_edits_~50_LOC_addition
- [ ] id=cli.scoped_fix lane=2 deps=cli.line_range payload=@file:internal/cli/fix.go#enhance_Scoped_Fix_obot_fix_path_scope_repo_dir_file_plan_apply_with_scope_control
- [ ] id=cli.review lane=2 payload=@file:internal/cli/review.go#implement_Review_Command_obot_review_path_diff_tests_runs_verification_without_execution_~50_LOC
- [ ] id=cli.search lane=2 deps=index.search payload=@file:internal/cli/search.go#implement_Search_Command_obot_search_query_files_symbols_uses_Repository_Index_from_item_278_~50_LOC
- [ ] id=cli.init lane=2 payload=@file:internal/cli/init.go#implement_Init_Command_obot_init_scaffolds_config_cache_paths_obotrules_template_~50_LOC
- [ ] id=cli.test_line_range lane=3 deps=cli.line_range payload=@cmd:go test ./internal/cli/... -run TestLineRangeParsingWorks
- [ ] id=cli.test_scope lane=3 deps=cli.scoped_fix payload=@cmd:go test ./internal/cli/... -run TestScopeFlagFiltersCorrectly
- [ ] id=cli.test_review lane=3 deps=cli.review payload=@cmd:go test ./internal/cli/... -run TestReviewRunsWithoutMutations
- [ ] id=cli.test_search lane=3 deps=cli.search payload=@cmd:go test ./internal/cli/... -run TestSearchIntegratesWithIndex
- [ ] id=cli.test_init lane=3 deps=cli.init payload=@cmd:go test ./internal/cli/... -run TestInitCreatesProperStructure

## SUMMARY STATISTICS

- [ ] id=stats.total_items lane=1 payload=@doc:Total_Items_307_unique_implementation_items
- [ ] id=stats.total_loc lane=1 payload=@doc:Total_Estimated_Code_36350_LOC_plus_20000_words_documentation
- [ ] id=stats.timeline lane=1 payload=@doc:Total_Timeline_25_weeks_for_v1_0_immediate_plus_18_weeks_v2_0_optional
- [ ] id=stats.immediate lane=1 payload=@doc:Immediate_Implementation_255_items_1_255_278_307_21950_LOC_25_weeks_4_6_developers
- [ ] id=stats.testing lane=1 payload=@doc:Testing_12_items_197_208_8000_LOC_6_weeks_2_developers
- [ ] id=stats.docs lane=1 payload=@doc:Documentation_5_items_273_277_20000_words_5_weeks_2_developers
- [ ] id=stats.deferred lane=1 payload=@doc:Deferred_to_v2_0_2_items_266_267_6400_LOC_18_weeks_2_developers
