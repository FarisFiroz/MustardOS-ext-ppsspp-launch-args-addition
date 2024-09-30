#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
ROM=$3

export HOME=$(GET_VAR "device" "board/home")

export SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
export SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
export SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"

SET_VAR "system" "foreground_process" "retroarch"

MESSAGE() {
	_TITLE=$1
	_MESSAGE=$2
	_FORM=$(
		cat <<EOF
$_TITLE

$_MESSAGE
EOF
	)
	/opt/muos/extra/muxstart "$_FORM" && sleep "$3"
}

ROMPATH=$(echo "$ROM" | awk -F'/' '{NF--; print}' OFS='/')
DOUK="$ROMPATH/.Cave Story (En)/Doukutsu.exe"

LOGPATH="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/nxe.log"

RA_CONF=/run/muos/storage/info/config/retroarch.cfg

if [ -e "$DOUK" ]; then
	retroarch -v -c "$RA_CONF" -L "$(GET_VAR "device" "storage/rom/mount")/MUOS/core/$CORE" "$DOUK" &
	RA_PID=$!
else
	CZ_NAME="Cave Story (En).zip"
	CAVE_URL="https://bot.libretro.com/assets/cores/Cave Story/$CZ_NAME"
	BIOS_FOLDER="/run/muos/storage/bios/"

	if [ -e "$BIOS_FOLDER$CZ_NAME" ]; then
		echo "$CZ_NAME exists at $BIOS_FOLDER" >>"$LOGPATH"
	else
		echo "$CZ_NAME not found in $BIOS_FOLDER" >>"$LOGPATH"
		## Is this thing on(line)?
		check_internet() {
			echo "Pinging github.com" >>"$LOGPATH"
			ping -c 1 github.com >/dev/null 2>&1
			return $?
		}
		if check_internet; then
			echo "Downloading from $CAVE_URL" >>"$LOGPATH"
			wget -O "$BIOS_FOLDER$CZ_NAME" "$CAVE_URL"
		else
			# If local copy doesn't exist and cannot download a copy, pop message
			echo "Unable to download $CZ_NAME" >>"$LOGPATH"
			TITLE="Missing File"
			CONTENT="Cave Story (En).zip not found in /MUOS/bios
			Please see https://muos.dev for more information!"
			MESSAGE "$TITLE" "$CONTENT" 5
		fi
	fi

	## Extract the zip
	echo "Extracting $CZ_NAME to $ROMPATH" >>"$LOGPATH"
	unzip -o "$BIOS_FOLDER$CZ_NAME" -d "$ROMPATH"

	if [ -e "$ROMPATH/Cave Story (En)" ]; then
		echo "Hiding folder" >>"$LOGPATH"
		mv "$ROMPATH/Cave Story (En)" "$ROMPATH/.Cave Story (En)"
	elif [ -e "$ROMPATH/.Cave Story (En)" ]; then
		echo "Already hidden" >>"$LOGPATH"
	else
		echo "Did extraction fail?" >>"$LOGPATH"
	fi

	# Include default button mappings from retroarch.device.cfg. (Settings
	# in the retroarch.cfg will take precedence. Modified settings will save
	# to the main retroarch.cfg, not the included retroarch.device.cfg.)
	sed -n -e '/^#include /!p' \
		-e '$a#include "/opt/muos/device/current/control/retroarch.device.cfg"' \
		-i "$RA_CONF"

	retroarch -v -c "$RA_CONF" -L "$(GET_VAR "device" "storage/rom/mount")/MUOS/core/$CORE" "$DOUK" &
	RA_PID=$!
fi

wait $RA_PID
