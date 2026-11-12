#!/usr/bin/env bash
set -euo pipefail
cd /workspaces/MoneyPrinterTurbo

if [ ! -f config.toml ]; then
  cp config.example.toml config.toml
fi

mkdir -p storage/logs

# Resolve uv from PATH first; Codespaces images can install it outside ~/.local/bin.
UV_BIN="$(command -v uv || true)"
if [ -z "$UV_BIN" ]; then
  for candidate in "$HOME/.local/bin/uv" "/usr/local/bin/uv" "/root/.local/bin/uv"; do
    if [ -x "$candidate" ]; then
      UV_BIN="$candidate"
      break
    fi
  done
fi

# Recover automatically if the devcontainer post-create install did not complete.
if [ -z "$UV_BIN" ]; then
  if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: uv is missing and curl is unavailable; install uv in the Codespace, then rerun this script." >&2
    exit 1
  fi
  curl -LsSf https://astral.sh/uv/install.sh | sh
  for candidate in "$HOME/.local/bin/uv" "/usr/local/bin/uv"; do
    if [ -x "$candidate" ]; then
      UV_BIN="$candidate"
      break
    fi
  done
fi

if [ -z "$UV_BIN" ]; then
  echo "ERROR: uv installation did not produce an executable. Check the Codespaces build log." >&2
  exit 1
fi

echo "Using uv at: $UV_BIN"

if ! pgrep -f '[s]treamlit run ./webui/Main.py' >/dev/null; then
  nohup "$UV_BIN" run streamlit run ./webui/Main.py \
    --server.address=0.0.0.0 --server.port=8501 \
    --browser.gatherUsageStats=false --server.headless=true \
    > storage/logs/codespaces-webui.log 2>&1 &
fi
if ! pgrep -f '[u]v run python main.py' >/dev/null; then
  nohup "$UV_BIN" run python main.py \
    > storage/logs/codespaces-api.log 2>&1 &
fi

echo "MoneyPrinterTurbo startup commands launched. Check storage/logs for service status."
