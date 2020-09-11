#!/bin/bash

set -Eeuox pipefail

echo "Review bcmweb"
sleep 3

bash -c ./publish_local.sh

echo "Sign and publish? (Y/N)"
read $SIGN_RESPONSE

if [ $SIGN_RESPONSE == "Y" ] || [ $SIGN_RESPONSE == "y" ]; then
    bash -c ./publish_zeronet.sh
else
    echo "Alright, have a nice day"
fi
