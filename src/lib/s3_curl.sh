#!/usr/bin/env bash


function echo_s3_host () {
	echo "s3.amazonaws.com"
}


function echo_s3_resource () {
	local bucket object
	expect_args bucket object -- "$@"

	echo "/${bucket}/${object:-}"
}


function echo_s3_url () {
	local bucket object
	expect_args bucket object -- "$@"

	local host resource
	host=$( echo_s3_host ) || die
	resource=$( echo_s3_resource "${bucket}" "${object}" ) || die

	echo "https://${host}${resource}"
}




function read_s3_bucket_xml () {
	IFS='>'

	local element contents
	while read -r -d '<' element contents; do
		if [ "${element}" = 'Key' ]; then
			echo "${contents}"
		fi
	done
}




function s3_curl_quietly () {
	expect_vars AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY

	local resource
	expect_args resource -- "$@"
	shift

	local host date
	host=$( echo_s3_host ) || die
	date=$( check_http_date ) || die

	local signature
	signature=$(
		sed "s/HTTP_DATE/${date}/" |
			perl -pe 'chomp if eof' |
			openssl sha1 -hmac "${AWS_SECRET_ACCESS_KEY}" -binary |
			base64
	) || die

	local auth
	auth="AWS ${AWS_ACCESS_KEY_ID}:${signature}"

	curl_quietly "https://${host}${resource}" \
		--header "Host: ${host}"          \
		--header "Date: ${date}"          \
		--header "Authorization: ${auth}" \
		"$@"
}




function s3_curl_download () {
	local src_bucket src_object dst_dir
	expect_args src_bucket src_object dst_dir -- "$@"
	expect_no "${dst_dir}/${src_object}"

	local src_resource
	src_resource=$( echo_s3_resource "${src_bucket}" "${src_object}" ) || die

	log_indent "Downloading s3:/${src_resource}..."

	mkdir -p "${dst_dir}" || die

	s3_curl_quietly "${src_resource}"           \
		--output "${dst_dir}/${src_object}" \
		<<-EOF
			GET


			HTTP_DATE
			${src_resource}
EOF
}


function s3_curl_list () {
	local src_bucket
	expect_args src_bucket -- "$@"

	local src_resource
	src_resource=$( echo_s3_resource "${src_bucket}" '' ) || die

	log_indent "Listing s3:/${src_resource}..."

	local status response
	status=0
	if ! response=$(
		s3_curl_quietly "${src_resource}"        \
			--output >( read_s3_bucket_xml ) \
			<<-EOF
				GET


				HTTP_DATE
				${src_resource}
EOF
	); then
		status=1
	else
		echo "${response}"
	fi

	return "${status}"
}


function s3_curl_check () {
	local src_bucket src_object
	expect_args src_bucket src_object -- "$@"

	local src_resource
	src_resource=$( echo_s3_resource "${src_bucket}" "${src_object}" ) || die

	log_indent "Checking s3:/${src_resource}..."

	s3_curl_quietly "${src_resource}" \
		--head                    \
		--output '/dev/null'      \
		<<-EOF
			HEAD


			HTTP_DATE
			${src_resource}
EOF
}


function s3_curl_upload () {
	local src_file dst_bucket dst_acl
	expect_args src_file dst_bucket dst_acl -- "$@"
	expect "${src_file}"

	local src_object dst_resource
	src_object=$( basename "${src_file}" ) || die
	dst_resource=$( echo_s3_resource "${dst_bucket}" "${src_object}" ) || die

	log_indent "Uploading s3:/${dst_resource}..."

	local src_digest
	src_digest=$(
		openssl md5 -binary <"${src_file}" |
			base64
	) || die

	s3_curl_quietly "${dst_resource}"             \
		--header "Content-MD5: ${src_digest}" \
		--header "x-amz-acl: ${dst_acl}"      \
		--output '/dev/null'                  \
		--upload-file "${src_file}"           \
		<<-EOF
			PUT
			${src_digest}

			HTTP_DATE
			x-amz-acl:${dst_acl}
			${dst_resource}
EOF
}


function s3_curl_create () {
	local dst_bucket dst_acl
	expect_args dst_bucket dst_acl -- "$@"

	local dst_resource
	dst_resource=$( echo_s3_resource "${dst_bucket}" '' ) || die

	log_indent "Creating s3:/${dst_resource}..."

	s3_curl_quietly "${dst_resource}"        \
		--header "x-amz-acl: ${dst_acl}" \
		--output '/dev/null'             \
		--request PUT                    \
		<<-EOF
			PUT


			HTTP_DATE
			x-amz-acl:${dst_acl}
			${dst_resource}
EOF
}


function s3_curl_copy () {
	local src_object src_bucket dst_object dst_bucket dst_acl
	expect_args src_object src_bucket dst_object dst_bucket dst_acl -- "$@"

	local src_resource dst_resource
	src_resource=$( echo_s3_resource "${src_bucket}" "${src_object}" ) || die
	dst_resource=$( echo_s3_resource "${dst_bucket}" "${dst_object}" ) || die

	log_indent "Copying s3:/${src_resource} to s3:/${dst_resource}..."

	s3_curl_quietly "${dst_resource}"                     \
		--header "x-amz-acl: ${dst_acl}"              \
		--header "x-amz-copy-source: ${src_resource}" \
		--output '/dev/null'                          \
		--request PUT                                 \
		<<-EOF
			PUT


			HTTP_DATE
			x-amz-acl:${dst_acl}
			x-amz-copy-source:${src_resource}
			${dst_resource}
EOF
}


function s3_curl_delete () {
	local dst_bucket dst_object
	expect_args dst_bucket dst_object -- "$@"

	local dst_resource
	dst_resource=$( echo_s3_resource "${dst_bucket}" "${dst_object}" ) || die

	log_indent "Deleting s3:/${dst_resource}..."

	s3_curl_quietly "${dst_resource}" \
		--output '/dev/null'      \
		--request DELETE          \
		<<-EOF
			DELETE


			HTTP_DATE
			${dst_resource}
EOF
}
