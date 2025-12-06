#!/bin/bash
# Update helper for Spotipi-eink on Raspberry Pi.
# - Stops running services
# - Pulls latest code from repo
# - Refreshes Python venv dependencies
# - Restarts services if they exist

set -euo pipefail

# Resolve repo directory:
# 1) If this script lives inside the repo, use that path.
# 2) Otherwise default to ~/spotipi-eink.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO_DIR="$SCRIPT_DIR"
if [ ! -d "${DEFAULT_REPO_DIR}/.git" ]; then
  DEFAULT_REPO_DIR="${HOME}/spotipi-eink"
fi
REPO_DIR="${1:-$DEFAULT_REPO_DIR}"

if [ ! -d "${REPO_DIR}/.git" ]; then
  echo "Repo not found at: ${REPO_DIR}"
  echo "Pass the repo path explicitly, e.g.:"
  echo "  ./update.sh /home/pi/spotipi-eink"
  exit 1
fi

echo "Using repo: ${REPO_DIR}"
cd "${REPO_DIR}"

stop_if_present() {
  local svc="$1"
  if systemctl list-unit-files | grep -q "^${svc}"; then
    echo "Stopping ${svc}"
    sudo systemctl stop "${svc}" || true
  else
    echo "Skipping ${svc} (not installed)"
  fi
}

start_if_present() {
  local svc="$1"
  if systemctl list-unit-files | grep -q "^${svc}"; then
    echo "Starting ${svc}"
    sudo systemctl enable "${svc}" || true
    sudo systemctl start "${svc}" || true
  else
    echo "Skipping ${svc} (not installed)"
  fi
}

echo "Stopping services..."
stop_if_present "spotipi-eink-display.service"
stop_if_present "spotipi-eink-token-refresher.service"
stop_if_present "spotipi-eink-buttons.service"

echo "Fetching latest code..."
git fetch --all
git pull --ff-only

echo "Refreshing Python environment..."
if [ ! -d "spotipienv" ]; then
  python3 -m venv --system-site-packages spotipienv
fi
source "${REPO_DIR}/spotipienv/bin/activate"
pip install --upgrade pip
pip install --upgrade -r requirements.txt
deactivate

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Starting services..."
start_if_present "spotipi-eink-display.service"
start_if_present "spotipi-eink-token-refresher.service"
start_if_present "spotipi-eink-buttons.service"

echo "Update complete."

