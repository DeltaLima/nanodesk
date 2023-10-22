# Welcome to nanodesk

`nanodesk` is yet another leightweight Debian flavor/distribution, 
that comes with the `jwm` window manager.

This is just a fun project for learning purposes. 

## install to disk

You can install nanodesk to your harddrive. Before doing so,
you have to get your drive partitioned and formated. 

Partitioning on an empty drive is simple, you need two partitions

- partition1: ext4 , mainfilesystem. 
- partition2 (optional, but recommended): swap

You can use `Menu -> System -> Gparted` or `fdisk` on the shell for this.
Please read their manuals.

This done, just run `sudo nanodesk-installer /dev/sdXY` from the terminal
and the installation will start. (change /dev/sdXY to your drive)

## installing software

There is `Menu -> System -> Synaptic` for installing software as GUI.
Alternatively you can use `apt` from the terminal. 

## getting root

When booting as livesystem, the default user is `debian` and the 
password is `debian` as well.

Depending on your choice by the installation, you will have to enter a password,
when you created your own using by the installer.
