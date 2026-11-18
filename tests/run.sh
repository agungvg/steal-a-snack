#!/bin/bash
# Headless render-equivalent check for the snack characters.
# Assembles the mock + Config + CharacterFactory + harness into one
# script (see tests/build-combined.py for why) and runs it under the
# standalone `luau` interpreter. The verdict is the RESULT: line.
set -e
cd "$(dirname "$0")/.."
python3 tests/build-combined.py
~/workspace/tools/luau-0.747/luau tests/_combined.luau
