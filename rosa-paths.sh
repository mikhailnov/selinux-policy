#!/usr/bin/env bash

# Recommended to run from root for
# better performance of urpmf

set -efu

TMP="${TMP:-$(mktemp -d)}"
PL="${PL:-${TMP}/paths.list}"
NOCHANGE_LIST="${NOCHANGE_LIST:-${TMP}/nochange.list}"

mk_paths_list(){
	# Make list of paths
	grep -inHrE '^/usr/|^/bin|^/sbin|^/srv|^/var' | \
		awk -F ':' '{print $3}' | \
		awk '{print $1}' | grep '^/' | \
		grep '\.\*' | grep -v '/run/' | awk -F '\\.*' '{print $1}' | 
		sed -e 's,/(,/,g' -e 's,(/,/,g' -e 's,\\+,+,g' -e 's,\\$,,g' | \
		sort -u > "$PL"
	echo "PL: $PL"
}

process_list(){
	while read -r line
	do
		# If this path exists...
		if urpmf "$line" 2>/dev/null >/dev/null; then
			if [ ! -f "$NOCHANGE_LIST" ]; then
				touch "$NOCHANGE_LIST"
			fi
			if ! grep -q "^$line" "$NOCHANGE_LIST"; then
				echo "$line" >> "$NOCHANGE_LIST"
			fi
			continue
		fi
		if echo "$line" | grep -qE '^/usr/bin/|^/usr/sbin/|^/bin/|^/sbin/'; then
			bin="$(echo "$line" | awk -F 'bin/' '{print $NF}')"
			echo "$bin"
			urpmf_results="$(urpmf "$bin" | awk -F ':' '{print $NF}' | grep "bin/")"
			unset append
			if echo "$urpmf_results" | grep -q "${bin}$"
				then
					append="$(echo "$urpmf_results" | grep -q "${bin}$")"
					echo "${line}:::${append}"
			fi
			#while read -r u_line
			#do
			#	if echo "$u_line" | grep -q '^/usr/'
			#		then awkN=3
			#		else awkN=2
			#	fi
			#done < <(echo "$urpmf_results")
		fi
	done < <(grep -v '/$' "$PL")
}

_duplicate(){
	while [ -n "$1" ]
	do
		case "$1" in
			--file ) shift; FILE="$1" ;;
			--path ) shift; PATH="$1" ;;
			--line-number ) shift; LINE_NUMBER_ORIG="$1" ;;
			--original-line ) shift; LINE_ORIG="$1" ;;
		esac
		shift
	done
	
	if [ -z "$FILE" ] || [ -z "$PATH" ] || [ -z "$LINE_NUMBER_ORIG" ] || [ -z "$LINE_ORIG" ]; then
		echo "Some variables are empty"
		return 1
	fi
	
	#LINE_NEW="$(echo "$LINE_ORIG" | sed -e )"
}

dublicate_paths(){
	if [ ! -f "$1" ]; then
		echo "File $file not found"
		return 1
	fi
	file="$1"
	
	# number of line in file that we are working with
	lnum=0
	while read -r line
	do
		if ! echo "$line" | grep -q '^/'; then
			# this line is not a path
			continue
		fi
		
		for bin in '/usr/bin' '/usr/sbin' '/bin' '/sbin'
		do
			if echo "$line" | grep -qE "^$bin"; then
				_duplicate \
					--file "$file" \
					--path "$line" \
					--line-number "$lnum" \
					--original-line="$line"
				# as we appended new line in place
				lnum=$((lnum+1))
				continue
			fi
		done
		
		lnum=$((lnum+1))
	done < "$file"
}

copy_and_add_paths(){
	if [ ! -f "$1" ]; then
		echo "File $file not found"
		return 1
	fi
	file="$1"
	new_file="${file}.new"
	
	touch "$new_file"
	
	while read -r line
	do
		echo "$line" >> "$new_file"
		
		if echo "$line" | grep -q '^/bin'; then
			echo "$line" | sed -e 's,^/bin,/usr/bin,g' >> "$new_file"
			echo "$line" | sed -e 's,^/bin,/sbin,g' >> "$new_file"
			echo "$line" | sed -e 's,^/bin,/usr/sbin,g' >> "$new_file"
			continue
		fi
		if echo "$line" | grep -q '^/sbin'; then
			echo "$line" | sed -e 's,^/sbin,/usr/sbin,g' >> "$new_file"
			echo "$line" | sed -e 's,^/sbin,/bin,g' >> "$new_file"
			echo "$line" | sed -e 's,^/sbin,/usr/bin,g' >> "$new_file"
			continue
		fi
		if echo "$line" | grep -q '^/usr/bin'; then
			echo "$line" | sed -e 's,^/usr/bin,/usr/sbin,g' >> "$new_file"
			echo "$line" | sed -e 's,^/usr/bin,/bin,g' >> "$new_file"
			echo "$line" | sed -e 's,^/usr/bin,/sbin,g' >> "$new_file"
			continue
		fi
		if echo "$line" | grep -q '^/usr/sbin'; then
			echo "$line" | sed -e 's,^/usr/sbin,/usr/bin,g' >> "$new_file"
			echo "$line" | sed -e 's,^/usr/sbin,/bin,g' >> "$new_file"
			echo "$line" | sed -e 's,^/usr/sbin,/sbin,g' >> "$new_file"
			continue
		fi

		if echo "$line" | grep -q '^/usr/lib/systemd'; then
			echo "$line" | sed -e 's,^/usr/lib/systemd,/lib/systemd,g' >> "$new_file"
			echo "$line" | sed -e 's,^/usr/lib/systemd,/usr/share/systemd,g' >> "$new_file"
			continue
		fi

		if echo "$line" | grep -q '^/usr/lib/'; then
			echo "$line" | sed -e 's,^/usr/lib/,/lib/,g' >> "$new_file"
			echo "$line" | sed -e 's,^/usr/lib/,/lib64/,g' >> "$new_file"
			echo "$line" | sed -e 's,^/usr/lib/,/usr/lib64/,g' >> "$new_file"
			echo "$line" | sed -e 's,^/usr/lib/,/usr/libexec/,g' >> "$new_file"
			continue
		fi
		if echo "$line" | grep -q '^/usr/libexec'; then
			echo "$line" | sed -e 's,^/usr/libexec,/lib,g' >> "$new_file"
			echo "$line" | sed -e 's,^/usr/libexec,/lib64,g' >> "$new_file"
			echo "$line" | sed -e 's,^/usr/libexec,/usr/lib,g' >> "$new_file"
			echo "$line" | sed -e 's,^/usr/libexec,/usr/lib64,g' >> "$new_file"
			continue
		fi
		
	done < "$file"	
}

process_dublicate_paths(){
	while read -r file
	do
		#dublicate_paths "$file"
		copy_and_add_paths "$file"
	done < <(find . -type f -iname '*.fc')
}

mk_paths_list
#process_list
process_dublicate_paths
