#!/bin/bash
set -e

JQ_FILTER='
  .[][] | select(type == "object") |
  to_entries[] |
  select(.key | test("temp[0-9]+_input$")) |
  "node_hwmon_temp_celsius{chip=\"" + (.key | gsub("temp[0-9]+_input"; "") | gsub("_$"; "") | gsub(" "; "-")) + "\",sensor=\"" + .key + "\"} " + (.value|tostring)
'

if [ "$1" == "test_filter" ]; then
    cat | jq -r "$JQ_FILTER"
    exit $?
fi

OUTPUT_FILE="{{ node_exporter_textfile_dir }}/hwmon.prom"
TMP_OUTPUT_FILE="${OUTPUT_FILE}.$$"

# Ensure directory exists (though Ansible should create it)
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Clear previous metrics for this file to avoid stale data
: > "$TMP_OUTPUT_FILE"

{
  echo "# HELP node_hwmon_temp_celsius Hardware sensor temperature in Celsius"
  echo "# TYPE node_hwmon_temp_celsius gauge"
} >> "$TMP_OUTPUT_FILE"

# Using sensors -j for JSON output, requires jq (installed by common role)
# This example extracts temperatures. Adapt for voltages, fan speeds etc. as needed.
sensors -j | jq -r "$JQ_FILTER" >> "$TMP_OUTPUT_FILE"

# Example for fan speeds (uncomment and adapt if your sensors output them)
# echo "# HELP node_hwmon_fan_rpm Hardware sensor fan speed in RPM" >> "$TMP_OUTPUT_FILE"
# echo "# TYPE node_hwmon_fan_rpm gauge" >> "$TMP_OUTPUT_FILE"
# sensors -j | jq -r '
#   .[][] | select(type == "object") |
#   to_entries[] |
#   select(.key | test("fan[0-9]+_input$")) |
#   "node_hwmon_fan_rpm{chip="" + (.key | gsub("fan[0-9]+_input"; "") | gsub("_$"; "") | gsub(" "; "-")) + "",sensor="" + .key + ""} " + (.value|tostring)
# ' >> "$TMP_OUTPUT_FILE"

mv "$TMP_OUTPUT_FILE" "$OUTPUT_FILE"
