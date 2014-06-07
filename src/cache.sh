#!/usr/bin/env bash


function echo_cache_tmp_dir () {
	mktemp -du "/tmp/halcyon-cache.XXXXXXXXXX"
}


function echo_cache_tmp_old_dir () {
	mktemp -du "/tmp/halcyon-cache.old.XXXXXXXXXX"
}




function prepare_cache () {
	expect_vars HALCYON_CACHE_DIR HALCYON_PURGE_CACHE

	export HALCYON_CACHE_DIR_TMP_OLD_DIR=$( echo_cache_tmp_old_dir ) || die

	if ! [ -d "${HALCYON_CACHE_DIR}" ]; then
		mkdir -p "${HALCYON_CACHE_DIR}" || die
		return 0
	fi

	if (( ${HALCYON_PURGE_CACHE} )); then
		log_begin 'Purging cache...'

		rm -rf "${HALCYON_CACHE_DIR}" || die
		mkdir -p "${HALCYON_CACHE_DIR}" || die

		log_end 'done'
		return 0
	fi

	log_begin 'Preparing cache...'

	rm -rf "${HALCYON_CACHE_DIR_TMP_OLD_DIR}" || die
	mkdir -p "${HALCYON_CACHE_DIR}" || die
	cp -R "${HALCYON_CACHE_DIR}" "${HALCYON_CACHE_DIR_TMP_OLD_DIR}" || die

	log_end 'done'

	log 'Examining cache'

	find_spaceless "${HALCYON_CACHE_DIR}" |
		sed "s:^${HALCYON_CACHE_DIR}/::" |
		sort_naturally |
		sed 's/^/+ /' |
		log_file_indent || die
}


function clean_cache () {
	expect_vars HALCYON_DIR HALCYON_CACHE_DIR HALCYON_CACHE_DIR_TMP_OLD_DIR

	expect_args build_dir -- "$@"

	log_begin 'Cleaning cache...'

	local tmp_dir
	tmp_dir=$( echo_cache_tmp_dir ) || die

	mkdir -p "${tmp_dir}" || die

	if [ -f "${HALCYON_DIR}/ghc/tag" ]; then
		local ghc_tag ghc_archive
		ghc_tag=$( <"${HALCYON_DIR}/ghc/tag" ) || die
		ghc_archive=$( echo_ghc_archive "${ghc_tag}" ) || die

		if [ -f "${HALCYON_CACHE_DIR}/${ghc_archive}" ]; then
			mv "${HALCYON_CACHE_DIR}/${ghc_archive}" "${tmp_dir}" || die
		fi
	fi

	if [ -f "${HALCYON_DIR}/cabal/tag" ]; then
		local cabal_tag cabal_archive
		cabal_tag=$( <"${HALCYON_DIR}/cabal/tag" ) || die
		cabal_archive=$( echo_cabal_archive "${cabal_tag}" ) || die

		if [ -f "${HALCYON_CACHE_DIR}/${cabal_archive}" ]; then
			mv "${HALCYON_CACHE_DIR}/${cabal_archive}" "${tmp_dir}" || die
		fi
	fi

	if [ -f "${HALCYON_DIR}/sandbox/tag" ]; then
		local sandbox_tag sandbox_archive
		sandbox_tag=$( <"${HALCYON_DIR}/sandbox/tag" ) || die
		sandbox_archive=$( echo_sandbox_archive "${sandbox_tag}" ) || die

		if [ -f "${HALCYON_CACHE_DIR}/${sandbox_archive}" ]; then
			mv "${HALCYON_CACHE_DIR}/${sandbox_archive}" "${tmp_dir}" || die
		fi
	fi

	local build_tag
	build_tag=$( infer_build_tag "${build_dir}" ) || die
	build_archive=$( echo_build_archive "${build_tag}" ) || die

	if [ -f "${HALCYON_CACHE_DIR}/${build_archive}" ]; then
		mv "${HALCYON_CACHE_DIR}/${build_archive}" "${tmp_dir}" || die
	fi

	rm -rf "${HALCYON_CACHE_DIR}" || die
	mv "${tmp_dir}" "${HALCYON_CACHE_DIR}" || die

	log_end 'done'

	if [ -d "${HALCYON_CACHE_DIR_TMP_OLD_DIR}" ]; then
		log 'Examining cache changes'

		compare_recursively "${HALCYON_CACHE_DIR_TMP_OLD_DIR}" "${HALCYON_CACHE_DIR}" |
			filter_not_matching '^= ' |
			log_file_indent || die
		rm -rf "${HALCYON_CACHE_DIR_TMP_OLD_DIR}" || die
	fi
}
