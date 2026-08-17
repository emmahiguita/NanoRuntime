# Graph Report - flutter_app  (2026-08-15)

## Corpus Check
- 198 files · ~259,276 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 3916 nodes · 5457 edges · 173 communities (151 shown, 22 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 65 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `bbb8ee9b`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- vnc_screen.dart
- term_screen.dart
- terminal_core.dart
- vnc_client.dart
- nano_runtime_api.dart
- NativeRuntimeSupervisor
- ansi_terminal.dart
- settings_screen.dart
- design_tokens.dart
- DesktopSessionManager
- desktop_audit_screen.dart
- dashboard_screen.dart
- models_screen.dart
- chat_screen.dart
- real_fs_shell.dart
- boot_orchestrator.dart
- EngineSupervisor
- docker_manager.dart
- desktop_launch_screen.dart
- settings_provider.dart
- terminal_dependencies.dart
- DebInstaller
- AgentAccessibilityService
- nanoroot.c
- vnc_des.dart
- chat_models_screens_test.dart
- Auditoría Técnica Integral — Plataforma nanoMOBILE
- nanoshell_ffi.dart
- chat_provider.dart
- terminal_types.dart
- ExecBinChannelHandler
- pty_manager.dart
- shell_executor.dart
- models_notifier.dart
- InternalXvncBackend
- Informe — Visor VNC: animación de carga, handshake, tiempo de carga y compatibilidad
- runtime_engine.dart
- Auditoría integral — NanoAI Mobile (flutter_app)
- Auditoría Integral de Arquitectura y Compatibilidad — 2026-08-13
- pty_shell.dart
- StatelessWidget
- command_dispatcher.dart
- chat_models.dart
- model_storage_scan_test.dart
- terminal_types.dart
- Plan Maestro — Integración NanoAI alrededor de Android
- llm_engine_client.dart
- Sprints
- device_info.dart
- package_service.dart
- ansi_parser.dart
- command_executor.dart
- main.dart
- kali_manager.dart
- .extract
- live_animations.dart
- nano_screen_shell.dart
- terminalservices.dart
- local_model.dart
- nanoshell.c
- Java_dev_nanoai_mobile_NanoshellBridge_ptySpawn
- ModelStorageChannelHandler
- NanoshellBridge
- proc_fs.dart
- terminal_screen.dart
- Java_dev_nanoai_mobile_NanoshellBridge_workerSpawnDetached
- dashboard_provider.dart
- package:flutter/material.dart
- catalog_models.dart
- dart:async
- device_metrics.dart
- rootfs_manager.dart
- MainActivity
- app_router.dart
- nano_type.dart
- i_bin_executor.dart
- noar_panel.dart
- widget_test.dart
- State
- pty.c
- PtyChannelHandler
- libandroid-shmem.c
- models_state.dart
- cron_scheduler.dart
- dart:io
- model_downloader_test.dart
- scaffold_shell.dart
- terminal_audit_logger.dart
- proot_manager.dart
- pty_session_registry.c
- RuntimeHeartbeat
- bool get
- [1.0.0+1] — 2026-08-08
- package:flutter_test/flutter_test.dart
- AgentChannelHandler
- SecurePathPolicy
- DeviceMetricsProvider
- app_providers.dart
- expression_evaluator.dart
- .decompressToStream
- hud.py
- app_theme.dart
- Auditoría Delta — Sprint B6+ (tarde 2026-08-13)
- StateNotifier
- model_storage_repository.dart
- static const
- WorkerController
- .downloadToFile
- SingleTickerProviderStateMixin
- NavigationChannelHandler
- typedef
- GeneratedPluginRegistrant.java
- RuntimeChannelHandler
- gradlew
- proot_manager.dart
- rootfs_env.dart
- command_tagger.dart
- NanoColors
- nanoai
- ChannelHandlers.kt
- _ScanlinePainter
- NanoThemeExtension
- _ThinkingIndicatorState
- chat_screen.dart
- dashboard_screen.dart
- models_screen.dart
- settings_screen.dart
- noar_builtin_commands.dart
- terminal_screen.dart
- double?
- Exception
- File?
- int?
- List
- Map
- Set
- String?
- Global Constraints
- settingsProvider
- widget_agent_console_test.dart
- .readLimited
- dart:io
- Diseño: Funcionalidad faltante de orquestación (agente, degradación, RAM, honestidad)
- fixtures.dart
- @Deprecated
- AnsiTerminalView
- @pantalla
- Java_dev_nanoai_mobile_NanoshellBridge_workerSpawnDetached
- nano_selector.dart
- SettingsNotifier
- ansi_terminal_test.dart
- AnsiTerminalView
- ModelDownloader
- dart:async
- linux_distribution_registry.dart
- agent_tool_dispatcher_test.dart
- pdf_report_service.dart
- linux_init.dart
- chatProvider
- terminal_plugin.dart
- LocalModelRepository
- LinuxDistribution
- _ScanlinePainter
- NanoRuntimeApi
- .readLimited
- devops_plugin.dart
- security_utils.dart
- dart:typed_data
- ModelReasoningBlock
- AnsiTerminalView

## God Nodes (most connected - your core abstractions)
1. `DesktopSessionManager` - 44 edges
2. `ExecBinChannelHandler` - 25 edges
3. `AgentAccessibilityService` - 25 edges
4. `redirect_path()` - 21 edges
5. `DebInstaller` - 20 edges
6. `ModelStorageChannelHandler` - 20 edges
7. `EngineSupervisor` - 19 edges
8. `Auditoría integral — NanoAI Mobile (flutter_app)` - 19 edges
9. `Auditoría Integral de Arquitectura y Compatibilidad — 2026-08-13` - 19 edges
10. `Auditoría Técnica Integral — Plataforma nanoMOBILE` - 19 edges

## Surprising Connections (you probably didn't know these)
- `pty_spawn()` --references--> `PtySession`  [EXTRACTED]
  android/app/src/main/cpp/pty.c → lib/core/services/pty_shell.dart
- `Java_dev_nanoai_mobile_NanoshellBridge_ptyRead()` --calls--> `pty_read()`  [INFERRED]
  android/app/src/main/cpp/pty_jni.c → android/app/src/main/cpp/pty.c
- `Java_dev_nanoai_mobile_NanoshellBridge_ptyWrite()` --calls--> `pty_write()`  [INFERRED]
  android/app/src/main/cpp/pty_jni.c → android/app/src/main/cpp/pty.c
- `Java_dev_nanoai_mobile_NanoshellBridge_ptyResize()` --calls--> `pty_resize()`  [INFERRED]
  android/app/src/main/cpp/pty_jni.c → android/app/src/main/cpp/pty.c
- `pty_registry_close()` --calls--> `pty_close()`  [INFERRED]
  android/app/src/main/cpp/pty_session_registry.c → android/app/src/main/cpp/pty.c

## Import Cycles
- None detected.

## Communities (173 total, 22 thin omitted)

### Community 0 - "vnc_screen.dart"
Cohesion: 0.02
Nodes (115): FocusNode, _activeMask, altActive, _altSticky, angle, animation, _appTile, _barButton (+107 more)

### Community 1 - "term_screen.dart"
Cohesion: 0.02
Nodes (99): int? _fgRgb,, _alt, backspace, bg, bgRgb, _blankRow, blink, bold (+91 more)

### Community 2 - "terminal_core.dart"
Cohesion: 0.02
Nodes (88): ../../core/services/hardware_info_service.dart, ../../core/services/llm_engine_client.dart, ../../core/services/terminal_dependencies.dart, ../../core/theme/design_tokens.dart, cron_scheduler.dart, keyboard_mapper.dart, _after, _ansi (+80 more)

### Community 3 - "vnc_client.dart"
Cohesion: 0.03
Nodes (70): _applyCopyRect, _applyRawRect, _availableBytes, _colourEntriesLeft, connect, _decodingFrame, _desktopName, disconnect (+62 more)

### Community 4 - "nano_runtime_api.dart"
Cohesion: 0.03
Nodes (66): _, agent, agentDumpScreen, agentDumpSnapshot, agentGlobalAction, agentInputText, agentLaunchPackage, agentLongPressAt (+58 more)

### Community 5 - "NativeRuntimeSupervisor"
Cohesion: 0.06
Nodes (26): DeviceMetricsChannelHandler, MethodCall, MethodChannel, Intent, List, String, NanoshellWorkerService, Boolean (+18 more)

### Community 6 - "ansi_terminal.dart"
Cohesion: 0.03
Nodes (60): ansi_parser.dart, int rows,, AnsiMetrics, _base16, baseStyle, _blink, build, _buildPalette (+52 more)

### Community 7 - "settings_screen.dart"
Cohesion: 0.09
Nodes (22): double value, min,, _batteryModes, colors, createState, _DesktopSection, _DesktopSectionState, dispose, label (+14 more)

### Community 8 - "design_tokens.dart"
Cohesion: 0.03
Nodes (58): Color get, aiBubble, background, card, colors, copyWith, elevated, error (+50 more)

### Community 9 - "DesktopSessionManager"
Cohesion: 0.09
Nodes (18): DesktopController, Any, Boolean, Int, Long, Map, String, DesktopSessionManager (+10 more)

### Community 10 - "desktop_audit_screen.dart"
Cohesion: 0.05
Nodes (40): ../../../../core/services/package_service.dart, app, appId, apps, _AppsPanel, _AppTile, body, bodyWidget (+32 more)

### Community 11 - "dashboard_screen.dart"
Cohesion: 0.04
Nodes (52): EdgeInsetsGeometry?, accent, _ActionSpec, _animatedValue, background, batteryPercent, blue, blur (+44 more)

### Community 12 - "models_screen.dart"
Cohesion: 0.04
Nodes (59): modelsProvider, accent, active, allFilesGranted, barRadius, build, cardRadius, chipRadius (+51 more)

### Community 13 - "chat_screen.dart"
Cohesion: 0.04
Nodes (55): _attachFile, attachmentNames, attachments, _buildAiBody, _buildChatMarkdownStyleSheet, _controller, createState, didUpdateWidget (+47 more)

### Community 14 - "real_fs_shell.dart"
Cohesion: 0.04
Nodes (44): _basenameDirname, _binCache, _cat, _cd, _cp, cwd, _df, _diff (+36 more)

### Community 15 - "boot_orchestrator.dart"
Cohesion: 0.05
Nodes (41): alias, export, BootOrchestrator, _chmodExecutable, _deployDesktopEyeCandy, df, EDITOR, _ensureCompatibilityLinks (+33 more)

### Community 16 - "EngineSupervisor"
Cohesion: 0.11
Nodes (20): EngineChannelHandler, Any, Int, Map, MethodCall, MethodChannel, String, EngineHandle (+12 more)

### Community 17 - "docker_manager.dart"
Cohesion: 0.05
Nodes (41): _checkInit, cmd, config, _Container, _containers, _containersDir, created, dispose (+33 more)

### Community 18 - "desktop_launch_screen.dart"
Cohesion: 0.05
Nodes (42): _ActionGrid, _applyDesktopStatus, _BadgeItem, _busy, colors, createState, _desktopReady, _detail (+34 more)

### Community 19 - "settings_provider.dart"
Cohesion: 0.05
Nodes (43): bool madvise,, double temperature,, AgentAutomationMode, autonomous, batteryMode, copyWith, description, desktopMobileMode (+35 more)

### Community 20 - "terminal_dependencies.dart"
Cohesion: 0.05
Nodes (36): docker_manager.dart, DockerManager? get, IBinExecutor? get, kali_manager.dart, KaliManager? get, baseDir, _defaultDockerFactory, _defaultKaliFactory (+28 more)

### Community 21 - "DebInstaller"
Cohesion: 0.13
Nodes (16): Boolean, List, String, PackageInstallController, bytesToHex(), DebInstaller, Boolean, ByteArray (+8 more)

### Community 22 - "AgentAccessibilityService"
Cohesion: 0.14
Nodes (13): AccessibilityEvent, AccessibilityNodeInfo, AccessibilityService, AgentAccessibilityBridge, AgentAccessibilityService, Any, Boolean, Int (+5 more)

### Community 23 - "nanoroot.c"
Cohesion: 0.11
Nodes (33): access(), bind(), FILE, key_t, connect(), dbg_exec(), execl(), execvp() (+25 more)

### Community 24 - "vnc_des.dart"
Cohesion: 0.05
Nodes (36): b1, b2, blockInt, bytes, c, d, _desBlock, desEncryptBlock (+28 more)

### Community 25 - "chat_models_screens_test.dart"
Cohesion: 0.06
Nodes (34): _FakeEngineClient, IconButton, LLMEngineClient, LLMStreamToken, LinearProgressIndicator, package:nanoai/core/models/chat_models.dart, package:nanoai/core/services/runtime_engine.dart, package:nanoai/features/models/presentation/screens/models_screen.dart (+26 more)

### Community 26 - "Auditoría Técnica Integral — Plataforma nanoMOBILE"
Cohesion: 0.06
Nodes (33): 10. Auditoría de procesos, 11. Auditoría de memoria, 12. Auditoría de rendimiento, 13. Auditoría de logs, 14. Código duplicado y deuda técnica, 15. Funciones faltantes / incompletas (demostradas), 16. Matriz SOLID, 17. Plan de corrección por fases (+25 more)

### Community 27 - "nanoshell_ffi.dart"
Cohesion: 0.06
Nodes (32): allowed_binaries.dart, dart:ffi, DynamicLibrary, _Free, _LastError, _allocOutPtrs, _allowedBinaries, _collectAndFree (+24 more)

### Community 28 - "chat_provider.dart"
Cohesion: 0.03
Nodes (61): ../agent/agent_tool_dispatcher.dart, _activeConnections, addAttachment, approvePendingTool, _attachmentsBlock, _buildChatPrompt, _buildDeepSeekPrompt, _buildGemmaPrompt (+53 more)

### Community 29 - "terminal_types.dart"
Cohesion: 0.06
Nodes (32): aliases, CmdFn, cons, ContainerRegistry, containers, cwd, env, exitCode (+24 more)

### Community 30 - "ExecBinChannelHandler"
Cohesion: 0.29
Nodes (3): ExecBinChannelHandler, MethodCall, MethodChannel

### Community 31 - "pty_manager.dart"
Cohesion: 0.07
Nodes (26): ansi_terminal.dart, AnsiTerminal? get, _ansi, close, _closeActiveSession, _closeFuture, dispose, _disposed (+18 more)

### Community 32 - "shell_executor.dart"
Cohesion: 0.06
Nodes (31): dart:isolate, ../../features/terminal/terminal_types.dart, _assetBinDir, _baseDir, bash, bashStream, binDir, exec (+23 more)

### Community 33 - "models_notifier.dart"
Cohesion: 0.05
Nodes (43): _applyScan, cancelDownload, _CatalogReconciliation, detected, dispose, _downloader, _downloadingId, downloadModel (+35 more)

### Community 34 - "InternalXvncBackend"
Cohesion: 0.14
Nodes (13): InternalXvncBackend, Boolean, Int, java, Long, Map, Pair, String (+5 more)

### Community 35 - "Informe — Visor VNC: animación de carga, handshake, tiempo de carga y compatibilidad"
Cohesion: 0.07
Nodes (27): 10. Plan de corrección (solo descripción; nada aplicado), 11. Criterios de cierre, 1. Resumen ejecutivo, 2.1 Procesos reales en el dispositivo, 2.2 Logcat a tiempo real (tag `flutter`, PID 25253), 2.3 Captura directa del socket (cliente RFB mínimo, handshake correcto), 2. Evidencia en vivo, 3. Bug primario (P0, CONFIRMADO) — corrupción del buffer de recepción (+19 more)

### Community 36 - "runtime_engine.dart"
Cohesion: 0.07
Nodes (29): EnginePhase get, _api, _applyStateMap, _client, copyWith, dispose, EngineStatus, ensureReady (+21 more)

### Community 37 - "Auditoría integral — NanoAI Mobile (flutter_app)"
Cohesion: 0.07
Nodes (26): Arquitectura encontrada (real, no esperada), Auditoría de logs, Auditoría de memoria, Auditoría de procesos, Auditoría de rendimiento, Auditoría integral — NanoAI Mobile (flutter_app), Auditoría JNI/C++, Auditoría Linux/Android (+18 more)

### Community 38 - "Auditoría Integral de Arquitectura y Compatibilidad — 2026-08-13"
Cohesion: 0.07
Nodes (26): 10. Auditoría de procesos, 11. Auditoría de memoria, 12. Auditoría de rendimiento, 13. Auditoría de logs, 14. Código duplicado y deuda técnica, 15. Funciones faltantes/incompletas, 16. Matriz SOLID, 17. Plan de corrección por fases (+18 more)

### Community 39 - "pty_shell.dart"
Cohesion: 0.07
Nodes (26): close, _closed, _closeSync, _done, _id, _inFlight, isClosed, _lastAlive (+18 more)

### Community 40 - "StatelessWidget"
Cohesion: 0.06
Nodes (31): AdaptiveGrid, AdaptiveList, BreakpointBuilder, _Composer, _EmptyChat, _MessageActions, _MessageBubble, _StreamingBubble (+23 more)

### Community 41 - "command_dispatcher.dart"
Cohesion: 0.08
Nodes (23): ../../core/services/terminal_audit_logger.dart, i_bin_executor.dart, TerminalAuditLogger, buildRegistry, _built, _cmds, CommandDispatcher, ctx (+15 more)

### Community 42 - "chat_models.dart"
Cohesion: 0.06
Nodes (34): DateTime?, activeModel, activeModelPath, attachmentNames, attachments, availableModels, canSend, ChatAttachment (+26 more)

### Community 43 - "model_storage_scan_test.dart"
Cohesion: 0.05
Nodes (41): Completer, ModelDownloader, required FakeStorageRepository storage,
  List, allFilesGranted, BlockingDownloader, catalog, _catalogModel, container (+33 more)

### Community 44 - "terminal_types.dart"
Cohesion: 0.11
Nodes (15): ../../core/services/proc_fs.dart, registerInto, DashboardPlugin, register, NetworkPlugin, register, PkgPlugin, register (+7 more)

### Community 45 - "Plan Maestro — Integración NanoAI alrededor de Android"
Cohesion: 0.08
Nodes (24): 0. Estado del repositorio, 10. Mapa final, 11. Guardas permanentes, 12. Próximo paso autorizado, 1. Arquitectura verificada, 2. Matriz declarado / implementado / conectado / probado, 3. Desalineamientos confirmados, 4. Clasificación de componentes (+16 more)

### Community 46 - "llm_engine_client.dart"
Cohesion: 0.10
Nodes (19): Client, baseUrl, _client, content, dispose, generate, generateStream, hasModel (+11 more)

### Community 47 - "Sprints"
Cohesion: 0.08
Nodes (23): CH-1 — channel startDesktop: cast bool→Map (CONFIRMADO, fix HOY), Clasificación consolidada, Closure gates activos, CONFIRMED (lectura directa del código, sin ambigüedad), DISCARDED, HYPOTHESIS_TO_VALIDATE, INFORMATIONAL, Plan de sprints de corrección — auditoría integral 2026-08-12 (+15 more)

### Community 48 - "device_info.dart"
Cohesion: 0.08
Nodes (23): _archFromCpuInfo, cpuCores, cpuHardware, cpuTempC, DeviceInfo, gid, groups, hostname (+15 more)

### Community 49 - "package_service.dart"
Cohesion: 0.08
Nodes (24): apps, DesktopStatus, failed, fromMap, getDesktopStatus, graphicalExtras, installed, installGraphical (+16 more)

### Community 50 - "ansi_parser.dart"
Cohesion: 0.08
Nodes (23): AnsiParser, _at, consume, _csi, _csiState, _decMode, _dispatch, _esc (+15 more)

### Community 51 - "command_executor.dart"
Cohesion: 0.12
Nodes (17): adaptive_theme.dart, dart:ui, design_tokens.dart, glass_container.dart, _AdaptivePageTransitionBuilder, AppTheme, _base, dark (+9 more)

### Community 52 - "main.dart"
Cohesion: 0.14
Nodes (15): core/providers/app_providers.dart, core/router/app_router.dart, core/services/boot_orchestrator.dart, core/theme/adaptive_theme.dart, core/theme/app_theme.dart, core/theme/light_animations.dart, themeModeProvider, binding (+7 more)

### Community 53 - "kali_manager.dart"
Cohesion: 0.09
Nodes (21): auditGroups, auditTools, checkInstalled, coverageSummary, _distDir, _downloading, expectedSha256, install (+13 more)

### Community 54 - ".extract"
Cohesion: 0.27
Nodes (10): Boolean, ByteArray, Exception, File, Int, java, Long, String (+2 more)

### Community 55 - "live_animations.dart"
Cohesion: 0.08
Nodes (26): Animation, AnimationController, dart:math, active, AnimatedMessageEntry, borderRadius, build, child (+18 more)

### Community 56 - "nano_screen_shell.dart"
Cohesion: 0.12
Nodes (14): Color, build, color, _Glow, NanoAmbientBackground, size, bracketedPasteEnabled, build (+6 more)

### Community 57 - "terminalservices.dart"
Cohesion: 0.09
Nodes (21): ../../core/services/docker_manager.dart, ../../core/services/proot_manager.dart, ../../core/services/rootfs_manager.dart, DockerManager, RootfsManager, ShellExecutor, IBinExecutor, TerminalCtx (+13 more)

### Community 58 - "local_model.dart"
Cohesion: 0.05
Nodes (38): chat_models.dart, entryOf, file, fileOf, LmCatalogEntry, models, name, NeuralCatalog (+30 more)

### Community 59 - "nanoshell.c"
Cohesion: 0.08
Nodes (25): fixtures.dart, SelectorFormatException, package:nanoai/core/agent/actionability_engine.dart, package:nanoai/core/agent/agent_result.dart, package:nanoai/core/agent/nano_selector.dart, package:nanoai/core/agent/nano_snapshot.dart, package:nanoai/core/agent/selector_engine.dart, main (+17 more)

### Community 60 - "Java_dev_nanoai_mobile_NanoshellBridge_ptySpawn"
Cohesion: 0.18
Nodes (26): jclass, jint, jlong, JNICALL, JNIEnv, jobjectArray, jstring, Java_dev_nanoai_mobile_NanoshellBridge_ptyClose() (+18 more)

### Community 61 - "ModelStorageChannelHandler"
Cohesion: 0.16
Nodes (13): Any, Boolean, File, Int, Intent, List, Map, MethodCall (+5 more)

### Community 62 - "NanoshellBridge"
Cohesion: 0.19
Nodes (7): Array, Boolean, ByteArray, Int, Long, String, NanoshellBridge

### Community 63 - "proc_fs.dart"
Cohesion: 0.09
Nodes (21): command_dispatcher.dart, ../../core/services/pty_shell.dart, alive, audit, bashCwd, CmdExecCtx, cmds, CommandExecutor (+13 more)

### Community 64 - "terminal_screen.dart"
Cohesion: 0.10
Nodes (20): _active, _add, _close, _clr, color, _counter, createState, dispose (+12 more)

### Community 65 - "Java_dev_nanoai_mobile_NanoshellBridge_workerSpawnDetached"
Cohesion: 0.05
Nodes (38): bottom, bounds, capturedAt, centerX, centerY, checked, clickable, depth (+30 more)

### Community 66 - "dashboard_provider.dart"
Cohesion: 0.08
Nodes (24): double storageTotalGb, storageFreeGb,, int get, ChatState, ChatNotifier, cpuCores, DashboardNotifier, DashboardState, dispose (+16 more)

### Community 67 - "package:flutter/material.dart"
Cohesion: 0.09
Nodes (31): main, main, main, main, main, main, package:flutter/material.dart, package:flutter_riverpod/flutter_riverpod.dart (+23 more)

### Community 68 - "catalog_models.dart"
Cohesion: 0.11
Nodes (22): ConsumerWidget, dashboardProvider, rootfsProvider, build, ScaffoldShell, build, DashboardScreen, NanoHomeScreen (+14 more)

### Community 69 - "dart:async"
Cohesion: 0.17
Nodes (10): package:flutter/services.dart, package:nanoai/core/theme/app_theme.dart, package:nanoai/features/settings/presentation/widgets/agent_console_section.dart, channel, dump, dumpProvider, focusedAfterTap, main (+2 more)

### Community 70 - "device_metrics.dart"
Cohesion: 0.11
Nodes (17): double get, double ramAvailableMb, ramTotalMb, storageTotalGb,, batteryPct, cpuCores, cpuTempC, DeviceMetrics, DeviceMetricsData, fallback (+9 more)

### Community 71 - "rootfs_manager.dart"
Cohesion: 0.09
Nodes (22): bootstrapUrl, checkInstalled, _computeSha256, _doInstall, _downloading, _extractKotlin, _fetchExpectedSha256, _fetchHashFromGitHubApi (+14 more)

### Community 72 - "MainActivity"
Cohesion: 0.14
Nodes (9): Array, FlutterEngine, Int, Intent, MethodChannel, String, MainActivity, FlutterActivity (+1 more)

### Community 73 - "app_router.dart"
Cohesion: 0.12
Nodes (16): ../../features/chat/presentation/screens/chat_screen.dart, ../../features/dashboard/presentation/screens/dashboard_screen.dart, ../../features/desktop/presentation/screens/desktop_audit_screen.dart, ../../features/desktop/presentation/screens/desktop_launch_screen.dart, ../../features/desktop/presentation/screens/vnc_screen.dart, ../../features/linux/presentation/screens/mobile_linux_screen.dart, ../../features/models/presentation/screens/models_screen.dart, ../../features/settings/presentation/screens/settings_screen.dart (+8 more)

### Community 74 - "nano_type.dart"
Cohesion: 0.12
Nodes (16): body, caption, display, hero, label, large, medium, metric (+8 more)

### Community 75 - "i_bin_executor.dart"
Cohesion: 0.14
Nodes (13): baseDir, bash, binDir, execRootfs, execRootfsWorker, init, initialized, killAll (+5 more)

### Community 76 - "noar_panel.dart"
Cohesion: 0.14
Nodes (14): _activeTag, build, _copy, createState, dark, dispose, fg, library (+6 more)

### Community 77 - "widget_test.dart"
Cohesion: 0.07
Nodes (29): ambiguityGap, anchorMinScore, _applyNearBonus, centerRegion, centerRegionRatio, _classify, clickableMatch, descriptionExact (+21 more)

### Community 78 - "State"
Cohesion: 0.12
Nodes (29): GlassContainer, _GlassContainerState, AnimatedGlassContainer, _AnimatedGlassContainerState, AnimatedLightBackground, _AnimatedLightBackgroundState, GlassBlurIn, _GlassBlurInState (+21 more)

### Community 79 - "pty.c"
Cohesion: 0.08
Nodes (24): build, _busy, _candidates, colors, createState, dispose, _executor, _feedback (+16 more)

### Community 80 - "PtyChannelHandler"
Cohesion: 0.47
Nodes (3): MethodCall, MethodChannel, PtyChannelHandler

### Community 81 - "libandroid-shmem.c"
Cohesion: 0.26
Nodes (12): key_t, libandroid_shmat(), libandroid_shmctl(), libandroid_shmdt(), libandroid_shmget(), shm_fd_create(), shmat(), shmctl() (+4 more)

### Community 82 - "models_state.dart"
Cohesion: 0.09
Nodes (21): ModelsNotifier, activeDetected, allFilesGranted, copyWith, detected, loadingDetectedUri, models, ModelsState (+13 more)

### Community 83 - "cron_scheduler.dart"
Cohesion: 0.06
Nodes (32): _, Iterable, _aliases, all, allowed, builtin, _builtinDefs, _byName (+24 more)

### Community 84 - "dart:io"
Cohesion: 0.04
Nodes (56): AdaptiveAnimationValues, AdaptiveGlassContainer, AdaptiveGlassValues, AdaptiveSafeArea, AdaptiveSpacingValues, AdaptiveTheme, animate, appBarHeight (+48 more)

### Community 85 - "model_downloader_test.dart"
Cohesion: 0.17
Nodes (11): Directory, DownloadException, HttpServer, package:crypto/crypto.dart, package:nanoai/features/models/data/model_downloader.dart, baseUrl, main, payload (+3 more)

### Community 86 - "scaffold_shell.dart"
Cohesion: 0.10
Nodes (22): _appChip, _navChip, shell, _tabs, package:go_router/go_router.dart, package:nanoai/core/providers/chat_provider.dart, package:nanoai/core/providers/dashboard_provider.dart, package:nanoai/core/providers/kali_provider.dart (+14 more)

### Community 87 - "terminal_audit_logger.dart"
Cohesion: 0.17
Nodes (11): _enabled, event, nextTraceId, _rotateIfNeeded, _sanitize, _sanitizeValue, _seq, _shortStack (+3 more)

### Community 88 - "proot_manager.dart"
Cohesion: 0.06
Nodes (34): ../../../../core/linux/linux_distribution.dart, ../../../../core/linux/linux_distribution_registry.dart, core/linux/linux_init.dart, ../../../../core/providers/kali_provider.dart, LinuxDistributionRegistry, build, createState, initState (+26 more)

### Community 89 - "pty_session_registry.c"
Cohesion: 0.09
Nodes (22): actionability, AgentErrorCode, AgentExecutionResult, best, candidates, errorCode, failure, isResolved (+14 more)

### Community 90 - "RuntimeHeartbeat"
Cohesion: 0.44
Nodes (3): Boolean, File, RuntimeHeartbeat

### Community 91 - "bool get"
Cohesion: 0.18
Nodes (10): bool get, DetectedModel, DetectedModelFormat, format, magicOk, name, path, sizeBytes (+2 more)

### Community 92 - "[1.0.0+1] — 2026-08-08"
Cohesion: 0.20
Nodes (9): [1.0.0+1] — 2026-08-08, Architecture (SOLID), Build, Changelog, Fixed, Lifecycle, Performance, Security (+1 more)

### Community 93 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.07
Nodes (28): Future, package:nanoai/core/agent/agent_executor.dart, package:nanoai/core/agent/agent_tool_dispatcher.dart, package:nanoai/core/agent/tool_registry.dart, package:nanoai/core/services/nano_runtime_api.dart, ajustesFocused, channel, dispatcher (+20 more)

### Community 94 - "AgentChannelHandler"
Cohesion: 0.36
Nodes (5): AgentChannelHandler, Int, MethodCall, MethodChannel, dev

### Community 95 - "SecurePathPolicy"
Cohesion: 0.33
Nodes (4): Boolean, File, String, SecurePathPolicy

### Community 96 - "DeviceMetricsProvider"
Cohesion: 0.33
Nodes (5): DeviceMetricsProvider, Any, Double, Map, String

### Community 97 - "app_providers.dart"
Cohesion: 0.22
Nodes (8): chat_provider.dart, dashboard_provider.dart, ../../features/models/application/models_provider.dart, kali_provider.dart, ../models/catalog_models.dart, ../models/chat_models.dart, rootfs_provider.dart, settings_provider.dart

### Community 98 - "expression_evaluator.dart"
Cohesion: 0.06
Nodes (32): agent_executor.dart, AgentToolDispatcher, AgentToolProtocol, _back, _describeScreen, _executeTool, _executeWithTimeout, _executor (+24 more)

### Community 99 - ".decompressToStream"
Cohesion: 0.29
Nodes (6): ByteArray, Exception, Long, XzDecoder, XzException, OutputStream

### Community 101 - "app_theme.dart"
Cohesion: 0.06
Nodes (34): architecture, command, defaultShell, distributionId, expectedSha256, fromOsRelease, getInfo, homeUrl (+26 more)

### Community 102 - "Auditoría Delta — Sprint B6+ (tarde 2026-08-13)"
Cohesion: 0.25
Nodes (7): 1. Resumen ejecutivo, 2. Tabla maestra delta, 3. Qué está inyectado / interceptado (exacto), 4. Qué funciona (verificado en código por dominio), 5. Qué falta, 6. Plan de fases (delta), Auditoría Delta — Sprint B6+ (tarde 2026-08-13)

### Community 103 - "StateNotifier"
Cohesion: 0.04
Nodes (49): Axis, Curve, _animation, baseColor, _blur, _borderOpacity, bounce, build (+41 more)

### Community 104 - "model_storage_repository.dart"
Cohesion: 0.06
Nodes (35): BorderRadius?, BorderSide?, EdgeInsets?, actions, adaptive, animate, blurAmount, border (+27 more)

### Community 105 - "static const"
Cohesion: 0.06
Nodes (33): 10. **Manejo Inseguro de Variables de Entorno**, 1. **Ubuntu Distribution Placeholder**, 1. **Validación de SHA256 en Kali Manager**, 1. **Vulnerabilidad de Inyección de Comandos - Shell Executor**, 2. **AllowedBinaries Allowlist**, 2. **Descarga HTTP sin Validación SSL - Ubuntu Distribution**, 2. **Kali Distribution Dependencia Externa**, 3. **Audit Logging Completo** (+25 more)

### Community 106 - "WorkerController"
Cohesion: 0.29
Nodes (4): Boolean, List, String, WorkerController

### Community 107 - ".downloadToFile"
Cohesion: 0.29
Nodes (5): DownloadService, File, Int, Long, String

### Community 108 - "SingleTickerProviderStateMixin"
Cohesion: 0.10
Nodes (19): actionability_engine.dart, agent_result.dart, Duration get, _api, _engine, NanoAgentExecutor, resolve, setText (+11 more)

### Community 109 - "NavigationChannelHandler"
Cohesion: 0.40
Nodes (3): MethodCall, MethodChannel, NavigationChannelHandler

### Community 110 - "typedef"
Cohesion: 0.10
Nodes (19): Duration, ActionabilityState, actionable, ActionKind, check, enabled, exists, expectedPackage (+11 more)

### Community 111 - "GeneratedPluginRegistrant.java"
Cohesion: 0.60
Nodes (3): GeneratedPluginRegistrant, FlutterEngine, Keep

### Community 112 - "RuntimeChannelHandler"
Cohesion: 0.50
Nodes (3): MethodCall, MethodChannel, RuntimeChannelHandler

### Community 113 - "gradlew"
Cohesion: 0.60
Nodes (3): gradlew script, die(), warn()

### Community 114 - "proot_manager.dart"
Cohesion: 0.18
Nodes (10): ../../features/terminal/i_bin_executor.dart, exec, init, isReady, killByTag, ProotManager, _prootPath, _ready (+2 more)

### Community 115 - "rootfs_env.dart"
Cohesion: 0.50
Nodes (3): _, build, RootfsEnv

### Community 116 - "command_tagger.dart"
Cohesion: 0.50
Nodes (3): _, CommandTagger, tag

### Community 117 - "NanoColors"
Cohesion: 0.67
Nodes (3): NanoColors, NanoDarkColors, NanoLightColors

### Community 120 - "_ScanlinePainter"
Cohesion: 0.11
Nodes (17): IconData, body, build, NanoScreenShell, title, trailing, build, child (+9 more)

### Community 121 - "NanoThemeExtension"
Cohesion: 0.11
Nodes (18): 1. EngineSupervisor.kt - Diagnóstico y Logging Mejorado, 2. LLMEngineClient.dart - Manejo de Timeouts Mejorado, Archivos Modificados, Beneficios de las Correcciones, Configuración de Entorno Validada, Correcciones Implementadas, Correcciones Implementadas para Timeout del Motor Llama.cpp, Generate (Modo No-Stream) (+10 more)

### Community 122 - "_ThinkingIndicatorState"
Cohesion: 0.12
Nodes (16): LLMEngineClient get, ProviderContainer, channel, _client, container, dispatcher, ensureReady, generateStream (+8 more)

### Community 123 - "chat_screen.dart"
Cohesion: 0.07
Nodes (27): architecture, _cachedInstalled, _computeSha256, defaultShell, _distDir, _downloadFile, _extractTarball, _filesDir (+19 more)

### Community 125 - "models_screen.dart"
Cohesion: 0.15
Nodes (11): dart:convert, KeyboardMapper, keyToPtyBytes, logicalToChar, entries, _key, load, NoarPersistence (+3 more)

### Community 140 - "Global Constraints"
Cohesion: 0.18
Nodes (10): Global Constraints, Notas de ejecución, Plan de implementación: Funcionalidad faltante de orquestación, Task 1: Herramientas swipe/global/launch en AgentToolDispatcher, Task 2: ContextBudget — presupuesto de contexto puro, Task 3: Integrar ContextBudget en chat_provider + chip de escalón en UI, Task 4: Puerta de RAM al cargar modelo, Task 5: Honestidad terminal — banner condicional e identidad real (+2 more)

### Community 141 - "settingsProvider"
Cohesion: 0.09
Nodes (21): bool?, clickable, description, editable, expectedCount, fromClassName, hasAnyCriterion, isPackageConstrained (+13 more)

### Community 142 - "widget_agent_console_test.dart"
Cohesion: 0.17
Nodes (12): command, CronJob, _cronJobs, CronScheduler, dispose, intervalMin, jobs, register (+4 more)

### Community 144 - "dart:io"
Cohesion: 0.15
Nodes (18): dlopen(), execve(), _call_stack_entry(), _elf_entry_of(), _load_nanoroot_for_detached(), nanoshell_spawn_busybox(), nanoshell_spawn_generic(), nanoshell_worker_spawn() (+10 more)

### Community 145 - "Diseño: Funcionalidad faltante de orquestación (agente, degradación, RAM, honestidad)"
Cohesion: 0.25
Nodes (7): Diseño: Funcionalidad faltante de orquestación (agente, degradación, RAM, honestidad), Fuera de alcance (explícito), Orden de implementación, Sección 1: Agente — gap real verificado (corrección de auditoría), Sección 2: Degradación de contexto automática por RAM, Sección 3: Puerta de RAM al cargar modelo, Sección 4: Honestidad UI y nativa

### Community 146 - "fixtures.dart"
Cohesion: 0.29
Nodes (6): snapshotAjustes, snapshotCentroVsEsquina, snapshotDobleAceptar, snapshotIdDiscrepante, snapshotLabelCampo, snapshotRebindEmpty

### Community 147 - "@Deprecated"
Cohesion: 0.67
Nodes (3): @Deprecated, agentFindText, agentTapOnText

### Community 148 - "AnsiTerminalView"
Cohesion: 0.10
Nodes (19): architecture, _cachedInstalled, defaultShell, expectedSha256, getInfo, id, initialEnvironment, install (+11 more)

### Community 149 - "@pantalla"
Cohesion: 0.10
Nodes (19): architecture, _cachedInstalled, defaultShell, expectedSha256, getInfo, id, initialEnvironment, install (+11 more)

### Community 150 - "Java_dev_nanoai_mobile_NanoshellBridge_workerSpawnDetached"
Cohesion: 0.18
Nodes (20): JNIEnv, jobjectArray, jni_cstr_array_free(), jni_cstr_array_from_object_array(), jclass, jint, JNICALL, JNIEnv (+12 more)

### Community 151 - "nano_selector.dart"
Cohesion: 0.12
Nodes (14): dart:io, dmesg, listPids, loadavg, meminfo, _parseKeyValInt, pidFds, pidStat (+6 more)

### Community 153 - "ansi_terminal_test.dart"
Cohesion: 0.60
Nodes (3): MethodCall, MethodChannel, ShareChannelHandler

### Community 154 - "AnsiTerminalView"
Cohesion: 0.17
Nodes (16): ConsumerState, ConsumerStatefulWidget, _KaliCard, kaliProvider, _KaliCard, _KaliCardState, DesktopAuditScreen, _DesktopAuditScreenState (+8 more)

### Community 155 - "ModelDownloader"
Cohesion: 0.18
Nodes (11): settingsProvider, _prepareStartAndEnter, _connect, _ensureDesktopStarted, initState, VncScreen, _VncScreenState, _applyPassword (+3 more)

### Community 156 - "dart:async"
Cohesion: 0.20
Nodes (9): dart:async, AllowedBinaries, _cache, isAllowed, load, _loadFromAssets, _loadFuture, static Future (+1 more)

### Community 157 - "linux_distribution_registry.dart"
Cohesion: 0.15
Nodes (12): clear, _distributions, getAllDistributions, getAvailableDistributions, getDistribution, getInstalledDistributions, instance, isRegistered (+4 more)

### Community 158 - "agent_tool_dispatcher_test.dart"
Cohesion: 0.20
Nodes (9): deviceId, _devId, fetchDeviceIdentity, HardwareInfoService, readCpuTemp, _readCpuTempSync, readGpuInfo, _readGpuInfoSync (+1 more)

### Community 159 - "pdf_report_service.dart"
Cohesion: 0.18
Nodes (10): _, buildPdfBytes, exportMarkdown, exportReport, PdfReportService, package:path_provider/path_provider.dart, package:pdf/pdf.dart, package:pdf/widgets.dart (+2 more)

### Community 160 - "linux_init.dart"
Cohesion: 0.18
Nodes (9): distributions/kali_distribution.dart, distributions/termux_distribution.dart, distributions/ubuntu_distribution.dart, initializeLinuxDistributions, registerKaliDistribution, registry, linux_distribution_registry.dart, ../services/kali_manager.dart (+1 more)

### Community 161 - "chatProvider"
Cohesion: 0.33
Nodes (6): chatProvider, build, ChatScreen, _ChatScreenState, _showToolConfirmDialog, Route /models

### Community 162 - "terminal_plugin.dart"
Cohesion: 0.33
Nodes (5): AiPlugin, CmdRegistrar, registerInto, TerminalPlugin, typedef

### Community 163 - "LocalModelRepository"
Cohesion: 0.25
Nodes (7): pid_t, pty_close(), pty_is_alive(), pty_kill(), pty_read(), pty_resize(), pty_write()

### Community 164 - "LinuxDistribution"
Cohesion: 0.50
Nodes (4): KaliDistribution, TermuxDistribution, UbuntuDistribution, LinuxDistribution

### Community 167 - ".readLimited"
Cohesion: 0.29
Nodes (4): File, Int, java, String

### Community 168 - "devops_plugin.dart"
Cohesion: 0.50
Nodes (3): ../../core/services/kali_manager.dart, DevOpsPlugin, register

### Community 169 - "security_utils.dart"
Cohesion: 0.50
Nodes (3): sanitizeCommand, sanitizeInput, SecurityUtils

## Knowledge Gaps
- **2520 isolated node(s):** `ChannelNames`, `TCP`, `UNIX`, `main`, `main` (+2515 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **22 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `pty_spawn()` connect `dart:io` to `LocalModelRepository`, `Java_dev_nanoai_mobile_NanoshellBridge_ptySpawn`?**
  _High betweenness centrality (0.023) - this node is a cross-community bridge._
- **Why does `PtySession` connect `dart:io` to `pty_shell.dart`?**
  _High betweenness centrality (0.023) - this node is a cross-community bridge._
- **Why does `RootfsManager` connect `terminalservices.dart` to `shell_executor.dart`, `vnc_screen.dart`, `rootfs_manager.dart`, `boot_orchestrator.dart`, `desktop_launch_screen.dart`, `terminal_dependencies.dart`, `@pantalla`, `pty_manager.dart`, `proc_fs.dart`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **What connects `ChannelNames`, `TCP`, `UNIX` to the rest of the system?**
  _2520 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `vnc_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.017241379310344827 - nodes in this community are weakly interconnected._
- **Should `term_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.02 - nodes in this community are weakly interconnected._
- **Should `terminal_core.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.022727272727272728 - nodes in this community are weakly interconnected._