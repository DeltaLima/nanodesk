#!/bin/bash

### this script makes everything to build a ready to boot .iso file of nanodesk
###
### By: DeltaLima
### 2023

CHROOTCMD="sudo chroot build/chroot/"
MIRROR=$1

if [ -z "$MIRROR" ]
then
  MIRROR="http://ftp.gwdg.de/debian/"
fi

message () {
  echo "== " $1
}

error () 
{
  message "ERROR!!"
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
  markdown

### stuff begins here
message "Checking build directory"
test -f build/chroot || mkdir -p build/chroot

### i have the problem, that fakechroot will not work atm. in ubuntu 22.04 i get libc6 version mismatch errors. so we run it direct as root. not my favorite, but works for now.
message "running debootstrap with mirror $MIRROR"
sudo debootstrap bullseye build/chroot/ $MIRROR || sudo debootstrap bullseye build/chroot/ $MIRROR 

message "copy xdgmenumaker deb file into chroot"
sudo cp deb/xdgmenumaker* build/chroot/tmp
message "deploying install_base"
cat <<EOF > build/chroot/tmp/install_base.sh
#!/bin/bash

message () {
  echo "== install_base: " "$1"
}

error () 
{
  message "ERROR!!"
  exit 1
}

### hostname setting
echo nanodesk > /etc/hostname

### noninteractive
DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND
### packages
message "install nanodesk base packages"
apt install -y \\
	live-boot \\
	linux-image-amd64 \\
	grub-pc \\
	ifupdown \\
	net-tools \\
	wireless-tools \\
	wpagui \\
	isc-dhcp-client \\
	man \\
	console-data \\
	locales \\
	sudo \\
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
	rsync \\
	vim \\
	links2 \\
	firefox-esr \\
	transmission-gtk \\
	lxterminal \\
	arandr \\
	zenity \\
	ncdu \\
	gparted \\
	/tmp/xdgmenumaker*.deb || error

message "set hostname in hosts"
sed -i 's/localhost/localhost nanodesk/g' /etc/hosts

### set root password
message "set root password to debian"
echo -e "debian\ndebian" | (passwd root)

### add debian user
message "create user debian"
useradd -m -U -s /bin/bash debian

### set password
message "set password debian for user debian"
echo -e "debian\ndebian" | (passwd debian)

### Configure timezone and locale
#dpkg-reconfigure locales
#dpkg-reconfigure console-data
#dpkg-reconfigure keyboard-configuration
###https://serverfault.com/a/689947
message "set locales and tzdata"
echo "Europe/Berlin" > /etc/timezone && \\
    dpkg-reconfigure -f noninteractive tzdata && \\
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \\
    echo 'LANG="en_US.UTF-8"'>/etc/default/locale && \\
    dpkg-reconfigure --frontend=noninteractive locales && \\
    locale-gen en_US.UTF-8 && \\
    update-locale LANG=en_US.UTF-8

### clean cache
message "apt clean"
apt clean

### but fetch packages for grub and kernel, so we do not need to download them
### in case nanodesk get installed to diska
message "apt --download linux-image and grub packages to have them in cache for installation by user"
apt -d --reinstall install \\
	linux-image-amd64 \\
	linux-image-5.10.0-22-amd64 \\
	grub-pc grub-pc-bin \\
	grub-common \\
	grub2-common \\
	os-prober || error
EOF
message "run install_base"
$CHROOTCMD /bin/bash /tmp/install_base.sh || error

message "clear /tmp"
$CHROOTCMD /usr/bin/rm -Rf /tmp/* || error

### process markdown files in src/ to html
message "convert .md from src to .html in build/chroot"
for md in $(find src/ -name "*.md")
  do markdown $md > $(echo $md|sed 's/\.md/\.html/')
done

### copy nanodesk configs to chroot
message "copy nanodesk config files into chroot"
sudo cp -r src/* build/chroot/

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

message "copy kernel and init images"
cp build/chroot/boot/vmlinuz-* build/staging/live/vmlinuz || error
cp build/chroot/boot/initrd.img-* build/staging/live/initrd || error

message "isolinux.cfg"
cat <<'EOF' >build/staging/isolinux/isolinux.cfg
UI vesamenu.c32

MENU TITLE Boot Menu
DEFAULT linux
TIMEOUT 600
MENU RESOLUTION 640 480
MENU COLOR border       30;44   #40ffffff #a0000000 std
MENU COLOR title        1;36;44 #9033ccff #a0000000 std
MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all
MENU COLOR unsel        37;44   #50ffffff #a0000000 std
MENU COLOR help         37;40   #c0ffffff #a0000000 std
MENU COLOR timeout_msg  37;40   #80ffffff #00000000 std
MENU COLOR timeout      1;37;40 #c0ffffff #00000000 std
MENU COLOR msg07        37;40   #90ffffff #a0000000 std
MENU COLOR tabmsg       31;40   #30ffffff #00000000 std

LABEL linux
  MENU LABEL nanodesk Live [BIOS/ISOLINUX]
  MENU DEFAULT
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live

LABEL linux
  MENU LABEL nanodesk Live [BIOS/ISOLINUX] (nomodeset)
  MENU DEFAULT
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live nomodeset
EOF

cat <<'EOF' > build/staging/boot/grub/grub.cfg
insmod part_gpt
insmod part_msdos
insmod fat
insmod iso9660

insmod all_video
insmod font

set default="0"
set timeout=30

# If X has issues finding screens, experiment with/without nomodeset.

menuentry "nanodesk Live [EFI/GRUB]" {
    search --no-floppy --set=root --label NANODESK
    linux ($root)/live/vmlinuz boot=live
    initrd ($root)/live/initrd
}

menuentry "nanodesk Live [EFI/GRUB] (nomodeset)" {
    search --no-floppy --set=root --label NANODESK
    linux ($root)/live/vmlinuz boot=live nomodeset
    initrd ($root)/live/initrd
}
EOF

cp build/staging/boot/grub/grub.cfg build/staging/EFI/BOOT/ || error

cat <<'EOF' >build/tmp/grub-embed.cfg
if ! [ -d "$cmdpath" ]; then
    # On some firmware, GRUB has a wrong cmdpath when booted from an optical disc.
    # https://gitlab.archlinux.org/archlinux/archiso/-/issues/183
    if regexp --set=1:isodevice '^(\([^)]+\))\/?[Ee][Ff][Ii]\/[Bb][Oo][Oo][Tt]\/?$' "$cmdpath"; then
        cmdpath="${isodevice}/EFI/BOOT"
    fi
fi
configfile "${cmdpath}/grub.cfg"
EOF

message "copy isolinux"
cp /usr/lib/ISOLINUX/isolinux.bin "build/staging/isolinux/" || error
cp /usr/lib/syslinux/modules/bios/* "build/staging/isolinux/" || error

message "copy grub-efi"
cp -r /usr/lib/grub/x86_64-efi/* "build/staging/boot/grub/x86_64-efi/"

message "make efi images"
grub-mkstandalone -O i386-efi \
    --modules="part_gpt part_msdos fat iso9660" \
    --locales="" \
    --themes="" \
    --fonts="" \
    --output="build/staging/EFI/BOOT/BOOTIA32.EFI" \
    "boot/grub/grub.cfg=build/tmp/grub-embed.cfg"

grub-mkstandalone -O x86_64-efi \
    --modules="part_gpt part_msdos fat iso9660" \
    --locales="" \
    --themes="" \
    --fonts="" \
    --output="build/staging/EFI/BOOT/BOOTx64.EFI" \
    "boot/grub/grub.cfg=build/tmp/grub-embed.cfg"

(cd build/staging && \
    dd if=/dev/zero of=efiboot.img bs=1M count=20 && \
    mkfs.vfat efiboot.img && \
    mmd -i efiboot.img ::/EFI ::/EFI/BOOT && \
    mcopy -vi efiboot.img \
        build/staging/EFI/BOOT/BOOTIA32.EFI \
        build/staging/EFI/BOOT/BOOTx64.EFI \
        build/staging/boot/grub/grub.cfg \
        ::/EFI/BOOT/
)

message "generate .iso"
xorriso \
    -as mkisofs \
    -iso-level 3 \
    -o "build/nanodesk_$(git rev-parse --short HEAD)_$(git describe --tags).iso" \
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
