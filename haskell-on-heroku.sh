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

	log 'Setting config vars'

	local ignored_pattern secret_pattern
	ignored_pattern='BUILDPACK_INTERNAL_.*|HALCYON_INTERNAL_.*|GIT_DIR|PATH|LIBRARY_PATH|LD_LIBRARY_PATH|LD_PRELOAD'
	secret_pattern='.*SECRET.*|.*PASSWORD.*|DATABASE_URL|.*_POSTGRESQL_.*_URL'

	local vars
	if ! vars=$(
		find_tree "${config_dir}" -maxdepth 1 -type f 2>'/dev/null' |
		sed "s:\./::" |
		sort_natural |
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
			log_indent_pad "${var}:" "(secret)"
		else
			log_indent_pad "${var}:" "${value}"
		fi

		export "${var}=${value}"
	done <<<"${vars}"
}


function heroku_compile () {
	expect_vars BUILDPACK_TOP_DIR
	expect_existing "${BUILDPACK_TOP_DIR}"

	set_halcyon_vars

	# NOTE: Files copied into build_dir will be present in /app on a dyno.

	local build_dir cache_dir env_dir
	expect_args build_dir cache_dir env_dir -- "$@"
	expect_existing "${build_dir}"
	expect_no_existing "${build_dir}/.haskell-on-heroku"

	log 'Archiving app source'
	tar_create "${build_dir}" '/tmp/haskell-on-heroku-app-source.tar.gz' || die
	set_config_vars "${env_dir}" || die
	log
	log

	local install_dir success
	install_dir=$( get_tmp_dir 'haskell-on-heroku-install' ) || die
	success=0

	if halcyon_deploy                      \
		--halcyon-dir='/app/.halcyon'  \
		--cache-dir="${cache_dir}"     \
		--install-dir="${install_dir}" \
		--no-copy-local-source         \
		--no-build-dependencies        \
		"${build_dir}"
	then
		success=1
	fi

	tar_copy "${BUILDPACK_TOP_DIR}" "${build_dir}/.haskell-on-heroku" --exclude '.git' || die
	cp -p '/tmp/haskell-on-heroku-app-source.tar.gz' "${build_dir}/.haskell-on-heroku" || die
	mkdir -p "${build_dir}/.profile.d" || die
	cp -p "${BUILDPACK_TOP_DIR}/profile.d/haskell-on-heroku.sh" "${build_dir}/.profile.d" || die

	if (( success )); then
		tar_copy "${install_dir}/app" "${build_dir}" || die

		if ! [ -f "${build_dir}/Procfile" ]; then
			local app_executable
			app_executable=$( detect_app_executable "${build_dir}" ) || die
			expect_existing "${build_dir}/.halcyon/slug/bin/${app_executable}"

			echo "web: /app/.halcyon/slug/bin/${app_executable}" >"${build_dir}/Procfile" || die
		fi

		help_deploy_succeeded
	else
		help_deploy_failed
	fi

	rm -rf "${install_dir}" || die
}


function heroku_build () {
	expect_existing '/app/.haskell-on-heroku'

	set_halcyon_vars
	if ! use_private_storage; then
		log_error 'Expected private storage'
		help_configure_private_storage
		die
	fi

	# NOTE: Files copied into build_dir in heroku_compile are present in /app on a
	# one-off dyno. This includes files which should not contribute to source_hash.

	local source_dir
	source_dir=$( get_tmp_dir 'haskell-on-heroku-source' ) || die

	log 'Restoring app source'
	tar_extract '/app/.haskell-on-heroku/haskell-on-heroku-app-source.tar.gz' "${source_dir}" || die
	log
	log

	# NOTE: There is no access to the cache used in heroku_compile from a one-off dyno.

	halcyon_deploy                               \
		--halcyon-dir='/app/.halcyon'        \
		--cache-dir='/var/tmp/halcyon-cache' \
		--no-copy-local-source               \
		--no-cache                           \
		--no-announce-deploy                 \
		"${source_dir}" || die

	help_build_succeeded

	rm -rf "${source_dir}" || die
}


function heroku_restore () {
	expect_existing '/app/.haskell-on-heroku'

	set_halcyon_vars

	# NOTE: Files copied into build_dir in heroku_compile are present in /app on a
	# one-off dyno. This includes files which should not contribute to source_hash.

	local source_dir
	source_dir=$( get_tmp_dir 'haskell-on-heroku-source' ) || die

	log 'Restoring app source'
	tar_extract '/app/.haskell-on-heroku/haskell-on-heroku-app-source.tar.gz' "${source_dir}" || die
	log
	log

	# NOTE: There is no access to the cache used in heroku_compile from a one-off dyno.

	halcyon_deploy                               \
		--halcyon-dir='/app/.halcyon'        \
		--cache-dir='/var/tmp/halcyon-cache' \
		--no-copy-local-source               \
		--no-build-dependencies              \
		--no-archive                         \
		--no-cache                           \
		--force-build-slug                   \
		--no-announce-deploy                 \
		"${source_dir}" || die

	# NOTE: All build products are normally kept in HALCYON_DIR/app.  Forcing the slug to
	# build and copying the build products is intended to help the user interact with the app.

	if [ -d '/app/.halcyon/app' ]; then
		tar_copy '/app/.halcyon/app' '/app' || die
	fi

	help_restore_succeeded

	rm -rf "${source_dir}" || die
}
