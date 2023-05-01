#!/bin/bash

### this script makes everything to build a ready to boot .iso file of nanodesk
###
### By: DeltaLima
### 2023

CHROOTCMD="sudo chroot build/chroot/"

message () {
  echo "== " $1
}

error () 
{
  message "ERROR!!"
  exit 1
}

check_requirements () {
  echo "we are checking for requirements"
  # ~fakeroot fakechroot~
  # debootstrap chroot 
  ### https://www.willhaley.com/blog/custom-debian-live-environment/
  sudo apt install \
    debootstrap \
    squashfs-tools \
    xorriso \
    isolinux \
    syslinux-efi \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub-efi-ia32-bin \
    mtools \
    dosfstools chroot


}

### stuff begins here
test -f build/chroot || mkdir -p build/chroot

###fakeroot -s build/fakechroot.save fakechroot debootstrap --variant=fakechroot bullseye build/chroot/ http://ftp.de.debian.org/debian
###fakechroot fakeroot debootstrap bullseye build/chroot/ http://ftp.de.debian.org/debian

### i have the problem, that fakechroot will not work atm. in ubuntu 22.04 i get libc6 version mismatch errors. so we run it direct as root. not my favorite, but works for now.

sudo debootstrap bullseye build/chroot/ http://ftp.de.debian.org/debian || sudo debootstrap bullseye build/chroot/ http://ftp.de.debian.org/debian 
cat <<EOF > build/chroot/tmp/install_base.sh
#!/bin/bash
echo nanodesk > /etc/hostname
DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND
apt install -y --no-install-recommends \\
	linux-image-generic \\
	grub-pc \\
	ifupdown \\
	man \\
	console-data \\
	locales \\
	xserver-xorg \\
	jwm \\
	xdm \\
	xterm \\
	xfe \\
	pcmanfm \\
	audacious \\
	htop \\
	host \\
	mc \\
	wget \\
	curl \\
	less \\
	vim \\
	links2
echo -e "debian\ndebian" | (passwd root)
useradd -m -s /bin/bash debian
echo -e "debian\ndebian" | (passwd debian)
#https://serverfault.com/a/689947
# Configure timezone and locale
echo "Europe/Berlin" > /etc/timezone && \\
    dpkg-reconfigure -f noninteractive tzdata && \\
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \\
    echo 'LANG="en_US.UTF-8"'>/etc/default/locale && \\
    dpkg-reconfigure --frontend=noninteractive locales && \\
    locale-gen en_US.UTF-8 && \\
    update-locale LANG=en_US.UTF-8
##dpkg-reconfigure locales
##dpkg-reconfigure console-data
##dpkg-reconfigure keyboard-configuration
EOF
$CHROOTCMD /bin/bash /tmp/install_base.sh || error
