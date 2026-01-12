# env.sh
REPO_ROOT="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$REPO_ROOT/bin:$PATH"
export DIOPTASE_ROOT="$REPO_ROOT"
