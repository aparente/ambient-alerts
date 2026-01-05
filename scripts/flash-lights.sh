#!/bin/bash
# ambient-alerts: Alert on permission request
# Supports multiple styles: flash, pulse, solid, subtle, breathe

CONFIG_FILE="${HOME}/.claude/ambient-alerts.json"

# Read session_id from stdin (hook input is JSON)
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "default"')
STATE_FILE="/tmp/ambient-alerts-state-${SESSION_ID}.json"

# Check if config exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  exit 0
fi

# Load configuration
BACKEND=$(jq -r '.backend // "openhue"' "$CONFIG_FILE")
ALERT_STYLE=$(jq -r '.alert_style // "flash"' "$CONFIG_FILE")
WAITING_ENABLED=$(jq -r '.waiting_state.enabled // true' "$CONFIG_FILE")

# === SAVE CURRENT STATE ===
if [[ ! -f "$STATE_FILE" ]]; then
  if [[ "$BACKEND" == "openhue" ]]; then
    LIGHT_NAME=$(jq -r '.light_name // "TV"' "$CONFIG_FILE")
    openhue get light "$LIGHT_NAME" --json > "$STATE_FILE" 2>/dev/null
  elif [[ "$BACKEND" == "custom" ]]; then
    SAVE_CMD=$(jq -r '.save_state_command // ""' "$CONFIG_FILE")
    if [[ -n "$SAVE_CMD" ]]; then
      eval "$SAVE_CMD" > "$STATE_FILE" 2>/dev/null
    fi
  fi
fi

# === EXECUTE ALERT STYLE ===
if [[ "$BACKEND" == "openhue" ]]; then
  LIGHT_NAME=$(jq -r '.light_name // "TV"' "$CONFIG_FILE")

  case "$ALERT_STYLE" in
    flash)
      FLASH_COLOR=$(jq -r '.styles.flash.flash_color // "cyan"' "$CONFIG_FILE")
      FLASH_BRIGHTNESS=$(jq -r '.styles.flash.flash_brightness // 100' "$CONFIG_FILE")
      FLASH_COUNT=$(jq -r '.styles.flash.flash_count // 3' "$CONFIG_FILE")
      FLASH_DURATION=$(jq -r '.styles.flash.flash_duration_ms // 120' "$CONFIG_FILE")
      FLASH_SEC=$(echo "scale=3; $FLASH_DURATION / 1000" | bc)

      # Get original color to flash back to
      ORIG_X=$(jq -r '.HueData.color.xy.x // 0.4' "$STATE_FILE" 2>/dev/null)
      ORIG_Y=$(jq -r '.HueData.color.xy.y // 0.4' "$STATE_FILE" 2>/dev/null)
      ORIG_BRIGHTNESS=$(jq -r '.HueData.dimming.brightness // 60' "$STATE_FILE" 2>/dev/null)

      for ((i=1; i<=FLASH_COUNT; i++)); do
        openhue set light "$LIGHT_NAME" --on -b "$FLASH_BRIGHTNESS" --color "$FLASH_COLOR" 2>/dev/null
        sleep "$FLASH_SEC"
        openhue set light "$LIGHT_NAME" --on -b "$ORIG_BRIGHTNESS" --xy "$ORIG_X,$ORIG_Y" 2>/dev/null
        sleep "$FLASH_SEC"
      done
      ;;

    pulse)
      PULSE_COLOR=$(jq -r '.styles.pulse.pulse_color // "warm_white"' "$CONFIG_FILE")
      PULSE_MIN=$(jq -r '.styles.pulse.pulse_min_brightness // 20' "$CONFIG_FILE")
      PULSE_MAX=$(jq -r '.styles.pulse.pulse_max_brightness // 80' "$CONFIG_FILE")
      PULSE_DURATION=$(jq -r '.styles.pulse.pulse_duration_ms // 1000' "$CONFIG_FILE")
      PULSE_SEC=$(echo "scale=3; $PULSE_DURATION / 1000" | bc)

      # Gentle pulse up and down
      openhue set light "$LIGHT_NAME" --on -b "$PULSE_MIN" --color "$PULSE_COLOR" 2>/dev/null
      sleep "$PULSE_SEC"
      openhue set light "$LIGHT_NAME" --on -b "$PULSE_MAX" --color "$PULSE_COLOR" 2>/dev/null
      sleep "$PULSE_SEC"
      openhue set light "$LIGHT_NAME" --on -b "$PULSE_MIN" --color "$PULSE_COLOR" 2>/dev/null
      sleep "$PULSE_SEC"
      ;;

    solid)
      SOLID_COLOR=$(jq -r '.styles.solid.solid_color // "powder_blue"' "$CONFIG_FILE")
      SOLID_BRIGHTNESS=$(jq -r '.styles.solid.solid_brightness // 60' "$CONFIG_FILE")
      openhue set light "$LIGHT_NAME" --on -b "$SOLID_BRIGHTNESS" --color "$SOLID_COLOR" 2>/dev/null
      ;;

    subtle)
      DIM_PERCENT=$(jq -r '.styles.subtle.dim_percent // 20' "$CONFIG_FILE")
      # Get current brightness and dim it
      CURRENT_BRIGHTNESS=$(jq -r '.HueData.dimming.brightness // 60' "$STATE_FILE" 2>/dev/null)
      NEW_BRIGHTNESS=$(echo "$CURRENT_BRIGHTNESS * (100 - $DIM_PERCENT) / 100" | bc)
      openhue set light "$LIGHT_NAME" --on -b "$NEW_BRIGHTNESS" 2>/dev/null
      ;;

    breathe)
      # Breathe: pulse brightness while keeping current color
      MIN_BRIGHTNESS=$(jq -r '.styles.breathe.min_brightness // 30' "$CONFIG_FILE")
      MAX_BRIGHTNESS=$(jq -r '.styles.breathe.max_brightness // 90' "$CONFIG_FILE")
      BREATH_DURATION=$(jq -r '.styles.breathe.breath_duration_ms // 800' "$CONFIG_FILE")
      BREATH_COUNT=$(jq -r '.styles.breathe.breath_count // 3' "$CONFIG_FILE")
      BREATH_SEC=$(echo "scale=3; $BREATH_DURATION / 1000" | bc)

      # Get current color coordinates from saved state
      COLOR_X=$(jq -r '.HueData.color.xy.x // 0.4' "$STATE_FILE" 2>/dev/null)
      COLOR_Y=$(jq -r '.HueData.color.xy.y // 0.4' "$STATE_FILE" 2>/dev/null)

      # Breathe: dim -> bright -> dim for each breath
      for ((i=1; i<=BREATH_COUNT; i++)); do
        openhue set light "$LIGHT_NAME" --on -b "$MIN_BRIGHTNESS" --xy "$COLOR_X,$COLOR_Y" 2>/dev/null
        sleep "$BREATH_SEC"
        openhue set light "$LIGHT_NAME" --on -b "$MAX_BRIGHTNESS" --xy "$COLOR_X,$COLOR_Y" 2>/dev/null
        sleep "$BREATH_SEC"
      done
      # End on dim before restore
      openhue set light "$LIGHT_NAME" --on -b "$MIN_BRIGHTNESS" --xy "$COLOR_X,$COLOR_Y" 2>/dev/null
      ;;
  esac

  # === SET WAITING STATE ===
  if [[ "$WAITING_ENABLED" == "true" && "$ALERT_STYLE" != "solid" ]]; then
    WAITING_COLOR=$(jq -r '.waiting_state.color // "powder_blue"' "$CONFIG_FILE")
    WAITING_BRIGHTNESS=$(jq -r '.waiting_state.brightness // 50' "$CONFIG_FILE")
    openhue set light "$LIGHT_NAME" --on -b "$WAITING_BRIGHTNESS" --color "$WAITING_COLOR" 2>/dev/null
  fi

elif [[ "$BACKEND" == "custom" ]]; then
  # Custom backend - run user-provided commands
  ALERT_CMD=$(jq -r '.alert_command // ""' "$CONFIG_FILE")
  WAITING_CMD=$(jq -r '.waiting_command // ""' "$CONFIG_FILE")

  if [[ -n "$ALERT_CMD" ]]; then
    eval "$ALERT_CMD" 2>/dev/null
  fi

  if [[ "$WAITING_ENABLED" == "true" && -n "$WAITING_CMD" ]]; then
    eval "$WAITING_CMD" 2>/dev/null
  fi
fi

exit 0
