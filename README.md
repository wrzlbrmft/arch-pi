# arch-pi2
A simple script installing [Arch Linux](https://www.archlinux.org/) on an SD
card for the
[Raspberry Pi 2](https://www.raspberrypi.org/products/raspberry-pi-2-model-b/).

The installation procedure pretty much matches the
[Arch Linux ARM Installation Guide](http://archlinuxarm.org/platforms/armv7/broadcom/raspberry-pi-2),
but also adds some configuration settings like networking, including a static IP
address for a fully screen-less setup.

## Requirements

In order to use
`arch-pi2`,
you need a Linux environment (Mac support is on its way...) which is online and
an SD card slot.

For the Linux environment, you can also use a Live-CD like
[Xubuntu](http://xubuntu.org/). Just make sure the following commands are
available:

* `lsblk`
* `fdisk`
* `dd`
* `parted`
* `wget`
* `tar`

## Usage Guide

In a Terminal download and unpack the latest version of
`arch-pi2`:

```
wget -O - https://github.com/wrzlbrmft/arch-pi2/archive/master.tar.gz | tar zxvf -
```

Insert the SD card on which you want to install Arch Linux, but make sure none
of its partitions is mounted, otherwise unmount them. Then determine the device
name of the SD card, e.g. `/dev/mmcblk0`, and open the configuration file:

```
vi arch-pi2-master/arch-pi2.conf
```

Make sure the `INSTALL_DEVICE` setting matches the device name of your SD card.

You may also want to change the following settings:

* `HOSTNAME`
* `TIMEZONE`
* `NETWORK_ADDRESS`, `NETWORK_GATEWAY` and `NETWORK_DNS`

Once you are done, save and close the configuration file.

To write and format partitions on the SD card,
`arch-pi2`
needs super-user privileges. So `su` to `root` or use `sudo` to start the
installation process:

```
sudo arch-pi2-master/arch-pi2.sh
```

**CAUTION:** The installation will delete *all* existing data on the SD card.

The installation is done, once you see

```
[arch-pi2] Wake up, Neo... The installation is done!
```

Then insert the SD card into your Raspberry Pi 2 and start it up.

That's it!

You can login as the default user `alarm` with the password `alarm`.
The default root password is `root`.

### Using an Alternative Configuration File

You can use an alternative configuration file by passing it to the installation
script:

```
arch-pi2-master/arch-pi2.sh -c my.conf
```

## License

This software is distributed under the terms of the
[GNU General Public License v3](https://www.gnu.org/licenses/gpl-3.0.en.html).
