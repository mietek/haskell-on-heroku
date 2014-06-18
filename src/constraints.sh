#!/usr/bin/env bash


function echo_constraints_digest () {
	openssl sha1 | sed 's/^.* //'
}


function echo_constraints_config () {
	awk 'BEGIN { printf "constraints:"; separator = " " }
		!/^$/ { printf "%s%s ==%s", separator, $1, $2; separator = ",\n             " }
		END { printf "\n" }'
}


function echo_constraints_config_difference () {
	expect_args old_constraints new_constraints -- "$@"

	local old_digest new_digest
	old_digest=$( echo_constraints_digest <<<"${old_constraints}" ) || die
	new_digest=$( echo_constraints_digest <<<"${new_constraints}" ) || die

	local tmp_old_config tmp_new_config
	tmp_old_config=$( echo_tmp_cabal_config ) || die
	tmp_new_config=$( echo_tmp_cabal_config ) || die

	echo_constraints_config <<<"${old_constraints}" >"${tmp_old_config}" || die
	echo_constraints_config <<<"${new_constraints}" >"${tmp_new_config}" || die

	echo "--- ${old_digest:0:7}/cabal.config"
	echo "+++ ${new_digest:0:7}/cabal.config"
	diff -u "${tmp_old_config}" "${tmp_new_config}" | tail -n +3 || true

	rm -f "${tmp_old_config}" "${tmp_new_config}" || die
}




function read_constraints_from_config () {
	awk '/^ *[Cc]onstraints:/, !/[:,]/ { print }' |
		sed 's/[Cc]onstraints://;s/[, ]//g;s/==/ /;/^$/d'
}


function read_constraints_from_freeze_dry_run () {
	tail -n +3 |
		sed 's/ == / /'
}


function read_constraints_from_install_dry_run () {
	tail -n +3 |
		awk '{ print $1 }' |
		sed -E 's/^(.*)-(.*)$/\1 \2/'
}




function filter_valid_constraints () {
	local -A constraints_A

	local candidate_package candidate_version
	while read -r candidate_package candidate_version; do
		if [ -n "${constraints_A[${candidate_package}]:+_}" ]; then
			die "Expected at most one ${candidate_package} constraint"
		fi
		constraints_A["${candidate_package}"]="${candidate_version}"

		echo "${candidate_package} ${candidate_version}"
	done

	if [ -z "${constraints_A[base]:+_}" ]; then
		die 'Expected base constraint'
	fi
}


function score_constraints () {
	local constraints sandbox_tag
	expect_args constraints sandbox_tag -- "$@"

	local sandbox_description
	sandbox_description=$( echo_sandbox_description "${sandbox_tag}" ) || die

	local -A constraints_A

	local package version
	while read -r package version; do
		constraints_A["${package}"]="${version}"
	done <<<"${constraints}"

	local score candidate_package candidate_version
	score=0
	while read -r candidate_package candidate_version; do
		local version
		version="${constraints_A[${candidate_package}]:-}"
		if [ -z "${version}" ]; then
			log_indent "Ignoring ${sandbox_description} as ${candidate_package} is not needed"
			echo 0
			return 0
		fi
		if [ "${candidate_version}" != "${version}" ]; then
			log_indent "Ignoring ${sandbox_description} as ${candidate_package}-${version} is needed and not ${candidate_version}"
			echo 0
			return 0
		fi
		score=$(( ${score} + 1 ))
	done

	log_indent "${score}"$'\t'"${sandbox_description}"
	echo "${score}"
}




function detect_self_constraint () {
	local build_dir
	expect_args build_dir -- "$@"

	local app_name app_version
	app_name=$( detect_app_name "${build_dir}" ) || die
	app_version=$( detect_app_version "${build_dir}" ) || die

	echo "${app_name} ${app_version}"
}


function filter_non_self_constraints () {
	local build_dir
	expect_args build_dir -- "$@"

	# NOTE: An application should not be its own dependency.
	# https://github.com/haskell/cabal/issues/1908

	local app_constraint
	app_constraint=$( detect_self_constraint "${build_dir}" ) || die

	filter_valid_constraints |
		filter_not_matching "^${app_constraint}$" |
		sort_naturally
}




function detect_lib_constraints () {
	local build_dir
	expect_args build_dir -- "$@"
	expect "${build_dir}/cabal.config"

	read_constraints_from_config <"${build_dir}/cabal.config" |
		filter_non_self_constraints "${build_dir}" || die
}




function cabal_list_implicit_lib_constraints () {
	local build_dir
	expect_args build_dir -- "$@"
	expect "${build_dir}"

	cabal_do "${build_dir}" --no-require-sandbox freeze --dry-run |
		read_constraints_from_freeze_dry_run |
		filter_non_self_constraints "${build_dir}" || die
}


function cabal_list_actual_lib_constraints () {
	local build_dir
	expect_args build_dir -- "$@"
	expect "${build_dir}"

	sandboxed_cabal_do "${build_dir}" freeze --dry-run |
		read_constraints_from_freeze_dry_run |
		filter_non_self_constraints "${build_dir}" || die
}




function cabal_list_planned_lib_constraints () {
	local build_dir
	expect_args build_dir -- "$@"
	expect "${build_dir}"

	sandboxed_cabal_do "${build_dir}" install --dependencies-only --dry-run |
		read_constraints_from_install_dry_run || die
}


function cabal_list_planned_constraints () {
	local build_dir
	expect_args build_dir -- "$@"
	expect "${build_dir}"

	sandboxed_cabal_do "${build_dir}" install --dry-run |
		read_constraints_from_install_dry_run || die
}




function cabal_get_package_file () {
	local package_name package_version package_dir
	expect_args package_name package_version package_dir -- "$@"

	# NOTE: This should not download the entire package:
	# https://github.com/haskell/cabal/issues/1954

	local package_label package_file tmp_dir
	package_label="${package_name}-${package_version}"
	package_file="${package_dir}/${package_label}.cabal"
	expect_no "${package_file}"
	tmp_dir=$( echo_tmp_cabal_dir ) || die

	mkdir -p "${package_dir}" "${tmp_dir}" || die
	silently cabal_do "${tmp_dir}" get "${package_label}" || die
	mv "${tmp_dir}/${package_label}/${package_name}.cabal" "${package_file}" || die
	rm -rf "${tmp_dir}" || die
}


function cabal_dump_do () {
	expect_vars HALCYON_SRC_DIR

	if ! [ -f "${HALCYON_SRC_DIR}/cabal_dump" ]; then
		ghc --make -O2 -o "${HALCYON_SRC_DIR}/cabal_dump" \
			"${HALCYON_SRC_DIR}/cabal_dump.hs"        \
			&> '/dev/null' || die
	fi

	"${HALCYON_SRC_DIR}/cabal_dump" "$@"
}


function cabal_dump_package_build_tools () {
	local package_file
	expect_args package_file -- "$@"
	expect "${package_file}"

	cabal_dump_do "${package_file}" --build-tools-only || die
}


function cabal_dump_package_extra_libs () {
	local package_file
	expect_args package_file -- "$@"
	expect "${package_file}"

	cabal_dump_do "${package_file}" --extra-libs-only || die
}




function cabal_get_all_package_files () {
	expect_vars HALCYON_DIR

	local hackage_only package_dir
	expect_args hackage_only package_dir -- "$@"

	mkdir -p "${package_dir}" || die

	if ! (( ${hackage_only} )); then
		# NOTE: This is unacceptably inefficient right now.

		local package_name package_version
		while read -r package_name package_version; do
			cabal_get_package_file "${package_name}" "${package_version}" "${package_dir}" || die
		done

		return 0
	fi

	local index_archive constraints
	index_archive="${HALCYON_DIR}/cabal/packages/hackage.haskell.org/00-index.tar.gz"
	constraints=$( cat ) || die

	echo "${constraints}" |
		awk '{ print $1 "/" $2 "/" $1 ".cabal" }' |
		xargs tar -zxf "${index_archive}" -C "${package_dir}" --strip-components=2 || die

	local package_name package_version
	while read -r package_name package_version; do
		mv "${package_dir}/${package_name}.cabal" "${package_dir}/${package_name}-${package_version}.cabal" || die
	done <<<"${constraints}"
}


function cabal_dump_all_package_build_tools () {
	local package_dir
	expect_args package_dir -- "$@"
	expect "${package_dir}"

	local -A build_tools_A

	local package_name package_version
	while read -r package_name package_version; do
		local package_file build_tool
		package_file="${package_dir}/${package_name}-${package_version}.cabal"
		cabal_dump_package_build_tools "${package_file}" |
			while read -r build_tool; do
				if [ -z "${build_tools_A[${build_tool}]:+_}" ]; then
					build_tools_A["${build_tool}"]=1
					echo "${build_tool}"
				fi
			done
	done
}


function cabal_dump_all_package_extra_libs () {
	local package_dir
	expect_args package_dir -- "$@"
	expect "${package_dir}"

	local -A extra_libs_A

	local package_name package_version
	while read -r package_name package_version; do
		local package_file extra_lib
		package_file="${package_dir}/${package_name}-${package_version}.cabal"
		cabal_dump_package_extra_libs "${package_file}" |
			while read -r extra_lib; do
				if [ -z "${extra_libs_A[${extra_lib}]:+_}" ]; then
					extra_libs_A["${extra_lib}"]=1
					echo "${extra_lib}"
				fi
			done
	done
}
