#!/bin/bash

set -Eeuo pipefail
cd "$(dirname "$0")"

BCM_CLI_VERB=${2:-}
if [ -z "${BCM_CLI_VERB}" ]; then
    cat ./help.txt
    exit
fi

if [[ $BCM_CLI_VERB == "list" ]]; then
    LXC_LIST_OUTPUT=$(lxc list --format csv --columns ns | grep "RUNNING")
    if echo "$LXC_LIST_OUTPUT" | grep -q "bcm-gateway"; then
        echo "gateway"
    fi
    
    if echo "$LXC_LIST_OUTPUT" | grep -q "bcm-kafka"; then
        echo "kafka"
    fi
    
    if echo "$LXC_LIST_OUTPUT" | grep -q "bcm-ui"; then
        echo "ui"
    fi
    
    if echo "$LXC_LIST_OUTPUT" | grep -q "bcm-bitcoin"; then
        echo "bitcoin"
    fi
    
    exit
fi

TIER_NAME=${3:-}
if [ -z "${TIER_NAME}" ]; then
    echo "Please specify a BCM tier."
    cat ./help.txt
    exit
    elif [[ $BCM_CLI_VERB == "create" ]]; then
    if bcm tier list | grep -q "$TIER_NAME"; then
        echo "WARNING: BCM tier already exists."
        exit
    fi
    
    if [[ $TIER_NAME == "gateway" ]]; then
        bash -c "$BCM_GIT_DIR/project/tiers/gateway/up.sh"
        elif [[ $TIER_NAME == "kafka" ]]; then
        bash -c "$BCM_GIT_DIR/project/tiers/kafka/up.sh"
        elif [[ $TIER_NAME == "ui" ]]; then
        bash -c "$BCM_GIT_DIR/project/tiers/ui/up.sh"
        elif  [[ $TIER_NAME == "bitcoin" ]]; then
        bash -c "$BCM_GIT_DIR/project/tiers/bitcoin/up.sh"
    fi
fi

if [[ $BCM_CLI_VERB == "remove" ]]; then
    if bcm tier list | grep -q "$TIER_NAME"; then
        if [[ $TIER_NAME == "gateway" ]]; then
            bash -c "$BCM_GIT_DIR/project/tiers/gateway/destroy.sh"
            elif [[ $TIER_NAME == "kafka" ]]; then
            bash -c "$BCM_GIT_DIR/project/tiers/kafka/destroy.sh"
            elif [[ $TIER_NAME == "ui" ]]; then
            bash -c "$BCM_GIT_DIR/project/tiers/ui/destroy.sh"
            elif  [[ $TIER_NAME == "bitcoin" ]]; then
            bash -c "$BCM_GIT_DIR/project/tiers/bitcoin/destroy.sh"
        fi
        
    fi
fi

if [[ $BCM_CLI_VERB != "list" && $BCM_CLI_VERB != "remove" && $BCM_CLI_VERB != "create" ]]; then
    echo "ERROR: next command should be 'create', 'remove', or 'list'."
    cat ./help.txt
fi
