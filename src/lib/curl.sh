#!/usr/bin/env bash


function curl_quietly () {
	local url
	expect_args url -- "$@"
	shift

	local status response
	status=0
	if ! response=$(
		curl "${url}"                      \
			--fail                     \
			--location                 \
			--silent                   \
			--show-error               \
			--write-out "%{http_code}" \
			"$@"                       \
			2>'/dev/null'
	); then
		status=1
	fi

	case "${response}" in
	'200')
		re_log 'done';;
	'2'*)
		re_log "done, ${response}";;
	*)
		re_log "${response}"
	esac

	return "${status}"
}




function curl_download () {
	local src_url dst_dir
	expect_args src_url dst_dir -- "$@"

	local src_object
	src_object=$( basename "${src_url}" ) || die
	expect_no "${dst_dir}/${src_object}"

	log_indent "Downloading ${src_url}..."

	mkdir -p "${dst_dir}" || die

	curl_quietly "${src_url}" \
		--output "${dst_dir}/${src_object}"
}


function curl_check () {
	local src_url
	expect_args src_url -- "$@"

	log_indent "Checking ${src_url}..."

	curl_quietly "${src_url}" \
		--head            \
		--output '/dev/null'
}


function curl_upload () {
	local src_file dst_url
	expect_args src_file dst_url -- "$@"
	expect "${src_file}"

	log_indent "Uploading ${dst_url}..."

	curl_quietly "${dst_url}"    \
		--output '/dev/null' \
		--upload-file "${src_file}"
}


function curl_delete () {
	local dst_url
	expect_args dst_url -- "$@"

	log_indent "Deleting ${dst_url}..."

	curl_quietly "${dst_url}"    \
		--output '/dev/null' \
		--request DELETE
}
