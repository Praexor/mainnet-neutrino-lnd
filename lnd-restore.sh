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
  echo "Found destination directory: $DESTINATION_DIR"
  dest_dir_num_files=$(find "$DESTINATION_DIR" -type -f | wc -l)
  if [[ "$dest_dir_num_files" -gt 5 ]];
  then
    echo "The $DESTINATION_DIR directory seems to be populated (has more than 5 files). Please remove it (rm -rf \"$DESTINATION_DIR\") to restore."
    exit 1
  fi
else
  mkdir "$DESTINATION_DIR"
fi

echo "Restoring $backup_path to $DESTINATION_DIR"
rsync -a "$backup_path"/. "$DESTINATION_DIR"/.
echo "Done! You may now start your node with \"systemctl start lnd\""
