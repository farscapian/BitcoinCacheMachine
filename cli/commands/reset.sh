#!/bin/bash

set -Eeuo pipefail
cd "$(dirname "$0")"

# shellcheck disable=SC1090
source "$BCM_GIT_DIR/env"



CONTINUE=0
if [[ -d "$GNUPGHOME" ]]; then
    while [[ "$CONTINUE" == 0 ]]
    do
        CHOICE=
        echo "WARNING: Are you sure you want to delete '$GNUPGHOME' and '$PASSWORD_STORE_DIR' directories."
        read -rp "Are you sure (y/n):  "   CHOICE
        
        if [[ "$CHOICE" == "y" ]]; then
            CONTINUE=1
            elif [[ "$CHOICE" == "n" ]]; then
            exit
        else
            echo "Invalid entry. Please try again."
        fi
    done
    
    if [[ $GNUPGHOME != "$HOME/.gnupg" ]]; then
        echo "Deleting $GNUPGHOME."
        sudo rm -Rf "$GNUPGHOME"
    fi
else
    echo "WARNING: GNUPGHOME directory '$GNUPGHOME' does not exist. You may need to run 'bcm init'."
fi

if [[ -d "$PASSWORD_STORE_DIR" ]]; then
    if [[ "$CHOICE" == 'y' ]]; then
        if [ "$PASSWORD_STORE_DIR" != "$HOME/.password_store" ]; then
            echo "Deleting $PASSWORD_STORE_DIR."
            sudo rm -Rf "$PASSWORD_STORE_DIR"
        fi
    fi
else
    echo "WARNING: PASSWORD_STORE_DIR directory '$PASSWORD_STORE_DIR' does not exist. You may need to run 'bcm init'."
fi

bash -c "$BCM_GIT_DIR/cli/tmp_down.sh"