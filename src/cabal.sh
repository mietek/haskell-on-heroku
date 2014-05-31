#!/usr/bin/env bash


function echo_cabal_original_url () {
	local cabal_version
	expect_args cabal_version -- "$@"

	case "${cabal_version}" in
	'1.20.0.2')
		echo 'http://www.haskell.org/cabal/release/cabal-install-1.20.0.2/cabal-install-1.20.0.2.tar.gz';;
	'1.20.0.1')
		echo 'http://www.haskell.org/cabal/release/cabal-install-1.20.0.1/cabal-install-1.20.0.1.tar.gz';;
	'1.20.0.0')
		echo 'http://www.haskell.org/cabal/release/cabal-install-1.20.0.0/cabal-install-1.20.0.0.tar.gz';;
	'1.18.0.3')
		echo 'http://www.haskell.org/cabal/release/cabal-install-1.18.0.3/cabal-install-1.18.0.3.tar.gz';;
	'1.18.0.2')
		echo 'http://www.haskell.org/cabal/release/cabal-install-1.18.0.2/cabal-install-1.18.0.2.tar.gz';;
	'1.18.0.1')
		echo 'http://www.haskell.org/cabal/release/cabal-install-1.18.0.1/cabal-install-1.18.0.1.tar.gz';;
	*)
		die "Unexpected Cabal version: ${cabal_version}"
	esac
}


function echo_cabal_default_version () {
	echo '1.20.0.2'
}




function echo_cabal_config () {
	expect_vars HALCYON

	cat <<-EOF
		remote-repo:                    hackage.haskell.org:http://hackage.haskell.org/packages/archive
		remote-repo-cache:              ${HALCYON}/cabal/packages
		avoid-reinstalls:               True
		reorder-goals:                  True
		require-sandbox:                True
		jobs:                           \$ncpus
		optimization:                   2
EOF
}




function echo_cabal_tag () {
	local cabal_version cabal_timestamp
	expect_args cabal_version cabal_timestamp -- "$@"

	echo "${cabal_version}${cabal_timestamp:+-${cabal_timestamp}}"
}


function echo_cabal_tag_version () {
	local cabal_tag
	expect_args cabal_tag -- "$@"

	echo "${cabal_tag%%-*}"
}


function echo_cabal_tag_timestamp () {
	local cabal_tag
	expect_args cabal_tag -- "$@"

	case "${cabal_tag}" in
	*'-'*)
		echo "${cabal_tag#*-}";;
	*)
		echo
	esac
}


function echo_cabal_archive () {
	local cabal_tag
	expect_args cabal_tag -- "$@"

	echo "halcyon-cabal-${cabal_tag}.tar.xz"
}


function echo_cabal_archive_tag () {
	local cabal_archive
	expect_args cabal_archive -- "$@"

	local archive_part
	archive_part="${cabal_archive#halcyon-cabal-}"

	echo "${archive_part%.tar.xz}"
}


function echo_updated_cabal_archive_prefix () {
	local cabal_version
	expect_args cabal_version -- "$@"

	echo "halcyon-cabal-${cabal_version}-"
}


function echo_updated_cabal_archive_pattern () {
	local cabal_version
	expect_args cabal_version -- "$@"

	echo "halcyon-cabal-${cabal_version}-.*\.tar\.xz"
}


function echo_cabal_description () {
	local cabal_tag
	expect_args cabal_tag -- "$@"

	local cabal_version cabal_timestamp
	cabal_version=$( echo_cabal_tag_version "${cabal_tag}" ) || die
	cabal_timestamp=$( echo_cabal_tag_timestamp "${cabal_tag}" ) || die

	if [ -z "${cabal_timestamp}" ]; then
		echo "Cabal ${cabal_version}"
	else
		local timestamp_date timestamp_time
		timestamp_date="${cabal_timestamp:0:4}-${cabal_timestamp:4:2}-${cabal_timestamp:6:2}"
		timestamp_time="${cabal_timestamp:8:2}:${cabal_timestamp:10:2}:${cabal_timestamp:12:2}"

		echo "updated Cabal ${cabal_version} (${timestamp_date} ${timestamp_time} UTC)"
	fi
}




function echo_cabal_tmp_dir () {
	mktemp -du "/tmp/halcyon-cabal.XXXXXXXXXX"
}




function validate_cabal_tag () {
	local cabal_version
	expect_args cabal_version -- "$@"

	local candidate_tag candidate_version
	candidate_tag=$( match_exactly_one ) || die
	candidate_version=$( echo_cabal_tag_version "${candidate_tag}" ) || die

	if [ "${candidate_version}" != "${cabal_version}" ]; then
		return 1
	fi
}


function validate_updated_cabal_tag () {
	local cabal_version
	expect_args cabal_version -- "$@"

	local candidate_tag candidate_version
	candidate_tag=$( match_exactly_one ) || die
	candidate_version=$( echo_cabal_tag_version "${candidate_tag}" ) || die

	if [ "${candidate_version}" != "${cabal_version}" ]; then
		return 1
	fi

	local candidate_timestamp yesterday_timestamp
	candidate_timestamp=$( echo_cabal_tag_timestamp "${candidate_tag}" ) || die
	yesterday_timestamp=$( check_timestamp -d yesterday ) || die

	if [[ "${candidate_timestamp}" < "${yesterday_timestamp}" ]]; then
		return 1
	fi
}




function match_updated_cabal_archive () {
	local cabal_version
	expect_args cabal_version -- "$@"

	local updated_pattern
	updated_pattern=$( echo_updated_cabal_archive_pattern "${cabal_version}" ) || die

	local updated_archive
	if ! updated_archive=$(
		filter_matching "^${updated_pattern}$" |
		sort_naturally |
		filter_last |
		match_exactly_one
	); then
		return 1
	fi

	if ! echo_cabal_archive_tag "${updated_archive}" |
		validate_updated_cabal_tag "${cabal_version}"
	then
		return 1
	fi

	echo "${updated_archive}"
}




function cabal_do () {
	expect_vars HALCYON
	expect "${HALCYON}/cabal/tag"

	local work_dir
	expect_args work_dir -- "$@"
	shift
	expect "${work_dir}"

	if ! (
		cd "${work_dir}" &&
		cabal --config-file="${HALCYON}/cabal/config" "$@"
	); then
		die 'Using Cabal failed'
	fi
}


function sandboxed_cabal_do () {
	expect_vars HALCYON

	local work_dir
	expect_args work_dir -- "$@"
	shift

	cabal_do "${work_dir}" \
		--sandbox-config-file="${HALCYON}/sandbox/cabal.sandbox.config" "$@"
}




function cabal_update () {
	silently cabal_do '.' update || die
}


function cabal_create_sandbox () {
	local sandbox_dir
	expect_args sandbox_dir -- "$@"
	expect_no "${sandbox_dir}"

	mkdir -p "${sandbox_dir}" || die
	silently cabal_do "${sandbox_dir}" sandbox init --sandbox '.' || die
}


function cabal_install () {
	local build_dir
	expect_args build_dir -- "$@"

	silently sandboxed_cabal_do "${build_dir}" install "$@" || die
}


function cabal_install_deps () {
	local build_dir unhappy_workaround
	expect_args build_dir unhappy_workaround -- "$@"

	if (( ${unhappy_workaround} )); then
		log_warning "Installing implicit versions of alex and happy"
		log

		silently sandboxed_cabal_do "${build_dir}" install alex happy || die
	fi

	silently sandboxed_cabal_do "${build_dir}" install --dependencies-only || die
}


function cabal_configure_app () {
	expect_vars HALCYON

	local build_dir
	expect_args build_dir -- "$@"

	silently sandboxed_cabal_do "${build_dir}" configure --prefix="${HALCYON}/app" || die
}


function cabal_build_app () {
	local build_dir
	expect_args build_dir -- "$@"

	silently sandboxed_cabal_do "${build_dir}" build || die
	silently sandboxed_cabal_do "${build_dir}" copy || die
}




function build_cabal () {
	expect_vars HOME HALCYON HALCYON_CACHE
	expect "${HOME}" "${HALCYON}/ghc/tag"
	expect_no "${HOME}/.cabal" "${HOME}/.ghc" "${HALCYON}/cabal"

	local cabal_version
	expect_args cabal_version -- "$@"

	log "Building Cabal ${cabal_version}"

	local original_url original_archive tmp_dir
	original_url=$( echo_cabal_original_url "${cabal_version}" ) || die
	original_archive=$( basename "${original_url}" ) || die
	tmp_dir=$( echo_cabal_tmp_dir ) || die

	if ! download_original "${original_archive}" "${original_url}" "${HALCYON_CACHE}"; then
		die "Cabal ${cabal_version} is not available"
	fi

	tar_extract "${HALCYON_CACHE}/${original_archive}" "${tmp_dir}" || die

	log "Bootstrapping Cabal ${cabal_version}"

	local ghc_tag ghc_version
	ghc_tag=$( <"${HALCYON}/ghc/tag" ) || die
	ghc_version=$( echo_ghc_tag_version "${ghc_tag}" ) || die

	case "${ghc_version}-${cabal_version}" in
	'7.8.2-1.20.0.'*)
		(
			cd "${tmp_dir}/cabal-install-${cabal_version}" || die
			patch -s <<-EOF
				--- a/bootstrap.sh
				+++ b/bootstrap.sh
				@@ -217,3 +217,3 @@ install_pkg () {

				-  \${GHC} --make Setup -o Setup ||
				+  \${GHC} -j -L"${HALCYON}/ghc/lib" -O2 --make Setup -o Setup ||
				      die "Compiling the Setup script failed."
EOF
		) || die;;
	*)
		die "Bootstrapping Cabal ${cabal_version} with GHC ${ghc_version} is not implemented yet"
	esac

	if ! (
		export EXTRA_BUILD_OPTS="-j" &&
		export EXTRA_CONFIGURE_OPTS="--extra-lib-dirs=${HALCYON}/ghc/lib -O2" &&
		alias curl="curl -fsS" &&
		cd "${tmp_dir}/cabal-install-${cabal_version}" &&
		silently ./bootstrap.sh --no-doc
	); then
		die 'Bootstrapping Cabal failed'
	fi

	mkdir -p "${HALCYON}/cabal/bin" || die
	mv "${HOME}/.cabal/bin/cabal" "${HALCYON}/cabal/bin/cabal" || die
	rm -rf "${HOME}/.cabal" "${HOME}/.ghc" "${tmp_dir}" || die

	echo_cabal_config >"${HALCYON}/cabal/config" || die
	echo_cabal_tag "${cabal_version}" '' >"${HALCYON}/cabal/tag" || die

	local cabal_size
	cabal_size=$( measure_recursively "${HALCYON}/cabal" ) || die
	log "Bootstrapped Cabal ${cabal_version}, ${cabal_size}"
}


function update_cabal () {
	expect_vars HALCYON
	expect "${HALCYON}/cabal/tag"

	local cabal_tag cabal_version
	cabal_tag=$( <"${HALCYON}/cabal/tag" ) || die
	cabal_version=$( echo_cabal_tag_version "${cabal_tag}" ) || die

	log "Updating Cabal ${cabal_version}"

	cabal_update || die

	local cabal_timestamp
	cabal_timestamp=$( check_timestamp ) || die
	echo_cabal_tag "${cabal_version}" "${cabal_timestamp}" >"${HALCYON}/cabal/tag" || die

	local cabal_size
	cabal_size=$( measure_recursively "${HALCYON}/cabal" ) || die
	log "Updated Cabal ${cabal_version}, ${cabal_size}"
}




function cache_cabal () {
	expect_vars HALCYON HALCYON_CACHE
	expect "${HALCYON}/cabal/tag"

	local cabal_tag
	cabal_tag=$( <"${HALCYON}/cabal/tag" ) || die
	cabal_description=$( echo_cabal_description "${cabal_tag}" ) || die

	log "Caching ${cabal_description}"

	local cabal_archive os
	cabal_archive=$( echo_cabal_archive "${cabal_tag}" ) || die
	os=$( detect_os ) || die

	rm -f "${HALCYON_CACHE}/${cabal_archive}" || die
	tar_archive "${HALCYON}/cabal" "${HALCYON_CACHE}/${cabal_archive}" || die
	upload_prepared "${HALCYON_CACHE}/${cabal_archive}" "${os}" || die
}


function restore_cabal () {
	expect_vars HALCYON HALCYON_CACHE

	local cabal_version
	expect_args cabal_version -- "$@"

	log "Restoring Cabal ${cabal_version}"

	if [ -f "${HALCYON}/cabal/tag" ] &&
		validate_cabal_tag "${cabal_version}" <"${HALCYON}/cabal/tag"
	then
		return 0
	fi
	rm -rf "${HALCYON}/cabal" || die

	local os cabal_tag cabal_archive
	os=$( detect_os ) || die
	cabal_tag=$( echo_cabal_tag "${cabal_version}" '' ) || die
	cabal_archive=$( echo_cabal_archive "${cabal_tag}" ) || die

	if ! download_prepared "${os}" "${cabal_archive}" "${HALCYON_CACHE}"; then
		log_warning "Cabal ${cabal_version} is not prepared"
		return 1
	fi

	tar_extract "${HALCYON_CACHE}/${cabal_archive}" "${HALCYON}/cabal" || die

	if ! [ -f "${HALCYON}/cabal/tag" ] ||
		! validate_cabal_tag "${cabal_version}" <"${HALCYON}/cabal/tag"
	then
		log_warning "Restoring ${cabal_archive} failed"
		rm -rf "${HALCYON}/cabal" || die
		return 1
	fi
}


function restore_cached_updated_cabal () {
	expect_vars HALCYON HALCYON_CACHE

	local cabal_version
	expect_args cabal_version -- "$@"

	if [ -f "${HALCYON}/cabal/tag" ] &&
		validate_updated_cabal_tag "${cabal_version}" <"${HALCYON}/cabal/tag"
	then
		return 0
	fi
	rm -rf "${HALCYON}/cabal" || die

	local cabal_archive
	if ! cabal_archive=$(
		find_spaceless "${HALCYON_CACHE}" |
		match_updated_cabal_archive "${cabal_version}"
	); then
		return 1
	fi

	tar_extract "${HALCYON_CACHE}/${cabal_archive}" "${HALCYON}/cabal" || die

	if ! [ -f "${HALCYON}/cabal/tag" ] ||
		! validate_updated_cabal_tag "${cabal_version}" <"${HALCYON}/cabal/tag"
	then
		log_warning "Restoring cached ${cabal_archive} failed"
		rm -rf "${HALCYON}/cabal" || die
		return 1
	fi
}


function restore_updated_cabal () {
	expect_vars HALCYON HALCYON_CACHE

	local cabal_version
	expect_args cabal_version -- "$@"

	log "Restoring updated Cabal ${cabal_version}"

	if restore_cached_updated_cabal "${cabal_version}"; then
		return 0
	fi

	log "Locating updated Cabal ${cabal_version}"

	local os archive_prefix
	os=$( detect_os ) || die
	archive_prefix=$( echo_updated_cabal_archive_prefix "${cabal_version}" ) || die

	local cabal_archive
	if ! cabal_archive=$(
		list_prepared "${os}/${archive_prefix}" |
		sed "s:${os}/::" |
		match_updated_cabal_archive "${cabal_version}"
	); then
		log_warning "No updated Cabal ${cabal_version} is prepared"
		return 1
	fi

	download_prepared "${os}" "${cabal_archive}" "${HALCYON_CACHE}" || die
	tar_extract "${HALCYON_CACHE}/${cabal_archive}" "${HALCYON}/cabal" || die

	if ! [ -f "${HALCYON}/cabal/tag" ] ||
		! validate_updated_cabal_tag "${cabal_version}" <"${HALCYON}/cabal/tag"
	then
		log_warning "Restoring ${cabal_archive} failed"
		rm -rf "${HALCYON}/cabal" || die
		return 1
	fi
}




function infer_cabal_version () {
	log_begin 'Inferring Cabal version...'

	local cabal_version
	if has_vars FORCE_CABAL_VERSION; then
		cabal_version="${FORCE_CABAL_VERSION}"

		log_end "${cabal_version}, forced"
	else
		cabal_version=$( echo_cabal_default_version ) || die

		log_end "done, ${cabal_version}"
	fi

	echo "${cabal_version}"
}




function activate_cabal () {
	expect_vars HOME HALCYON
	expect "${HOME}" "${HALCYON}/cabal/tag"

	local cabal_tag cabal_description
	cabal_tag=$( <"${HALCYON}/cabal/tag" ) || die
	cabal_description=$( echo_cabal_description "${cabal_tag}" ) || die

	log_begin "Activating ${cabal_description}..."

	if [ -e "${HOME}/.cabal/config" ] && ! [ -h "${HOME}/.cabal/config" ]; then
		die "Expected no custom ${HOME}/.cabal/config"
	fi

	mkdir -p "${HOME}/.cabal" || die
	rm -f "${HOME}/.cabal/config" || die
	ln -s "${HALCYON}/cabal/config" "${HOME}/.cabal/config" || die

	log_end 'done'
}


function deactivate_cabal () {
	expect_vars HOME HALCYON
	expect "${HOME}" "${HALCYON}/cabal/tag"

	local cabal_tag cabal_description
	cabal_tag=$( <"${HALCYON}/cabal/tag" ) || die
	cabal_description=$( echo_cabal_description "${cabal_tag}" ) || die

	log_begin "Deactivating ${cabal_description}..."

	if [ -e "${HOME}/.cabal/config" ] && ! [ -h "${HOME}/.cabal/config" ]; then
		die "Expected no custom ${HOME}/.cabal/config"
	fi

	rm -f "${HOME}/.cabal/config" || die

	log_end 'done'
}




function prepare_cabal () {
	expect_vars FORCE_CABAL_UPDATE NO_HALCYON_RESTORE

	local has_time
	expect_args has_time -- "$@"

	local cabal_version
	cabal_version=$( infer_cabal_version ) || die

	if ! (( ${NO_HALCYON_RESTORE} )) && ! (( ${FORCE_CABAL_UPDATE} )) &&
		restore_updated_cabal "${cabal_version}"
	then
		activate_cabal || die
		return 0
	fi

	if ! (( ${NO_HALCYON_RESTORE} )) && restore_cabal "${cabal_version}"; then
		update_cabal || die
		cache_cabal || die
		activate_cabal || die
		return 0
	fi

	(( ${has_time} )) || return 1

	build_cabal "${cabal_version}" || die
	cache_cabal || die
	update_cabal || die
	cache_cabal || die
	activate_cabal || die
}
