#!/bin/bash
# ambient-alerts: Match room's average color
# Queries other lights in the same room and sets target light to their average

CONFIG_FILE="${HOME}/.claude/ambient-alerts.json"

# Get target light name from config or argument
if [[ -n "$1" ]]; then
  LIGHT_NAME="$1"
else
  LIGHT_NAME=$(jq -r '.light_name // "Pitcher"' "$CONFIG_FILE" 2>/dev/null)
fi

# Get all lights with their room and color data
ALL_LIGHTS=$(openhue get lights --json 2>/dev/null)

# Find the room of our target light
TARGET_ROOM=$(echo "$ALL_LIGHTS" | jq -r --arg name "$LIGHT_NAME" '
  .[] | select(.Name == $name) | .Parent.Parent.Name
')

if [[ -z "$TARGET_ROOM" || "$TARGET_ROOM" == "null" ]]; then
  echo "Could not find room for light: $LIGHT_NAME" >&2
  exit 1
fi

# Get all OTHER lights in the same room (exclude target light and plugs)
ROOM_LIGHTS=$(echo "$ALL_LIGHTS" | jq --arg room "$TARGET_ROOM" --arg exclude "$LIGHT_NAME" '
  [.[] |
    select(.Parent.Parent.Name == $room) |
    select(.Name != $exclude) |
    select(.Type != "plug") |
    select(.HueData.on.on == true) |
    select(.HueData.color.xy != null) |
    {
      name: .Name,
      x: .HueData.color.xy.x,
      y: .HueData.color.xy.y,
      brightness: .HueData.dimming.brightness
    }
  ]
')

# Count how many lights we found
LIGHT_COUNT=$(echo "$ROOM_LIGHTS" | jq 'length')

if [[ "$LIGHT_COUNT" -eq 0 ]]; then
  # No other lights on in room - use a warm default
  echo "No other lights on in $TARGET_ROOM, using warm default"
  openhue set light "$LIGHT_NAME" --on -b 40 --color antique_white 2>/dev/null
  exit 0
fi

# Calculate average x, y, and brightness
AVG_X=$(echo "$ROOM_LIGHTS" | jq '[.[].x] | add / length')
AVG_Y=$(echo "$ROOM_LIGHTS" | jq '[.[].y] | add / length')
AVG_BRIGHTNESS=$(echo "$ROOM_LIGHTS" | jq '[.[].brightness] | add / length | floor')

# Clamp brightness to reasonable range (at least 20%)
if [[ $(echo "$AVG_BRIGHTNESS < 20" | bc) -eq 1 ]]; then
  AVG_BRIGHTNESS=20
fi

echo "Matching room '$TARGET_ROOM': avg xy=($AVG_X, $AVG_Y) brightness=$AVG_BRIGHTNESS% from $LIGHT_COUNT lights"

# Set the target light to match
openhue set light "$LIGHT_NAME" --on -b "$AVG_BRIGHTNESS" -x "$AVG_X" -y "$AVG_Y" 2>/dev/null

exit 0
