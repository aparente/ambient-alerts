#!/bin/bash
# ambient-alerts: Gentle color animation
# Usage: animate.sh <light_name> <start_rgb> <end_rgb> <steps> <step_ms> <brightness> [--session <id>]
#
# Smoothly oscillates between two colors with configurable speed
# Runs in background, writes PID to file for clean shutdown

LIGHT_NAME="$1"
START_RGB="$2"
END_RGB="$3"
STEPS="${4:-40}"
STEP_MS="${5:-1000}"
BRIGHTNESS="${6:-60}"
SESSION_ID="default"

# Parse optional session arg
shift 6
while [[ $# -gt 0 ]]; do
  case $1 in
    --session)
      SESSION_ID="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

PID_FILE="/tmp/ambient-alerts-anim-${SESSION_ID}.pid"
STEP_SEC=$(echo "scale=3; $STEP_MS / 1000" | bc)

# Helper: Convert hex to RGB components
hex_to_rgb() {
  local hex="${1#\#}"
  echo "$((16#${hex:0:2})) $((16#${hex:2:2})) $((16#${hex:4:2}))"
}

# Helper: Interpolate between two values
lerp() {
  local start=$1
  local end=$2
  local t=$3  # 0.0 to 1.0
  echo "scale=0; $start + ($end - $start) * $t / 1" | bc
}

# Helper: RGB to hex
rgb_to_hex() {
  printf "#%02X%02X%02X" "$1" "$2" "$3"
}

# Parse start and end colors
read START_R START_G START_B <<< $(hex_to_rgb "$START_RGB")
read END_R END_G END_B <<< $(hex_to_rgb "$END_RGB")

# Kill any existing animation for this session
if [[ -f "$PID_FILE" ]]; then
  OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
  if [[ -n "$OLD_PID" ]] && kill -0 "$OLD_PID" 2>/dev/null; then
    kill "$OLD_PID" 2>/dev/null
    wait "$OLD_PID" 2>/dev/null
  fi
  rm -f "$PID_FILE"
fi

# Run animation in background
(
  trap "exit 0" TERM INT

  direction=1  # 1 = forward, -1 = backward
  step=0

  while true; do
    # Calculate interpolation factor (0.0 to 1.0)
    t=$(echo "scale=6; $step / $STEPS" | bc)

    # Interpolate RGB
    R=$(lerp $START_R $END_R $t)
    G=$(lerp $START_G $END_G $t)
    B=$(lerp $START_B $END_B $t)

    # Convert to hex
    HEX=$(rgb_to_hex $R $G $B)

    # Set the light with smooth transition
    openhue set light "$LIGHT_NAME" --on --rgb "$HEX" -b "$BRIGHTNESS" --transition-time "${STEP_SEC}s" 2>/dev/null

    sleep "$STEP_SEC"

    # Move to next step, reversing at boundaries (ping-pong)
    step=$((step + direction))
    if [[ $step -ge $STEPS ]]; then
      direction=-1
      step=$STEPS
    elif [[ $step -le 0 ]]; then
      direction=1
      step=0
    fi
  done
) &

# Save PID
echo $! > "$PID_FILE"
exit 0
