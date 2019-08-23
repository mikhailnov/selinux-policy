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

# append with out suplicates -- and
_and(){
	# Usage: _and <file> <string> <sed pattern>
	if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
		echo "Not sufficient args, usage: _and <file> <string> <sed pattern>"
		return 1
	fi
	line_fixed="$(echo "$2" | sed -e 's,  , ,g' -e 's,\t, ,g')"
	if grep -q "$2" "$1" || grep -q "$line_fixed" "$1"
		then
			:
		else
			echo "$2" | sed -e "$3" >> "$1"
	fi
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
			_and "$new_file" "$line" 's,^/bin,/usr/bin,g'
			_and "$new_file" "$line" 's,^/bin,/sbin,g'
			_and "$new_file" "$line" 's,^/bin,/usr/sbin,g'
			continue
		fi
		if echo "$line" | grep -q '^/sbin'; then
			_and "$new_file" "$line" 's,^/sbin,/usr/sbin,g'
			_and "$new_file" "$line" 's,^/sbin,/bin,g'
			_and "$new_file" "$line" 's,^/sbin,/usr/bin,g'
			continue
		fi
		if echo "$line" | grep -q '^/usr/bin'; then
			_and "$new_file" "$line" 's,^/usr/bin,/usr/sbin,g'
			_and "$new_file" "$line" 's,^/usr/bin,/bin,g'
			_and "$new_file" "$line" 's,^/usr/bin,/sbin,g'
			continue
		fi
		if echo "$line" | grep -q '^/usr/sbin'; then
			_and "$new_file" "$line" 's,^/usr/sbin,/usr/bin,g'
			_and "$new_file" "$line" 's,^/usr/sbin,/bin,g'
			_and "$new_file" "$line" 's,^/usr/sbin,/sbin,g'
			continue
		fi

		if echo "$line" | grep -q '^/usr/lib/systemd'; then
			_and "$new_file" "$line" 's,^/usr/lib/systemd,/lib/systemd,g'
			_and "$new_file" "$line" 's,^/usr/lib/systemd,/usr/share/systemd,g'
			continue
		fi

		if echo "$line" | grep -q '^/usr/lib/'; then
			_and "$new_file" "$line" 's,^/usr/lib/,/lib/,g'
			_and "$new_file" "$line" 's,^/usr/lib/,/lib64/,g'
			_and "$new_file" "$line" 's,^/usr/lib/,/usr/lib64/,g'
			_and "$new_file" "$line" 's,^/usr/lib/,/usr/libexec/,g'
			continue
		fi
		if echo "$line" | grep -q '^/usr/libexec'; then
			_and "$new_file" "$line" 's,^/usr/libexec,/lib,g'
			_and "$new_file" "$line" 's,^/usr/libexec,/lib64,g'
			_and "$new_file" "$line" 's,^/usr/libexec,/usr/lib,g'
			_and "$new_file" "$line" 's,^/usr/libexec,/usr/lib64,g'
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

_rename(){
	while read -r file
	do
		new_name="$(echo "$file" | sed -e 's,.fc.new$,.fc,g')"
		rm -f "$new_name"
		mv "$file" "$new_name"
	done < <(find . -type f -iname '*.fc.new')
}

mk_paths_list
process_dublicate_paths

if [ "$PKG_BUILD" = 1 ]; then _rename ; fi
