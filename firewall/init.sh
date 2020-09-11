#!/bin/bash

set -Eeuox pipefail
cd "$(dirname "$0")"

# update the system first.
sudo apt-get update
sudo apt-get upgrade -y

# Let's add the current user to the sudoers group so we don't have to be asked for a password each time.
# TODO; restrict the commands which are allowed in sudoers file.
sudo usermod -aG sudo "$SUDO_USER"

# clear any existing FW rules
sudo ufw --force reset

# set explicity default deny policy
sudo ufw default deny incoming

# allow SSH to management host (192.168.5.2)
sudo ufw allow from 192.168.5.0/24 to 192.168.5.2 port 22 proto tcp

# clear all netplan rules; load them with ours.
sudo rm -rf /etc/netplan/*
sudo cp ./config/netplan.yml /etc/netplan/01-bcm.yaml

#set the ssh config
sudo cp ./config/sshd_config /etc/ssh/sshd_config

# disable IPv6 on the machine.
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1

sudo netplan generate
sudo netplan apply

#ufw
sudo cp ./config/ufw_before.rules /etc/ufw/before.rules
sudo cp ./config/ufw.conf /etc/ufw/ufw.conf
sudo cp ./config/ufw_sysctl.conf /etc/ufw/sysctl.conf

sudo ufw --force enable


# install docker
if [[ ! -f "$(command -v docker)" ]]; then
    snap install docker --channel="stable"
fi

# add the docker group
if ! grep -q docker /etc/group; then
    addgroup --system docker
fi

# and add the sudo_user to be a member of the docker group
if ! groups "$SUDO_USER" | grep -q docker; then
    adduser "$SUDO_USER" docker
fi

# # add the current user to the docker group.
# sudo usermod -aG docker "$SUDO_USER"

SUDOER_TEXT="$SUDO_USER ALL=(ALL) NOPASSWD: ALL"
if ! cat /etc/sudoers | grep -q "$SUDOER_TEXT"; then
    sudo echo "$SUDOER_TEXT" >> /etc/sudoers
fi

# let's disable systemd-resolved so we don't get any conflicts on port 53.
# the mask disables the service on reboot.
sudo systemctl disable systemd-resolved
sudo systemctl mask systemd-resolved
#sudo systemctl unmask systemd-resolved
#sudo systemctl enable systemd-resolved

if ss -tulpn | grep -q "192.168.5.2:22"; then
    sudo systemctl restart ssh
fi

#sudo shutdown -r now
