#!/usr/bin/env bash


function echo_app_label () {
	local app_name app_version
	expect_args app_name app_version -- "$@"

	echo "${app_name}-${app_version}"
}


function echo_app_label_name () {
	local app_label
	expect_args app_label -- "$@"

	echo "${app_label%-*}"
}


function echo_app_label_version () {
	local app_label
	expect_args app_label -- "$@"

	echo "${app_label##*-}"
}


function echo_fake_app_label () {
	local real_app_label
	expect_args real_app_label -- "$@"

	local real_app_name app_version fake_app_name
	real_app_name=$( echo_app_label_name "${real_app_label}" ) || die
	app_version=$( echo_app_label_version "${real_app_label}" ) || die
	fake_app_name="halcyon-sandbox-${real_app_name}"

	echo_app_label "${fake_app_name}" "${app_version}"
}


function echo_real_app_label () {
	local app_label
	expect_args app_label -- "$@"

	if [ -z "${app_label}" ]; then
		echo ''
		return 0
	fi

	local app_name app_version real_app_name
	app_name=$( echo_app_label_name "${app_label}" ) || die
	app_version=$( echo_app_label_version "${app_label}" ) || die
	real_app_name="${app_name#halcyon-sandbox-}"

	if [ "${real_app_name}" = 'base' ]; then
		echo ''
	else
		echo_app_label "${real_app_name}" "${app_version}"
	fi
}




function echo_fake_package () {
	local real_app_label
	expect_args real_app_label -- "$@"

	local real_app_name app_version fake_app_label fake_app_name
	real_app_name=$( echo_app_label_name "${real_app_label}" ) || die
	app_version=$( echo_app_label_version "${real_app_label}" ) || die
	fake_app_label=$( echo_fake_app_label "${real_app_label}" ) || die
	fake_app_name=$( echo_app_label_name "${fake_app_label}" ) || die

	cat <<-EOF
		name:           ${fake_app_name}
		version:        ${app_version}
		build-type:     Simple
		cabal-version:  >= 1.2

		executable ${fake_app_name}
EOF

	if [ "${real_app_name}" = 'base' ]; then
		echo '  build-depends: base'
	else
		echo "  build-depends: base, ${real_app_name} ==${app_version}"
	fi
}




function detect_package () {
	local build_dir
	expect_args build_dir -- "$@"
	expect "${build_dir}"

	local package_file
	if ! package_file=$(
		find_spaceless "${build_dir}" -maxdepth 1 -name '*.cabal' |
		match_exactly_one
	); then
		die "Expected exactly one ${build_dir}/*.cabal"
	fi

	cat "${package_file}"
}


function detect_app_name () {
	local build_dir
	expect_args build_dir -- "$@"

	local app_name
	if ! app_name=$(
		detect_package "${build_dir}" |
		awk '/^ *[Nn]ame:/ { print $2 }' |
		match_exactly_one
	); then
		die 'Expected exactly one app name'
	fi

	echo "${app_name}"
}


function detect_app_version () {
	local build_dir
	expect_args build_dir -- "$@"

	local app_version
	if ! app_version=$(
		detect_package "${build_dir}" |
		awk '/^ *[Vv]ersion:/ { print $2 }' |
		match_exactly_one
	); then
		die 'Expected exactly one app version'
	fi

	echo "${app_version}"
}


function detect_app_executable () {
	local build_dir
	expect_args build_dir -- "$@"

	local app_executable
	if ! app_executable=$(
		detect_package "${build_dir}" |
		awk '/^ *[Ee]xecutable / { print $2 }' |
		match_exactly_one
	); then
		die 'Expected exactly one app executable'
	fi

	echo "${app_executable}"
}


function detect_app_label () {
	local build_dir
	expect_args build_dir -- "$@"

	local app_name app_version
	app_name=$( detect_app_name "${build_dir}" ) || die
	app_version=$( detect_app_version "${build_dir}" ) || die

	echo_app_label "${app_name}" "${app_version}"
}
