#!/bin/bash
# Lints a Swift file right after Claude edits it. Exits with status 2 so
# Claude Code sends any violations back to Claude to fix.

file=$(jq -r '.tool_input.file_path // .tool_input.filePath // empty')
[[ "$file" == *.swift ]] || exit 0

# Xcode's tools pass project paths that start with the project name, such as
# "VideoPlayer/VideoPlayer/Player.swift".
[[ "$file" == /* ]] || file="$CLAUDE_PROJECT_DIR/${file#*/}"
[[ -f "$file" ]] || exit 0

# Use the SwiftLint binary that the Xcode package plugin downloaded.
shopt -s nullglob
binaries=(~/Library/Developer/Xcode/DerivedData/VideoPlayer-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint)
[[ ${#binaries[@]} -gt 0 ]] || exit 0

cd "$CLAUDE_PROJECT_DIR" || exit 0
output=$("${binaries[0]}" lint --quiet "$file" 2>/dev/null)
[[ -n "$output" ]] || exit 0

echo "SwiftLint found problems in $file. Fix any in code you just wrote or" \
  "changed before moving on; leave ones in untouched code unless asked:" >&2
echo "$output" >&2
exit 2
