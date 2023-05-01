#!/bin/bash

### this script makes everything to build a ready to boot .iso file of nanodesk
###
### By: DeltaLima
### 2023

CHROOTCMD="sudo chroot build/chroot/"
VERSION="$(git describe --tags)" #-$(git rev-parse --short HEAD)"

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

     if [ "$1" == "info" ] || [ "$1" == "error" ]
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
  dosfstools \
  coreutils \
  markdown || error

message "start building nanodesk ${YELLOW}${VERSION}${ENDCOLOR}"

read -p "press [enter] to continue"

### stuff begins here
message "Checking build directory"
test -f build/chroot || mkdir -p build/chroot

### i have the problem, that fakechroot will not work atm. in ubuntu 22.04 i get libc6 version mismatch errors. so we run it direct as root. not my favorite, but works for now.
message "running debootstrap with mirror $MIRROR"
sudo debootstrap bullseye build/chroot/ $MIRROR || sudo debootstrap bullseye build/chroot/ $MIRROR 

message "copy xdgmenumaker deb file into chroot"
sudo cp deb/xdgmenumaker* build/chroot/tmp || error

message "copy template/install_base.sh to build/chroot/tmp/install_base.sh"
cp templates/install_base.tpl.sh build/chroot/tmp/install_base.sh || error

message "run install_base.sh"
$CHROOTCMD /bin/bash /tmp/install_base.sh || error

message "clear /tmp"
$CHROOTCMD /usr/bin/rm -Rf /tmp/* || error

message "writing nanodesk-installer.sh into /root"
#first get the installed kernel version
KERNEL_VER="$($CHROOTCMD /usr/bin/dpkg -l "linux-image-*" | 
            grep "^ii"| 
            awk '{print $2}' | 
            grep -E 'linux-image-[0-9]\.([0-9]|[0-9][0-9])\.([0-9]|[0-9][0-9])-([0-9]|[0-9][0-9]).*-amd64$')"
message "using Kernel $KERNEL_VER"
sudo sed "s/%KERNEL_VER%/${KERNEL_VER}/g" templates/nanodesk-installer.tpl.sh > build/tmp/nanodesk-installer.sh
sudo cp build/tmp/nanodesk-installer.sh build/chroot/root/nanodesk-installer.sh
sudo chmod +x build/chroot/root/nanodesk-installer.sh

message "convert rootdir/usr/share/nanodesk/firstlogin/*.md to .html"
for md in $(find rootdir/ -name "*.md")
  do markdown $md > $(echo $md|sed 's/\.md/\.html/')
done

message "write nanodesk version $VERSION into rootdir/usr/share/nanodesk/version"
echo $VERSION > rootdir/usr/share/nanodesk/version

### copy nanodesk configs to chroot
message "copy nanodesk config files into chroot"
sudo cp -r rootdir/* build/chroot/

message "correct file permissions"
$CHROOTCMD /usr/bin/chmod 440 /etc/sudoers

### liveboot part, https://www.willhaley.com/blog/custom-debian-live-environment/
message "checking liveboot directories"
for dir in $(echo build/{staging/{EFI/BOOT,boot/grub/x86_64-efi,isolinux,live},tmp})
do
  message "check $dir"
  test -d $dir || mkdir -p $dir
done
#mkdir -p build/{staging/{EFI/BOOT,boot/grub/x86_64-efi,isolinux,live},tmp}

message "make squashfs"
test -f build/staging/live/filesystem.squashfs && sudo rm build/staging/live/filesystem.squashfs
sudo mksquashfs \
    build/chroot \
    build/staging/live/filesystem.squashfs \
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
    mkfs.vfat efiboot.img && \
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
