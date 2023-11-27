#!/bin/bash

true
SCRIPT_NAME="AIO-Provisioning"
SCRIPT_EXPLAINER="This script provisions AIO for you."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

install_if_not whiptail

install_popup "$SCRIPT_NAME"


NEXTCLOUD_DATADIR="$(input_box_flow "Please enter the location of the datadir.
If you want to cancel, just type in 'exit' and press [ENTER].")"
if [ "$NEXTCLOUD_DATADIR" = 'exit' ]
then
    exit 1
fi

NEXTCLOUD_MOUNT="$(input_box_flow "Please enter the location NEXTCLOUD_MOUNT.
If you want to cancel, just type in 'exit' and press [ENTER].")"
if [ "$NEXTCLOUD_MOUNT" = 'exit' ]
then
    exit 1
fi

set -ex

# Install docker
curl -fsSL https://get.docker.com | sudo sh

# Adjust permissions
sudo mkdir -p /mnt/ncdata
sudo chown -R 33:0 /mnt/ncdata

# Install Nextcloud
sudo docker run -d \
--init \
--name nextcloud-aio-mastercontainer \
--restart always \
-p 80:80 \
-p 8080:8080 \
-p 8443:8443 \
-e NEXTCLOUD_MOUNT="$NEXTCLOUD_MOUNT" \
-e NEXTCLOUD_DATADIR="$NEXTCLOUD_DATADIR" \
--volume nextcloud_aio_mastercontainer:/mnt/docker-aio-config \
--volume /var/run/docker.sock:/var/run/docker.sock:ro \
nextcloud/all-in-one:latest

# Some Info
cat << EOF | sudo tee /etc/motd

 #    #  ######  #    #   #####   ####   #        ####   #    #  #####
 ##   #  #        #  #      #    #    #  #       #    #  #    #  #    #
 # #  #  #####     ##       #    #       #       #    #  #    #  #    #
 #  # #  #         ##       #    #       #       #    #  #    #  #    #
 #   ##  #        #  #      #    #    #  #       #    #  #    #  #    #
 #    #  ######  #    #     #     ####   ######   ####    ####   #####

If you point a domain to this server, open port 8443 and 80 you can open the admin interface at https://yourdomain.com:8443
Otherwise you can open the admin interface at https://ip.address.of.this.server:8080

Further documentation is available here: https://github.com/nextcloud/all-in-one

EOF

# Cleanup
export DEBIAN_FRONTEND=noninteractive
sudo apt-get -y update
sudo apt-get install unattended-upgrades -y
sudo -E NEEDRESTART_MODE=a apt-get -o Dpkg::Options::="--force-confold" upgrade -q -y --force-yes
sudo apt-get -y autoremove
sudo apt-get -y autoclean
sudo rm -rf /tmp/* /var/tmp/*
history -c
# shellcheck disable=SC2002
cat /dev/null | sudo tee /root/.bash_history
unset HISTFILE
sudo find /var/log -mtime -1 -type f -exec truncate -s 0 {} \;
sudo rm -rf /var/log/*.gz /var/log/*.[0-9] /var/log/*-????????
sudo rm -rf /var/lib/cloud/instances/*
sudo rm -f /root/.ssh/authorized_keys /etc/ssh/*key*
sudo rm -rf /home/*/.ssh/authorized_keys
sudo touch /etc/ssh/revoked_keys
sudo chmod 600 /etc/ssh/revoked_keys
sudo docker stop nextcloud-aio-mastercontainer
sudo rm -f /var/lib/docker/volumes/nextcloud_aio_mastercontainer/_data/certs/ssl.*

