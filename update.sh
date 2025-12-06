#!/bin/bash
# Update helper for Spotipi-eink on Raspberry Pi.
# - Stops running services
# - Pulls latest code from repo
# - Refreshes Python venv dependencies
# - Ensures systemd units exist (recreates if missing)
# - Restarts services

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

ensure_env_file() {
  local env_file="/etc/systemd/system/spotipi-eink-display.service.d/spotipi-eink-display_env.conf"
  if [ -f "$env_file" ]; then
    echo "Using existing env file: $env_file"
    return
  fi
  echo "Creating Spotify environment file: $env_file"
  read -r -p "Enter Spotify Client ID: " SPOTIPY_CLIENT_ID
  read -r -p "Enter Spotify Client Secret: " SPOTIPY_CLIENT_SECRET
  read -r -p "Enter Spotify Redirect URI: " SPOTIPY_REDIRECT_URI
  sudo mkdir -p "$(dirname "$env_file")"
  cat <<EOF | sudo tee "$env_file" >/dev/null
[Service]
Environment="SPOTIPY_CLIENT_ID=${SPOTIPY_CLIENT_ID}"
Environment="SPOTIPY_CLIENT_SECRET=${SPOTIPY_CLIENT_SECRET}"
Environment="SPOTIPY_REDIRECT_URI=${SPOTIPY_REDIRECT_URI}"
EOF
}

ensure_display_service() {
  local svc="/etc/systemd/system/spotipi-eink-display.service"
  if [ -f "$svc" ]; then
    echo "Display service already installed."
    return
  fi
  echo "Installing display service..."
  sudo cp "${REPO_DIR}/setup/service_template/spotipi-eink-display.service" "$svc"
  sudo sed -i -e "/\[Service\]/a ExecStart=${REPO_DIR}/spotipienv/bin/python3 ${REPO_DIR}/python/spotipiEinkDisplay.py" "$svc"
  sudo sed -i -e "/ExecStart/a WorkingDirectory=${REPO_DIR}" "$svc"
  sudo sed -i -e "/EnvironmentFile/a User=$(id -u)" "$svc"
  sudo sed -i -e "/User/a Group=$(id -g)" "$svc"
  sudo mkdir -p /etc/systemd/system/spotipi-eink-display.service.d
  ensure_env_file
}

ensure_token_service() {
  local svc="/etc/systemd/system/spotipi-eink-token-refresher.service"
  if [ -f "$svc" ]; then
    echo "Token refresher service already installed."
    return
  fi
  echo "Installing token refresher service..."
  sed "s|{{ INSTALL_PATH }}|${REPO_DIR}|g; s|{{ USER_ID }}|$(id -u)|g; s|{{ GROUP_ID }}|$(id -g)|g" \
    "${REPO_DIR}/setup/service_template/spotipi-eink-token-refresher.service" \
    | sudo tee "$svc" >/dev/null
  sudo chmod 644 "$svc"
}

ensure_buttons_service() {
  local svc="/etc/systemd/system/spotipi-eink-buttons.service"
  if ! grep -q "^model = inky" "${REPO_DIR}/config/eink_options.ini"; then
    echo "Buttons service not needed (model != inky)."
    return
  fi
  if [ -f "$svc" ]; then
    echo "Buttons service already installed."
    return
  fi
  echo "Installing buttons service..."
  sudo cp "${REPO_DIR}/setup/service_template/spotipi-eink-buttons.service" "$svc"
  sudo sed -i -e "/\[Service\]/a ExecStart=${REPO_DIR}/spotipienv/bin/python3 ${REPO_DIR}/python/buttonActions.py" "$svc"
  sudo sed -i -e "/ExecStart/a WorkingDirectory=${REPO_DIR}" "$svc"
  sudo sed -i -e "/EnvironmentFile/a User=$(id -u)" "$svc"
  sudo sed -i -e "/User/a Group=$(id -g)" "$svc"
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

echo "Ensuring systemd services exist..."
ensure_display_service
ensure_token_service
ensure_buttons_service

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Starting services..."
start_if_present "spotipi-eink-display.service"
start_if_present "spotipi-eink-token-refresher.service"
start_if_present "spotipi-eink-buttons.service"

echo "Update complete."

