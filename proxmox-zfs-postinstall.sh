#!/bin/bash

###### CONFIG SECTION ######

# Define basic tools to install
TOOLS="sudo vim ifupdown2 net-tools dnsutils ethtool git curl unzip screen iftop lshw smartmontools nvme-cli lsscsi sysstat zfs-auto-snapshot htop mc rpl lsb-release"

#### PVE CONF BACKUP CONFIGURATION ####

# Define target dataset for backup of /etc
# IMPORTANT NOTE: Don't type in the leading /, this will be set where needed
PVE_CONF_BACKUP_TARGET=rpool/pveconf

# Define timer for your backup cronjob (default: every 15 minutes fron 3 through 59)
PVE_CONF_BACKUP_CRON_TIMER="3/15 * * * *"


###### SYSTEM INFO AND INTERACTIVE CONFIGURATION SECTION ######

ROUND_FACTOR=512

roundup(){
    echo $(((($1 + $ROUND_FACTOR) / $ROUND_FACTOR) * $ROUND_FACTOR))
}

roundoff(){
    echo $((($1 / $ROUND_FACTOR) * $ROUND_FACTOR))
}

#### L1ARC SIZE CONFIGURATION ####

# get total size of all zpools
ZPOOL_SIZE_SUM_BYTES=0
for line in $(zpool list -o size -Hp); do ZPOOL_SIZE_SUM_BYTES=$(($ZPOOL_SIZE_SUM_BYTES+$line)); done

# get information about available ram
MEM_TOTAL_BYTES=$(($(awk '/MemTotal/ {print $2}' /proc/meminfo) * 1024))

# get values if defaults are set
ARC_MAX_DEFAULT_BYTES=$(($MEM_TOTAL_BYTES / 2))
ARC_MIN_DEFAULT_BYTES=$(($MEM_TOTAL_BYTES / 32))

# get current settings
ARC_MIN_CUR_BYTES=$(cat /sys/module/zfs/parameters/zfs_arc_min)
ARC_MAX_CUR_BYTES=$(cat /sys/module/zfs/parameters/zfs_arc_max)

# calculate suggested l1arc sice
ZFS_ARC_MIN_MEGABYTES=$(roundup $(($ZPOOL_SIZE_SUM_BYTES / 2048 / 1024 / 1024)))
ZFS_ARC_MAX_MEGABYTES=$(roundoff $(($ZPOOL_SIZE_SUM_BYTES / 1024 / 1024 / 1024)))

echo -e "######## CONFIGURE ZFS L1ARC SIZE ########\n"
echo "System Summary:"
echo -e "\tSystem Memory:\t\t$(($MEM_TOTAL_BYTES / 1024 / 1024))\tMB"
echo -e "\tZpool size (sum):\t$(($ZPOOL_SIZE_SUM_BYTES / 1024 / 1024))\tMB"
echo -e "Calculated l1arc if set to defaults:"
if [ $ARC_MIN_DEFAULT_BYTES -lt 33554432 ]; then
    echo -e "\tDefault zfs_arc_min:\t32\tMB"
else
    echo -e "\tDefault zfs_arc_min:\t$(($ARC_MIN_DEFAULT_BYTES / 1024 / 1024))\tMB"
fi
echo -e "\tDefault zfs_arc_max:\t$(($ARC_MAX_DEFAULT_BYTES / 1024 / 1024))\tMB"
echo -e "Current l1arc configuration:"
if [ $ARC_MIN_CUR_BYTES -gt 0 ]; then
    echo -e "\tCurrent zfs_arc_min:\t$(($ARC_MIN_CUR_BYTES / 1024 / 1024))\tMB"
else
    echo -e "\tCurrent zfs_arc_min:\t0"
fi
if [ $ARC_MAX_CUR_BYTES -gt 0 ]; then
    echo -e "\tCurrent zfs_arc_max:\t$(($ARC_MAX_CUR_BYTES / 1024 / 1024))\tMB"
else
    echo -e "\tCurrent zfs_arc_max:\t0"
fi
echo -e "Note: If your current values are 0, the calculated values above will apply."
echo ""
echo -e "The l1arc cache will be set relative to the size (sum) of your zpools by policy"
echo -e "zfs_arc_min:\t\t\t$(($ZFS_ARC_MIN_MEGABYTES))\tMB\t\t= 512 MB RAM per 1 TB ZFS storage (round off in 512 MB steps)"
echo -e "zfs_arc_max:\t\t\t$(($ZFS_ARC_MAX_MEGABYTES))\tMB\t\t= 1 GB RAM per 1 TB ZFS storage (round up in 512 MB steps)"
echo ""
RESULT=not_set
while [ "$(echo $RESULT | awk '{print tolower($0)}')" != "y" ] && [ "$(echo $RESULT | awk '{print tolower($0)}')" != "n" ] && [ "$(echo $RESULT | awk '{print tolower($0)}')" != "" ]; do
    echo "If you want to apply the values by script policy type 'y', type 'n' to adjust the values yourself [Y/n]?"
    read
    RESULT=${REPLY}
done
if [[ "$(echo $RESULT | awk '{print tolower($0)}')" == "n" ]]; then
    echo "Please type in the desired value in MB for 'zfs_arc_min' [$(($ZFS_ARC_MIN_MEGABYTES))]:"
    read
    if [[ ${REPLY} -gt 0 ]]; then
        ZFS_ARC_MIN_MEGABYTES=$((${REPLY}))
    fi
    echo "Please type in the desired value in MB for 'zfs_arc_max' [$(($ZFS_ARC_MAX_MEGABYTES))]:"
    read
    if [[ ${REPLY} -gt 0 ]]; then
        ZFS_ARC_MAX_MEGABYTES=$((${REPLY}))
    fi
fi

#### SWAPPINESS ####

echo -e "######## CONFIGURE SWAPPINESS ########\n"
SWAPPINESS=$(cat /proc/sys/vm/swappiness)
echo "The current swappiness is configured to '$SWAPPINESS %' of free memory until using swap."
read -p "If you want to change the swappiness, please type in the percentage as number (0 = diasbled):" user_input
if echo "$user_input" | grep -qE '^[0-9]+$'; then
    echo "Changing swappiness from '$SWAPPINESS %' to '$user_input %'"
    SWAPPINESS=$user_input
else
    echo "No input - swappiness unchanged at '$SWAPPINESS %'."
fi

#### ZFS AUTO SNAPSHOT CONFIGURATION ####

# get information about zfs-auto-snapshot and ask for snapshot retention
declare -A auto_snap_keep=( ["frequent"]="8" ["hourly"]="48" ["daily"]="31" ["weekly"]="8" ["monthly"]="3" )
dpkg -l zfs-auto-snapshot > /dev/null

if [ $? -eq 0 ]; then
    echo "'zfs-auto-snapshot' already installed. Reading config..."
    for interval in "${!auto_snap_keep[@]}"; do
        if [[ "$interval" == "frequent" ]]; then
            auto_snap_keep[$interval]=$(cat /etc/cron.d/zfs-auto-snapshot | grep keep | cut -d' ' -f19 | cut -d '=' -f2)
        else
            auto_snap_keep[$interval]=$(cat /etc/cron.$interval/zfs-auto-snapshot | grep keep | cut -d' ' -f6 | cut -d'=' -f2)
        fi
    done
else
    echo "'zfs-auto-snapshot' not installed yet, using script defaults..."
fi
echo -e "######## CONFIGURE ZFS AUTO SNAPSHOT ########\n"
for interval in "${!auto_snap_keep[@]}"; do
    read -p "Please set how many $interval snapshots to keep (current: keep=${auto_snap_keep[$interval]})" user_input
    if echo "$user_input" | grep -qE '^[0-9]+$'; then
        echo "Changing $interval from ${auto_snap_keep[$interval]} to $user_input"
        auto_snap_keep[$interval]=$user_input
    else
        echo "No input - $interval unchanged at ${auto_snap_keep[$interval]}."
    fi
done

###### INSTALLER SECTION ######

# disable pve-enterprise repo and add pve-no-subscription repo
if [[ "$(uname -r)" == *"-pve" ]]; then
    echo "Deactivating pve-enterprise repository"
    mv /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve-enterprise.list.bak > /dev/null 2>&1
    echo "Activating pve-no-subscription repository"
    echo "deb http://download.proxmox.com/debian/pve buster pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
fi
echo "Getting latest package lists"
apt update > /dev/null 2>&1

# update system and install basic tools
echo "Upgrading system to latest version - Depending on your version this could take a while..."
DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt -y -qq dist-upgrade > /dev/null 2>&1
echo "Installing toolset - Depending on your version this could take a while..."
DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt -y -qq install $TOOLS > /dev/null 2>&1

# configure zfs-auto-snapshot
for interval in "${!auto_snap_keep[@]}"; do
    echo "Setting zfs-auto-snapshot retention: $interval = ${auto_snap_keep[$interval]}"
    if [[ "$interval" == "frequent" ]]; then
        CURRENT=$(cat /etc/cron.d/zfs-auto-snapshot | grep keep | cut -d' ' -f19 | cut -d '=' -f2)
        if [[ "${auto_snap_keep[$interval]}" != "$CURRENT" ]]; then
            rpl "keep=$CURRENT" "keep=${auto_snap_keep[$interval]}" /etc/cron.d/zfs-auto-snapshot > /dev/null 2>&1
        fi
    else
        CURRENT=$(cat /etc/cron.$interval/zfs-auto-snapshot | grep keep | cut -d' ' -f6 | cut -d'=' -f2)
        if [[ "${auto_snap_keep[$interval]}" != "$CURRENT" ]]; then
            rpl "keep=$CURRENT" "keep=${auto_snap_keep[$interval]}" /etc/cron.$interval/zfs-auto-snapshot > /dev/null 2>&1
        fi
    fi
done

echo "Configuring swappiness"
echo "vm.swappiness=$SWAPPINESS" > /etc/sysctl.d/swappiness.conf
sysctl -w vm.swappiness=$SWAPPINESS

echo "Configuring pve-conf-backup"
# create backup jobs of /etc
zfs list $PVE_CONF_BACKUP_TARGET > /dev/null 2>&1
if [ $? -ne 0 ]; then
    zfs create $PVE_CONF_BACKUP_TARGET
fi
echo "$PVE_CONF_BACKUP_CRON_TIMER root rsync -va --delete /etc /$PVE_CONF_BACKUP_TARGET > /$PVE_CONF_BACKUP_TARGET/pve-conf-backup.log" > /etc/cron.d/pve-conf-backup

ZFS_ARC_MIN_BYTES=$((ZFS_ARC_MIN_MEGABYTES * 1024 *1024))
ZFS_ARC_MAX_BYTES=$((ZFS_ARC_MAX_MEGABYTES * 1024 *1024))

echo "Adjusting ZFS level 1 arc"
echo $ZFS_ARC_MIN_BYTES > /sys/module/zfs/parameters/zfs_arc_min
echo $ZFS_ARC_MAX_BYTES > /sys/module/zfs/parameters/zfs_arc_max

cat << EOF > /etc/modprobe.d/zfs.conf
options zfs zfs_arc_min=$ZFS_ARC_MIN_BYTES
options zfs zfs_arc_max=$ZFS_ARC_MAX_BYTES
EOF

echo "Updating initramfs - This will take some time..."
update-initramfs -u -k all > /dev/null 2>&1

echo "Proxmox postinstallation finished!"
