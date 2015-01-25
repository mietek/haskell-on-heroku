private_storage () {
	[[ -n "${HALCYON_AWS_ACCESS_KEY_ID:+_}"
	&& -n "${HALCYON_AWS_SECRET_ACCESS_KEY:+_}"
	&& -n "${HALCYON_S3_BUCKET:+_}" ]] || return 1
}


expect_private_storage () {
	if ! private_storage; then
		log_error 'Expected private storage'
		log
		log_indent 'To set up private storage:'
		log_indent '$ heroku config:set HALCYON_AWS_ACCESS_KEY_ID=...'
		log_indent '$ heroku config:set HALCYON_AWS_SECRET_ACCESS_KEY=...'
		log_indent '$ heroku config:set HALCYON_S3_BUCKET=...'
		log
		return 1
	fi
}


buildpack_compile () {
	expect_vars BUILDPACK_DIR

	expect_existing "${BUILDPACK_DIR}" || return 1

	local build_dir cache_dir
	expect_args build_dir cache_dir -- "$@"

	expect_existing "${build_dir}" || return 1
	expect_no_existing "${build_dir}/.buildpack" || return 1

	local root_dir
	root_dir=$( get_tmp_dir 'root' ) || return 1

	# NOTE: Files copied into build_dir will be present in /app on a
	# dyno.  This includes files which should not contribute to
	# source_hash, hence the need to archive and restore the source dir.
	if ! create_archive "${build_dir}" '/tmp/source.tar.gz' 2>'/dev/null'; then
		log_error 'Failed to prepare source directory'
		return 1
	fi

	local label executable
	if ! label=$(
		HALCYON_NO_SELF_UPDATE=1 \
		HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
			halcyon label "${build_dir}" 2>'/dev/null'
	) || ! executable=$(
		HALCYON_NO_SELF_UPDATE=1 \
		HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
			halcyon executable "${build_dir}" 2>'/dev/null'
	); then
		log_error 'Failed to detect app'
		return 1
	fi

	# NOTE: Returns 2 if build is needed, if NO_BUILD_DEPENDENCIES is 1.
	local status
	status=0
	HALCYON_NO_SELF_UPDATE=1 \
	HALCYON_BASE='/app' \
	HALCYON_PREFIX='/app' \
	HALCYON_ROOT="${root_dir}" \
	HALCYON_NO_BUILD_DEPENDENCIES="${HALCYON_NO_BUILD_DEPENDENCIES:-1}" \
	HALCYON_CACHE="${cache_dir}" \
	HALCYON_INTERNAL_NO_ANNOUNCE_INSTALL=1 \
	HALCYON_INTERNAL_NO_CLEANUP=1 \
	HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
		halcyon install "${build_dir}" || status="$?"

	if ! copy_dir_over "${BUILDPACK_DIR}" "${build_dir}/.buildpack" ||
		! copy_file "${BUILDPACK_DIR}/profile.d/buildpack.sh" \
			"${build_dir}/.profile.d/buildpack.sh" ||
		! copy_file '/tmp/source.tar.gz' "${build_dir}/.buildpack/source.tar.gz"
	then
		log_error 'Failed to prepare slug directory'
		return 1
	fi

	if [[ ! -f "${build_dir}/.ghci" ]]; then
		if ! echo ':set prompt "\ESC[32;1m\x03BB \ESC[0m"' >"${build_dir}/.ghci"; then
			log_error 'Failed to set custom GHCi prompt'
			return 1
		fi
	fi

	case "${status}" in
	'0')
		if ! copy_dir_into "${root_dir}/app" "${build_dir}"; then
			log_error 'Failed to copy app to slug directory'
			return 1
		fi

		if (( ${HALCYON_KEEP_DEPENDENCIES:-0} )); then
			if ! copy_dir_over '/app/ghc' "${build_dir}/ghc" ||
				! copy_dir_over '/app/cabal' "${build_dir}/cabal" ||
				! copy_dir_over '/app/sandbox' "${build_dir}/sandbox"
			then
				log_error 'Failed to copy dependencies to slug directory'
				return 1
			fi
		fi

		if [[ ! -f "${build_dir}/Procfile" ]]; then
			if ! echo "web: /app/bin/${executable}" >"${build_dir}/Procfile"; then
				log_error 'Failed to generate Procfile'
				return 1
			fi
		fi

		log
		log_label 'App deployed:' "${label}"
		log
		log_indent 'To see the app, spin up at least one web dyno:'
		log_indent '$ heroku ps:scale web=1'
		log_indent '$ heroku open'
		log
		log_indent 'To run GHCi, use a one-off dyno:'
		log_indent '$ heroku run bash'
		log_indent '$ restore'
		log_indent '$ cabal repl'
		log
		log
		;;
	'2')
		log_error 'Failed to deploy app'

		# NOTE: There is no access to the Heroku cache from one-off
		# dynos.  Hence, the cache is included in the slug to speed
		# up the next step, which is building the app on a one-off
		# dyno.
		log_error 'Deploying buildpack with cache'

		if ! copy_dir_over "${cache_dir}" "${build_dir}/.buildpack/cache"; then
			log_error 'Failed to copy cache to slug directory'
			return 1
		fi

		log
		if ! private_storage; then
			log_indent 'First, set up private storage:'
			log_indent '$ heroku config:set HALCYON_AWS_ACCESS_KEY_ID=...'
			log_indent '$ heroku config:set HALCYON_AWS_SECRET_ACCESS_KEY=...'
			log_indent '$ heroku config:set HALCYON_S3_BUCKET=...'
			log
		fi
		log_indent 'To continue, build the app on a one-off PX dyno:'
		log_indent '$ heroku run --size=PX build'
		log
		log_indent 'Next, deploy the app:'
		log_indent '$ git commit --amend --no-edit'
		log_indent '$ git push -f heroku master'
		log
		log
		;;
	*)
		log_error 'Failed to deploy app'
		return 1
	esac
}


buildpack_install () {
	expect_vars BUILDPACK_DIR

	expect_existing "${BUILDPACK_DIR}" || return 1

	local source_dir
	source_dir=$( get_tmp_dir 'buildpack-source' ) || return 1

	if ! extract_archive_over "${BUILDPACK_DIR}/source.tar.gz" "${source_dir}" 2>'/dev/null'; then
		log_error 'Failed to restore source directory'
		return 1
	fi

	local label
	if ! label=$(
		HALCYON_NO_SELF_UPDATE=1 \
		HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
			halcyon label "${source_dir}" 2>'/dev/null'
	); then
		log_error 'Failed to detect app'
		return 1
	fi

	HALCYON_NO_SELF_UPDATE=1 \
	HALCYON_BASE='/app' \
	HALCYON_PREFIX='/app' \
	HALCYON_CACHE="${BUILDPACK_DIR}/cache" \
	HALCYON_INTERNAL_NO_ANNOUNCE_INSTALL=1 \
	HALCYON_INTERNAL_NO_CLEANUP=1 \
	HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
		halcyon install "${source_dir}" "$@" || return 1

	echo "${label}"
}


buildpack_build () {
	expect_private_storage || return 1

	local label
	if ! label=$( buildpack_install "$@" ); then
		log_error 'Failed to build app'
		return 1
	fi

	log
	log_label 'App built:' "${label}"
	log
	log_indent 'To deploy the app:'
	log_indent '$ git commit --amend --no-edit'
	log_indent '$ git push -f heroku master'
	log
	log
}


buildpack_restore () {
	local label
	if ! label=$(
		HALCYON_KEEP_DEPENDENCIES=1 \
			buildpack_install "$@"
	); then
		log_error 'Failed to restore app'
		return 1
	fi

	log
	log_label 'App restored:' "${label}"
	log
	log_indent 'To run GHCi:'
	log_indent '$ cabal repl'
	log
	log
}
