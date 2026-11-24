#!/usr/bin/env bash
# Set up the course development tools for this repository without sudo.
# Run with: bash scripts/setup-dev-environment.sh
# At the end, source the printed environment commands in your current shell.

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_BIN="$HOME/.local/bin"
FNM_DIR="$HOME/.local/share/fnm"

command -v curl >/dev/null 2>&1 || {
  printf 'Error: curl is required. Ask an administrator to install curl.\n' >&2
  exit 1
}

mkdir -p "$LOCAL_BIN"
export PATH="$LOCAL_BIN:$FNM_DIR:$HOME/.cargo/bin:$PATH"

# Install uv in the user's home directory and avoid editing shell profiles.
if ! command -v uv >/dev/null 2>&1 || [ "$(uv --version | awk '{print $2}')" != "0.13.9" ]; then
  curl -LsSf https://astral.sh/uv/0.13.9/install.sh | env UV_NO_MODIFY_PATH=1 sh
  export PATH="$LOCAL_BIN:$PATH"
fi

# Create an isolated Python 3.12.3 environment for this repository.
uv venv --python 3.12.3 "$REPO_ROOT/.venv"
uv pip install --python "$REPO_ROOT/.venv/bin/python" numpy matplotlib jupyter

# Reuse Node.js 26.13.1; otherwise install it in the user's home directory
# with fnm, without changing shell startup files.
node_ok=false
if command -v node >/dev/null 2>&1; then
  if node -e 'process.exit(process.versions.node === "26.13.1" ? 0 : 1)'; then
    node_ok=true
  fi
fi

if [ "$node_ok" = false ]; then
  command -v unzip >/dev/null 2>&1 || {
    printf 'Error: unzip is required to install fnm. Ask an administrator to install unzip.\n' >&2
    exit 1
  }
  if [ ! -x "$FNM_DIR/fnm" ]; then
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$FNM_DIR" --skip-shell
  fi
  export PATH="$FNM_DIR:$PATH"
  eval "$("$FNM_DIR/fnm" env --shell bash)"
  fnm install 26.13.1
  fnm use 26.13.1
fi

command -v npm >/dev/null 2>&1 || {
  printf 'Error: npm was not found with Node.js. Check the Node.js installation.\n' >&2
  exit 1
}

# Keep pnpm user-local. npm 12 requires explicit approval for install scripts.
NPM_MAJOR="$(npm --version | cut -d. -f1)"
if [ "$NPM_MAJOR" -ge 12 ]; then
  npm install --global --prefix "$HOME/.local" --allow-scripts=pnpm pnpm@12.23.0
else
  npm install --global --prefix "$HOME/.local" pnpm@12.23.0
fi

# Install Rust and Cargo in the user's home directory, without shell-file edits.
if ! command -v rustup >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --no-modify-path -y
fi
rustup toolchain install 1.100.0
rustup default 1.100.0

if [ -f "$HOME/.cargo/env" ]; then
  # shellcheck disable=SC1091
  source "$HOME/.cargo/env"
fi

printf '\nSetup complete. Detected tool versions:\n'
uv --version
"$REPO_ROOT/.venv/bin/python" --version
node --version
npm --version
pnpm --version
rustc --version
cargo --version

printf '\nTo load the tools in your current shell, run:\n'
printf '  source "$HOME/.local/bin/env"\n'
if [ -x "$FNM_DIR/fnm" ]; then
  printf '  export PATH="%s:$PATH"\n' "$FNM_DIR"
  printf '  eval "$(%s/fnm env --shell bash)"\n' "$FNM_DIR"
fi
printf '  source "$HOME/.cargo/env"\n'
printf '  source "%s/.venv/bin/activate"\n' "$REPO_ROOT"
