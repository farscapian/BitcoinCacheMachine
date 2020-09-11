#!/bin/bash

set -Eeuox pipefail
cd "$(dirname "$0")"

# NOTE! The SSH_HOST is what is defined under ~/.ssh/config !!!!!  Not a DNS HOSTNAME
export SSH_HOST="antsle"
export PASSWORD="testing"

ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$SSH_HOST"

rsync --verbose -a $(pwd)/ "bcm@$SSH_HOST:/home/bcm/fw"

# TOD
#ssh "$SSH_HOST" sudo 'echo "bcm  ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers'

#ssh -t "$SSH_HOST" sudo bash -c /home/bcm/fw/init.sh

#sleep 30

# this is the IP of the SSH management interface on the trusted zone.
wait-for-it -t 30 192.168.5.2:22

# TODO update ssh conf to reflect new IP address.

ssh -t "$SSH_HOST" "bash -c '/home/bcm/fw/network_setup.sh --password=$PASSWORD --trusted-interface=eno2'"
