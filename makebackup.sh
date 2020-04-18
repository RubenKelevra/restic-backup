#!/bin/bash
#
########
#
# Copyright © 2020 @RubenKelevra
#
# LICENSE contains the licensing informations
#
########

# simple script to backup a arch linux system, while avoiding to store any file
# supplied by the package manager - for efficient backups
#
# requires: 
# - restic
# - paccheck

set -e

USER=user
HOSTNAME=hostname
SERVER=server

KEEP_DAILY=14
KEEP_WEEKLY=3
KEEP_MONTHLY=5
KEEP_YEARLY=1

# make sure this directory exist and you have write access
CACHEDIR='/var/cache/restic/'

# set capability for reading all files (this avoid that restic needs to be run as root)
sudo setcap cap_dac_read_search=+ep /usr/bin/restic

echo "Generating exclude lists..."

# fetch all files currently supplied by packages
rm -f /tmp/pkg_files
while IFS= read -r -d $'\n' filepath; do
	[ -f "$filepath" ] && echo "$filepath" >> /tmp/pkg_files
done < <(sudo pacman -Ql | cut -f 1 -d ' ' --complement)

# check all files supplied by packages for changes, and write the changed files to a list
sudo paccheck --md5sum --quiet --db-files --noupgrade --backup | awk '{ print $2 }' | sed "s/'//g" > /tmp/changed_files

# backup the changed files (remove them from the blacklist)
grep -v -x -f /tmp/changed_files /tmp/pkg_files | sed 's/\[/\\[/g' > /tmp/blacklist

# add the global exclude list to the black list
cat ~/makebackup.excludes >> /tmp/blacklist
echo "$CACHEDIR" >> /tmp/blacklist

echo "Generating package lists..."

# generate package-lists for native and foreign packages, to be able to restore the system from a mirror
sudo pacman -Qne | sudo tee /.explicit_packages.list >/dev/null
sudo pacman -Qme | sudo tee /.explicit_foreign_packages.list >/dev/null

echo "Backing up..."
restic -r sftp:$server:/home/$user/backups/$hostname --verbose --cache-dir="$cachdir" backup / --exclude-file=/tmp/blacklist

echo "Full system-backup done. Forgetting old snapshots..."
restic -r sftp:$server:/home/$user/backups/$hostname --cache-dir="$cachdir" forget --keep-daily $KEEP_DAILY --keep-weekly $KEEP_WEEKLY --keep-monthly $KEEP_MONTHLY --keep-yearly $KEEP_YEARLY

sudo setcap cap_dac_read_search=-ep /usr/bin/restic

echo "Operation completed."
