#Black MODE
wget https://raw.githubusercontent.com/Weilbyte/PVEDiscordDark/master/PVEDiscordDark.sh
bash PVEDiscordDark.sh install
# install cockpit
echo "deb http://deb.debian.org/debian buster-backports main" > /etc/apt/sources.list.d/buster-backport.list
apt update
apt-get -t buster-backports install cockpit
# add ZFS manager
git clone https://github.com/optimans/cockpit-zfs-manager.git && cp -r cockpit-zfs-manager/zfs /usr/share/cockpit
# start cockpit
systemctl start cockpit.service
systemctl enable cockpit.service
systemctl status cockpit.service
