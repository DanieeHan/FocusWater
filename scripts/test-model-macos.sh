#!/bin/bash
if [ -z "${BASH_VERSION:-}" ] || shopt -oq posix; then
    exec /bin/bash +o posix "$0" "$@"
fi
set -euo pipefail

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
xcode_dir=${FOCUSWATER_XCODE_DIR:-/Applications/Xcode.app/Contents/Developer}
toolchain_dir="$xcode_dir/Toolchains/XcodeDefault.xctoolchain/usr/bin"
platform_dir="$xcode_dir/Platforms/MacOSX.platform/Developer"
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/focuswater-model.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM

sources=()
while IFS= read -r source_path; do
    sources+=("$source_path")
done < <(rg --files "$project_dir/FocusWater" -g '*.swift')

compiler="$toolchain_dir/swiftc"
flags=(-sdk "$platform_dir/SDKs/MacOSX.sdk" -target "$(uname -m)-apple-macosx14.0")

# Exercise the real models on macOS without launching the app or an iOS simulator.
"$compiler" "${flags[@]}" -emit-library -emit-module -enable-testing -D DEBUG -module-name FocusWater \
    -external-plugin-path "$platform_dir/usr/lib/swift/host/plugins#$toolchain_dir/swift-plugin-server" \
    -emit-module-path "$test_dir/FocusWater.swiftmodule" -o "$test_dir/libFocusWater.dylib" "${sources[@]}"

"$compiler" "${flags[@]}" -I "$test_dir" -I "$platform_dir/usr/lib" \
    -F "$platform_dir/Library/Frameworks" -L "$test_dir" -L "$platform_dir/usr/lib" -lFocusWater \
    -Xlinker -rpath -Xlinker "$test_dir" \
    -Xlinker -rpath -Xlinker "$platform_dir/usr/lib" \
    -Xlinker -rpath -Xlinker "$platform_dir/Library/Frameworks" \
    -Xlinker -rpath -Xlinker "$platform_dir/Library/PrivateFrameworks" \
    "$project_dir/FocusWaterTests/FocusViewModelTests.swift" "$project_dir/scripts/ModelTestMain.swift" \
    -o "$test_dir/checks"
"$test_dir/checks"
