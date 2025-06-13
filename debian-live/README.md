# Test for building nanodesk with debian live

## Build

```sh
# configure
lb config -d stable --image-name nanodesk-lb --archive-areas "main contrib non-free non-free-firmware"
# build as root
sudo lb build
```
