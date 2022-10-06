#!/usr/bin/env bash
set -e

BACKUP_DIR_NAME=lnd_backup
MOUNT_DIR_NAME=/media
SOURCE_DIR="${SOURCE_LND_DIR:-lnd}"
KEEP_BACKUPS=10

which rsync > /dev/null

echo "Finding a device..."
backup_path=""
backup_name="$(date +%y-%m-%d-%H%M%S)-backup"

is_device_found=1
ls "$MOUNT_DIR_NAME"/*/*/"$BACKUP_DIR_NAME" > /dev/null  2>&1 || is_device_found=0

if [[ $is_device_found -eq 1 ]]; then
  for i in "$MOUNT_DIR_NAME"/*/*/"$BACKUP_DIR_NAME"; do
     backup_path="$i"/"$backup_name"
  done

  echo "Backup directory to use: $backup_path"
  mkdir "$backup_path"
else
  echo "Backup directory \"$BACKUP_DIR_NAME\" not found"
  exit 1
fi

BACKUP_TMP=$(mktemp -d -t ${BACKUP_DIR_NAME}.XXXX)
echo "Temp directory to use: $BACKUP_TMP"

echo "Stopping LND to back everything up"
systemctl stop lnd

pgrep_exit=0
pgrep lnd > /dev/null || pgrep_exit=1

if [[ ! pgrep_exit -eq 0 ]]; then
  echo "LND is stopped, making backup..."
  rsync_exit=0
  rsync --exclude=neutrino.db \
    --exclude=block_headers.bin \
    --exclude=reg_filter_headers.bin \
    --exclude=lnd.log \
    -a "${SOURCE_DIR}"/. "${BACKUP_TMP}"/.
  cp -r /var/lib/tor /etc/tor/torrc ${BACKUP_TMP}/.
  echo "Done to temporary directory! Starting LND back..."
  systemctl start lnd
  echo "LND looks started back"
  echo "Copying to external storage..."
  rsync -a --no-perms --no-owner --no-group "${BACKUP_TMP}"/. "${backup_path}"/. || rsync_exit=$?
  if [[ $rsync_exit -eq 0 ]];
  then
    echo "Backup done, size and path is:"
    du -hsx "${backup_path}"
    echo -n "Number of files:"
    find "${backup_path}" -type f | wc -l

    backups_found=$(ls -rt "${backup_path}/.." | wc -l)
    if [[ $backups_found -gt $KEEP_BACKUPS ]]; then
      dir_to_rm=$(ls -t "${backup_path}/.." | head -1)
      echo "removing old backup directory (keeping up to $KEEP_BACKUPS): $dir_to_rm"
      rm -rf "$dir_to_rm"
    fi
    echo ""
    echo "==> List of backups:"
    ls -1tr "${backup_path}/.."
  fi
fi

test -d "$BACKUP_TMP" && rm -rf "$BACKUP_TMP"
