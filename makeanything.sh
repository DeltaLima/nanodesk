#!/bin/bash

### this script makes everything to build a ready to boot .iso file of nanodesk
###
### By: DeltaLima
### 2023

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
  # fakeroot fakechroot debootstrap
}

### stuff begins here
test -f build/chroot || mkdir -p build/chroot

fakeroot -s build/fakechroot.save fakechroot debootstrap --variant=fakechroot bullseye build/chroot/ http://ftp.de.debian.org/debian
