#!/usr/bin/env bash
set -euo pipefail
cd /workspaces/MoneyPrinterTurbo

if [ ! -f config.toml ]; then
  cp config.example.toml config.toml
fi

mkdir -p storage/logs
if ! pgrep -f "streamlit run ./webui/Main.py" >/dev/null; then
  nohup ~/.local/bin/uv run streamlit run ./webui/Main.py \
    --server.address=0.0.0.0 --server.port=8501 \
    --browser.gatherUsageStats=false --server.headless=true \
    > storage/logs/codespaces-webui.log 2>&1 &
fi
if ! pgrep -f "python main.py" >/dev/null; then
  nohup ~/.local/bin/uv run python main.py \
    > storage/logs/codespaces-api.log 2>&1 &
fi
echo "MoneyPrinterTurbo services starting. Web UI: port 8501; API: port 8080."
