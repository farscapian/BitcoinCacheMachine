#!/bin/bash

set -Eeuox pipefail
cd "$(dirname "$0")"

source ./env

# this stores cached jekyll data that is pulled from the
# internet the first time an image is created.
if ! docker volume list | grep -q buildcache; then
    docker volume create buildcache
fi

IMAGE="jekyll/jekyll:latest"
docker image pull "$IMAGE"

if [ -f "$SITE_PATH/Gemfile.lock" ]; then
    rm "$SITE_PATH/Gemfile.lock"
fi

# let's remove the old version of the site.
rm -rf "$SITE_PATH/_site"

docker run -it \
-v buildcache:/usr/local/bundle \
-v "$SITE_PATH:/srv/jekyll" \
"$IMAGE" jekyll build --incremental --disable-disk-cache --verbose --trace
