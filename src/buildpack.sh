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

	if HALCYON_NO_SELF_UPDATE=1 \
		HALCYON_BASE='/app' \
		HALCYON_PREFIX='/app' \
		HALCYON_ROOT="${root_dir}" \
		HALCYON_NO_BUILD_DEPENDENCIES=1 \
		HALCYON_CACHE="${cache_dir}" \
		HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
			halcyon install "${build_dir}"
	then
		# NOTE: This assumes nothing is installed into root_dir
		# outside root_dir/app.

		copy_dir_into "${root_dir}/app" "${build_dir}" || return 1

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

		help_install_succeeded
	else
		# NOTE: There is no access to the Heroku cache from one-off
		# dynos.  Hence, the cache is included in the slug, to speed
		# up the next step, which is building the app on a one-off
		# dyno.

		copy_dir_over "${cache_dir}" "${build_dir}/.buildpack/cache" || true

		help_install_failed
	fi


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
	HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
		halcyon install "${source_dir}" "$@" || return 1

	help_build_succeeded

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
	HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
		halcyon install "${source_dir}" "$@" || return 1

	help_restore_succeeded

	rm -rf "${source_dir}" || return 0
}
