#!/usr/bin/env bash

set -euo pipefail

# The root CI intentionally excludes the two Verilog CPU repositories. Keep
# this allowlist explicit so adding a new submodule cannot silently expand CI
# scope or let a misspelled workflow argument select an unintended path.
readonly SOFTWARE_SUBMODULES=(
  Dioptase-Assembler
  Dioptase-Emulators/Dioptase-Emulator-Full
  Dioptase-Emulators/Dioptase-Emulator-Simple
  Dioptase-Languages/Dioptase-C-Compiler
  Dioptase-OS
)

if [ "$#" -eq 0 ]; then
  requested_submodules=("${SOFTWARE_SUBMODULES[@]}")
else
  requested_submodules=("$@")
fi

for requested in "${requested_submodules[@]}"; do
  allowed=false
  for software_submodule in "${SOFTWARE_SUBMODULES[@]}"; do
    if [ "$requested" = "$software_submodule" ]; then
      allowed=true
      break
    fi
  done

  if [ "$allowed" != true ]; then
    echo "Software submodule initialization: unsupported path '$requested'." >&2
    exit 1
  fi
done

# All software repositories must be public for fork PRs to initialize them
# without a cross-repository secret. Translate the legacy SSH URLs accordingly.
git -c url."https://github.com/".insteadOf="git@github.com:" \
  submodule update --init --depth 1 -- "${requested_submodules[@]}"
