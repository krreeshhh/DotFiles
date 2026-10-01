#!/usr/bin/env bash
# ==========================================================
# launcher.sh - Quickshell Native App Launcher Trigger
# ==========================================================
set -euo pipefail

exec quickshell ipc call shell toggleAppLauncher
