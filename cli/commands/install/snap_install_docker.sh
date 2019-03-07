#!/bin/bash

set -Eeuo pipefail
cd "$(dirname "$0")"

# let's install and configure docker-ce
if ! snap list | grep -q docker; then
    sudo snap install docker --candidate
fi

if ! grep -q docker /etc/group; then
    sudo addgroup docker
fi

if ! groups "$USER" | grep -q docker; then
    sudo usermod -aG docker "$USER"
fi

# next we need to determine the underlying file system so we can upload the correct daemon.json
DEVICE="$(df -h "$HOME" | grep ' /' | awk '{print $1}')"
FILESYSTEM="$(mount | grep "$DEVICE")"
DAEMON_CONFIG="overlay_daemon.json"

if echo "$FILESYSTEM" | grep -q "btrfs"; then
    DAEMON_CONFIG="btrfs_daemon.json"
fi

sudo cp "./$DAEMON_CONFIG" /var/snap/docker/current/config/daemon.json
sudo snap restart docker
