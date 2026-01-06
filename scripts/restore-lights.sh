#!/bin/bash
# ambient-alerts: Handle post-tool-use event
# Now uses the unified state system

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${HOME}/.claude/ambient-alerts.json"

# Read hook input from stdin
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "default"')
TOOL_RESULT=$(echo "$INPUT" | jq -r '.tool_result // "success"')

# Determine if this was success or error
if echo "$INPUT" | jq -e '.error' >/dev/null 2>&1; then
  EVENT_TYPE="PostToolUse.error"
else
  EVENT_TYPE="PostToolUse.success"
fi

# Check if config exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  exit 0
fi

# Check if we're using the new state-based system
HAS_STATES=$(jq -r '.states // empty' "$CONFIG_FILE")
if [[ -n "$HAS_STATES" ]]; then
  # New system: look up event mapping and call set-state.sh
  TARGET_STATE=$(jq -r ".events[\"${EVENT_TYPE}\"] // \"\"" "$CONFIG_FILE")

  # Fall back to generic PostToolUse if specific event not found
  if [[ -z "$TARGET_STATE" || "$TARGET_STATE" == "null" ]]; then
    TARGET_STATE=$(jq -r '.events.PostToolUse // ""' "$CONFIG_FILE")
  fi

  if [[ -n "$TARGET_STATE" && "$TARGET_STATE" != "null" ]]; then
    "$SCRIPT_DIR/set-state.sh" "$TARGET_STATE" --session "$SESSION_ID"
  fi

  exit 0
fi

# === LEGACY SYSTEM BELOW ===
# Kept for backward compatibility with old configs

STATE_FILE="/tmp/ambient-alerts-state-${SESSION_ID}.json"

# Check if state file exists for this session
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

BACKEND=$(jq -r '.backend // "openhue"' "$CONFIG_FILE")

# Kill any continuous pulse process for this session
PID_FILE="/tmp/ambient-alerts-pulse-${SESSION_ID}.pid"
if [[ -f "$PID_FILE" ]]; then
  kill $(cat "$PID_FILE") 2>/dev/null
  rm -f "$PID_FILE"
fi

# Restore the lights
if [[ "$BACKEND" == "openhue" ]]; then
  LIGHT_NAME=$(jq -r '.light_name // "TV"' "$CONFIG_FILE")

  # Extract values from saved state (OpenHue JSON format)
  BRIGHTNESS=$(jq -r '.HueData.dimming.brightness // 60' "$STATE_FILE")
  CIE_X=$(jq -r '.HueData.color.xy.x // 0.5' "$STATE_FILE")
  CIE_Y=$(jq -r '.HueData.color.xy.y // 0.4' "$STATE_FILE")

  # Restore the light
  openhue set light "$LIGHT_NAME" --on -b "$BRIGHTNESS" -x "$CIE_X" -y "$CIE_Y" 2>/dev/null

elif [[ "$BACKEND" == "custom" ]]; then
  RESTORE_CMD=$(jq -r '.restore_command // ""' "$CONFIG_FILE")

  if [[ -n "$RESTORE_CMD" ]]; then
    cat "$STATE_FILE" | eval "$RESTORE_CMD" 2>/dev/null
  fi
fi

# Clean up state file
rm -f "$STATE_FILE"

exit 0
