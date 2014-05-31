#!/usr/bin/env bash


function echo_cache_tmp_dir () {
	mktemp -du "/tmp/halcyon-cache.XXXXXXXXXX"
}


function echo_cache_tmp_old_dir () {
	mktemp -du "/tmp/halcyon-cache.old.XXXXXXXXXX"
}




function prepare_cache () {
	expect_vars HALCYON_CACHE PURGE_HALCYON_CACHE

	export HALCYON_CACHE_TMP_OLD_DIR=$( echo_cache_tmp_old_dir ) || die

	if ! [ -d "${HALCYON_CACHE}" ]; then
		mkdir -p "${HALCYON_CACHE}" || die
		return 0
	fi

	if (( ${PURGE_HALCYON_CACHE} )); then
		log_begin 'Purging cache...'

		rm -rf "${HALCYON_CACHE}" || die
		mkdir -p "${HALCYON_CACHE}" || die

		log_end 'done'
		return 0
	fi

	log_begin 'Preparing cache...'

	rm -rf "${HALCYON_CACHE_TMP_OLD_DIR}" || die
	mkdir -p "${HALCYON_CACHE}" || die
	cp -R "${HALCYON_CACHE}" "${HALCYON_CACHE_TMP_OLD_DIR}" || die

	log_end 'done'

	log 'Examining cache'

	find_spaceless "${HALCYON_CACHE}" |
		sed "s:^${HALCYON_CACHE}/::" |
		sort_naturally |
		sed 's/^/+ /' |
		log_file_indent || die
}


function clean_cache () {
	expect_vars HALCYON HALCYON_CACHE HALCYON_CACHE_TMP_OLD_DIR

	expect_args build_dir -- "$@"

	log_begin 'Cleaning cache...'

	local tmp_dir
	tmp_dir=$( echo_cache_tmp_dir ) || die

	mkdir -p "${tmp_dir}" || die

	if [ -f "${HALCYON}/ghc/tag" ]; then
		local ghc_tag ghc_archive
		ghc_tag=$( <"${HALCYON}/ghc/tag" ) || die
		ghc_archive=$( echo_ghc_archive "${ghc_tag}" ) || die

		if [ -f "${HALCYON_CACHE}/${ghc_archive}" ]; then
			mv "${HALCYON_CACHE}/${ghc_archive}" "${tmp_dir}" || die
		fi
	fi

	if [ -f "${HALCYON}/cabal/tag" ]; then
		local cabal_tag cabal_archive
		cabal_tag=$( <"${HALCYON}/cabal/tag" ) || die
		cabal_archive=$( echo_cabal_archive "${cabal_tag}" ) || die

		if [ -f "${HALCYON_CACHE}/${cabal_archive}" ]; then
			mv "${HALCYON_CACHE}/${cabal_archive}" "${tmp_dir}" || die
		fi
	fi

	if [ -f "${HALCYON}/sandbox/tag" ]; then
		local sandbox_tag sandbox_archive
		sandbox_tag=$( <"${HALCYON}/sandbox/tag" ) || die
		sandbox_archive=$( echo_sandbox_archive "${sandbox_tag}" ) || die

		if [ -f "${HALCYON_CACHE}/${sandbox_archive}" ]; then
			mv "${HALCYON_CACHE}/${sandbox_archive}" "${tmp_dir}" || die
		fi
	fi

	local build_tag
	build_tag=$( infer_build_tag "${build_dir}" ) || die
	build_archive=$( echo_build_archive "${build_tag}" ) || die

	if [ -f "${HALCYON_CACHE}/${build_archive}" ]; then
		mv "${HALCYON_CACHE}/${build_archive}" "${tmp_dir}" || die
	fi

	rm -rf "${HALCYON_CACHE}" || die
	mv "${tmp_dir}" "${HALCYON_CACHE}" || die

	log_end 'done'

	if [ -d "${HALCYON_CACHE_TMP_OLD_DIR}" ]; then
		log 'Examining cache changes'

		compare_recursively "${HALCYON_CACHE_TMP_OLD_DIR}" "${HALCYON_CACHE}" |
			filter_not_matching '^= ' |
			log_file_indent || die
		rm -rf "${HALCYON_CACHE_TMP_OLD_DIR}" || die
	fi
}
