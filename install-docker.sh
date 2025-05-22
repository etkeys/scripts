#!/usr/bin/env bash

# Docker Installation Script
#
# Automates the installation of Docker Engine on Ubuntu-based systems
# by removing conflicting packages and setting up official Docker repositories.
#
# Features:
# - Removes existing Docker-related packages to prevent conflicts
# - Adds Docker's official GPG key and APT repository
# - Installs Docker Engine, containerd, and Docker Compose
# - Verifies installation by running hello-world container
#
# Prerequisites:
# - Must be run with sudo/root privileges
# - Target system must be Ubuntu or Ubuntu-based distribution
# - Internet connection required
#
# Usage:
#   sudo ./install-docker.sh
#   or
#   sudo curl -fsSL https://raw.githubusercontent.com/etkeys/scripts/main/install-docker.sh | bash
#
# Post-Installation:
# - User can be added to docker group using:
#   sudo usermod -aG docker $USER
#
# Exit Codes:
# - 2: Script not run with root privileges
#
# Note: Requires manual logout/login to apply group changes

set -eu

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 2
fi

# Remove any docker related packages from distribution that may have been installed
# These packages may conflict with packages to be installed from docker
for pkg in \
  docker.io \
  docker-doc \
  docker-compose \
  docker-compose-v2 \
  containerd \
  runc; do
    if dpkg -l | grep -q "^ii  $pkg "; then
        echo "Removing $pkg..."
        apt-get remove --purge -y "$pkg"
    fi
done

# Add Docker's official GPG key
apt-get update
apt-get install -y \
  ca-certificates \
  curl \
  gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | tee /etc/apt/keyrings/docker.asc > /dev/null
chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker's official APT repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update

# Install Docker Engine, containerd, and Docker Compose
apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-compose-plugin

# Run hello-world to verify installation
docker run hello-world

echo ""
echo "If needed, add your user to the docker group:"
echo "    sudo usermod -aG docker \$USER"
echo "Then log out and back in to apply the group change."
echo ""
echo "Docker installation complete."