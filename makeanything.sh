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
### Configure timezone and locale
#dpkg-reconfigure locales
#dpkg-reconfigure console-data
#dpkg-reconfigure keyboard-configuration
###https://serverfault.com/a/689947
echo "Europe/Berlin" > /etc/timezone && \\
    dpkg-reconfigure -f noninteractive tzdata && \\
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \\
    echo 'LANG="en_US.UTF-8"'>/etc/default/locale && \\
    dpkg-reconfigure --frontend=noninteractive locales && \\
    locale-gen en_US.UTF-8 && \\
    update-locale LANG=en_US.UTF-8
EOF
$CHROOTCMD /bin/bash /tmp/install_base.sh || error

### prepeare liveboot
mkdir -p build/{staging/{EFI/BOOT,boot/grub/x86_64-efi,isolinux,live},tmp}
sudo mksquashfs \
    build/chroot \
    build/staging/live/filesystem.squashfs \
    -e boot || error

cp build/chroot/boot/vmlinuz-* build/staging/live/vmlinuz || error
cp build/chroot/boot/initrd.img-* build/staging/live/initrd || error

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
  MENU LABEL Debian Live [BIOS/ISOLINUX]
  MENU DEFAULT
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live

LABEL linux
  MENU LABEL Debian Live [BIOS/ISOLINUX] (nomodeset)
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

menuentry "Debian Live [EFI/GRUB]" {
    search --no-floppy --set=root --label NANODESK
    linux ($root)/live/vmlinuz boot=live
    initrd ($root)/live/initrd
}

menuentry "Debian Live [EFI/GRUB] (nomodeset)" {
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

cp /usr/lib/ISOLINUX/isolinux.bin "build/staging/isolinux/" || error
cp /usr/lib/syslinux/modules/bios/* "build/staging/isolinux/" || error

cp -r /usr/lib/grub/x86_64-efi/* "build/staging/boot/grub/x86_64-efi/"

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

xorriso \
    -as mkisofs \
    -iso-level 3 \
    -o "build/nanodesk_$(git rev-parse --short HEAD).iso" \
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
