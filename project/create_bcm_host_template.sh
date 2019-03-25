#!/bin/bash

set -Eeuo pipefail
cd "$(dirname "$0")"

# the base project
source ./env

for i in "$@"; do
    case $i in
        --project-name=*)
            BCM_PROJECT_NAME="${i#*=}"
            shift # past argument=value
        ;;
    esac
done

# let's make sure the cluster name is set.
if [[ -z "$BCM_PROJECT_NAME" ]]; then
    echo "BCM_PROJECT_NAME not set."
    exit
fi

# make sure we're on the right remove
if ! lxc project list | grep -q "$BCM_PROJECT_NAME"; then
    lxc project create "$BCM_PROJECT_NAME" -c features.images=false -c features.profiles=false
    lxc project switch "$BCM_PROJECT_NAME"
else
    echo "LXC project '$BCM_PROJECT_NAME' already exists."
fi

# first, let's check to see if our end proudct -- namely our LXC image with alias 'bcm-template'
# if it exists, we will quit by default, UNLESS the user has passed in an override, in which case
# it (being the lxc image 'bcm-template') will be rebuilt.
if lxc image list --format csv | grep -q "$LXC_BCM_BASE_IMAGE_NAME"; then
    echo "INFO: LXC image '$LXC_BCM_BASE_IMAGE_NAME' has already been built."
fi

# create the docker_unprivileged profile
if ! lxc profile list | grep -q "docker_unprivileged"; then
    lxc profile create docker_unprivileged
    cat ./lxd_profiles/docker_unprivileged.yml | lxc profile edit docker_unprivileged
fi

# create the docker_privileged profile
if ! lxc profile list | grep -q "docker_privileged"; then
    lxc profile create docker_privileged
    cat ./lxd_profiles/docker_privileged.yml | lxc profile edit docker_privileged
fi

if lxc list --format csv -c n | grep -q "bcm-bionic-base"; then
    echo "The LXD image 'bcm-bionic-base' doesn't exist. Exiting."
    exit
fi

# download the main ubuntu image if it doesn't exist.
# if it does exist, it SHOULD be the latest image (due to auto-update).
if ! lxc image list --format csv | grep -q "bcm-bionic-base"; then
    # 'images' is the publicly avaialb e image server. Used whenever there's no LXD image cache specified.
    IMAGE_REMOTE="images"
    if [[ ! -z $BCM_LXD_IMAGE_CACHE ]]; then
        IMAGE_REMOTE="$BCM_LXD_IMAGE_CACHE"
        if ! lxc remote list --format csv | grep -q "$IMAGE_REMOTE"; then
            lxc remote add "$IMAGE_REMOTE" "$IMAGE_REMOTE:8443"
        fi
    fi
    
    echo "Copying the ubuntu/18.04 lxc image from LXD image server '$IMAGE_REMOTE:' server to '$(lxc remote get-default):bcm-bionic-base'"
    lxc image copy "$IMAGE_REMOTE:ubuntu/18.04" "$(lxc remote get-default):" --alias bcm-bionic-base --auto-update
fi


# the way we provision a network on a cluster of count 1 is DIFFERENT
# than one that's larger than 1.
if [[ $(bcm cluster list --endpoints | wc -l) -gt 1 ]]; then
    # we run the following command if it's a cluster having more than 1 LXD node.
    for ENDPOINT in $(bcm cluster list --endpoints); do
        lxc network create --target "$ENDPOINT" bcmbr0
    done
else
    if ! lxc network list --format csv | grep -q bcmbr0; then
        # but if it's just one node, we just create the network.
        lxc network create bcmbr0 ipv4.nat=true ipv6.nat=false
    fi
fi

# If there was more than one node, this is the last command we need
# to run to initiailze the network across the cluster. This isn't
# executed when we have a cluster of size 1.
if lxc network list | grep bcmbr0 | grep -q PENDING; then
    lxc network create bcmbr0 ipv4.nat=true ipv6.nat=false
fi

if ! lxc list --format csv | grep -q bcm-host-template; then
    echo "Creating host 'bcm-host-template'."
    lxc init bcm-bionic-base -p bcm_default -p docker_privileged -n bcmbr0 bcm-host-template
fi

# if our image is not prepared, let's go ahead and create it.
if ! lxc image list --format csv | grep -q "$LXC_BCM_BASE_IMAGE_NAME"; then
    if lxc list --format csv -c=ns | grep bcm-host-template | grep -q STOPPED; then
        lxc start bcm-host-template
        
        sleep 5
        
        echo "Installing required software on LXC host 'bcm-host-template'."
        lxc exec bcm-host-template -- apt-get update
        
        # docker.io is the only package that seems to work seamlessly with
        # storage backends. Using BTRFS since docker recognizes underlying file system
        lxc exec bcm-host-template -- apt-get install -y docker.io wait-for-it ifmetric
        
        if [[ $BCM_DEBUG == 1 ]]; then
            lxc exec bcm-host-template -- apt-get install -y jq nmap curl slurm tcptrack dnsutils tcpdump
        fi
        
        ## checking if this alleviates docker swarm troubles in lxc.
        #https://github.com/stgraber/lxd/commit/255b875c37c87572a09e864b4fe6dd05a78b4d01
        lxc exec bcm-host-template -- touch /.dockerenv
        lxc exec bcm-host-template -- mkdir -p /etc/docker
        
        # this helps suppress some warning messages.
        lxc file push ./sysctl.conf bcm-host-template/etc/sysctl.conf
        lxc exec bcm-host-template -- chmod 0644 /etc/sysctl.conf
        
        # clean up the image before publication
        lxc exec bcm-host-template -- apt-get autoremove -qq
        lxc exec bcm-host-template -- apt-get clean -qq
        lxc exec bcm-host-template -- rm -rf /tmp/*
        
        lxc exec bcm-host-template -- systemctl stop docker
        lxc exec bcm-host-template -- systemctl enable docker
        
        #stop the template since we don't need it running anymore.
        lxc stop bcm-host-template
        
        lxc profile remove bcm-host-template docker_privileged
        lxc network detach bcmbr0 bcm-host-template
    fi
    
    # Let's publish a snapshot. This will be the basis of our LXD image.
    lxc snapshot bcm-host-template bcmHostSnapshot
    
    # publish the resulting image
    # other members of the LXD cluster will be able to pull and run this image
    echo "Publishing bcm-host-template/bcmHostSnapshot 'bcm-template' on cluster '$(lxc remote get-default)'."
    lxc publish bcm-host-template/bcmHostSnapshot --alias "$LXC_BCM_BASE_IMAGE_NAME"
    
    if lxc image list --format csv | grep -q "$LXC_BCM_BASE_IMAGE_NAME"; then
        lxc delete bcm-host-template
    fi
else
    echo "The image '$LXC_BCM_BASE_IMAGE_NAME' is already published."
fi