#!/usr/bin/env bash

# Manipulate with paths in SELinux policies to make them work
# in another GNU/Linux distribution, e.g. adopt Fedora's selinux-policy for ROSA
# without changing all thousands of paths manually.

# In MODE=alias-dups-remove if there are both lines like e.g.
# /bin/su -- gen_context(system_u:object_r:su_exec_t,s0)
# /usr/bin/su -- gen_context(system_u:object_r:su_exec_t,s0)
# we must remove a line with either /bin/su or /usr/bin/su by this script,
# all occurences of /bin, /sbin and /usr/sbin will be changed to /usr/bin
# and then /bin, /sbin and /usr/sbin must be aliased to /usr/bin
# in file_contexts.subs_dist. This will allow us to not worry that binary xxx
# may be in defferent *bin* directories in different distributions.
# When both those lines are in policy AND there are aliases
# "/bin /usr/bin" and (or?) "/usr/bin /bin"
# matchpathcon(3) will do something like just ignoring that lines in policy.
# We try to avoid that.
# That's why MODE=alias-dups-remove was invented.

# In MODE=duplicate we do not add aliases to file_contexts.subs_dist
# but this script will duplicate lines changing path in duplicated ones.
# Currently this mode leads to not buildable Fedora's selinux-policy for
# some unknown reasons. This was the original reason to write this script.

# When environmental variable PKG_BUILD=1 real changes to files are made,
# otherwise files *.fc are copied to *.fc.new and you can diff original
# *.fc and *.fc.new ones.

# Authors:
# - Mikhail Novosyolov <m.novosyolov@rosalinux.ru>, 2019

set -efu

TMP="${TMP:-$(mktemp -d)}"
PL="${PL:-${TMP}/paths.list}"
NOCHANGE_LIST="${NOCHANGE_LIST:-${TMP}/nochange.list}"
MODE="${MODE:-alias-dups-remove}"
DISTRO="${DISTRO:-redhat}"

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

# "and" is "append without duplicates"
_and(){
	# Usage: _and <file> <string> <sed pattern>
	if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
		echo "Not sufficient args, usage: _and <file> <string> <sed pattern>"
		return 1
	fi
	sedded_line="$(echo "$2" | sed -e "$3")"
	line_fixed="$(echo "$sedded_line" | sed -e 's,  , ,g' -e 's,\t, ,g')"
	if [ -n "$add_grep_pattern" ]
		then grep_pattern="${sedded_line}|${line_fixed}|${add_grep_pattern}"
		else grep_pattern="${sedded_line}|${line_fixed}"
	fi
	#grep_results="$(grep -rEI "$grep_pattern" .)"
	#if [ -n "$grep_results" ]
	if grep -rEIq --include="*.fc.new" "$grep_pattern" .
		then
			:
		else
			echo "$sedded_line" >> "$1"
	fi
	unset add_grep_pattern
}

_ln(){
	ln="$(cat "$new_file" | wc -l)"
}

copy_and_add_paths(){
	if [ ! -f "$1" ]; then
		echo "File $file not found"
		return 1
	fi
	file="$1"
	new_file="${file}.new"
	touch "$new_file"
	skipping=0
	ln=0 # line number

	while read -r line
	do
		_ln
		# skip all ifdef/ifndef blocks which do not refer to the target distro
		if echo "$line" | grep -qE '^ifdef|^ifndef' && ! echo "$line" | grep -q "distro_${DISTRO}"; then
			skipping=1
		fi
		if [ "$skipping" = 1 ]; then
			if echo "$line" | grep -q "^')"
				then skipping=0 && continue
				else continue
			fi
		fi

		case "$MODE" in
		duplicate )
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
		;;
		alias-dups-remove )
		if echo "$line" | grep -qE '^/bin/|^/usr/bin/|^/sbin/|^/usr/sbin/'
			then
				# Bellow 's,\\,\\\\,g' fixes a problem that `grep "xxx\.foo"` (with backslash) does not find anything,
				# but `grep "xxx\\.foo"` does find.
				# 's,*,\\*,g' fixes a problem that `grep "/bin/.*"` also finds "/bin", here we escape "*" to prevent it from being a wildcard.
				p1="$(echo "$line" | awk -F 'bin/' '{print $NF}' | awk '{print $1}' | sed -e 's,\\,\\\\,g' -e 's,*,\\*,g')"
				p2="$(echo "$line" | awk -F 'bin/' '{print $NF}' | awk '{print $NF}')"
				# [[:blank:]] is a POSIX regexp for both tabs and spaces
				if ! grep -inHr --include="*.fc.new" "/${p1}[[:blank:]]" . | grep -q --include="*.fc.new" "${p2}" ; then
					echo "$line" | sed \
						-e 's,^/bin/,/usr/bin/,g' \
						-e 's,^/sbin/,/usr/bin/,g' \
						-e 's,^/usr/sbin/,/usr/bin/,g' \
						>> "$new_file"
				fi
			else
				echo "$line" >> "$new_file"
				_ln
				# cleanup 'if' blocks which got empty
				if echo "$line" | grep -q "^')" && \
					sed "$((ln-1))!d" "$new_file" | grep -qE '^ifdef|^ifndef' ; then
						sed "$((ln-1))d" -i "$new_file"
						sed "${ln}d" -i "$new_file"
						continue
				fi
				_ln
				if echo "$line" | grep -q "^')" && \
					sed "$((ln-1))!d" "$new_file" | grep -q "^'\," ; then
						sed "$((ln-1))d" -i "$new_file"
						continue
				fi
				_ln
		fi
		;;
		* )
		echo "Unknown METHOD $METHOD"
		exit 1
		;;
		esac

		#ln=$((ln+1))
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
