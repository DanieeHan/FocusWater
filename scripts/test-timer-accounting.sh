#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/focuswater-timer.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM

if [ -n "${SWIFT_COMPILER:-}" ]; then
    compiler=$SWIFT_COMPILER
elif [ -x /Library/Developer/CommandLineTools/usr/bin/swiftc ]; then
    compiler=/Library/Developer/CommandLineTools/usr/bin/swiftc
else
    compiler=swiftc
fi

if [ -n "${SWIFT_SDK:-}" ]; then
    set -- -sdk "$SWIFT_SDK"
elif [ -d /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk ]; then
    set -- -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
else
    set --
fi

# Compile the production accounting code, without Xcode, SwiftData or a simulator.
"$compiler" "$@" "$project_dir/FocusWater/Models/FocusTimer.swift" \
    "$project_dir/scripts/TimerAccountingChecks.swift" -o "$test_dir/checks"
"$test_dir/checks"
