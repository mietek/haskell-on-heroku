#!/usr/bin/env bash


function echo_sandbox_label () {
	local ghc_tag app_label
	expect_args ghc_tag app_label -- "$@"

	local ghc_version real_label
	ghc_version=$( echo_ghc_tag_version "${ghc_tag}" ) || die
	real_label=$( echo_real_app_label "${app_label}" ) || die

	echo "ghc-${ghc_version}${real_label:+-${real_label}}"
}


function echo_sandbox_tag () {
	local sandbox_digest sandbox_label
	expect_args sandbox_digest sandbox_label -- "$@"

	echo "${sandbox_label:+${sandbox_label}-}${sandbox_digest}"
}


function echo_sandbox_tag_digest () {
	local sandbox_tag
	expect_args sandbox_tag -- "$@"

	echo "${sandbox_tag##*-}"
}


function echo_sandbox_tag_label () {
	local sandbox_tag
	expect_args sandbox_tag -- "$@"

	case "${sandbox_tag}" in
	*'-'*)
		echo "${sandbox_tag%-*}";;
	*)
		echo
	esac
}


function echo_sandbox_archive () {
	local sandbox_tag
	expect_args sandbox_tag -- "$@"

	echo "halcyon-sandbox-${sandbox_tag}.tar.gz"
}


function echo_sandbox_archive_tag () {
	local sandbox_archive
	expect_args sandbox_archive -- "$@"

	local archive_part
	archive_part="${sandbox_archive#halcyon-sandbox-}"

	echo "${archive_part%.tar.xz}"
}


function echo_sandbox_config () {
	local sandbox_tag
	expect_args sandbox_tag -- "$@"

	echo "halcyon-sandbox-${sandbox_tag}.cabal.config"
}


function echo_sandbox_config_tag () {
	local sandbox_config
	expect_args sandbox_config -- "$@"

	local config_part
	config_part="${sandbox_config#halcyon-sandbox-}"

	echo "${config_part%.cabal.config}"
}


function echo_sandbox_config_pattern () {
	local ghc_tag
	expect_args ghc_tag -- "$@"

	local ghc_version
	ghc_version=$( echo_ghc_tag_version "${ghc_tag}" ) || die

	echo "halcyon-sandbox-ghc-${ghc_version}.*\.cabal\.config"
}




function validate_sandbox_tag () {
	local sandbox_tag
	expect_args sandbox_tag -- "$@"

	local candidate_tag
	candidate_tag=$( match_exactly_one ) || die

	if [ "${candidate_tag}" != "${sandbox_tag}" ]; then
		return 1
	fi
}


function validate_sandbox () {
	expect_vars HALCYON

	local build_dir sandbox_tag sandbox_constraints
	expect_args build_dir sandbox_tag sandbox_constraints -- "$@"

	local sandbox_digest
	sandbox_digest=$( echo_sandbox_tag_digest "${sandbox_tag}" ) || die

	local actual_constraints actual_digest
	actual_constraints=$( freeze_constraints "${build_dir}" 0 ) || die
	actual_digest=$( echo_constraints_digest <<< "${actual_constraints}" ) || die

	if [ "${actual_digest}" = "${sandbox_digest}" ]; then
		return 0
	fi

	log_warning "Actual sandbox digest is ${actual_digest}"
	log_warning 'Unexpected constraints difference:'
	echo_constraints_difference "${sandbox_constraints}" "${actual_constraints}" | log_file_indent
	log
	log_indent "Congratulations!  You have reproduced a Cabal issue!"
	log_indent "Please let the Cabal developers know:"
	log_indent "https://github.com/haskell/cabal/issues/1896"
	log
	log
}




function build_sandbox () {
	expect_vars HALCYON
	expect "${HALCYON}/ghc/tag" "${HALCYON}/cabal/tag"

	local build_dir sandbox_tag unhappy_workaround
	expect_args build_dir sandbox_tag unhappy_workaround -- "$@"
	expect "${build_dir}"

	local sandbox_label
	sandbox_label=$( echo_sandbox_tag_label "${sandbox_tag}" ) || die

	log "Building sandbox ${sandbox_label}..."

	if ! [ -d "${HALCYON}/sandbox" ]; then
		cabal_create_sandbox "${HALCYON}/sandbox" || die
	fi
	cabal_install_deps "${build_dir}" "${unhappy_workaround}" || die

	rm -rf "${HALCYON}/sandbox/logs" "${HALCYON}/sandbox/share" || die

	local sandbox_constraints
	if [ -f "${build_dir}/cabal.config" ]; then
		sandbox_constraints=$( detect_constraints "${build_dir}" ) || die
	else
		sandbox_constraints=$( freeze_constraints "${build_dir}" 1 ) || die
	fi

	validate_sandbox "${build_dir}" "${sandbox_tag}" "${sandbox_constraints}" || die

	echo_constraints <<< "${sandbox_constraints}" > "${HALCYON}/sandbox/cabal.config" || die
	echo "${sandbox_tag}" > "${HALCYON}/sandbox/tag" || die

	local sandbox_size
	sandbox_size=$( measure_recursively "${HALCYON}/sandbox" ) || die
	re_log "done, ${sandbox_size}"
}


function strip_sandbox () {
	expect_vars HALCYON
	expect "${HALCYON}/sandbox/tag"

	local sandbox_tag sandbox_label
	sandbox_tag=$(< "${HALCYON}/sandbox/tag" ) || die
	sandbox_label=$( echo_sandbox_tag_label "${sandbox_tag}" ) || die

	log "Stripping sandbox ${sandbox_label}..."

	find "${HALCYON}/sandbox"           \
			-type f        -and \
			\(                  \
			-name '*.so'   -or  \
			-name '*.so.*' -or  \
			-name '*.a'         \
			\)                  \
			-print0 |
		strip0 --strip-unneeded

	local sandbox_size
	sandbox_size=$( measure_recursively "${HALCYON}/sandbox" ) || die
	re_log "done, ${sandbox_size}"
}




function cache_sandbox () {
	expect_vars HALCYON HALCYON_CACHE
	expect "${HALCYON}/sandbox/tag"

	local sandbox_tag sandbox_label
	sandbox_tag=$(< "${HALCYON}/sandbox/tag" ) || die
	sandbox_label=$( echo_sandbox_tag_label "${sandbox_tag}" ) || die

	log "Caching sandbox ${sandbox_label}"

	local sandbox_archive sandbox_config
	sandbox_archive=$( echo_sandbox_archive "${sandbox_tag}" ) || die
	sandbox_config=$( echo_sandbox_config "${sandbox_tag}" ) || die

	rm -f "${HALCYON_CACHE}/${sandbox_archive}" "${HALCYON_CACHE}/${sandbox_config}" || die
	tar_archive "${HALCYON}/sandbox" "${HALCYON_CACHE}/${sandbox_archive}" || die
	cp "${HALCYON}/sandbox/cabal.config" "${HALCYON_CACHE}/${sandbox_config}" || die
	upload_prepared "${HALCYON_CACHE}/${sandbox_archive}" || die
	upload_prepared "${HALCYON_CACHE}/${sandbox_config}" || die
}


function restore_sandbox () {
	expect_vars HALCYON HALCYON_CACHE

	local sandbox_tag
	expect_args sandbox_tag -- "$@"

	local sandbox_label
	sandbox_label=$( echo_sandbox_tag_label "${sandbox_tag}" ) || die

	log "Restoring sandbox ${sandbox_label}"

	if [ -f "${HALCYON}/sandbox/tag" ] &&
		validate_sandbox_tag "${sandbox_tag}" < "${HALCYON}/sandbox/tag"
	then
		return 0
	fi
	rm -rf "${HALCYON}/sandbox" || die

	local sandbox_archive
	sandbox_archive=$( echo_sandbox_archive "${sandbox_tag}" ) || die

	if ! download_prepared "${sandbox_archive}" "${HALCYON_CACHE}"; then
		log_warning "Sandbox ${sandbox_label} is not prepared"
		return 1
	fi

	tar_extract "${HALCYON_CACHE}/${sandbox_archive}" "${HALCYON}/sandbox" || die

	if ! [ -f "${HALCYON}/sandbox/tag" ] ||
		! validate_sandbox_tag "${sandbox_tag}" < "${HALCYON}/sandbox/tag"
	then
		log_warning "Restoring ${sandbox_archive} failed"
		rm -rf "${HALCYON}/sandbox" || die
		return 1
	fi
}




function infer_sandbox_constraints () {
	local build_dir
	expect_args build_dir -- "$@"
	expect "${build_dir}"

	log 'Inferring sandbox constraints...'

	local sandbox_constraints
	if [ -f "${build_dir}/cabal.config" ]; then
		sandbox_constraints=$( detect_constraints "${build_dir}" ) || die

		re_log 'done'
	else
		sandbox_constraints=$( freeze_constraints "${build_dir}" 1 ) || die

		re_log 'implicit'
		if ! (( ${HALCYON_FAKE_BUILD:-0} )); then
			log_warning 'Expected cabal.config with explicit constraints'
			log
			log_add_config_help "${sandbox_constraints}"
			log
		else
			echo_constraints <<< "${sandbox_constraints}" >&2 || die
		fi
	fi

	echo "${sandbox_constraints}"
}


function infer_sandbox_digest () {
	local sandbox_constraints
	expect_args sandbox_constraints -- "$@"

	log 'Inferring sandbox digest...'

	local sandbox_digest
	sandbox_digest=$( echo_constraints_digest <<< "${sandbox_constraints}" ) || die

	re_log "done, ${sandbox_digest}"

	echo "${sandbox_digest}"
}


function locate_matched_sandbox_tag () {
	expect_vars HALCYON HALCYON_CACHE
	expect "${HALCYON}/ghc/tag"

	local sandbox_constraints
	expect_args sandbox_constraints -- "$@"

	log 'Locating matched sandboxes'

	local ghc_tag config_pattern
	ghc_tag=$(< "${HALCYON}/ghc/tag" ) || die
	config_pattern=$( echo_sandbox_config_pattern "${ghc_tag}" ) || die

	local matched_configs
	if ! matched_configs=$(
		list_prepared |
		filter_matching "^${config_pattern}$" |
		sort_naturally |
		match_at_least_one
	); then
		log_warning 'No matched sandbox is prepared'
		return 1
	fi

	download_any_prepared "${matched_configs}" "${HALCYON_CACHE}" || die

	log "Scoring matched sandboxes"

	local matched_scores
	if ! matched_scores=$(
		local config
		while read -r config; do
			local tag
			tag=$( echo_sandbox_config_tag "${config}" ) || die

			local score
			if ! score=$(
				read_constraints < "${HALCYON_CACHE}/${config}" |
				sort_naturally |
				filter_valid_constraints |
				score_constraints "${sandbox_constraints}" "${tag}"
			); then
				continue
			fi

			echo -e "${score}\t${tag}"
		done <<< "${matched_configs}" |
			filter_not_matching '^0\t' |
			sort_naturally |
			match_at_least_one
	); then
		log_warning 'No sandbox is matched closely enough'
		return 1
	fi

	log_file_indent <<< "${matched_scores}"

	local matched_tag
	matched_tag=$(
		filter_last <<< "${matched_scores}" |
		match_exactly_one |
		sed 's/^.*'$'\t''//'
	) || die

	echo "${matched_tag}"
}




function activate_sandbox () {
	expect_vars HALCYON
	expect "${HALCYON}/sandbox/tag"

	local build_dir
	expect_args build_dir -- "$@"
	expect "${build_dir}"

	local sandbox_tag sandbox_label
	sandbox_tag=$(< "${HALCYON}/sandbox/tag" ) || die
	sandbox_label=$( echo_sandbox_tag_label "${sandbox_tag}" ) || die

	log "Activating sandbox ${sandbox_label}..."

	if [ -e "${build_dir}/cabal.sandbox.config" ] && ! [ -h "${build_dir}/cabal.sandbox.config" ]; then
		die "Expected no custom ${build_dir}/cabal.sandbox.config"
	fi

	rm -f "${build_dir}/cabal.sandbox.config" || die
	ln -s "${HALCYON}/sandbox/cabal.sandbox.config" "${build_dir}/cabal.sandbox.config" || die

	re_log 'done'
}


function deactivate_sandbox () {
	expect_vars HALCYON
	expect "${HALCYON}/sandbox/tag"

	local build_dir
	expect_args build_dir -- "$@"
	expect "${build_dir}"

	local sandbox_tag sandbox_label
	sandbox_tag=$(< "${HALCYON}/sandbox/tag" ) || die
	sandbox_label=$( echo_sandbox_tag_label "${sandbox_tag}" ) || die

	log "Deactivating sandbox ${sandbox_label}..."

	if [ -e "${build_dir}/cabal.sandbox.config" ] && ! [ -h "${build_dir}/cabal.sandbox.config" ]; then
		die "Expected no custom ${build_dir}/cabal.sandbox.config"
	fi

	rm -f "${build_dir}/cabal.sandbox.config" || die

	re_log 'done'
}




function prepare_extended_sandbox () {
	expect_vars HALCYON

	local has_time build_dir sandbox_tag matched_tag unhappy_workaround
	expect_args has_time build_dir sandbox_tag matched_tag unhappy_workaround -- "$@"

	if ! restore_sandbox "${matched_tag}"; then
		return 1
	fi

	local sandbox_digest sandbox_label
	sandbox_digest=$( echo_sandbox_tag_digest "${sandbox_tag}" ) || die
	sandbox_label=$( echo_sandbox_tag_label "${sandbox_tag}" ) || die

	local matched_digest matched_label
	matched_digest=$( echo_sandbox_tag_digest "${matched_tag}" ) || die
	matched_label=$( echo_sandbox_tag_label "${matched_tag}" ) || die

	if [ "${sandbox_digest}" = "${matched_digest}" ]; then
		log "Using matched sandbox ${matched_label} as sandbox ${sandbox_label}"

		echo "${sandbox_tag}" > "${HALCYON}/sandbox/tag" || die
		cache_sandbox || die
		activate_sandbox "${build_dir}" || die
		return 0
	fi

	log "Extending matched sandbox ${matched_label} to sandbox ${sandbox_label}"
	if ! (( ${has_time} )); then
		log
		log_extend_sandbox_help
		log
	fi

	build_sandbox "${build_dir}" "${sandbox_tag}" "${unhappy_workaround}" || die
	strip_sandbox || die
	cache_sandbox || die
	activate_sandbox "${build_dir}" || die
}


function prepare_sandbox () {
	expect_vars HALCYON
	expect "${HALCYON}/ghc/tag"

	local has_time build_dir
	expect_args has_time build_dir -- "$@"

	local ghc_tag app_label
	ghc_tag=$(< "${HALCYON}/ghc/tag" ) || die
	app_label=$( detect_app_label "${build_dir}" ) || die

	local sandbox_constraints sandbox_digest
	sandbox_constraints=$( infer_sandbox_constraints "${build_dir}" ) || die
	sandbox_digest=$( infer_sandbox_digest "${sandbox_constraints}" ) || die

	local unhappy_workaround
	unhappy_workaround=0
	if filter_matching '^(language-javascript|haskell-src-exts) ' <<< "${sandbox_constraints}" |
		match_at_least_one > '/dev/null'
	then
		unhappy_workaround=1
	fi

	local sandbox_label sandbox_tag
	sandbox_label=$( echo_sandbox_label "${ghc_tag}" "${app_label}" ) || die
	sandbox_tag=$( echo_sandbox_tag "${sandbox_digest}" "${sandbox_label}" ) || die

	if ! (( ${FORCE_SANDBOX_BUILD:-0} )) && restore_sandbox "${sandbox_tag}"; then
		activate_sandbox "${build_dir}" || die
		return 0
	fi

	(( ${has_time} )) || ! (( ${NO_EXTEND_SANDBOX:-0} )) || return 1

	local matched_tag
	if ! (( ${FORCE_SANDBOX_BUILD:-0} )) &&
		matched_tag=$( locate_matched_sandbox_tag "${sandbox_constraints}" ) &&
		prepare_extended_sandbox "${has_time}" "${build_dir}" "${sandbox_tag}" "${matched_tag}" "${unhappy_workaround}"
	then
		return 0
	fi

	(( ${has_time} )) || return 1

	build_sandbox "${build_dir}" "${sandbox_tag}" "${unhappy_workaround}" || die
	strip_sandbox || die
	cache_sandbox || die
	activate_sandbox "${build_dir}" || die
}
