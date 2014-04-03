#!/bin/sh
# This script is called from the /lib/udev/rules.d/11-usb-auto-mount.rules file
# to take the appropriate action based on content of the USB key. This script
# must be passed a parameter that is the device of the key. For example "sda1"

# Main
######

/bin/warpleds red
# confirm input
/usr/bin/logger -s -t USBMOUNT -p 5  "Processing /dev/$1"
if [ $# -lt 1 ]; then
	/usr/bin/logger -s -t USBMOUNT -p 1 "There needs to be a parameter passed to this script corresponding to device of USB key"
	exit 1
fi

# Brief pause before we start
/bin/sleep 2

# check if we are started up
if [ ! -f /tmp/.file-systems-mounted ]; then
	/usr/bin/logger -s -t USBMOUNT -p 1 "Overlay not mounted yet. Will let usbupgradecheck handle USB key."
	exit 0
else
	/bin/usbupgrade.sh $1
fi

exit 0
