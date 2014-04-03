#!/bin/sh
# This script is called from the /lib/udev/rules.d/11-usb-auto-mount.rules file
# to take the appropriate action based on content of the USB key. This script
# must be passed a parameter that is the device of the key. For example "sda1"

# Functions
###

# This function takes a parameter and returns 0 if it is numeric
# and 1 if it is not or blank
is_numeric () {
	if [ "$1" == "" ]; then
		return 1
	fi
	NUMCHECK=`/bin/echo "$1" | /usr/bin/awk '$0 ~/[^ 0-9]/ { print "invalid" }'`
	if [ "$NUMCHECK" == "invalid" ]; then
		return 1
	else
		return 0
	fi
}

# This function terminates applications in the list to free up memory
# for a bigger /tmp directory
kill_processes() { 
	local sig=9
	local stat
	for stat in /proc/[0-9]*/stat; do
		[ -f "$stat" ] || continue

		local pid name state ppid rest
		read pid name state ppid rest < $stat
		name="${name#(}"; name="${name%)}"

		local cmdline
		read cmdline < /proc/$pid/cmdline

		# Skip kernel threads 
		[ -n "$cmdline" ] || continue

		case "$name" in
			# Killable process
			*asterisk*|*uhttpd*|*dnsmasq*|*dropbear*|*crond*|*dhcpc*|*dhcpd*|*telnetd*)
				if [ $pid -ne $$ ] && [ $ppid -ne $$ ]; then
					echo -n "$name "
					kill -$sig $pid 2>/dev/null
				fi
			;;
			*)
			;;
		esac
	done
	echo ""
}

kill_remaining() { # [ <signal> ]
	local sig="${1:-TERM}"
	echo -n "Sending $sig to remaining processes ... "

	local stat
	for stat in /proc/[0-9]*/stat; do
		[ -f "$stat" ] || continue

		local pid name state ppid rest
		read pid name state ppid rest < $stat
		name="${name#(}"; name="${name%)}"

		local cmdline
		read cmdline < /proc/$pid/cmdline

		# Skip kernel threads 
		[ -n "$cmdline" ] || continue

		case "$name" in
			# Skip essential services
			*usbmount*|*udevd*|*procd*|*ash*|*bash*|*init*|*watchdog*|*dropbear*|*login*|*hostapd*|*wpa_supplicant*|*nas*) : ;;

			# Killable process
			*)
				if [ $pid -ne $$ ] && [ $ppid -ne $$ ]; then
					echo -n "$name "
					kill -$sig $pid 2>/dev/null
				fi
			;;
		esac
	done
	echo ""
}

# reset leds 
set_exit_leds() {
	/bin/warpleds green
}

# This function checks for the system upgrade file of format,
# openwrt-ar71xx-generic-uwarp-ar7420-squashfs-*.bin, on the USB. There can only
# be one on the key. Function returns 0 if file is found, 1 if no file is
# found, 2 if more than one file is found or 3 if already burnt file exists.
# The function also sets the value for UPGRADE_FILENAME
check_for_upgrade_file () {
	# see if file burnt already
	if [ -f $OPENUWARP_BURN_TEST_FILE ]; then
		return 3
	fi
	UPGRADE_FILENAME=""
	COUNT=`/bin/ls -l $USB_MOUNT_DIR/openwrt-ar71xx-generic-uwarp-ar7420-squashfs-*.bin | egrep "factory|sysupgrade" | grep -c ".bin"`
	if [ $COUNT -eq 0 ]; then
		if [ -f $USB_MOUNT_DIR/openwrt-*.bin ]; then
			# do not allow other openwrt files
			/bin/echo "ERROR: Only files created for the PIKA Open uWARP are supported. You have an invalid *.bin file on your USB key." >> $OPENUWARP_UPGRADE_LOG
			return 2
		else
			return 1
		fi
	elif [ $COUNT -eq 1 ]; then
		cd $USB_MOUNT_DIR
		UPGRADE_FILENAME=`/bin/ls openwrt-ar71xx-generic-uwarp-ar7420-squashfs-*.bin`
		/bin/echo "NOTICE: Selecting firmware file \"$UPGRADE_FILENAME\" file on your USB key." >> $OPENUWARP_UPGRADE_LOG
		return 0
	elif [ $COUNT -gt 1 ]; then
		/bin/echo "ERROR: There can only be 1 openwrt-ar71xx-generic-uwarp-ar7420-squashfs-*.bin file on your USB key." >> $OPENUWARP_UPGRADE_LOG
		/bin/echo "ERROR: You have $COUNT of the files on your key. Please remove all but one of them!" >> $OPENUWARP_UPGRADE_LOG
		return 2
	else
		/bin/echo "ERROR: In checking for openwrt-ar71xx-generic-uwarp-ar7420-squashfs-*.bin file on your USB key." >> $OPENUWARP_UPGRADE_LOG
		return 1
	fi
}

# This function verifies it is a proper upgrade file.
# It returns 0 on successful copy and verification and
# 1 if any error occurs.
verify_upgrade_file () {
	/bin/echo "NOTICE: Attempting to verify file \"$1\" ...." >> $OPENUWARP_UPGRADE_LOG
	if [ -f $1 ]; then
		MAGIC=`cat $1 | dd bs=2 count=1 2>/dev/null | hexdump -v -n 2 -e '1/1 "%02x"'`
		if [ "$MAGIC" == "0100" ]; then
			/bin/echo "NOTICE: Upgrade file \"$1\" passed verification of MAGIC number." >> $OPENUWARP_UPGRADE_LOG
			return 0
		else
			/bin/echo "ERROR: Upgrade file \"$1\" failed verification of MAGIC number." >> $OPENUWARP_UPGRADE_LOG
			return 1
		fi
	else
		/bin/echo "ERROR: Cannot find upgrade file \"$1\"" >> $OPENUWARP_UPGRADE_LOG
		return 1
	fi
}

do_upgrade () {
	cd $USB_MOUNT_DIR
	if [ -f $UPGRADE_FILENAME ]; then
		# mark that we are burning file
		echo "Attempted burn at:" > $OPENUWARP_BURN_TEST_FILE
		date >> $OPENUWARP_BURN_TEST_FILE
		sync
		# start upgrade process
		/bin/echo "NOTICE: Stopping processes ..."  >> $OPENUWARP_UPGRADE_LOG
		kill_processes
		kill_remaining
		sleep 1
		# remount tmp and copy upgrade script to it
		/bin/mount tmpfs /tmp -t tmpfs -o remount,size=20m,nosuid,nodev
		sleep 1
		/bin/echo "NOTICE: Copying $UPGRADE_FILENAME file to /tmp" >> $OPENUWARP_UPGRADE_LOG
		/bin/cp -f $USB_MOUNT_DIR/$UPGRADE_FILENAME /tmp
		/bin/echo "NOTICE: Finished copying $UPGRADE_FILENAME file to /tmp" >> $OPENUWARP_UPGRADE_LOG
		verify_upgrade_file /tmp/$UPGRADE_FILENAME
		if [ $? -ne 0 ]; then
			return 1
		fi
		/bin/echo "NOTICE: Upgrading system using file \"$UPGRADE_FILENAME\" ..."  >> $OPENUWARP_UPGRADE_LOG
		# if factory image do not preserve settings
		echo "$UPGRADE_FILENAME" | grep -q factory
		if [ $? -eq 0 ]; then
			/sbin/sysupgrade -v -n /tmp/$UPGRADE_FILENAME >> $OPENUWARP_UPGRADE_LOG
		else
			/sbin/sysupgrade -v /tmp/$UPGRADE_FILENAME >> $OPENUWARP_UPGRADE_LOG
		fi
		return 0
	else
		/bin/echo "ERROR: Upgrade file \"$UPGRADE_FILENAME\" not found!" >> $OPENUWARP_UPGRADE_LOG
		return 1
	fi
}

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

# check if mount in /lib/udev/rules.d/11-usb-auto-mount.rules was successful
/bin/mount | grep -q "/dev/$1 "
if [ $? -eq 0 ]; then
	USB_MOUNT_DIR="/mnt/usbhd-$1"
	OPENUWARP_LOG_DIR="$USB_MOUNT_DIR/uwarp"
	mkdir -p $OPENUWARP_LOG_DIR
	OPENUWARP_INFO_LOG="$OPENUWARP_LOG_DIR/uwarp-info.txt"
	OPENUWARP_UPGRADE_LOG="$OPENUWARP_LOG_DIR/uwarp-upgrade.log"
	OPENUWARP_BURN_TEST_FILENAME="uwarp-image.burnt"
	OPENUWARP_BURN_TEST_FILE="$USB_MOUNT_DIR/$OPENUWARP_BURN_TEST_FILENAME"
else
	/usr/bin/logger -s -t USBMOUNT -p 1 "Device, /dev/$1, was not mounted. Remove it's directory!!"
	if [ -d /mnt/usbhd-$1 ]; then
		/bin/rm -rf /mnt/usbhd-$1
	else
		/usr/bin/logger -s -t USBMOUNT -p 1 "Device, /dev/$1, directory /mnt/usbhd-$1 not found!!"
	fi
	exit 1
fi

# add header to current log entry
echo "" >> $OPENUWARP_UPGRADE_LOG
echo "==============================" >> $OPENUWARP_UPGRADE_LOG
date >> $OPENUWARP_UPGRADE_LOG
echo "==============================" >> $OPENUWARP_UPGRADE_LOG
echo "" >> $OPENUWARP_UPGRADE_LOG

# check if there is an update file, run it if found
check_for_upgrade_file
FILECHECK=$?
if [ $FILECHECK -eq 0 ]; then
	/usr/bin/logger -s -t USBMOUNT -p 5  "Upgrade file found."
	verify_upgrade_file $USB_MOUNT_DIR/$UPGRADE_FILENAME
	if [ $? -eq 0 ]; then
		do_upgrade
		if [ $? -eq 0 ]; then
			/bin/sync
			/bin/umount $USB_MOUNT_DIR
			/sbin/reboot
			exit 0
		else
			set_exit_leds
			exit 1
		fi
	fi
elif [ $FILECHECK -eq 2 ]; then
	echo "NOTICE: There is an invalid upgrade file found." >> $OPENUWARP_UPGRADE_LOG
	set_exit_leds
	exit 1
elif [ $FILECHECK -eq 3 ]; then
	/bin/echo "NOTICE: the firmware file has already burnt. Remove the \"$OPENUWARP_BURN_TEST_FILENAME\" file on your USB key if you want to burn again." >> $OPENUWARP_UPGRADE_LOG
else
	echo "NOTICE: No upgrade file found." >> $OPENUWARP_UPGRADE_LOG
fi

# create uWARP info file on USB key
/usr/bin/logger -s -t USBMOUNT -p 1 "Creating info file on USB key at, $OPENUWARP_INFO_LOG"
/bin/echo "" > $OPENUWARP_INFO_LOG
/bin/echo "##########################################################" >> $OPENUWARP_INFO_LOG
date >> $OPENUWARP_INFO_LOG
/bin/echo "Version: `cat /etc/openwrt_version`" >> $OPENUWARP_INFO_LOG
/bin/echo "##########################################################" >> $OPENUWARP_INFO_LOG
/bin/echo "" >> $OPENUWARP_INFO_LOG
/bin/echo "Network info:" >> $OPENUWARP_INFO_LOG
/bin/echo "" >> $OPENUWARP_INFO_LOG
/sbin/ifconfig -a  >> $OPENUWARP_INFO_LOG
/bin/echo "" >> $OPENUWARP_INFO_LOG
/bin/echo "##########################################################" >> $OPENUWARP_INFO_LOG
/bin/echo "" >> $OPENUWARP_INFO_LOG


/bin/sync
set_exit_leds
exit 0
