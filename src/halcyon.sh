#!/usr/bin/env bash


set -o nounset
set -o pipefail

self_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "${self_dir}/lib/curl.sh"
source "${self_dir}/lib/expect.sh"
source "${self_dir}/lib/log.sh"
source "${self_dir}/lib/s3_curl.sh"
source "${self_dir}/lib/tar.sh"
source "${self_dir}/lib/tools.sh"
source "${self_dir}/build.sh"
source "${self_dir}/cabal.sh"
source "${self_dir}/cache.sh"
source "${self_dir}/constraints.sh"
source "${self_dir}/ghc.sh"
source "${self_dir}/package.sh"
source "${self_dir}/sandbox.sh"
source "${self_dir}/transfer.sh"




function set_defaults () {
	! (( ${HALCYON_DEFAULTS_SET:-0} )) || return 0
	export HALCYON_DEFAULTS_SET=1

	export HALCYON_S3_URL="${HALCYON_S3_URL:-http://s3.halcyon.sh/}"

	export HALCYON_PREFIX="${HALCYON_PREFIX:-/app}"
	export HALCYON_SUFFIX="${HALCYON_SUFFIX:-.halcyon}"
	export HALCYON="${HALCYON_PREFIX}/${HALCYON_SUFFIX}"
	export HALCYON_CACHE="${HALCYON_CACHE:-/var/tmp/halcyon-cache}"

	export PATH="${HALCYON}/buildpack/bin:${PATH:-}"
	export PATH="${HALCYON}/ghc/bin:${PATH}"
	export PATH="${HALCYON}/cabal/bin:${PATH}"
	export PATH="${HALCYON}/sandbox/bin:${PATH}"
	export PATH="${HALCYON}/app/bin:${PATH}"
	export LIBRARY_PATH="${HALCYON}/ghc/lib:${LIBRARY_PATH:-}"
	export LD_LIBRARY_PATH="${HALCYON}/ghc/lib:${LD_LIBRARY_PATH:-}"

	export LANG="${LANG:-en_US.UTF-8}"

	export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
	export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
	export HALCYON_S3_BUCKET="${HALCYON_S3_BUCKET:-}"
	export HALCYON_S3_ACL="${HALCYON_S3_ACL:-private}"

	export PURGE_HALCYON_CACHE="${PURGE_CACHE:-0}"
	export SILENCE_HALCYON_OUTPUT="${SILENCE_HALCYON_OUTPUT:-0}"
	export NO_HALCYON_RESTORE="${NO_HALCYON_RESTORE:-0}"
	export FORCE_GHC_VERSION="${FORCE_GHC_VERSION:-}"
	export NO_CUT_GHC="${NO_CUT_GHC:-0}"
	export FORCE_CABAL_VERSION="${FORCE_CABAL_VERSION:-}"
	export FORCE_CABAL_UPDATE="${FORCE_CABAL_UPDATE:-0}"
	export NO_EXTEND_SANDBOX="${NO_EXTEND_SANDBOX:-0}"
}


set_defaults




function set_config_vars () {
	local env_dir
	expect_args env_dir -- "$@"

	if ! [ -d "${env_dir}" ]; then
		return 0
	fi

	log 'Setting config vars'

	local ignored_pattern secret_pattern
	ignored_pattern='GIT_DIR|PATH|LIBRARY_PATH|LD_LIBRARY_PATH|LD_PRELOAD'
	secret_pattern='AWS_SECRET_ACCESS_KEY|DATABASE_URL|.*_POSTGRESQL_.*_URL'

	local var
	for var in $(
		find_spaceless "${env_dir}" -maxdepth 1 |
			sed "s:^${env_dir}/::" |
			sort_naturally |
			filter_not_matching "^(${ignored_pattern})$"
	); do
		local value
		value=$( match_exactly_one <"${env_dir}/${var}" ) || die
		if filter_matching "^(${secret_pattern})$" <<<"${var}" |
			match_exactly_one >'/dev/null'
		then
			log_indent "${var} (secret)"
		else
			log_indent "${var}=${value}"
		fi
		export "${var}=${value}" || die
	done
}




function halcyon_prepare () {
	local has_time app
	has_time=1
	app=''
	if [ -n "${2:-}" ]; then
		has_time="$1"
		app="$2"
	elif [ -n "${1:-}" ]; then
		app="$1"
	fi

	local build_dir app_label app_description
	build_dir=''
	app_label=''
	if [ -z "${app}" ]; then
		export HALCYON_FAKE_BUILD=1
		app_label='base-0.0'
		app_description='base sandbox'
	elif ! [ -d "${app}" ]; then
		export HALCYON_FAKE_BUILD=1
		app_label="${app}"
		app_description="sandbox for ${app_label}"
	else
		build_dir="${app}"
		app_description=$( detect_app_label "${build_dir}" ) || die
	fi

	log
	log "Preparing ${app_description}"
	log

	prepare_ghc "${has_time}" "${build_dir}" || die
	log

	if (( ${HALCYON_FAKE_BUILD:-0} )); then
		build_dir=$( fake_build_dir "${app_label}" ) || die
	fi

	prepare_cabal "${has_time}" || die
	log

	prepare_sandbox "${has_time}" "${build_dir}" || die
	log

	if (( ${HALCYON_FAKE_BUILD:-0} )); then
		rm -rf "${build_dir}" || die
	else
		configure_build "${build_dir}" || die
		build "${build_dir}" || die
		log
	fi

	log
	log "Prepared ${app_description}"
	log
}




function log_extend_sandbox_help () {
	log_file_indent <<-EOF
		In case of timeout, disable sandbox extending and try again:
		$ export NO_EXTEND_SANDBOX=1
EOF
}


function log_add_config_help () {
	local sandbox_constraints
	expect_args sandbox_constraints -- "$@"

	log_file_indent <<-EOF
		To use explicit constraints, add cabal.config:
		$ cat >cabal.config <<EOF
EOF
	echo_constraints <<<"${sandbox_constraints}" >&2 || die
	echo 'EOF' >&2
}
