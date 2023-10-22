# Welcome to nanodesk

`nanodesk` is yet another lightweight Debian flavor/distribution, 
that comes with the `jwm` window manager.

This is just a fun project for learning purposes. 

## install to disk

You can install nanodesk to your harddrive. Before doing so,
you have to get your drive partitioned and formated. 

Partitioning on an empty drive is simple, you need two partitions

- partition1: ext4, main filesystem. 
- partition2: swap, optional but recommended. About 20%-50% the size of your RAM.

You can use `Menu -> System -> GParted` or `fdisk` on the shell for this.
Please read their manuals.

This done, just run `sudo nanodesk-installer /dev/sdXY` from the terminal
and the installation will start. (change /dev/sdXY to your drive)

## installing software

There is `Menu -> System -> Synaptic` for installing software as GUI.
Alternatively you can use `apt` from the terminal. 

## getting root

When booting as livesystem, the default user is `debian` and the 
password is `debian` as well.

In some cases you get asked by the GUI to enter your password. (e.g. GParted)
On commandline you can enter `sudo su - ` to get root access.
