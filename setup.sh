#!/bin/bash

# Install Programs
echo "Starting installation process..."

# Update package lists
sudo apt update

# Install dependencies and Git
echo "Installing Git and dependencies..."
sudo apt install -y wget git

# Install Visual Studio Code
echo "Installing Visual Studio Code..."
sudo apt install -y code

# Install .NET SDK
echo "Installing .NET SDK..."
sudo apt install -y dotnet-sdk-8.0

# Create desktop directory
sudo mkdir -p /home/pslearner/Desktop

# Install Firefox
# Create a directory to store APT repository keys if it doesn't exist:
sudo install -d -m 0755 /etc/apt/keyrings

# Import the Mozilla APT repository signing key:
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null

# Add the Mozilla APT repository to your sources list:
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | sudo tee -a /etc/apt/sources.list.d/mozilla.list > /dev/null

# Configure APT to prioritize packages from the Mozilla repository:
echo '
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
' | sudo tee /etc/apt/preferences.d/mozilla

# Update your package list, and install the Firefox .deb package:
sudo apt-get update && sudo apt-get install firefox
# End of Firefox installation


# Configure Git
echo "Configuring Git..."
sudo -u pslearner git config --global user.name "PS Learner"
sudo -u pslearner git config --global user.email "pslearner@example.com"

# Clone sample repository
echo "Cloning sample repository..."
cd /home/pslearner/Desktop
sudo -u pslearner git clone https://github.com/dotnet/AspNetCore.Docs.Samples.git sample-repo


# Set permissions
sudo chown -R pslearner:pslearner /home/pslearner/Desktop

echo "Installation complete. "
