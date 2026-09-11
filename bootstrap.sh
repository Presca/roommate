#!/usr/bin/env bash
# Generates Roommate.xcodeproj from project.yml and opens it.
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "→ installing xcodegen with Homebrew"
    brew install xcodegen
  else
    echo "xcodegen is missing and Homebrew isn't installed."
    echo "Install Homebrew from https://brew.sh then re-run ./bootstrap.sh"
    exit 1
  fi
fi

if [ -n "${TEAM_ID:-}" ]; then
  echo "→ using DEVELOPMENT_TEAM=$TEAM_ID"
  sed -i '' "s/DEVELOPMENT_TEAM: \"\"/DEVELOPMENT_TEAM: \"$TEAM_ID\"/" project.yml
fi

echo "→ generating Roommate.xcodeproj"
xcodegen generate

if ls Shared/Character.xcassets/pose-peek.imageset/*.png >/dev/null 2>&1; then
  echo "→ character artwork found"
else
  echo "→ no character artwork yet. Put the two sheets in Artwork/ and run:"
  echo "     python3 Scripts/slice_sheets.py Artwork/standing.png Artwork/sitting.png"
fi

open Roommate.xcodeproj
