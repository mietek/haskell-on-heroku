#!/usr/bin/env bash


if [ "$( uname )" = 'Linux' ]; then
	function check_date () {
		date "$@"
	}
else
	function check_date () {
		gdate "$@"
	}
fi


function check_http_date () {
	check_date --utc --rfc-2822 "$@"
}


function check_timestamp () {
	check_date --utc +'%Y%m%d%H%M%S' "$@"
}




function filter_last () {
	tail -n 1
}


function filter_not_last () {
	sed '$d'
}


function filter_matching () {
	local pattern
	expect_args pattern -- "$@"

	awk '/'"${pattern}"'/ { print }'
}


function filter_not_matching () {
	local pattern
	expect_args pattern -- "$@"

	awk '!/'"${pattern}"'/ { print }'
}




function match_at_most_one () {
	awk '{ print } NR == 2 { exit 2 }'
}


function match_at_least_one () {
	grep .
}


function match_exactly_one () {
	match_at_most_one | match_at_least_one
}




if [ "$( uname )" = 'Linux' ]; then
	function sort_naturally () {
		sort -V "$@"
	}
else
	function sort_naturally () {
		gsort -V "$@"
	}
fi


function sort0_naturally () {
	sort_naturally -z
}




function strip0 () {
	local file
	while read -rd $'\0' file; do
		strip "$@" "${file}"
	done
}




function measure_recursively () {
	local path
	expect_args path -- "$@"

	du -sh "${path}" | awk '{ print $1 }' || die
}




function find_spaceless () {
	local dst_dir
	expect_args dst_dir -- "$@"
	shift

	find "${dst_dir}" "$@" -type f -and \( -path '* *' -prune -or -print \)
}




function find_added () {
	local old_dir new_dir
	expect_args old_dir new_dir -- "$@"

	local new_file
	find "${new_dir}" -type f -print0 |
		sort0_naturally |
		while read -rd $'\0' new_file; do
			local path old_file
			path="${new_file##${new_dir}/}"
			old_file="${old_dir}/${path}"
			if ! [ -f "${old_file}" ]; then
				echo "${path}"
			fi
		done
}


function find_changed () {
	local old_dir new_dir
	expect_args old_dir new_dir -- "$@"

	local new_file
	find "${new_dir}" -type f -print0 |
		sort0_naturally |
		while read -rd $'\0' new_file; do
			local path old_file
			path="${new_file##${new_dir}/}"
			old_file="${old_dir}/${path}"
			if [ -f "${old_file}" ] && ! cmp -s "${old_file}" "${new_file}"; then
				echo "${path}"
			fi
		done
}


function find_not_changed () {
	local old_dir new_dir
	expect_args old_dir new_dir -- "$@"

	local new_file
	find "${new_dir}" -type f -print0 |
		sort0_naturally |
		while read -rd $'\0' new_file; do
			local path old_file
			path="${new_file##${new_dir}/}"
			old_file="${old_dir}/${path}"
			if [ -f "${old_file}" ] && cmp -s "${old_file}" "${new_file}"; then
				echo "${path}"
			fi
		done
}


function find_removed () {
	local old_dir new_dir
	expect_args old_dir new_dir -- "$@"

	local old_file
	find "${old_dir}" -type f -print0 |
		sort0_naturally |
		while read -rd $'\0' old_file; do
			local path new_file
			path="${old_file##${old_dir}/}"
			new_file="${new_dir}/${path}"
			if ! [ -f "${new_file}" ]; then
				echo "${path}"
			fi
		done
}




function compare_recursively () {
	local old_dir new_dir
	expect_args old_dir new_dir -- "$@"

	(
		find_added "${old_dir}" "${new_dir}" | sed 's/$/ +/'
		find_changed "${old_dir}" "${new_dir}" | sed 's/$/ */'
		find_not_changed "${old_dir}" "${new_dir}" | sed 's/$/ =/'
		find_removed "${old_dir}" "${new_dir}" | sed 's/$/ -/'
	) |
		sort_naturally |
		awk '{ print $2 " " $1 }'
}




function silently () {
	expect_vars SILENCE_HALCYON_OUTPUT

	expect_args cmd -- "$@"
	shift

	if (( ${SILENCE_HALCYON_OUTPUT} )); then
		local tmp_log
		tmp_log=$( mktemp -u "/tmp/${cmd}.log.XXXXXXXXXX" ) || die

		if ! "${cmd}" "$@" >&"${tmp_log}"; then
			log_file_indent <"${tmp_log}"
			die
		fi

		rm -f "${tmp_log}" || die
	else
		"${cmd}" "$@" |& log_file_indent || die
	fi
}
