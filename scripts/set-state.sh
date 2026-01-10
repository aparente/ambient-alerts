#!/bin/bash
# ambient-alerts: Set presence state
# Usage: set-state.sh <state_name> [--session <id>]
#
# States are defined in ~/.claude/ambient-alerts.json under "states"
# Supports: fixed colors, animations, color temperature, and auto-transitions

CONFIG_FILE="${HOME}/.claude/ambient-alerts.json"
STATE_NAME="${1:-idle}"
SESSION_ID="default"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --session)
      SESSION_ID="$2"
      shift 2
      ;;
    *)
      STATE_NAME="$1"
      shift
      ;;
  esac
done

CURRENT_STATE_FILE="/tmp/ambient-alerts-current-${SESSION_ID}.txt"
ANIM_PID_FILE="/tmp/ambient-alerts-anim-${SESSION_ID}.pid"

# Stop any running animation
stop_animation() {
  if [[ -f "$ANIM_PID_FILE" ]]; then
    local pid=$(cat "$ANIM_PID_FILE" 2>/dev/null)
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
    fi
    rm -f "$ANIM_PID_FILE"
  fi
}

# Check if config exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

# Check if presence/volitional is enabled (for non-event calls)
PRESENCE_ENABLED=$(jq -r '.presence.enabled // .volitional.enabled // true' "$CONFIG_FILE")
if [[ "$PRESENCE_ENABLED" == "false" ]]; then
  exit 0
fi

# Load configuration
BACKEND=$(jq -r '.backend // "openhue"' "$CONFIG_FILE")
LIGHT_NAME=$(jq -r '.presence.light_name // .light_name // "TV"' "$CONFIG_FILE")

# Get state definition
STATE_COLOR=$(jq -r ".states.${STATE_NAME}.color // \"white\"" "$CONFIG_FILE")
STATE_BRIGHTNESS=$(jq -r ".states.${STATE_NAME}.brightness // 50" "$CONFIG_FILE")
STATE_MODE=$(jq -r ".states.${STATE_NAME}.mode // \"fixed\"" "$CONFIG_FILE")

# Check if state exists (some modes don't require color)
if [[ "$STATE_MODE" != "match_room" ]] && [[ "$STATE_MODE" != "animate" ]] && [[ "$STATE_MODE" != "temperature" ]] && [[ "$STATE_COLOR" == "null" || -z "$STATE_COLOR" ]]; then
  echo "Unknown state: $STATE_NAME" >&2
  echo "Available states: $(jq -r '.states | keys | join(", ")' "$CONFIG_FILE")" >&2
  exit 1
fi

# Always stop any running animation when changing state
stop_animation

# Handle special "off" state
if [[ "$STATE_NAME" == "off" ]]; then
  if [[ "$BACKEND" == "openhue" ]]; then
    openhue set light "$LIGHT_NAME" --off 2>/dev/null
  fi
  echo "$STATE_NAME" > "$CURRENT_STATE_FILE"
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Handle match_room mode - call the match-room script
if [[ "$STATE_MODE" == "match_room" ]]; then
  "$SCRIPT_DIR/match-room.sh" "$LIGHT_NAME"
  echo "$STATE_NAME" > "$CURRENT_STATE_FILE"
  exit 0
fi

# Handle animate mode - gentle color cycling
if [[ "$STATE_MODE" == "animate" ]]; then
  ANIM_START=$(jq -r ".states.${STATE_NAME}.animation.start_color // \"#4169E1\"" "$CONFIG_FILE")
  ANIM_END=$(jq -r ".states.${STATE_NAME}.animation.end_color // \"#00CED1\"" "$CONFIG_FILE")
  ANIM_STEPS=$(jq -r ".states.${STATE_NAME}.animation.steps // 40" "$CONFIG_FILE")
  ANIM_STEP_MS=$(jq -r ".states.${STATE_NAME}.animation.step_ms // 1000" "$CONFIG_FILE")
  ANIM_BRIGHTNESS=$(jq -r ".states.${STATE_NAME}.animation.brightness // .states.${STATE_NAME}.brightness // 60" "$CONFIG_FILE")

  "$SCRIPT_DIR/animate.sh" "$LIGHT_NAME" "$ANIM_START" "$ANIM_END" "$ANIM_STEPS" "$ANIM_STEP_MS" "$ANIM_BRIGHTNESS" --session "$SESSION_ID"
  echo "$STATE_NAME" > "$CURRENT_STATE_FILE"
  exit 0
fi

# Handle temperature mode - color temperature (e.g., Hue "Read" preset)
if [[ "$STATE_MODE" == "temperature" ]]; then
  STATE_TEMP=$(jq -r ".states.${STATE_NAME}.temperature // 350" "$CONFIG_FILE")
  if [[ "$BACKEND" == "openhue" ]]; then
    openhue set light "$LIGHT_NAME" --on -b "$STATE_BRIGHTNESS" -t "$STATE_TEMP" 2>/dev/null
  fi
  echo "$STATE_NAME" > "$CURRENT_STATE_FILE"
  exit 0
fi

# Apply the state (fixed color mode)
if [[ "$BACKEND" == "openhue" ]]; then
  openhue set light "$LIGHT_NAME" --on -b "$STATE_BRIGHTNESS" --color "$STATE_COLOR" 2>/dev/null
elif [[ "$BACKEND" == "custom" ]]; then
  # Custom backend - look for state-specific command or generic set command
  STATE_CMD=$(jq -r ".custom_commands.${STATE_NAME} // \"\"" "$CONFIG_FILE")
  if [[ -n "$STATE_CMD" && "$STATE_CMD" != "null" ]]; then
    eval "$STATE_CMD" 2>/dev/null
  else
    # Try generic set command with substitution
    SET_CMD=$(jq -r '.custom_commands.set // ""' "$CONFIG_FILE")
    if [[ -n "$SET_CMD" && "$SET_CMD" != "null" ]]; then
      SET_CMD="${SET_CMD//\{color\}/$STATE_COLOR}"
      SET_CMD="${SET_CMD//\{brightness\}/$STATE_BRIGHTNESS}"
      eval "$SET_CMD" 2>/dev/null
    fi
  fi
fi

# Record current state
echo "$STATE_NAME" > "$CURRENT_STATE_FILE"

# Handle transitions (e.g., completed -> idle after 2s)
TRANSITION_DURATION=$(jq -r ".transitions.${STATE_NAME}.duration_ms // 0" "$CONFIG_FILE")
TRANSITION_THEN=$(jq -r ".transitions.${STATE_NAME}.then // \"\"" "$CONFIG_FILE")

if [[ "$TRANSITION_DURATION" -gt 0 ]] && [[ -n "$TRANSITION_THEN" ]] && [[ "$TRANSITION_THEN" != "null" ]]; then
  TRANSITION_SEC=$(echo "scale=3; $TRANSITION_DURATION / 1000" | bc)

  # Run transition in background so we don't block
  (
    sleep "$TRANSITION_SEC"
    # Only transition if we're still in the expected state
    if [[ -f "$CURRENT_STATE_FILE" ]] && [[ "$(cat "$CURRENT_STATE_FILE")" == "$STATE_NAME" ]]; then
      "$0" "$TRANSITION_THEN" --session "$SESSION_ID"
    fi
  ) &
fi

exit 0
