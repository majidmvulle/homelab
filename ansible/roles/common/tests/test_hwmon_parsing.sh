#!/bin/bash

TEST_SCRIPT="../files/export_hwmon_metrics.sh"
FAILED=0

run_test() {
  local description="$1"
  local input="$2"
  local expected="$3"

  echo "Running test: $description"

  # Use bash explicitly to run the script
  output=$(echo "$input" | bash "$TEST_SCRIPT" test_filter)
  exit_code=$?

  if [ $exit_code -ne 0 ]; then
    echo "❌ FAILED: Script exited with code $exit_code"
    FAILED=1
    return
  fi

  # Normalize whitespace
  output_norm=$(echo "$output" | xargs)
  expected_norm=$(echo "$expected" | xargs)

  if [ "$output_norm" == "$expected_norm" ]; then
    echo "✅ PASSED"
  else
    echo "❌ FAILED"
    echo "Expected: [$expected_norm]"
    echo "Actual:   [$output_norm]"
    FAILED=1
  fi
  echo "----------------------------------------"
}

# Test 1
input1='{
   "coretemp-isa-0000":{
      "Adapter": "ISA adapter",
      "Package id 0":{
         "temp1_input": 51.0
      }
   }
}'
expected1="node_hwmon_temp_celsius{chip=\"\",sensor=\"temp1_input\"} 51.0"
run_test "Standard input" "$input1" "$expected1"

# Test 2
input2='{
   "coretemp-isa-0000":{
      "Package id 0":{
         "temp1_input": 50.0
      },
      "Core 0":{
         "temp2_input": 45.0
      }
   }
}'
expected2="node_hwmon_temp_celsius{chip=\"\",sensor=\"temp1_input\"} 50.0 node_hwmon_temp_celsius{chip=\"\",sensor=\"temp2_input\"} 45.0"
run_test "Multiple sensors" "$input2" "$expected2"

# Test 3
input3='{
   "wifi-pci-0200":{
      "Adapter": "PCI adapter",
      "voltage1":{
         "in0_input": 1.2
      }
   }
}'
expected3=""
run_test "No temp sensors" "$input3" "$expected3"

# Test 4
input4='{
   "somedriver":{
      "Adapter": "Virtual",
      "MyChip":{
         "MyChip_temp1_input": 60.0
      }
   }
}'
expected4="node_hwmon_temp_celsius{chip=\"MyChip\",sensor=\"MyChip_temp1_input\"} 60.0"
run_test "Prefixed sensor" "$input4" "$expected4"

if [ $FAILED -eq 1 ]; then
  echo "Some tests failed."
  exit 1
else
  echo "All tests passed."
  exit 0
fi
