#!/usr/bin/env bash

set -e

export TREZOR_USB_PATH=""

# currentlt those hex nubmers are the vendor/product for the Trezor T. Need to find out if there are more of these combos that can be supported.
NEW_USB_BASELINE=$(lsusb -d 0x1209:0x53c1 | xargs)

if [[ $(echo $NEW_USB_BASELINE | wc | awk '{print $2}') -eq 0 ]]; then
    echo "Your Trezor was NOT found. Please ensure it's plugged in AND you've entered your PIN number to unlock the USB communication."
else
    # get 2nd word in output, which is the BUS
    NEW_USB_BUS=$(echo $NEW_USB_BASELINE | awk  '{print $2}')
    NEW_USB_DEVICE=$(echo $NEW_USB_BASELINE | awk  '{print $4}' | cut -c 1-3 )
    NEW_USB_ID=$(echo $NEW_USB_BASELINE | awk  '{print $6}' )
    export TREZOR_USB_PATH="/dev/bus/usb/$NEW_USB_BUS/$NEW_USB_DEVICE"
    echo "Discovered a Trezor at the following path: $TREZOR_USB_PATH"
fi
