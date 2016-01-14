#!/usr/bin/env bash

SCRIPT_HOME=$( cd "`dirname "${BASH_SOURCE[0]}"`" && pwd )
SCRIPT_FILENAME="`basename "${BASH_SOURCE[0]}"`"
SCRIPT_NAME="`printf "$SCRIPT_FILENAME" | awk -F '.' '{ print $1 }'`"

doPrintPrompt() {
	printf "[$SCRIPT_NAME] $*"
}

doPrint() {
	doPrintPrompt "$*\n"
}

doPrintHelpMessage() {
	printf "Usage: ./$SCRIPT_FILENAME [-h] [-c config]\n"
}

while getopts :hc: opt; do
	case "$opt" in
		h)
			doPrintHelpMessage
			exit 0
			;;

		c)
			INSTALL_CONFIG="$OPTARG"
			;;

		:)
			printf "ERROR: "
			case "$OPTARG" in
				c)
					printf "Missing config file"
					;;
			esac
			printf "\n"
			exit 1
			;;

		\?)
			printf "ERROR: Invalid option ('-$OPTARG')\n"
			exit 1
			;;
	esac
done
shift $((OPTIND - 1))

if [ -z "$INSTALL_CONFIG" ]; then
	INSTALL_CONFIG="$SCRIPT_HOME/$SCRIPT_NAME.conf"
fi

if [ ! -f "$INSTALL_CONFIG" ]; then
	printf "ERROR: Config file not found ('$INSTALL_CONFIG')\n"
	exit 1
fi

. "$INSTALL_CONFIG"

# =================================================================================
#    F U N C T I O N S
# =================================================================================

doSelectRaspberryPi() {
	local i=0

	if [ -z "$RASPBERRY_PI_SELECT" ]; then
		doPrint "Select Raspberry Pi"

		local j=1
		while [ "$i" -lt "${#RASPBERRY_PI[@]}" ]; do
			doPrint "$j = ${RASPBERRY_PI[$i]}"
			let i=i+3
			let j=j+1
		done

		doPrintPrompt "> "
		read i
		if [[ ! $i =~ ^[0-9]+$ ]] || [ ! "$i" -gt "0" ] || [ ! "$i" -lt "$j" ]; then
			printf "ERROR: Invalid selection ('$i')\n"
			exit 1
		else
			RASPBERRY_PI_SELECT="$i"
		fi
	fi

	let i=$RASPBERRY_PI_SELECT*3-3
	doPrint "Installing for ${RASPBERRY_PI[$i]}"

	let i=i+1
	ARCH_LINUX_DOWNLOAD="${RASPBERRY_PI[$i]}"

	let i=i+1
	ARCH_LINUX_PACKAGES_URL="${RASPBERRY_PI[$i]}"
}

doConfirmInstall() {
	doPrint "Installing to '$INSTALL_DEVICE' - ALL DATA ON IT WILL BE LOST!"
	doPrint "Enter 'YES' (in capitals) to confirm and start the installation."

	doPrintPrompt "> "
	read i
	if [ "$i" != "YES" ]; then
		doPrint "Aborted."
		exit 0
	fi

	for i in {10..1}; do
		doPrint "Starting in $i - Press CTRL-C to abort..."
		sleep 1
	done
}

getAllPartitions() {
	lsblk -l -n -o NAME "$INSTALL_DEVICE" | grep -v "^$INSTALL_DEVICE_NAME$"
}

doFlush() {
	sync
	sync
	sync
}

doWipeAllPartitions() {
	for i in $( getAllPartitions | sort -r ); do
		umount "$INSTALL_DEVICE_HOME/$i"
		dd if=/dev/zero of="$INSTALL_DEVICE_HOME/$i" bs=1M count=1
	done

	doFlush
}

doPartProbe() {
	partprobe "$INSTALL_DEVICE"
}

doWipeDevice() {
	dd if=/dev/zero of="$INSTALL_DEVICE" bs=1M count=1

	doFlush
	doPartProbe
}

doCreateNewPartitionTable() {
	parted -s -a optimal "$INSTALL_DEVICE" mklabel "$1"
}

doCreateNewPartitions() {
	local START="1"; local END="$BOOT_SIZE"
	case "$BOOT_FILESYSTEM" in
		fat32)
			parted -s -a optimal "$INSTALL_DEVICE" mkpart primary "$BOOT_FILESYSTEM" "${START}MiB" "${END}MiB"
			;;

		*)
			parted -s -a optimal "$INSTALL_DEVICE" mkpart primary "${START}MiB" "${END}MiB"
			;;
	esac

	START="$END"; END="100%"
	parted -s -a optimal "$INSTALL_DEVICE" mkpart primary "${START}MiB" "${END}MiB"

	parted -s -a optimal "$INSTALL_DEVICE" set 1 boot on

	doFlush
	doPartProbe
}

doDetectDevices() {
	local ALL_PARTITIONS=($( getAllPartitions ))

	BOOT_DEVICE="$INSTALL_DEVICE_HOME/${ALL_PARTITIONS[0]}"
	ROOT_DEVICE="$INSTALL_DEVICE_HOME/${ALL_PARTITIONS[1]}"
}

doMkfs() {
	case "$1" in
		fat32)
			mkfs -t fat -F 32 -n "$2" "$3"
			;;

		*)
			mkfs -t "$1" -L "$2" "$3"
			;;
	esac
}

doFormat() {
	doMkfs "$BOOT_FILESYSTEM" "$BOOT_LABEL" "$BOOT_DEVICE"
	doMkfs "$ROOT_FILESYSTEM" "$ROOT_LABEL" "$ROOT_DEVICE"
}

doMount() {
	mkdir -p root
	mount "$ROOT_DEVICE" root
	mkdir -p boot
	mount "$BOOT_DEVICE" boot
}

doDownloadArchLinux() {
	if [ ! -f "`basename "$ARCH_LINUX_DOWNLOAD"`" ] || [ "$ARCH_LINUX_DOWNLOAD_FORCE" == "yes" ]; then
		rm -f "`basename "$ARCH_LINUX_DOWNLOAD"`"
		curl --retry 999 --retry-delay 0 --retry-max-time 300 --speed-time 10 --speed-limit 0 \
			-LO "$ARCH_LINUX_DOWNLOAD"
	fi
}

doUnpackArchLinux() {
	tar xvf "`basename "$ARCH_LINUX_DOWNLOAD"`" -C root -p
}

doFinalizeBoot() {
	mv root/boot/* boot

	doFlush
}

doSetHostname() {
	cat > root/etc/hostname << __END__
$1
__END__
}

doSetTimezone() {
	ln -sf "/usr/share/zoneinfo/$1" root/etc/localtime
}

doSetConsole() {
	cat > root/etc/vconsole.conf << __END__
KEYMAP=$1
FONT=$2
__END__
}

doSetEthernetDhcp() {
	cat > "root/etc/systemd/network/$ETHERNET_INTERFACE.network" << __END__
[Match]
Name=$ETHERNET_INTERFACE

[Network]
DHCP=yes
__END__
}

doSetEthernetStatic() {
	cat > "root/etc/systemd/network/$ETHERNET_INTERFACE.network" << __END__
[Match]
Name=$ETHERNET_INTERFACE

[Network]
DNS=$ETHERNET_DNS

[Address]
Address=$ETHERNET_ADDRESS

[Route]
Gateway=$ETHERNET_GATEWAY
__END__
}

doSetWirelessDhcp() {
	cat > "root/etc/netctl/$WIRELESS_INTERFACE" << __END__
Interface=$WIRELESS_INTERFACE
Connection=wireless
Security=$WIRELESS_SECURITY
IP=dhcp
ESSID='$WIRELESS_ESSID'
Key='$WIRELESS_KEY'
Hidden=$WIRELESS_HIDDEN
__END__

	chmod 0600 "root/etc/netctl/$WIRELESS_INTERFACE"
}

doSetWirelessStatic() {
	cat > "root/etc/netctl/$WIRELESS_INTERFACE" << __END__
Interface=$WIRELESS_INTERFACE
Connection=wireless
Security=$WIRELESS_SECURITY
IP=static
Address=('$WIRELESS_ADDRESS')
Gateway='$WIRELESS_GATEWAY'
DNS=('$WIRELESS_DNS')
ESSID='$WIRELESS_ESSID'
Key='$WIRELESS_KEY'
Hidden=$WIRELESS_HIDDEN
__END__

	chmod 0600 "root/etc/netctl/$WIRELESS_INTERFACE"
}

doEnableWireless() {
	cat > "root/etc/systemd/system/netctl@$WIRELESS_INTERFACE.service" << __END__
.include /usr/lib/systemd/system/netctl@.service

[Unit]
BindsTo=sys-subsystem-net-devices-$WIRELESS_INTERFACE.device
After=sys-subsystem-net-devices-$WIRELESS_INTERFACE.device
__END__

	ln -s "/etc/systemd/system/netctl@$WIRELESS_INTERFACE.service" "root/etc/systemd/system/multi-user.target.wants/netctl@$WIRELESS_INTERFACE.service"
}

doDisableIpv6() {
	cat > root/etc/sysctl.d/40-ipv6.conf << __END__
ipv6.disable_ipv6=1
__END__
}

doBashLogoutClear() {
	cat >> root/root/.bash_logout << __END__
clear
__END__
}

doSshAcceptKeyTypeSshDss() {
	cat >> root/etc/ssh/ssh_config << __END__
Host *
  PubkeyAcceptedKeyTypes=+ssh-dss
__END__

	cat >> root/etc/ssh/sshd_config << __END__
PubkeyAcceptedKeyTypes=+ssh-dss
__END__
}

doSymlinkHashCommands() {
	ln -s /usr/bin/md5sum root/usr/local/bin/md5
	ln -s /usr/bin/sha1sum root/usr/local/bin/sha1
}

doOptimizeSwappiness() {
	cat > root/etc/sysctl.d/99-sysctl.conf << __END__
vm.swappiness=$OPTIMIZE_SWAPPINESS_VALUE
__END__
}

doDownloadPackage() {
	local REPOSITORY="`printf "$2" | awk -F '/' '{ print $1 }'`"
	local PACKAGE="`printf "$2" | awk -F '/' '{ print $2 }'`"

	local PACKAGE_FILE="`curl -sL "$ARCH_LINUX_PACKAGES_URL$REPOSITORY" | sed -e 's/<[^>]*>/ /g' | grep "$PACKAGE-.*xz[^.]" | awk '{ print \$1 }'`"
	local PACKAGE_FILE_DOWNLOAD="$ARCH_LINUX_PACKAGES_URL$REPOSITORY/$PACKAGE_FILE"

	doPrint ">>> [$1] $REPOSITORY/$PACKAGE ($PACKAGE_FILE_DOWNLOAD)"

	mkdir -p "root$DOWNLOAD_PACKAGE_SETS_PATH"
	curl --retry 999 --retry-delay 0 --retry-max-time 300 --speed-time 10 --speed-limit 0 \
		-L "$PACKAGE_FILE_DOWNLOAD" -o "root$DOWNLOAD_PACKAGE_SETS_PATH/$PACKAGE_FILE"
}

doDownloadPackageSets() {
	doPrint "Downloading package sets..."
	for i in $DOWNLOAD_PACKAGE_SETS; do
		for j in ${PACKAGE_SET[$i]}; do
			doDownloadPackage "$i" "$j"
		done
	done
}

doUnmount() {
	umount "$BOOT_DEVICE"
	rmdir boot

	umount "$ROOT_DEVICE"
	rmdir root
}

# =================================================================================
#    M A I N
# =================================================================================

doSelectRaspberryPi

doConfirmInstall

doWipeAllPartitions
doWipeDevice

doCreateNewPartitionTable "$PARTITION_TABLE_TYPE"

doCreateNewPartitions
doDetectDevices

doFormat
doMount

doDownloadArchLinux
doUnpackArchLinux

doFinalizeBoot

doSetHostname "$HOSTNAME"
doSetTimezone "$TIMEZONE"

doSetConsole "$CONSOLE_KEYMAP" "$CONSOLE_FONT"

if [ "$SET_ETHERNET" == "yes" ]; then
	if [ "$ETHERNET_DHCP" == "no" ]; then
		doSetEthernetStatic
	else
		doSetEthernetDhcp
	fi
fi

if [ "$SET_WIRELESS" == "yes" ]; then
	if [ "$WIRELESS_DHCP" == "no" ]; then
		doSetWirelessStatic
	else
		doSetWirelessDhcp
	fi

	doEnableWireless
fi

[ "$DISABLE_IPV6" == "yes" ] && doDisableIpv6

[ "$ROOT_USER_BASH_LOGOUT_CLEAR" == "yes" ] && doBashLogoutClear

[ "$SSH_ACCEPT_KEY_TYPE_SSH_DSS" == "yes" ] && doSshAcceptKeyTypeSshDss

[ "$SYMLINK_HASH_COMMANDS" == "yes" ] && doSymlinkHashCommands

[ "$OPTIMIZE_SWAPPINESS" == "yes" ] && doOptimizeSwappiness

[ ! -z "$DOWNLOAD_PACKAGE_SETS" ] && doDownloadPackageSets

doPrint "Flushing - this might take a while..."
doFlush

doUnmount

doPrint "Wake up, Neo... The installation is done!"

exit 0
