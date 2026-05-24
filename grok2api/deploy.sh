#!/bin/bash
# ============================================================
#  Grok2API — One-Click Deploy / Restart
#  Usage: bash deploy.sh
#  - Kills any process on port 8885
#  - Starts fresh instance
#  - Logs to logs/grok2api.log
# ============================================================

PORT=8885
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$INSTALL_DIR/logs/grok2api.log"
PID_FILE="$INSTALL_DIR/logs/grok2api.pid"

mkdir -p "$INSTALL_DIR/logs"

echo "=============================="
echo "  Grok2API Deploy"
echo "  Port: $PORT"
echo "  Dir : $INSTALL_DIR"
echo "=============================="

# --- Kill existing process on port 8885 ---
echo "[1/3] Checking port $PORT..."
OLD_PID=$(lsof -ti tcp:$PORT 2>/dev/null || true)
if [ -n "$OLD_PID" ]; then
    echo "  Killing old process (PID: $OLD_PID)..."
    kill -9 $OLD_PID 2>/dev/null || true
    sleep 1
fi

# Also kill by PID file
if [ -f "$PID_FILE" ]; then
    OLD_PID2=$(cat "$PID_FILE")
    kill -9 "$OLD_PID2" 2>/dev/null || true
    rm -f "$PID_FILE"
fi

echo "  Port $PORT is free."

# --- Check uv ---
export PATH="$HOME/.local/bin:$PATH"
if ! command -v uv &>/dev/null; then
    echo "[2/3] Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
else
    echo "[2/3] uv found: $(uv --version)"
fi

# --- Start server ---
echo "[3/3] Starting Grok2API on port $PORT..."
cd "$INSTALL_DIR"

nohup uv run uvicorn main:app \
    --host 0.0.0.0 \
    --port $PORT \
    --workers 1 \
    >> "$LOG_FILE" 2>&1 &

NEW_PID=$!
echo $NEW_PID > "$PID_FILE"

sleep 2

# --- Verify ---
if kill -0 $NEW_PID 2>/dev/null; then
    echo ""
    echo "=============================="
    echo "  Grok2API started!"
    echo "  PID : $NEW_PID"
    echo "  Port: $PORT"
    echo "  Log : $LOG_FILE"
    echo ""
    echo "  Test: curl http://localhost:$PORT/v1/models"
    echo "  Stop: kill \$(cat $PID_FILE)"
    echo "  Logs: tail -f $LOG_FILE"
    echo "=============================="
else
    echo "  ERROR: Failed to start. Check logs:"
    tail -20 "$LOG_FILE"
    exit 1
fi
