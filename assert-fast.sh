#!/bin/bash

set -e

test -x ./target/raylee

max_exec_time=5
time_output=$((time -p ./target/raylee scripts/capture-10-frames.lua >/dev/null) 2>&1)
real_time=$(grep -oP '(?<=real ).*' <<< "$time_output")

echo >&2 "Execution time is: $real_time"

if (( $(bc <<< "$real_time > $max_exec_time") )); then
    exit 1
fi
