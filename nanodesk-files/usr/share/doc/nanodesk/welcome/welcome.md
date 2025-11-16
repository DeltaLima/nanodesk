# Welcome to nanodesk-kiosk

`nanodesk-kiosk` is a lightweight Debian flavor/distribution, 
that comes with the `jwm` window manager, stripped down to host just
a single (bunch) of applications in a kiosk-mode like environment.

This is just a fun project for learning purposes. 

Visit the git repository at 
[git.la10cy.net/DeltaLima/nanodesk](https://git.la10cy.net/DeltaLima/nanodesk)

## install to disk: nanodesk-installer

You can install nanodesk to your harddrive. Before doing so,
you have to get your drive partitioned and formated. 

Under `Menu -> System -> nanodesk-installer` you find the GUI 
of the nanodesk-installer. It will guide you through the first basic
partitioning steps and formating your drive with `GParted`.
The installation process itself is done by the `nanodesk-installer` cli.

You can also just run the cli directly running
`sudo nanodesk-installer [TARGET]`

Keep in Mind, that `[TARGET]` needs to be a (ext4) preformated 
blockdevice and should be a partition.

## installing software

There is `Menu -> System -> Synaptic` for installing software as GUI.
Alternatively you can use `apt` from the terminal. 

## getting root

When booting as livesystem, the default user is `debian` and the 
password is `debian` as well.

In some cases you get asked by the GUI to enter your password. (e.g. GParted)
On commandline you can enter `sudo su - ` to get root access.
