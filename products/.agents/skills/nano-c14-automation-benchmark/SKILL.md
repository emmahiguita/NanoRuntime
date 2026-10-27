---
name: nano-c14-automation-benchmark
description: Diagnose and maintain Nano Mobile's C14 automation benchmark, especially Android accessibility preflight and lifecycle failures.
---

# Nano C14 automation benchmark

Use this skill when C14 reports stale or contradictory preflight states, will not start, or leaves Android automation running after cancellation.

## Android accessibility is an explicit user permission

- Verify that Nano's own `AgentAccessibilityService` component is enabled. A global accessibility flag or another service such as Select to Speak does not prove Nano can read the UI tree.
- Treat service availability as the prerequisite for screen and unlock observations. Show those dependent checks as pending while the service is unavailable; keep the accessibility check itself as a real failure so C14 never runs UI actions without consent.
- On Android versions that restrict sideloaded apps, explain the user-controlled "Allow restricted settings" step and open the relevant system settings. Never toggle `enabled_accessibility_services`, `ACCESS_RESTRICTED_SETTINGS`, or another permission through shell commands or app code.
- After returning from Settings, re-read the exact service state before offering a retry. Do not say the permission is active based only on the user opening the Settings page.

## Benchmark and task lifecycle

- Run preflight before dispatching any benchmark task. A failed prerequisite must produce a diagnostic report and zero UI actions.
- Keep one owner for restoration and cleanup. Do not relaunch the app both in the widget and in the benchmark runner.
- On cancellation, signal the active operation and wait for its completion before releasing shared runtime or accessibility resources.
- Preserve evidence-based result states: distinguish a blocked preflight from a task failure and from a benchmark that never ran.

## Validation

- Follow the user's current preference on automated tests; use targeted formatting, static analysis, and the Android build when requested or necessary.
- For device verification, preserve app data, install the intended variant, confirm the app opens, inspect Android's exact enabled-service value and relevant logcat entries, then report any remaining user action explicitly.
- Do not claim the benchmark passed until C14 actually ran its selected tasks and produced a report on the target device.
