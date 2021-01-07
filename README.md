# arch-pi
A simple script installing [Arch Linux](https://www.archlinux.org/) on an SD
card for the
[Raspberry Pi](https://www.raspberrypi.org/products/).

The script supports the following hardware models of the
Raspberry Pi:

* Raspberry Pi Model A/A+/B/B+, Compute Module, Zero, Zero W (ARMv6)
* Raspberry Pi 2 Model B (ARMv7)
* Raspberry Pi 3 Model B/B+ (ARMv8, but using ARMv7)
* Raspberry Pi 4 Model B (ARMv8, but using ARMv7)

**NOTE:** For the time being, the Raspberry Pi 3 Model B will install the ARMv7
version of Arch Linux also used by the Raspberry Pi 2 Model B.

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

### Initialize Pacman

Before you can install additional packages, you must initialize the pacman
keyring and populate the Arch Linux ARM package signing keys.

Login as `root` and type in:

```
pacman-key --init && pacman-key --populate archlinuxarm
```

After Pacman is initialized, it's probably a good idea to check for available
package updates:

```
pacman -Syyu
```

That's it!

### Installing Yay or Yaourt

`arch-pi`
can also download the packages required for installing
[Yay](https://github.com/Jguer/yay) or
[Yaourt](https://github.com/archlinuxfr/yaourt), by changing the `DOWNLOAD_YAY`
or `DOWNLOAD_YAOURT` settings. Both Yay and Yaourt in turn allow you to install
packages from the [AUR](https://aur.archlinux.org/).

**NOTE:** Yaourt is not maintained anymore.

Before you can install Yay or Yaourt, you first have to set up a build
environment, so login as `root` (password is `root`) and type in:

```
pacman -Syy --noconfirm --needed base-devel sudo
```

Next, configure `sudo`, allowing members of the group `wheel` to use it by
editing the `sudoers` file:

```
nano -w /etc/sudoers
```

Remove the leading `#` from the following line to uncomment it:

```
%wheel ALL=(ALL) ALL
```

Save the `sudoers` file by pressing `Ctrl-X`, `y`, `Enter` and then logout:

```
logout
```

Login again, but this time as the user `alarm` (password is `alarm`), and change
to the directory containing the Yaourt packages:

```
cd /home/alarm/software/aaa.dist
```

**NOTE:** The Yay and Yaourt packages are in `/home/alarm/software/aaa.dist`
unless you changed the `YAY_PATH` or `YAOURT_PATH` settings.

To install Yay:

```
tar xvf yay.tar.gz
cd yay
makepkg -i -s --noconfirm --needed

cd ..
```

To install Yaourt:

```
tar xvf package-query.tar.gz
cd package-query
makepkg -i -s --noconfirm --needed

cd ..

tar xvf yaourt.tar.gz
cd yaourt
makepkg -i -s --noconfirm --needed

cd ..
```

After Yay or Yaourt is installed, you can check for available package updates:

Using Yay:

```
yay -Syyu
```

Using Yaourt:

```
yaourt -Syyua
```

If there are, just follow the instructions on the screen.

That's it!

### Using an Alternative Configuration File

You can use an alternative configuration file by passing it to the installation
script:

```
arch-pi-master/arch-pi.sh -c my.conf
```

## License

This software is distributed under the terms of the
[GNU General Public License v3](https://www.gnu.org/licenses/gpl-3.0.en.html).
