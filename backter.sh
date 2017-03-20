#!/bin/bash

# Example config content (without hashes ofc)
# Destination:[Directory]
# Directory:[Source directory]:[File name regexp]:[Destination Directory]

# Destination:/media/backups
# Directory:/home/userx/Documents:.+:Documents
# Directory:/home/userx/Pictures:.+:Pics
# Directory:/home/userx/workspace:.+:JavaWorkspaceB
# Directory:/var/log:.+:SysLogs


cfg="backterHouse.cfg"
sdups="Y"
sbacks="Y"
smiss="Y"
mhc="sha256sum"
echo "Backter House v1.02"

if ! test "$SHELL" = "/bin/bash"; then
	echo "SHELL is not '/bin/bash'... need it!"
	exit 1
fi

if test $# -eq 0; then
	echo "Usage: $0 [-c] COMMAND"
	echo "COMMAND:"
	echo "   -c file  - Specifies the config file"
	echo "	-id      - Hide messages for already backed up files"
	echo "	-ib      - Hide backup messages"
	echo "   -im      - Hide messages for missing files at verify"
	echo "   backup   - Creates backup according the configuration"
	echo "   compare  - Compares the content of the backed up files and their existing counterparts"
	exit 0
fi

for px in `seq $(($#-1)) -1 0`; do
	if test "${BASH_ARGV[$px]}" = "-c"; then
		cfg="${BASH_ARGV[$((px-1))]}"
		echo "Config file name set to '$cfg'"
	fi
	if test "${BASH_ARGV[$px]}" = "-id"; then
		sdups="N"
	fi
	if test "${BASH_ARGV[$px]}" = "-ib"; then
		sbacks="N"
	fi
	if test "${BASH_ARGV[$px]}" = "-im"; then
		smiss="N"
	fi
done

if ! test -f "$cfg"; then
	echo "No '$cfg' exists... Where is the config file?!"
	exit 1
fi

dst=""

if test "$1" = "backup"; then
	echo "Backup selected..."
	cat "$cfg" | while read cl; do
		com=`echo "$cl" | cut -d: -f1`
		if test "$com" = "Destination"; then
			dst=`echo "$cl" | cut -d: -f2`
			dstrp=`realpath "$dst"`
			if ! test -d "$dstrp"; then
				echo "Destination '$dst' is not a directory!"
				exit 1
			fi
		fi
		if test "$com" = "Directory"; then
			if test "$dst" = ""; then
				echo "'Destination' folder not yet specified in the command chain"
				exit 1
			fi
			src=`echo "$cl" | cut -d: -f2`
			frx=`echo "$cl" | cut -d: -f3`
			dfdr=`echo "$cl" | cut -d: -f4`
			srcfp=`realpath "$src"`
			srcfpl=$((${#srcfp}+2))
			find "$srcfp" -mindepth 1 -type f -regex "$frx" | while read -r fn; do
				ffp=`realpath "$fn"`
				pffp=`echo "$ffp" | cut -c $srcfpl-`
				if test -f "$ffp"; then
					dfn="$dst/$dfdr/$pffp.gz"
					ddn=`echo "$dfn" | rev | cut -d/ -f2- | rev`
					if ! test -d "$ddn"; then
						echo "Making directory '$ddn'"
						mkdir -p "$ddn"
					fi
					if test -f "$dfn"; then
						HA=`zcat "$dfn" | $mhc | cut -c-64`
						HB=`cat "$ffp" | $mhc | cut -c-64`
					else
						HA="A"
						HB="B"
					fi
					if test "$HA" = "$HB"; then
						if test "$sdups" = "Y"; then
							echo "Duplicate: $ffp"
						fi
					else
						if test "$sbacks" = "Y"; then
							echo "Backing up: $ffp"
						fi
						cat "$ffp" | gzip -c >"$dfn"
					fi
				else
					echo "Could not open file '$ffp'"
				fi
			done
		fi
	done
fi
if test "$1" = "verify"; then
	echo "Verify selected..."
	cat "$cfg" | while read cl; do
		com=`echo "$cl" | cut -d: -f1`
		if test "$com" = "Destination"; then
			dst=`echo "$cl" | cut -d: -f2`
			dstrp=`realpath "$dst"`
			if ! test -d "$dstrp"; then
				echo "Destination '$dst' is not a directory!"
				exit 1
			fi
		fi
		if test "$com" = "Directory"; then
			if test "$dst" = ""; then
				echo "'Destination' folder not yet specified in the command chain"
				exit 1
			fi
			src=`echo "$cl" | cut -d: -f2`
			frx=`echo "$cl" | cut -d: -f3`
			dfdr=`echo "$cl" | cut -d: -f4`
			srcfp=`realpath "$src"`
			srcfpl=$((${#srcfp}+2))
			find "$srcfp" -mindepth 1 -type f -regex "$frx" | while read -r fn; do
				ffp=`realpath "$fn"`
				pffp=`echo "$ffp" | cut -c $srcfpl-`
				if test -f "$ffp"; then
					dfn="$dst/$dfdr/$pffp.gz"
					if test -f "$dfn"; then
						HA=`zcat "$dfn" | $mhc | cut -c-64`
						HB=`cat "$ffp" | $mhc | cut -c-64`
						if ! test "$HA" = "$HB"; then
							echo "Content mismatch"
							echo "Backup: $dfn"
							echo "Existing: $ffp"
						fi
					else
						if test "$smiss" = "Y"; then
							echo "Backup not exists for: $ffp"
						fi
					fi
				fi
			done
		fi
	done
fi
