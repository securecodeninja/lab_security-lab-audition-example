#!/bin/bash
#
# This is the lab environment provisioning script for the Globomantics command injection lab.
#
# Designed to run non-interactively on a FRESH Ubuntu host (e.g. an AWS EC2
# Ubuntu 22.04 instance). It installs the .NET SDK, Visual Studio Code, Git, and
# Firefox, ensures the lab user exists, and clones the project onto that
# user's Desktop.
#
# Run as a user with sudo privileges:  bash setup.sh
#
set -euo pipefail

LAB_USER="pslearner"
LAB_REPO="https://github.com/securecodeninja/lab_security-lab-audition-example.git"
DESKTOP_DIR="/home/${LAB_USER}/Desktop"
export DEBIAN_FRONTEND=noninteractive

echo "==> Starting lab environment setup..."

# ---------------------------------------------------------------------------
# 1. Base packages
# ---------------------------------------------------------------------------
echo "==> Updating package lists and installing base dependencies..."
sudo apt-get update
sudo apt-get install -y wget gpg apt-transport-https ca-certificates lsb-release git

# ---------------------------------------------------------------------------
# 2. Ensure the lab user exists
#    (On the lab platform pslearner already exists or on a bare Ubuntu it
#    does not, so create it once.)
# ---------------------------------------------------------------------------
if ! id "${LAB_USER}" &>/dev/null; then
    echo "==> Creating lab user '${LAB_USER}'..."
    sudo useradd -m -s /bin/bash "${LAB_USER}"
fi

# ---------------------------------------------------------------------------
# 3. Microsoft package repository (required for .NET SDK and VS Code on a
#    fresh Ubuntu which is neither in the default apt sources).
# ---------------------------------------------------------------------------
echo "==> Registering Microsoft package repository..."
UBUNTU_VER="$(lsb_release -rs)"
wget -q "https://packages.microsoft.com/config/ubuntu/${UBUNTU_VER}/packages-microsoft-prod.deb" \
    -O /tmp/packages-microsoft-prod.deb
sudo dpkg -i /tmp/packages-microsoft-prod.deb
rm -f /tmp/packages-microsoft-prod.deb

# VS Code repository (published separately from the .NET feed).
echo "==> Registering Visual Studio Code repository..."
sudo install -d -m 0755 /etc/apt/keyrings
wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor \
    | sudo tee /etc/apt/keyrings/packages.microsoft.gpg > /dev/null
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null

# ---------------------------------------------------------------------------
# 4. .NET SDK 8.0 and Visual Studio Code
# ---------------------------------------------------------------------------
echo "==> Installing .NET SDK 8.0 and Visual Studio Code..."
sudo apt-get update
sudo apt-get install -y dotnet-sdk-8.0 code

# ---------------------------------------------------------------------------
# 5. Firefox (via the official Mozilla apt repository)
# ---------------------------------------------------------------------------
echo "==> Installing Firefox from the Mozilla repository..."
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- \
    | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
    | sudo tee /etc/apt/sources.list.d/mozilla.list > /dev/null
echo '
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
' | sudo tee /etc/apt/preferences.d/mozilla > /dev/null
sudo apt-get update
sudo apt-get install -y firefox

# ---------------------------------------------------------------------------
# 6. Git identity and project clone (run as the lab user)
# ---------------------------------------------------------------------------
echo "==> Configuring Git for '${LAB_USER}'..."
sudo -u "${LAB_USER}" git config --global user.name "PS Learner"
sudo -u "${LAB_USER}" git config --global user.email "pslearner@example.com"

echo "==> Cloning the lab repository to the Desktop..."
sudo -u "${LAB_USER}" mkdir -p "${DESKTOP_DIR}"
if [ ! -d "${DESKTOP_DIR}/lab_security-lab-audition-example" ]; then
    sudo -u "${LAB_USER}" git clone "${LAB_REPO}" \
        "${DESKTOP_DIR}/lab_security-lab-audition-example"
fi

# ---------------------------------------------------------------------------
# 7. Permissions
# ---------------------------------------------------------------------------
sudo chown -R "${LAB_USER}:${LAB_USER}" "/home/${LAB_USER}/Desktop"

echo "==> Installation complete."
echo "==> Project is at ${DESKTOP_DIR}/lab_security-lab-audition-example"