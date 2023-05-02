#!/bin/bash

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"

function message() {
     case $1 in
     error)
       MESSAGE_TYPE="${RED}ERROR${ENDCOLOR}"
     ;;
     info|*)
       MESSAGE_TYPE="${GREEN}INFO${ENDCOLOR}"
     ;;
     esac

     if [ "$1" == "info" ] || [ "$1" == "error" ]
     then
       MESSAGE=$2
     else
       MESSAGE=$1
     fi

     echo -e "[${MESSAGE_TYPE}] ${YELLOW}install_base${ENDCOLOR}: $MESSAGE"
}


error () 
{
  message error "ERROR!!"
  exit 1
}

### hostname setting
echo nanodesk > /etc/hostname

### noninteractive
DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

message "activate contrib and non-free repositories"
sed -i 's/main$/main contrib non-free/g' /etc/apt/sources.list || error

message "activate backports repository"
sed 's/bullseye/bullseye-backports/g' /etc/apt/sources.list > /etc/apt/sources.list.d/bullseye-backports.list || error

message "apt update"
apt update || error

### packages
message "install nanodesk base packages"
apt install -y  \
	live-boot \
	dialog \
	sudo \
	console-data \
	locales \
	man \
	grub-pc \
	ifupdown \
	net-tools \
	isc-dhcp-client \
	host \
	wireless-tools \
	wpagui \
	connman-gtk \
	connman-ui \
	xserver-xorg \
	xscreensaver \
	xfonts-75dpi \
	xfonts-100dpi \
	xterm \
	xdm \
	jwm \
	xfe \
	mc \
	wget \
	curl \
	less \
	rsync \
	vim \
	links2 \
	ncdu \
	htop \
	git \
	gxmessage \
	arandr \
	lxterminal \
	gparted \
	firefox-esr \
	pcmanfm \
	/tmp/xdgmenumaker*.deb || error

######
####
##
## customization can be done here
##  the placeholder within '%%' gets 
####  filled by makeanything.sh
######

message "install custom packages from templates/install_base.custompkg.tpl.sh"
. /tmp/install_base.custompkg.tpl.sh

######
#### it's a simple sudo 
## command
##  / customization End /
##
####
######



message "install linux-kernel from backports"
apt install -t bullseye-backports -y linux-image-amd64

message "set hostname in hosts"
sed -i 's/localhost/localhost nanodesk/g' /etc/hosts

### set root password
message "set root password to 'debian'"
echo -e "debian\ndebian" | (passwd root)

### add debian user
message "create user debian"
useradd -m -U -s /bin/bash debian

### set password
message "set password for user debian to 'debian'"
echo -e "debian\ndebian" | (passwd debian)

### Configure timezone and locale
#dpkg-reconfigure locales
#dpkg-reconfigure console-data
#dpkg-reconfigure keyboard-configuration
###https://serverfault.com/a/689947

message "set locales and tzdata"
echo "Europe/Berlin" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata && \
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    echo 'LANG="en_US.UTF-8"'>/etc/default/locale && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8

### clean cache
message "apt clean"
apt clean

KERNEL_VER="$(ls -1 /boot/|grep "vmlinuz-"|sed 's/vmlinuz-//'|sort -g|head -n +1)" 
test -n "$KERNEL_VER" || error
message "KERNEL_VER=${YELLOW}${KERNEL_VER}${ENDCOLOR}"

### but fetch packages for grub and kernel, so we do not need to download them
### in case nanodesk get installed to diska
message "apt --download linux-image and grub packages to have them in cache for installation by user"
apt -d --reinstall install \
	linux-image-amd64 \
	$KERNEL_VER \
	grub-pc grub-pc-bin \
	grub-common \
	grub2-common \
	os-prober || error
