---
name: diagnose-crash
description: Analyze system and process crashes from systemd-coredump, inspect backtraces and logs, determine root causes, and provide actionable fixes or bug reports.
---

# Diagnose Crash Skill

This skill guides the agent through investigating, debugging, and resolving application and system crashes on Linux (Arch Linux / Hyprland).

## Overview
When an application crashes (e.g. SIGSEGV, SIGABRT, SIGBUS, SIGFPE), the system records a coredump via `systemd-coredump` and generates a diagnostic report in `~/.local/state/crashes/`. Your objective is to:
1. Identify the exact process, PID, and termination signal.
2. Analyze the stack trace (call stack) to pinpoint the failing instruction, function, or library.
3. Correlate with recent system and application logs.
4. Determine whether the crash is caused by:
   - Configuration / theme errors (e.g. invalid Hyprland/Waybar/Quickshell config, missing assets)
   - Permission / missing socket / IPC issues
   - Upstream software bug / memory corruption (null pointer dereference, use-after-free, assertion failure)
   - Out of memory (OOM) or hardware/driver faults
5. Apply a fix directly if it is a configuration/script error, or formulate an upstream bug report.

---

## Diagnostic Workflow

### 1. Read Crash Report & Coredump Metadata
When given a crash report path or a PID:
- View the generated markdown report:
  ```bash
  cat ~/.local/state/crashes/crash_<timestamp>_<exe>_<pid>.md
  ```
- Or query `coredumpctl` directly:
  ```bash
  coredumpctl info <pid>
  ```

### 2. Inspect the Stack Trace
Analyze the thread call stack (focus on `Thread 1` or the thread that raised the signal):
- **Signal Types:**
  - `SIGSEGV` (11): Invalid memory access (null pointer dereference, wild pointer). Look at the top stack frames for the offending function.
  - `SIGABRT` (6): Abort called via `assert()`, panic, or `std::terminate()`. Look for assertion messages right before abort in `journalctl`.
  - `SIGBUS` (7): Alignment fault or mmap access failure.
  - `SIGFPE` (8): Division by zero or floating point exception.
  - `SIGTRAP` (5): Breakpoint / debug trap / panic handler.

### 3. Check Application Logs
Inspect surrounding stdout/stderr output from systemd journal:
```bash
journalctl _PID=<pid> -n 100 --no-pager
# Or inspect the unit logs:
journalctl -u <unit_name> --since "10 minutes ago" --no-pager
```

### 4. Categorize & Resolve

#### Scenario A: Configuration or Script Issue
- If the crash occurred in a desktop component (`hyprland`, `quickshell`, `waybar`, `dunst`, custom python/bash script):
  - Check the user's config files in `~/.config/<app>/`.
  - Look for syntax errors, missing referenced files, invalid colors, or broken IPC handlers.
  - Suggest or apply the exact fix to the user's config.

#### Scenario B: Missing Dependency or Library Conflict
- Check if a shared library is missing or incompatible:
  ```bash
  ldd /path/to/executable
  pacman -Qo /path/to/executable
  ```
- Suggest package reinstall or updating system packages (`sudo pacman -Syu`).

#### Scenario C: Upstream Software Bug
- If the crash is inside third-party binary code:
  - Summarize the exact backtrace, failing module, and reproduction steps.
  - Check if the issue is already reported upstream.
  - Formulate a clear bug report draft with reproduction details and symbolized stack trace.

---

## Output Format
Always provide a concise diagnosis summary:
1. **Target:** `<Executable>` (PID `<pid>`)
2. **Failure Signal:** `<Signal Name & Code>`
3. **Crash Location:** `<Failing Function / Shared Library>`
4. **Root Cause Analysis:** Clear explanation of why the crash happened.
5. **Remediation / Action Taken:** Proposed code/config fix or resolution steps.
