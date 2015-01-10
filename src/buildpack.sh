buildpack_compile () {
	expect_vars BUILDPACK_DIR

	expect_existing "${BUILDPACK_DIR}" || return 1

	# NOTE: Files copied into build_dir will be present in /app on a
	# dyno.  This includes files which should not contribute to
	# source_hash, hence the need to archive and restore the source dir.

	local build_dir cache_dir env_dir
	expect_args build_dir cache_dir env_dir -- "$@"

	expect_existing "${build_dir}" || return 1
	expect_no_existing "${build_dir}/.buildpack" || return 1

	local root_dir
	root_dir=$( get_tmp_dir 'root' ) || return 1

	log 'Archiving source directory'

	if ! create_archive "${build_dir}" '/tmp/source.tar.gz' ||
		! copy_dir_over "${BUILDPACK_DIR}" "${build_dir}/.buildpack" ||
		! copy_file "${BUILDPACK_DIR}/profile.d/buildpack.sh" \
			"${build_dir}/.profile.d/buildpack.sh" ||
		! copy_file '/tmp/source.tar.gz' "${build_dir}/.buildpack/source.tar.gz"
	then
		log_error 'Failed to prepare slug directory'
		return 1
	fi

	# NOTE: Returns 2 if build is needed, due to NO_BUILD_DEPENDENCIES.

	local status
	status=0
	HALCYON_NO_SELF_UPDATE=1 \
	HALCYON_BASE='/app' \
	HALCYON_PREFIX='/app' \
	HALCYON_ROOT="${root_dir}" \
	HALCYON_NO_BUILD_DEPENDENCIES=1 \
	HALCYON_CACHE="${cache_dir}" \
	HALCYON_INTERNAL_NO_ANNOUNCE_INSTALL=1 \
	HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
		halcyon install "${build_dir}" || status="$?"

	case "${status}" in
	'0')
		# NOTE: Assumes nothing is installed into root_dir outside
		# root_dir/app.

		copy_dir_into "${root_dir}/app" "${build_dir}" || return 1

		local label
		if ! label=$(
			HALCYON_NO_SELF_UPDATE=1 \
			HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
				halcyon label "${build_dir}" 2>'/dev/null'
		); then
			log_error 'Failed to determine label'
			return 1
		fi

		local executable
		if ! executable=$(
			HALCYON_NO_SELF_UPDATE=1 \
			HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
				halcyon executable "${build_dir}" 2>'/dev/null'
		) ||
			! expect_existing "${build_dir}/bin/${executable}"
		then
			log_error 'Failed to determine executable'
			return 1
		fi

		if [[ ! -f "${build_dir}/Procfile" ]]; then
			log 'Creating Procfile'

			if ! echo "web: /app/bin/${executable}" >"${build_dir}/Procfile"; then
				log_error 'Failed to create Procfile'
				return 1
			fi
		fi

		log
		log
		log_label 'App deployed:' "${label}"
		log
		log 'To see the app, spin up at least one web dyno:'
		log_indent '$ heroku ps:scale web=1'
		log_indent '$ heroku open'
		log
		log 'To run GHCi, use a one-off dyno:'
		log_indent '$ heroku run bash'
		log_indent '$ restore'
		log_indent '$ cabal repl'
		log
		log
		;;
	'2')
		# NOTE: There is no access to the Heroku cache from one-off
		# dynos.  Hence, the cache is included in the slug, to speed
		# up the next step, which is building the app on a one-off
		# dyno.

		copy_dir_over "${cache_dir}" "${build_dir}/.buildpack/cache" || true

		log
		log
		log_warning 'Paused deploying app'
		log
		log_warning 'To continue, build the app on a one-off PX dyno:'
		log_indent '$ heroku run --size=PX build'
		log
		log_warning 'Next, deploy the app:'
		log_indent '$ git commit --amend --no-edit'
		log_indent '$ git push -f heroku master'
		log
		log
		;;
	*)
		log
		log
		log_error 'Failed to deploy app'
		return 1
	esac

	rm -rf "${root_dir}" || return 0
}


buildpack_build () {
	expect_vars BUILDPACK_DIR

	expect_existing "${BUILDPACK_DIR}" || return 1

	local source_dir
	source_dir=$( get_tmp_dir 'buildpack-source' ) || return 1

	log 'Restoring source directory'

	if ! extract_archive_over "${BUILDPACK_DIR}/source.tar.gz" "${source_dir}"; then
		log_error 'Failed to restore source directory'
		return 1
	fi

	log
	log
	HALCYON_NO_SELF_UPDATE=1 \
	HALCYON_BASE='/app' \
	HALCYON_PREFIX='/app' \
	HALCYON_CACHE="${BUILDPACK_DIR}/cache" \
	HALCYON_INTERNAL_NO_ANNOUNCE_INSTALL=1 \
	HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
		halcyon install "${source_dir}" "$@" || return 1

	log
	log
	log 'App built'
	log
	log 'To deploy the app:'
	log_indent '$ git commit --amend --no-edit'
	log_indent '$ git push -f heroku master'

	rm -rf "${source_dir}" || return 0
}


buildpack_restore () {
	expect_vars BUILDPACK_DIR

	expect_existing "${BUILDPACK_DIR}" || return 1

	local source_dir
	source_dir=$( get_tmp_dir 'buildpack-source' ) || return 1

	log 'Restoring source directory'

	if ! extract_archive_over "${BUILDPACK_DIR}/source.tar.gz" "${source_dir}"; then
		log_error 'Failed to restore source directory'
		return 1
	fi

	log
	log
	HALCYON_NO_SELF_UPDATE=1 \
	HALCYON_BASE='/app' \
	HALCYON_PREFIX='/app' \
	HALCYON_RESTORE_DEPENDENCIES=1 \
	HALCYON_NO_BUILD_DEPENDENCIES=1 \
	HALCYON_CACHE="${BUILDPACK_DIR}/cache" \
	HALCYON_NO_ARCHIVE=1 \
	HALCYON_INTERNAL_NO_ANNOUNCE_INSTALL=1 \
	HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
		halcyon install "${source_dir}" "$@" || return 1

	log
	log
	log 'App restored'
	log
	log 'To run GHCi:'
	log_indent '$ cabal repl'

	rm -rf "${source_dir}" || return 0
}
