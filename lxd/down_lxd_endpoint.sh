#!/bin/bash

# call bcm_script_before.sh to perform the things that every BCM script must do prior to proceeding
bash -c $BCM_LOCAL_GIT_REPO/resources/bcm/bcm_script_before.sh

# quit if there are no BCM environment variables
if [[ -z $(env | grep BCM) ]]; then
  echo "BCM variables not set. Please source BCM environment variables."
  exit
fi

echo "Calling ./gateway/down_lxd_cachestack.sh"
bash -c ./cachestack/down_lxd_cachestack.sh

echo "Calling ./gateway/down_lxd_gateway.sh"
bash -c ./gateway/down_lxd_gateway.sh

echo "Calling ./host_template/down_lxd_host_template.sh"
bash -c ./host_template/down_lxd_host_template.sh




# if [[ $BCM_BITCOIN_DELETE = "true" ]]; then
#   echo "Calling ./bitcoin/down_lxd_bitcoin.sh"
#   bash -c ./bitcoin/down_lxd_bitcoin.sh
# else
#   echo "BCM environment variables are configured to SKIP deletion of LXD host 'bitcoin'."
# fi

# if [[ $BCM_MANAGERS_DELETE = "true" ]]; then
#   echo "Calling ./managers/down_lxd_managers.sh"
  # bash -c ./managers/down_lxd_managers.sh
# else
#   echo "BCM environment variables are configured to SKIP deletion of LXD 'manager' hosts."
# fi

