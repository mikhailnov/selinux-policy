#!/usr/bin/env bash

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
process_dublicate_paths
