#!/usr/bin/env bash
set -e
BACKUP_DIR_NAME=lnd_backup
MOUNT_DIR_NAME=/media
DESTINATION_DIR="${DESTINATION_DIR:-lnd}"

which rsync > /dev/null

echo "Finding a device... (you may specify your backup directory using \"$0 [backup_path]\""
backup_path=""
is_device_found=1

# Determine the backup directory
if [[ x"$1" == x ]]; then
  ls "$MOUNT_DIR_NAME"/*/*/"$BACKUP_DIR_NAME"/* > /dev/null  2>&1 || is_device_found=0
  if [[ $is_device_found -eq 1 ]]; then
    for i in "$MOUNT_DIR_NAME"/*/*/"$BACKUP_DIR_NAME"/*; do
      backup_path="$i"
    done
  fi
else
  if [[ -d "$1" ]]; then
    backup_path="$1"
  else
    is_device_found=0
  fi
fi

if [[ $is_device_found -eq 1 ]]; then
  echo "Backup directory to restore: $backup_path"
else
  echo "Backup directory not found. Aborting."
  exit 1
fi

if [[ -d "$DESTINATION_DIR" ]]; then
  echo "The $DESTINATION_DIR directory seems to be existing. Please remove it (rm -rf \"$DESTINATION_DIR\") to restore."
  exit 1
else
  mkdir "$DESTINATION_DIR"
fi

echo "Restoring $backup_path to $DESTINATION_DIR"
rsync -a "$backup_path"/. "$DESTINATION_DIR"/.

if [[ -f "$DESTINATION_DIR"/tor/torrc ]]; then
  which tor > /dev/null || apt-get install -y tor
  sudo systemctl stop tor || true
  echo "torrc found, restoring to /etc/tor/torrc"
  if [[ -f /etc/tor/torrc ]];
  then
    backup_filename="/etc/tor/torrc.$(date +%y-%m-%d-%H%M%S).bak"
    echo "Warning! /etc/tor/torrc is already exists."
    echo "Backing up to: $backup_filename"
    mv /etc/tor/torrc "$backup_filename"
  fi
  echo "copying torrc from backup"
  install -o debian-tor -g debian-tor -m 0600 "$DESTINATION_DIR"/tor/torrc /etc/tor/torrc
fi

if [[ -d "$DESTINATION_DIR"/tor/tor ]]; then
  echo "tor data directory found, restoring to /var/lib/tor"
  if [[ -d /var/lib/tor ]];
  then
    backup_filename="/var/lib/tor.$(date +%y-%m-%d-%H%M%S).bak"
    echo "Warning! /var/lib/tor is already exists."
    echo "Backing up to: $backup_filename"
    mv /var/lib/tor "$backup_filename"
  fi
  echo "copying tor data from backup"
  cp -r "$DESTINATION_DIR"/tor/tor /var/lib/tor
  chown -R debian-tor /var/lib/tor
  find /var/lib/tor -type d -exec chmod 700 {} \+
  find /var/lib/tor -type f -exec chmod 600 {} \+
fi

sudo systemctl start tor || true

echo "Done! You may now do test run: node index.js"
