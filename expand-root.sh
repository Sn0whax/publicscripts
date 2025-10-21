# Configure 70-rootpt-resize
cat << "EOF" > /etc/uci-defaults/70-rootpt-resize
if [ ! -e /etc/rootpt-resize ] \
&& type parted > /dev/null \
&& lock -n /var/lock/root-resize
then
    MAJOR_MINOR=$(awk '$9=="/dev/root"{print $3}' /proc/self/mountinfo)
    if [ -n "$MAJOR_MINOR" ]; then
        SYS_PATH="$(readlink -f /sys/dev/block/"$MAJOR_MINOR")"
        ROOT_BLK="/dev/${SYS_PATH##*/}"
        if [ -n "$ROOT_BLK" ] && [ -b "$ROOT_BLK" ]; then
            ROOT_DISK="/dev/$(basename "${SYS_PATH%/*}")"
            ROOT_PART="${ROOT_BLK##*[^0-9]}"
            parted -f -s "${ROOT_DISK}" resizepart "${ROOT_PART}" 100%
            mount_root done
            touch /etc/rootpt-resize
            if [ -e /boot/cmdline.txt ]; then
                NEW_UUID=$(blkid "${ROOT_DISK}p${ROOT_PART}" | sed -n 's/.*PARTUUID="\([^"]*\)".*/\1/p')
                if [ -n "$NEW_UUID" ]; then
                    sed -i "s/PARTUUID=[^ ]*/PARTUUID=${NEW_UUID}/" /boot/cmdline.txt
                fi
            fi
            reboot
        else
            echo "Error: ROOT_BLK ($ROOT_BLK) is not a block device"
            exit 1
        fi
    else
        echo "Error: No major:minor number found for /dev/root"
        exit 1
    fi
fi
exit 1
EOF

# Configure 80-rootfs-resize
cat << "EOF" > /etc/uci-defaults/80-rootfs-resize
if [ ! -e /etc/rootfs-resize ] \
&& [ -e /etc/rootpt-resize ] \
&& type resize2fs > /dev/null \
&& lock -n /var/lock/root-resize
then
    MAJOR_MINOR=$(awk '$9=="/dev/root"{print $3}' /proc/self/mountinfo)
    if [ -n "$MAJOR_MINOR" ]; then
        SYS_PATH="$(readlink -f /sys/dev/block/"$MAJOR_MINOR")"
        ROOT_DEV="/dev/${SYS_PATH##*/}"
        if [ -n "$ROOT_DEV" ] && [ -b "$ROOT_DEV" ]; then
            resize2fs -f "$ROOT_DEV"
            mount_root done
            touch /etc/rootfs-resize
            reboot
        else
            echo "Error: ROOT_DEV ($ROOT_DEV) is not a block device"
            exit 1
        fi
    else
        echo "Error: No major:minor number found for /dev/root"
        exit 1
    fi
fi
exit 1
EOF

# Update sysupgrade.conf
cat << "EOF" >> /etc/sysupgrade.conf
/etc/uci-defaults/70-rootpt-resize
/etc/uci-defaults/80-rootfs-resize
EOF
