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

message "set hostname in hosts"
sed -i 's/localhost/localhost nanodesk/g' /etc/hosts

### noninteractive
DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

##message "activate contrib and non-free repositories"
##sed -i 's/main$/main contrib non-free/g' /etc/apt/sources.list || error
##
##message "activate backports repository"
##sed 's/bullseye/bullseye-backports/g' /etc/apt/sources.list > /etc/apt/sources.list.d/bullseye-backports.list || error

message "apt-get update"
apt-get update || error

### install base packages --no-install-recommends
message "install nanodesk minimal base packages (apt-get install --no-install-recommends)"
#apt install -y \
apt-get install -y --no-install-recommends \
  linux-image-amd64 \
  firmware-linux \
  firmware-linux-nonfree \
  firmware-zd1211 firmware-ti-connectivity \
  firmware-realtek firmware-netxen firmware-netronome firmware-myricom \
  firmware-libertas firmware-iwlwifi \
  firmware-intel-sound firmware-cavium firmware-brcm80211 firmware-bnx2x \
  firmware-bnx2 firmware-atheros firmware-ath9k-htc \
  firmware-ast firmware-carl9170 firmware-cirrus firmware-intel-graphics firmware-intel-misc \
  firmware-mediatek firmware-nvidia-graphics firmware-qcom-media \
  live-boot \
  live-config \
  live-config-systemd \
  systemd-sysv \
  dialog \
  sudo \
  console-data \
  bash-completion \
  locales \
  man \
  unzip \
  zip \
  bzip2 \
  zstd \
  grub-pc \
  host \
  wireless-tools \
  unrar \
  p7zip-full \
  xz-utils \
  wpagui \
  xserver-xorg \
  xscreensaver \
  xfonts-75dpi \
  xfonts-100dpi \
  fonts-noto-color-emoji \
  x11-apps \
  x11-utils \
  xdg-utils \
  xdg-user-dirs \
  xterm \
  xdm \
  jwm \
  mc \
  wget \
  curl \
  less \
  openssh-client \
  rsync \
  vim \
  links2 \
  ncdu \
  htop \
  git \
  telnet \
  netcat-traditional \
  gxmessage \
  gsimplecal \
  alsa-utils \
  volumeicon-alsa \
  arandr \
  xfe \
  xarchiver \
  qpdfview \
  lxterminal \
  lxpolkit \
  gparted \
  dillo \
  falkon \
  gtk2-engines \
  gnome-themes-extra \
  adwaita-qt \
  adwaita-icon-theme \
  gnome-icon-theme \
  lxde-icon-theme \
  tango-icon-theme \
  squashfs-tools \
  synaptic \
  imagemagick \
  ifstat \
  /tmp/xdgmenumaker*.deb || error

message "install nanodesk base packages with recommends"
apt-get install -y \
  grub-pc \
  network-manager \
  network-manager-gnome \
  net-tools \
  isc-dhcp-client \
  host \
  wireless-tools \
  gvfs-common \
  pcmanfm \

#message "install linux-kernel from backports"
#apt install -t bullseye-backports -y linux-image-amd64


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

######
####
##
## customization can be done here
##  
####  
######

message "run custom steps from /tmp/install_base.customsteps.sh"
. /tmp/install_base.customsteps.sh

######
#### 
## 
##  / customization End /
##
####
######

### clean cache
message "apt-get clean"
apt-get clean

KERNEL_VER="$(ls -1 /boot/|grep "vmlinuz-"|sed 's/vmlinuz-//'|sort -g|head -n +1)" 
test -n "$KERNEL_VER" || error
message "KERNEL_VER=${YELLOW}${KERNEL_VER}${ENDCOLOR}"

### but fetch packages for grub and kernel, so we do not need to download them
### in case nanodesk get installed to diska
message "apt-get --download linux-image and grub packages to have them in cache for nanodesk-installer.sh offline installation"
apt-get -d --reinstall install \
	linux-image-amd64 \
	linux-image-$KERNEL_VER \
	grub-pc grub-pc-bin \
	grub-common \
	grub2-common \
	os-prober || error
