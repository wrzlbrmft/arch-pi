# arch-pi
A simple script installing [Arch Linux](https://www.archlinux.org/) on an SD
card for the
[Raspberry Pi](https://www.raspberrypi.org/products/).

The script is capable of installing both the ARMv6 and ARMv7 version of Arch
Linux supporting all current models of the Raspberry Pi, including the very
latest [Raspberry Pi Zero](https://www.raspberrypi.org/blog/raspberry-pi-zero/).

* Raspberry Pi Model A/A+/B/B+, Compute Module, Zero (ARMv6)
* Raspberry Pi 2 Model B (ARMv7)

The installation procedure pretty much matches the Installation Guides from
[Arch Linux ARM](http://archlinuxarm.org/),
but also adds some configuration settings like networking, including a static IP
address for a fully headless setup without a screen or keyboard.

After the installation you can directly login to your
Raspberry Pi
using the pre-configured IP address.

## Requirements

In order to use
`arch-pi`,
you need an extra Linux environment (Mac support not quite there...) which is
connected to the Internet and has an SD card slot.

For the Linux environment, you can also use a Live-CD like
[Xubuntu](http://xubuntu.org/). Just make sure the following commands are
available:

* `lsblk`
* `dd`
* `parted`
* `curl`
* `tar`

## Usage Guide

In a Terminal download and unpack the latest version of
`arch-pi`:

```
curl -L https://github.com/wrzlbrmft/arch-pi/archive/master.tar.gz | tar zxvf -
```

Insert the SD card on which you want to install Arch Linux, but make sure none
of its partitions is mounted, otherwise unmount them. Then use `lsblk` to
determine the device name of the SD card, e.g. `/dev/mmcblk0`, and open the
configuration file:

```
vi arch-pi-master/arch-pi.conf
```

Make sure the `INSTALL_DEVICE` setting matches the device name of your SD card.

You may also want to change the following settings:

* `HOSTNAME`
* `TIMEZONE`
* `CONSOLE_KEYMAP`
* `SET_ETHERNET` -- if set to `YES`, then also check the other `ETHERNET_*` settings
* `SET_WIRELESS` -- if set to `YES`, then also check the other `WIRELESS_*` settings

Once you are done, save and close the configuration file.

To write and format partitions on the SD card,
`arch-pi`
needs super-user privileges. So `su` to `root` or use `sudo` to start the
installation process:

```
sudo arch-pi-master/arch-pi.sh
```

**CAUTION:** The installation will delete *all* existing data on the SD card.

The installation is done, once you see

```
[arch-pi] Wake up, Neo... The installation is done!
```

Then insert the SD card into your
Raspberry Pi
and start it up.

That's it!

You can login as the default user `alarm` with the password `alarm`.
The default root password is `root`.

### Wireless Networking

Unfortunately, the Arch Linux ARM distribution does not contain all packages
required for wireless networking out of the box, namely:

* `crda`
* `dialog`
* `iw`
* `libnl`
* `wireless-regdb`
* `wpa_supplicant`

However, during the installation process
`arch-pi`
downloads these packages to the SD card. While the configuration is already done
according to the `SET_WIRELESS` and `WIRELESS_*` settings, you just have to
install the packages to get wireless networking up and running.

After booting your
Raspberry Pi
from the SD card, login as `root` (password is `root`) and type in:

```
pacman -U /root/software/aaa.dist/*.tar.xz
```

**NOTE:** The packages are in `/root/software/aaa.dist` unless you changed the
`DOWNLOAD_PACKAGE_SETS_PATH` setting.

The installation is configured to automatically connect to the given wireless
network, so simply reboot you are online.

### Using an Alternative Configuration File

You can use an alternative configuration file by passing it to the installation
script:

```
arch-pi-master/arch-pi.sh -c my.conf
```

## License

This software is distributed under the terms of the
[GNU General Public License v3](https://www.gnu.org/licenses/gpl-3.0.en.html).
