#!/bin/bash
#
# virt-killer.sh - A script to completely remove a VM from the system.
# Usage: virt-killer.sh <vm-name>

image_directory=
config_directory=  # /etc/libvirt/qemu/

/usr/bin/virsh dominfo $1 | grep -q 'shut off'

if [ ! $? == 0 ]
then
    virsh destroy $1
fi

rm -rf "$image_directory$1.img"
rm -rf "$config_directory$1.xml"

/sbin/service libvirtd restart
