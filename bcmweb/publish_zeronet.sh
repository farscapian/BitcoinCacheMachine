#!/bin/bash

set -Eeuox pipefail
cd "$(dirname "$0")"

# This script builds the bcm website and publishes it to zeronet. You MUST have the private key
# to the assocaited BCM_ZERONET_ADDRESS to perform this.

source ./env

# let's build the website using jekyll.
# should only need this in one location, not in publish_local and publish_zeronet
bash -c ./build_site.sh

if [ -f "$BCM_ZERONET_PATH/content.json" ]; then
    sudo cp "$BCM_ZERONET_PATH/content.json" ./content.json
fi

sudo rm -rf $BCM_ZERONET_PATH/*
sudo cp -r $SITE_PATH/_site/* $BCM_ZERONET_PATH/
sudo cp ./content.json "$BCM_ZERONET_PATH/content.json"

if ! docker ps | grep -q zeronet; then

    # pulls the image down from dockerhub if needed and runs the build script which makes a few modifications to the image.
    docker pull "$ZERONET_BASE_DOCKER_IMAGE"
    docker build --build-arg BASE_IMAGE="$ZERONET_BASE_DOCKER_IMAGE" -t bcmzeronet ./zeronet/

    # run the zeronet daemon.
    docker run --name zeronet -d \
    -e ENABLE_TOR=true \
    -v "$DATA_DIR":/root/data  \
    -v "$LOG_DIR":/root/log \
    -p 127.0.0.1:43110:43110/tcp \
    "bcmzeronet:$VERSION"

    wait-for-it -t 30 127.0.0.1:43110
fi

#docker exec -it zeronet python3 zeronet.py siteSign "$BCM_ZERONET_ADDRESS" --publish

#xdg-open "http://127.0.0.1:43110/$BCM_ZERONET_ADDRESS"
