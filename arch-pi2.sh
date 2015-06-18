#!/usr/bin/env bash

INSTALL_HOME=$( cd "`dirname "${BASH_SOURCE[0]}"`" && pwd )
INSTALL_SCRIPT="`basename "${BASH_SOURCE[0]}"`"
INSTALL_NAME="`printf "$INSTALL_SCRIPT" | awk -F '.' '{ print $1 }'`"

doPrint() {
	printf "[$INSTALL_NAME] $*\n"
}

doPrintHelpMessage() {
	printf "Usage: ./$INSTALL_SCRIPT [-h] [-c config] [target [options...]]\n"
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
	INSTALL_CONFIG="$INSTALL_HOME/$INSTALL_NAME.conf"
fi

if [ ! -f "$INSTALL_CONFIG" ]; then
	printf "ERROR: Config file not found ('$INSTALL_CONFIG')\n"
	exit 1
fi

. "$INSTALL_CONFIG"

# =================================================================================
#    F U N C T I O N S
# =================================================================================

doConfirmInstall() {
	doPrint "Installing to '$INSTALL_DEVICE' - ALL DATA ON IT WILL BE LOST!"
	doPrint "Enter 'YES' (in capitals) to confirm:"
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
		dd if=/dev/zero of="$INSTALL_DEVICE_HOME/$i" bs=1M count=1
	done

	doFlush
}

doPartProbe() {
	partprobe "$INSTALL_DEVICE"
}

doDeleteAllPartitions() {
	fdisk "$INSTALL_DEVICE" << __END__
o
w
__END__

	doFlush
	doPartProbe
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
	parted -s -a optimal "$INSTALL_DEVICE" mkpart primary linux-swap "${START}MiB" "${END}MiB"

	START="$END"; END="100%"
	parted -s -a optimal "$INSTALL_DEVICE" mkpart primary linux-swap "${START}MiB" "${END}MiB"

	parted -s -a optimal "$INSTALL_DEVICE" toggle 1 boot

	doFlush
	doPartProbe
}

doSetNewPartitionTypes() {
	fdisk "$INSTALL_DEVICE" << __END__
t
1
$BOOT_PARTITION_TYPE
t
2
$ROOT_PARTITION_TYPE
w
__END__

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
	if [ ! -e "`basename "$ARCH_LINUX_DOWNLOAD"`" ] || [ "$ARCH_LINUX_DOWNLOAD_FORCE" == "yes" ]; then
		rm -f "`basename "$ARCH_LINUX_DOWNLOAD"`"
		wget "$ARCH_LINUX_DOWNLOAD"
	fi
}

doUnpackArchLinux() {
	bsdtar -xpf "`basename "$ARCH_LINUX_DOWNLOAD"`" -C root

	doFlush
}

doMoveBoot() {
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

doSetNetwork() {
	cat > root/etc/systemd/network/eth0.network << __END__
[Match]
Name=eth0

[Network]
DNS=$NETWORK_DNS

[Address]
Address=$NETWORK_ADDRESS

[Route]
Gateway=$NETWORK_GATEWAY
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

doUnmount() {
	umount boot
	rmdir boot

	umount root
	rmdir root
}

# =================================================================================
#    M A I N
# =================================================================================

doConfirmInstall

doWipeAllPartitions
doDeleteAllPartitions
doWipeDevice

doCreateNewPartitionTable "$PARTITION_TABLE_TYPE"

doCreateNewPartitions
doSetNewPartitionTypes
doDetectDevices

doFormat
doMount

doDownloadArchLinux
doUnpackArchLinux

doSetHostname "$HOSTNAME"
doSetTimezone "$TIMEZONE"

if [ "$SET_NETWORK" == "yes" ]; then
	doSetNetwork
fi

if [ "$SYMLINK_HASH_COMMANDS" == "yes" ]; then
	doSymlinkHashCommands
fi

if [ "$OPTIMIZE_SWAPPINESS" == "yes" ]; then
	doOptimizeSwappiness
fi

doUnmount

doPrint "Wake up, Neo... The installation is done!"

exit 0
