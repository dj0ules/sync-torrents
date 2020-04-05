#!/usr/bin/env bash

# ------------------------------------------------------------------------
# sync-torrents_debian.sh
# A simple script to push torrent file on rtorrent server watch directory
# Author : dj0ules
# ------------------------------------------------------------------------


# ------------
# Variables Definition
# ------------

# SSH params
_ssh_user=johndoe
_ssh_server_addr=1.2.3.4
_ssh_server_port=2222

# Local location of torrent files
_source_dir=$HOME/Downloads/Torrents

# Torrent folder hierarchy
_media_folder=(
	$_source_dir/Applications/{Linux,MacOS}
	$_source_dir/Films/{VF_HD,VF_SD,VOST_HD,VOST_SD}
	$_source_dir/SeriesTV/{VF_HD,VF_SD,VOST_HD,VOST_SD}
	$_source_dir/Musique/{FLAC,MP3}
)

# Location where to push the data
_watch_dir=/home/downloads/.watch

# Log file
_logdir=$HOME/.sync-torrents
_logfile=$_logdir/sync-torrents.log
_tmp_log=$_logdir/sync-torrents.log.tmp



# ------------
# Script Execution
# ------------

# Check if terminal-notifier exists
if [ ! -e /usr/bin/notify-send ]; then
	echo 'This script need libnotify-bin to run, please enter your password if asked'
	sudo apt install --yes libnotify-bin
fi


# Check if the log directory exists
if [ ! -d $_logdir ]; then
        mkdir $_logdir
fi


# Check if the torrent media folders exists and create them if not
for _dir in "${_media_folder[@]}"; do
	if [ ! -e "$_dir" ]; then 
		mkdir -p $_dir
	fi
done


# Create a container folder for TV show from torrent file name
# Ex: Breaking.Bad.S01.MULTi.1080p.BluRay.x264-RLZTEAM => Breaking_Bad
_tvshow_dir=$_source_dir/SeriesTV

for _tvshow in $(find $_tvshow_dir -name '*.torrent' -type f); do
	_tvshow_name=$(echo $_tvshow | sed -e 's/\.[Ss][0-9].*//g' -e 's/\./_/g')
	mkdir -p $_tvshow_name
	mv $_tvshow $_tvshow_name
done


# Set title for log file
_sync_date=$(date +"%A %d %B %Y %H:%M")
_log_title="Sync Torrents - $_sync_date"
_log_title_length=${#_log_title}

getTitle() {
	echo $_log_title >> $_logfile
	for (( i = 0; i < $_log_title_length; i++ )); do
		echo -n "-" >> $_logfile
	done
	echo "" >> $_logfile
}


# Push data on remote server and write in log file
_torrent_count=$(find $_source_dir -name "*.torrent" -type f | wc -l | awk '{print $1}')

rsync -vrz --human-readable  --exclude=".DS_Store" -e "ssh -p $_ssh_server_port" \
$_source_dir $_ssh_user@$_ssh_server_addr:$_watch_dir > $_tmp_log 2>&1

if [ "$?" -eq 0 ]; then
	if [ "$_torrent_count" -gt 0 ]; then
		/usr/bin/notify-send "sync-torrents" "$_torrent_count files have been added to the remote server!"
		getTitle
		cat $_tmp_log >> $_logfile
		echo >> $_logfile
		find $_source_dir -name "*.torrent" -type f -delete
		find $_tvshow_dir -mindepth 2 -maxdepth 2 -type d -delete
	else
		exit 0
	fi
else
	/usr/bin/notify-send "sync-torrents" "Script failed! Please check log file."
	getTitle
	cat $_tmp_log >> $_logfile
	echo >> $_logfile
fi


# Remove temp log
rm $_tmp_log