#!/bin/bash
# ambient-alerts: Restore lights after tool use completes
# Supports OpenHue CLI or custom commands

CONFIG_FILE="${HOME}/.claude/ambient-alerts.json"

# Read session_id from stdin (hook input is JSON)
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "default"')
STATE_FILE="/tmp/ambient-alerts-state-${SESSION_ID}.json"

# Check if state file exists for this session
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# Check if config exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  rm -f "$STATE_FILE"
  exit 0
fi

# Load configuration
BACKEND=$(jq -r '.backend // "openhue"' "$CONFIG_FILE")

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
    # Pass saved state as stdin to restore command
    cat "$STATE_FILE" | eval "$RESTORE_CMD" 2>/dev/null
  fi
fi

# Clean up state file
rm -f "$STATE_FILE"

exit 0
