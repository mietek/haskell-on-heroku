export BUILDPACK_TOP_DIR
BUILDPACK_TOP_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P )

if ! [ -d "${BUILDPACK_TOP_DIR}/lib/halcyon" ]; then
	mkdir -p "${BUILDPACK_TOP_DIR}/lib" || exit 1
	if ! git clone --depth=1 --quiet 'https://github.com/mietek/halcyon.git' "${BUILDPACK_TOP_DIR}/lib/halcyon"; then
		echo '   *** ERROR: Cannot clone Halcyon' >&2
		exit 1
	fi
fi

if ! [ -d "${BUILDPACK_TOP_DIR}/lib/halcyon/lib/bashmenot" ]; then
	mkdir -p "${BUILDPACK_TOP_DIR}/lib/halcyon/lib" || exit 1
	if ! git clone --depth=1 --quiet 'https://github.com/mietek/bashmenot.git' "${BUILDPACK_TOP_DIR}/lib/halcyon/lib/bashmenot"; then
		echo '   *** ERROR: Cannot clone bashmenot' >&2
		exit 1
	fi
fi

source "${BUILDPACK_TOP_DIR}/lib/halcyon/halcyon.sh"
source "${BUILDPACK_TOP_DIR}/src/help.sh"


function set_config_vars () {
	local config_dir
	expect_args config_dir -- "$@"

	log 'Setting config vars:'

	local ignored_pattern secret_pattern
	ignored_pattern='BUILDPACK_INTERNAL_.*|HALCYON_INTERNAL_.*|GIT_DIR|PATH|LIBRARY_PATH|LD_LIBRARY_PATH|LD_PRELOAD'
	secret_pattern='HALCYON_AWS_SECRET_ACCESS_KEY|DATABASE_URL|.*_POSTGRESQL_.*_URL'

	local vars
	if ! vars=$(
		find_spaceless_recursively "${config_dir}" -maxdepth 1 |
		sort_naturally |
		filter_not_matching "^(${ignored_pattern})$" |
		match_at_least_one
	); then
		echo '(none)'
		return 0
	fi

	local var
	while read -r var; do
		local value
		value=$( match_exactly_one <"${config_dir}/${var}" ) || die
		if filter_matching "^(${secret_pattern})$" <<<"${var}" | match_exactly_one >'/dev/null'; then
			log_indent "${var} (secret)"
		else
			log_indent "${var}=${value}"
		fi

		export "${var}"="${value}"
	done <<<"${vars}"
}


function copy_buildpack () {
	expect_vars BUILDPACK_TOP_DIR
	expect_existing "${BUILDPACK_TOP_DIR}"

	local build_dir
	expect_args build_dir -- "$@"
	expect_no_existing "${build_dir}/.haskell-on-heroku"

	tar_copy "${BUILDPACK_TOP_DIR}" "${build_dir}/.haskell-on-heroku" \
		--exclude '.git' || die

	mkdir -p "${build_dir}/.profile.d" || die
	(
		cat >"${build_dir}/.profile.d/haskell-on-heroku.sh" <<-EOF
			if ! (( ${BUILDPACK_INTERNAL_PATHS:-0} )); then
				export BUILDPACK_INTERNAL_PATHS=1

				export PATH="/app/.haskell-on-heroku/bin:\${PATH}"
				export PATH="/app/.halcyon/slug/bin:\${PATH}"
			fi

			source '/app/.haskell-on-heroku/lib/halcyon/src/paths.sh'
			set_halcyon_paths
EOF
	) || die
}


# NOTE: "${build_dir}/.halcyon" will become '/app/.halcyon' on a dyno.

function copy_slug () {
	expect_existing '/app/.halcyon/slug'

	local build_dir
	expect_args build_dir -- "$@"
	expect_no_existing "${build_dir}/.halcyon/slug" "${build_dir}/.ghc" "${build_dir}/.cabal" "${build_dir}/.cabal-sandbox"

	rm -rf "${build_dir}/cabal.sandbox.config" "${build_dir}/dist" || die
	tar_copy '/app/.halcyon/slug' "${build_dir}/.halcyon/slug" || die

	if ! [ -f "${build_dir}/Procfile" ]; then
		local app_executable
		app_executable=$( detect_app_executable "${build_dir}" ) || die
		expect_existing "${build_dir}/.halcyon/slug/bin/${app_executable}"

		echo "web: /app/.halcyon/slug/bin/${app_executable}" >"${build_dir}/Procfile" || die
	fi
}


function heroku_compile () {
	local build_dir cache_dir env_dir
	expect_args build_dir cache_dir env_dir -- "$@"
	expect_existing "${build_dir}"

	copy_buildpack "${build_dir}" || die

	set_halcyon_vars
	set_config_vars "${env_dir}" || die

	log
	if ! halcyon_deploy --halcyon-dir='/app/.halcyon' --cache-dir="${cache_dir}" --only-build-app "${build_dir}"; then
		log
		help_deploy_failed
		log
		return 0
	fi
	log
	help_deploy_succeeded
	log

	copy_slug "${build_dir}" || die
}


# NOTE: Intended to run on a one-off dyno.

function heroku_build () {
	expect_existing '/app'

	set_halcyon_vars
	if ! validate_private_storage; then
		log_error 'Expected private storage'
		log
		help_configure_private_storage
		die
	fi

	halcyon_deploy --halcyon-dir='/app/.halcyon' --cache-dir='/var/tmp/cache/halcyon' '/app' || die
	log
	help_build_succeeded
}


# NOTE: Intended to run on a one-off dyno.

function heroku_restore () {
	expect_existing '/app'

	set_halcyon_vars

	halcyon_deploy --halcyon-dir='/app/.halcyon' --cache-dir='/var/tmp/cache/halcyon' --only-build-app '/app' || die
	log
	help_restore_succeeded
}
