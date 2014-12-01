buildpack_compile () {
	expect_vars BUILDPACK_DIR
	expect_existing "${BUILDPACK_DIR}"

	# NOTE: Files copied into build_dir will be present in /app on a
	# dyno.  This includes files which should not contribute to
	# source_hash, hence the need to archive and restore the source dir.

	local build_dir cache_dir env_dir
	expect_args build_dir cache_dir env_dir -- "$@"
	expect_existing "${build_dir}"
	expect_no_existing "${build_dir}/.buildpack"

	local root_dir
	root_dir=$( get_tmp_dir 'buildpack-root' ) || return 1

	log 'Archiving source directory'

	create_archive "${build_dir}" '/tmp/source.tar.gz' || return 1

	if HALCYON_NO_SELF_UPDATE=1 \
		HALCYON_BASE='/app' \
		HALCYON_PREFIX='/app' \
		HALCYON_ROOT="${root_dir}" \
		HALCYON_NO_BUILD_LAYERS=1 \
		HALCYON_CACHE="${cache_dir}" \
		HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
			halcyon deploy "${build_dir}"
	then
		# NOTE: This assumes nothing is installed into root_dir
		# outside root_dir/app.

		copy_dir_into "${root_dir}/app" "${build_dir}" || return 1
		copy_file "${BUILDPACK_DIR}/profile.d/buildpack.sh" \
			"${build_dir}/.profile.d/buildpack.sh" || return 1

		if [[ ! -f "${build_dir}/Procfile" ]]; then
			local executable
			if ! executable=$( HALCYON_NO_SELF_UPDATE=1 halcyon executable "${build_dir}" ); then
				log_warning 'No executable detected'
			else
				expect_existing "${build_dir}/bin/${executable}"

				echo "web: /app/bin/${executable}" \
					>"${build_dir}/Procfile" || return 1
			fi
		fi

		help_deploy_succeeded
	else
		# NOTE: There is no access to the Heroku cache from one-off
		# dynos.  Hence, the cache is included in the slug, to speed
		# up the next step, which is building the app on a one-off
		# dyno.

		copy_dir_over "${cache_dir}" "${build_dir}/.buildpack/cache" || return 1

		help_deploy_failed
	fi

	copy_dir_over "${BUILDPACK_DIR}" "${build_dir}/.buildpack" || return 1
	copy_file '/tmp/source.tar.gz' "${build_dir}/.buildpack/source.tar.gz" || return 1

	rm -rf "${root_dir}" || return 1
}


buildpack_build () {
	expect_existing "${BUILDPACK_DIR}"

	local source_dir
	source_dir=$( get_tmp_dir 'buildpack-source' ) || return 1

	log 'Restoring source directory'

	extract_archive_over "${BUILDPACK_DIR}/source.tar.gz" "${source_dir}" || return 1

	log
	log
	HALCYON_NO_SELF_UPDATE=1 \
	HALCYON_BASE='/app' \
	HALCYON_PREFIX='/app' \
	HALCYON_CACHE="${BUILDPACK_DIR}/cache" \
	HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
		halcyon deploy "${source_dir}" "$@" || return 1

	help_build_succeeded

	rm -rf "${source_dir}" || return 1
}


buildpack_restore () {
	expect_existing "${BUILDPACK_DIR}"

	local source_dir
	source_dir=$( get_tmp_dir 'buildpack-source' ) || return 1

	log 'Restoring source directory'

	extract_archive_over "${BUILDPACK_DIR}/source.tar.gz" "${source_dir}" || return 1

	log
	log
	HALCYON_NO_SELF_UPDATE=1 \
	HALCYON_BASE='/app' \
	HALCYON_PREFIX='/app' \
	HALCYON_RESTORE_LAYERS=1 \
	HALCYON_NO_BUILD_LAYERS=1 \
	HALCYON_CACHE="${BUILDPACK_DIR}/cache" \
	HALCYON_NO_ARCHIVE=1 \
	HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
		halcyon deploy "${source_dir}" "$@" || return 1

	help_restore_succeeded

	rm -rf "${source_dir}" || return 1
}
