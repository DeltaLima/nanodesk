# Welcome to nanodesk


nanodesk is a debian base linux "distribution". I put distribution in ""
becuase it is just a minimal debian debootstrap installation, which you 
can boot from a DVD or usb-stick and install it to disk, with well picked
packages I like and a customized jwm config. Taddaa - a new distribution. 


Everything done with having the goal to consume as less ram as possible.


## install to disk

You can install nanodesk to your harddrive. Before doing so,
you have to get your drive partitioned and formated. 

Partiotioning on an empty drive is simple, you need two partitions

- partition1: ext4 , mainfilesystem. 
- partition2 (optional, but recommended): swap

You can use `gparted` or `fdisk` for this. Please read their manuals.

This done, just run `sudo /root/install_nanodesk.sh /dev/sdXY` from the terminal
and the installation will start. (change /dev/sdXY to your drive)

## installing software

There is no GUI tool for installing software. You have to use `apt` from the
terminal.

## getting root

In the LiveCD mode you can just do `sudo su -` without being asked for a password.
Depending on your choice by the installation, you will have to enter a password,
when you created your own using by the installer.

So or so good old `su - ` works fine as well, just type in the root password.
