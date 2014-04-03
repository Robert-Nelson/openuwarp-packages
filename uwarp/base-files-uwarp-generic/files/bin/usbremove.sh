#!/bin/sh

# This script is called from the /lib/udev/rules.d/11-usb-auto-mount.rules file
# to take the appropriate action based on content of the USB key. This script must
# be passed a parameter that is the device of the key. For example "sda1"

logger -s -t USBUNMOUNT -p 5  "Processing /dev/$1"
if [ $# -lt 1 ]; then
	logger -s -t USBUNMOUNT -p 1 "There needs to be a parameter passed to this script corresponding to device of USB key"
	exit 1
fi

/bin/warpleds red
# check if mount in /lib/udev/rules.d/11-usb-auto-mount.rules was successful
mount | grep -q "/dev/$1 "
if [ $? -eq 0 ]; then
	umount -l /mnt/usbhd-$1
fi

# remove any old directories
if [ -L /mnt/usbhd-$1 ]; then
	/bin/rm -f /mnt/usbhd-$1
elif [ -d /mnt/usbhd-$1 ]; then
	/bin/rm -rf /mnt/usbhd-$1
fi
if [ -d /mnt/usbhd-$1 ]; then
	/bin/rm -rf /mnt/usbhd-$1
fi

/bin/warpleds green
exit 0
