#!/bin/bash

### installer for nanodesk
### By: DeltaLima
### 2023
### 
### this is just a hobby, nothing serious. i know the debian installer and other
### exist, but i wanted to try some handcrafted installation.


CHROOTCMD="chroot /mnt/"

##message () {
##  echo "== " $1
##}

# colors for colored output 8)
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"

function message() {
     case $1 in
     warn)
       MESSAGE_TYPE="${YELLOW}WARN${ENDCOLOR}"
     ;;
     error)
       MESSAGE_TYPE="${RED}ERROR${ENDCOLOR}"
     ;;
     info|*)
       MESSAGE_TYPE="${GREEN}INFO${ENDCOLOR}"
     ;;
     esac

     if [ "$1" == "info" ] || [ "$1" == "warn" ] ||  [ "$1" == "error" ]
     then
       MESSAGE=$2
     else
       MESSAGE=$1
     fi

     echo -e "[${MESSAGE_TYPE}] $MESSAGE"
}

error () {
  message error "ERROR!"
  exit 1
}

finish () {
  message "removing firststart dialoge from jwm config"
  $CHROOTCMD /usr/bin/sed -i '/firstlogin\/welcome/d' /etc/jwm/system.jwmrc || error

  message "removing installer files from target"
  $CHROOTCMD /usr/bin/rm -Rf /root/nanodesk-installer.sh || error

  message "removing live-packages from target"
  $CHROOTCMD /usr/bin/apt -y purge 'live-boot*' 'live-tools*'

  message "autoremove unneeded dependencies"
  $CHROOTCMD /usr/bin/apt -y autoremove


  message "we are now ready to boot from $target"
  exit 0
}

if [ "$1" == "--help" ] || [ -z "$1" ] 
then
  echo "Usage: $0 [OPTION] TARGETDEVICE
Example: $0 /dev/sda1

TARGETDEVICE: blockdevice already formatted with filesystem like ext4

Options:
  --help: Show this helptext

  $0 trys to install grub into the mbr of the given targetdevice.
  We simply cut the last character away from the targetdevice,
  so /dev/sda1 gets /dev/sda, where grub will be installed."
  exit 1
fi

target="$1"
if [ ! -b "$target" ]
then
  message "$target does not exist or is not a blockdevice."
  error
fi

message "              ----==== nanodesk Installer ====----"
message "Make sure you have a linux compatible filesystem at $target"
message warn "!! The installer immediately begins to write things to disk !!"
message warn "!! The installer only works reliable with legacy BIOS boot  !!"
message
message "I will mount $target to /mnt/. I try to install grub to ${target::-1}"
message
message "Are you sure to install nanodesk to $target?"
message "To continue type 'YES' and enter, to cancel type anything else or CTRL+C"

read -p "> " DOINSTALL
test "$DOINSTALL" == "YES" || error

message "... GOOD LUCK!"
message "mounting $target to /mnt/"
mount $target /mnt || error

message "copy systemfiles"
rsync -aHx / /mnt/ || error

message "bind mount dev proc sys"
for m in dev proc sys
do
	mount -o bind /$m /mnt/$m || error
done

message "creating /boot directory"
mkdir -p /mnt/boot/ || error

message "create tmp script for reinstalling grub and kernel"
cat <<\EOF > /mnt/tmp/reinstall_kernel.sh
DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND
#/usr/bin/apt --yes purge 'linux-image-*' 'grub-*'
/usr/bin/apt --yes --reinstall install \
        linux-image-amd64 \
        %KERNEL_VER% \
        grub-pc grub-pc-bin \
        grub-common \
        grub2-common \
        os-prober
EOF

message "install kernel and grub"
$CHROOTCMD /bin/bash /tmp/reinstall_kernel.sh || error

message "modify /etc/default/grub"
$CHROOTCMD /usr/bin/sed -i 's/GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR=\"nanodesk \`cat \/usr\/share\/nanodesk\/version\`\"/g' /etc/default/grub

message "grub-install $target"
$CHROOTCMD grub-install ${target::-1} || error

message "create initramfs"
$CHROOTCMD /usr/sbin/update-initramfs.orig.initramfs-tools -k all -c || error

message "update-grub"
$CHROOTCMD /usr/sbin/update-grub || error

message "create fstab"
echo "UUID=$(blkid -o value -s UUID $target) / $(blkid -o value -s TYPE $target) defaults 0 1" >> /mnt/etc/fstab

message "activating swap if present in fstab"
SWAP="$(blkid -o list | grep swap | awk '{print $5}')"
test -n "$SWAP" && echo "UUID=$SWAP none swap defaults 0 0" >> /mnt/etc/fstab 

message "Cleanup and create own [U]ser or [K]eep everything as it is?"
read -p "> " USERSTEP

STEPFINISH=0
while [ $STEPFINISH != 1 ]
do
  case $USERSTEP in
    u|U)
      message "please change root pw"
      $CHROOTCMD /usr/bin/passwd root || error

      message "deleting user 'debian'"
      $CHROOTCMD /usr/bin/id -u debian && $CHROOTCMD /usr/sbin/userdel -f debian || error

      message "removing user 'debian' from sudoers"
      $CHROOTCMD /usr/bin/sed -i '/^debian/d' /etc/sudoers || error

      message "please enter a name for a new user"
      read -p "> " NEWUSER
      $CHROOTCMD /usr/sbin/adduser $NEWUSER || error

      message "adding $NEWUSER to sudo group"
      $CHROOTCMD /usr/sbin/usermod -G sudo $NEWUSER || error
      $CHROOTCMD /usr/bin/ln -s -f /usr/share/nanodesk/pixmaps/nanodesk-installed.xpm /usr/share/nanodesk/pixmaps/nanodesk.xpm || error
      $CHROOTCMD /usr/bin/ln -s -f /usr/share/nanodesk/pixmaps/nanodesk-bw-installed.xpm /usr/share/nanodesk/pixmaps/nanodesk-bw.xpm || error
      
      STEPFINISH=1
      
      ;;
    k|K)
      finish
      ;;
  esac
done

finish
