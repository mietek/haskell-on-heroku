#!/usr/bin/env bash


function prefix_log () {
	local prefix
	prefix="$1"
	shift

	export LAST_LOG="${*:+${prefix}$*}"
	echo "${LAST_LOG}" >&2
}


function re_log () {
	echo -en "\e[A\e[K\r" >&2
	echo "${LAST_LOG:+${LAST_LOG} }$*" >&2
}




function log () {
	prefix_log '-----> ' "$@"
}


function log_indent () {
	prefix_log '       ' "$@"
}


function log_debug () {
	prefix_log '   *** DEBUG: ' "$@"
}


function log_warning () {
	prefix_log '   *** WARNING: ' "$@"
}


function log_error () {
	prefix_log '   *** ERROR: ' "$@"
}




if [ "$( uname )" = 'Linux' ]; then
	function log_file_indent () {
		sed -u "s/^/       /" >&2
	}
elif [ "$( uname )" = 'Darwin' ]; then
	function log_file_indent () {
		sed -l "s/^/       /"
	}
else
	function log_file_indent () {
		sed "s/^/       /"
	}
fi




function die () {
	if [ -n "${*:+_}" ]; then
		log_error "$@"
	fi
	exit 1
}
