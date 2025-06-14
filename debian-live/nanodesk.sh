#!/bin/sh
#
sudo lb clean
lb config -d stable --image-name nanodesk-lb --archive-areas "main contrib non-free non-free-firmware"
sudo lb build
