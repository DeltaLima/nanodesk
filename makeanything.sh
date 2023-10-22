#!/bin/bash

### this script makes everything to build a ready to boot .iso file of nanodesk
###
### By: DeltaLima
### 2023

### include config
. makeanything.conf

CHROOTCMD="sudo chroot build/chroot/"
test -n "$VERSION" || VERSION="$(git describe --tags)" #-$(git rev-parse --short HEAD)"

MIRROR=$1
if [ -z "$MIRROR" ]
then
  MIRROR="http://ftp.gwdg.de/debian/"
fi

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

     if [ "$1" == "info" ] || [ "$1" == "warn" ] || [ "$1" == "error" ]
     then
       MESSAGE=$2
     else
       MESSAGE=$1
     fi

     echo -e "[${MESSAGE_TYPE}] $MESSAGE"
}

error () 
{
  message error "ERROR!!"
  exit 1
}

message "installing requirements"
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
  dosfstools \
  coreutils \
  pandoc || error



message "start building nanodesk ${YELLOW}${VERSION}${ENDCOLOR}"

read -p "press [enter] to continue"

### stuff begins here

message "creating build directories"
for dir in $(echo build/{staging/{EFI/BOOT,boot/grub/x86_64-efi,isolinux,live},tmp,chroot,nanodesk-files})
do
  message "$dir"
  test -d $dir || mkdir -p $dir
done

message "running debootstrap $DEBOOTSTRAP_OPTS $DEBOOTSTRAP_SUITE $MIRROR"
sudo debootstrap ${DEBOOTSTRAP_OPTS} ${DEBOOTSTRAP_SUITE} build/chroot/ $MIRROR || message warn "debootstrap exited with code $?"

message "copy xdgmenumaker deb file into chroot"
sudo cp deb/xdgmenumaker* build/chroot/tmp || error

message "copy install_base scripts to build/chroot/tmp/"
sudo cp install_base/* build/chroot/tmp/ || error


#### install_base
message "run install_base.sh"
$CHROOTCMD /bin/bash /tmp/install_base.sh || error
####

### copy nanodesk files in nanodesk-files/ to build/nanodesk-files/ so we can make changes there,
### like generate version file and convert .md to .html in usr/share/docs/nanodesk
message "copy nanodesk-files/ to build/nanodesk-files/"
cp -r nanodesk-files/* build/nanodesk-files/

message "write nanodesk version $VERSION into build/nanodesk-files/usr/share/nanodesk/version"
echo $VERSION > build/nanodesk-files/usr/share/nanodesk/version

message "convert .md files in build/nanodesk-files/usr/doc/nanodesk/ to .html"
for md in $(find build/nanodesk-files/usr/share/doc/nanodesk/ -name "*.md")
  do pandoc --self-contained --css=pandoc/pandoc.css -M pagetitle:$(basename $md|sed 's/\.md//') -s $md -o $(echo $md | sed 's/\.md/\.html/')
done

message "copy build/nanodesk-files/ to build/chroot/"
sudo cp -r build/nanodesk-files/* build/chroot/

message "generate icon path list for jwm config"
find build/chroot/usr/share/icons/ -type d | sed 's/build\/chroot//g' > build/tmp/jwm.iconlist
sed -i -e 's/^/\ \ \ \ <IconPath>/g' -e 's/$/<\/IconPath>/g' build/tmp/jwm.iconlist
sudo cp build/tmp/jwm.iconlist build/chroot/tmp/ || error

message "putting generated icon path list to /etc/jwm/system.jwmrc"
$CHROOTCMD sed -i '/<\!-- GENERATED ICONLIST -->/r /tmp/jwm.iconlist' /etc/jwm/system.jwmrc || error

message "correct file permissions"
$CHROOTCMD /usr/bin/chmod 440 /etc/sudoers || error
$CHROOTCMD /usr/bin/chmod 755 /root/nanodesk-installer.sh || error

message "set x-terminal-emulator to lxterminal"
$CHROOTCMD /usr/bin/update-alternatives --set x-terminal-emulator /usr/bin/lxterminal

### set root password
message "set root password to 'debian'"
echo -e "debian\ndebian" | $CHROOTCMD /usr/bin/passwd root

### add debian user
message "create user debian, password 'debian'"
echo -e "debian\ndebian\nDebian\n\n\n\n\y\n" | $CHROOTCMD /usr/sbin/adduser debian

message "clear /tmp"
$CHROOTCMD /usr/bin/rm -Rf /tmp/* || error

### liveboot part, https://www.willhaley.com/blog/custom-debian-live-environment/
message "make squashfs"
test -f build/staging/live/filesystem.squashfs && sudo rm build/staging/live/filesystem.squashfs
sudo mksquashfs \
    build/chroot \
    build/staging/live/filesystem.squashfs \
    -comp xz \
    -e boot || error


message "copy kernel and initrd images"
cp build/chroot/boot/vmlinuz-* build/staging/live/vmlinuz || error
cp build/chroot/boot/initrd.img-* build/staging/live/initrd || error

message "generate isolinux.cfg"
sed "s/%VERSION%/${VERSION}/g" templates/isolinux.tpl.cfg > build/staging/isolinux/isolinux.cfg

message "generate grub.cfg"
sed "s/%VERSION%/${VERSION}/g" templates/grub.tpl.cfg > build/staging/boot/grub/grub.cfg
sed "s/%VERSION%/${VERSION}/g" templates/grub.tpl.cfg > build/staging/EFI/BOOT/grub.cfg

message "copy grub-embed.cfg"
cp templates/grub-embed.tpl.cfg build/tmp/grub-embed.cfg

message "copy isolinux"
cp /usr/lib/ISOLINUX/isolinux.bin "build/staging/isolinux/" || error
cp /usr/lib/syslinux/modules/bios/* "build/staging/isolinux/" || error

message "copy grub-efi"
cp -r /usr/lib/grub/x86_64-efi/* "build/staging/boot/grub/x86_64-efi/" || error

message "make efi images"
grub-mkstandalone -O i386-efi \
    --modules="part_gpt part_msdos fat iso9660" \
    --locales="" \
    --themes="" \
    --fonts="" \
    --output="build/staging/EFI/BOOT/BOOTIA32.EFI" \
    "boot/grub/grub.cfg=build/tmp/grub-embed.cfg" || error

grub-mkstandalone -O x86_64-efi \
    --modules="part_gpt part_msdos fat iso9660" \
    --locales="" \
    --themes="" \
    --fonts="" \
    --output="build/staging/EFI/BOOT/BOOTx64.EFI" \
    "boot/grub/grub.cfg=build/tmp/grub-embed.cfg" || error

(cd build/staging && \
    dd if=/dev/zero of=efiboot.img bs=1M count=20 && \
    /usr/sbin/mkfs.vfat efiboot.img && \
    mmd -i efiboot.img ::/EFI ::/EFI/BOOT && \
    mcopy -vi efiboot.img \
        ../../build/staging/EFI/BOOT/BOOTIA32.EFI \
        ../../build/staging/EFI/BOOT/BOOTx64.EFI \
        ../../build/staging/boot/grub/grub.cfg \
        ::/EFI/BOOT/
) || error

message "generate .iso"
xorriso \
    -as mkisofs \
    -iso-level 3 \
    -o "build/nanodesk_$VERSION.iso" \
    -full-iso9660-filenames \
    -volid "NANODESK" \
    --mbr-force-bootable -partition_offset 16 \
    -joliet -joliet-long -rational-rock \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -eltorito-boot \
        isolinux/isolinux.bin \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --eltorito-catalog isolinux/isolinux.cat \
    -eltorito-alt-boot \
        -e --interval:appended_partition_2:all:: \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
    -append_partition 2 C12A7328-F81F-11D2-BA4B-00A0C93EC93B build/staging/efiboot.img \
    "build/staging"
