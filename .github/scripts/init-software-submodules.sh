#!/usr/bin/env bash

set -euo pipefail

# The root CI intentionally excludes the two Verilog CPU repositories. Keep
# this list explicit so adding a new submodule cannot silently expand CI scope.
readonly SOFTWARE_SUBMODULES=(
  Dioptase-Assembler
  Dioptase-Emulators/Dioptase-Emulator-Full
  Dioptase-Emulators/Dioptase-Emulator-Simple
  Dioptase-Languages/Dioptase-C-Compiler
  Dioptase-OS
)

# All software repositories must be public for fork PRs to initialize them
# without a cross-repository secret. Translate the legacy SSH URLs accordingly.
git -c url."https://github.com/".insteadOf="git@github.com:" \
  submodule update --init --depth 1 -- "${SOFTWARE_SUBMODULES[@]}"
