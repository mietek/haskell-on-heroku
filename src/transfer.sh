#!/usr/bin/env bash


function has_s3 () {
	has_vars AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY HALCYON_S3_BUCKET HALCYON_S3_ACL
}




function echo_default_s3_url () {
	expect_vars HALCYON_S3_URL

	local object
	expect_args object -- "$@"

	echo "${HALCYON_S3_URL}${object:-}"
}




function download_original () {
	local src_object original_url dst_dir
	expect_args src_object original_url dst_dir -- "$@"

	if [ -f "${dst_dir}/${src_object}" ]; then
		return 0
	fi

	if has_s3; then
		if s3_curl_download "${HALCYON_S3_BUCKET}" "${src_object}" "${dst_dir}"; then
			return 0
		fi
	fi

	curl_download "${original_url}" "${dst_dir}"

	if has_s3; then
		s3_curl_upload "${dst_dir}/${src_object}" "${HALCYON_S3_BUCKET}" "${HALCYON_S3_ACL}"
	fi
}





function download_prepared () {
	local src_object dst_dir
	expect_args src_object dst_dir -- "$@"

	if [ -f "${dst_dir}/${src_object}" ]; then
		return 0
	fi

	if has_s3; then
		if s3_curl_download "${HALCYON_S3_BUCKET}" "${src_object}" "${dst_dir}"; then
			return 0
		fi
		return 1
	fi

	local prepared_url
	if has_vars HALCYON_S3_BUCKET; then
		prepared_url=$( echo_s3_url "${HALCYON_S3_BUCKET}" "${src_object}" ) || die
	else
		prepared_url=$( echo_default_s3_url "${src_object}" ) || die
	fi

	curl_download "${prepared_url}" "${dst_dir}"
}


function list_prepared () {
	if has_s3; then
		if s3_curl_list "${HALCYON_S3_BUCKET}"; then
			return 0
		fi
		return 1
	fi

	local prepared_url
	if has_vars HALCYON_S3_BUCKET; then
		prepared_url=$( echo_s3_url "${HALCYON_S3_BUCKET}" '' ) || die
	else
		prepared_url=$( echo_default_s3_url '' ) || die
	fi

	log_indent "Listing ${prepared_url}..."

	local status response
	status=0
	if ! response=$( curl_quietly "${prepared_url}" --output >( read_s3_bucket_xml ) ); then
		status=1
	else
		echo "${response}"
	fi

	return "${status}"
}


function upload_prepared () {
	local src_file
	expect_args src_file -- "$@"

	if has_s3; then
		s3_curl_upload "${src_file}" "${HALCYON_S3_BUCKET}" "${HALCYON_S3_ACL}"
	fi
}




function download_any_prepared () {
	local src_objects dst_dir
	expect_args src_objects dst_dir -- "$@"

	local status src_object
	status=1
	while read -r src_object; do
		if download_prepared "${src_object}" "${dst_dir}"; then
			status=0
		fi
	done <<<"${src_objects}"

	return "${status}"
}
