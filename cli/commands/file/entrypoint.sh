#!/bin/bash

set -Eeuox pipefail
cd "$(dirname "$0")"


VALUE=${2:-}
if [ ! -z "${VALUE}" ]; then
    BCM_CLI_VERB="$2"
else
    echo "Please provide a SSH command."
    cat ./help.txt
    exit
fi

BCM_HELP_FLAG=0
INPUT_FILE_PATH=
OUTPUT_DIR=

for i in "$@"; do
    case $i in
        --input-file-path=*)
            INPUT_FILE_PATH="${i#*=}"
            shift # past argument=value
        ;;
        --output-dir=*)
            OUTPUT_DIR="${i#*=}"
            shift # past argument=value
        ;;
        --help)
            BCM_HELP_FLAG=1
            shift # past argument=value
        ;;
        *)
            # unknown option
        ;;
    esac
done

if [[ $BCM_HELP_FLAG == 1 ]]; then
    cat ./help.txt
    exit
fi

if [[ -z "$INPUT_FILE_PATH" ]]; then
    echo "INPUT_FILE_PATH not set."
    cat ./help.txt
    exit
fi

if [[ ! -f "$INPUT_FILE_PATH" ]]; then
    echo "$INPUT_FILE_PATH does not exist. Exiting."
    cat ./help.txt
    exit
fi

if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "$OUTPUT_DIR does not exist. Exiting."
    exit
fi

if [[ ! -d "$GNUPGHOME" ]]; then
    echo "ERROR: $GNUPGHOME doesn't exist. Exiting."
    exit
fi

if [[ ! -f "$GNUPGHOME/env" ]]; then
    echo "ERROR: $GNUPGHOME/env does not exist. '$INPUT_FILE_NAME' cannot be encrypted."
    exit
fi

INPUT_DIR=$(dirname $INPUT_FILE_PATH)
INPUT_FILE_NAME=$(basename $INPUT_FILE_PATH)

source "$GNUPGHOME/env"

if [[ $BCM_CLI_VERB == "encrypt" ]]; then
    # start the container / trezor-gpg-agent
    docker run -it --rm --name trezorencryptor \
    -v "$GNUPGHOME":/root/.gnupg \
    -v "$INPUT_DIR":/inputdir \
    -v "$OUTPUT_DIR":/outputdir \
    bcm-trezor:latest gpg --output "/inputdir/$INPUT_FILE_NAME.gpg" --encrypt --recipient "$BCM_DEFAULT_KEY_ID" "/outputdir/$INPUT_FILE_NAME"
    
    if [[ -f "$INPUT_FILE_PATH.gpg" ]]; then
        echo "Encrypted file created at $INPUT_FILE_PATH.gpg"
        
        # if [[ $DELETE_INPUT_FILE_FLAG == 1 ]]; then
        #     rm "$INPUT_FILE_PATH"
        # fi
    fi
    
    elif [[ $BCM_CLI_VERB == "decrypt" ]]; then
    ./decrypt/decrypt.sh "$@"
    elif [[ $BCM_CLI_VERB == "createsignature" ]]; then
    ./create_signature/create_signature.sh "$@"
    elif [[ $BCM_CLI_VERB == "verifysignature" ]]; then
    ./verify_signature/verify_signature.sh "$@"
else
    cat ./help.txt
fi
