buildpack_compile () {
	expect_vars BUILDPACK_TOP_DIR
	expect_existing "${BUILDPACK_TOP_DIR}"

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

	set_halcyon_vars
	if [[ "${HALCYON_PREFIX}" != "${HALCYON_APP_DIR}" ]]; then
		log_error "Unexpected prefix: ${HALCYON_PREFIX}"
		log_error "Expected default prefix: ${HALCYON_APP_DIR}"
		return 1
	fi

	if 	HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
		HALCYON_INTERNAL_NO_PURGE_APP_DIR=1 \
			halcyon_main deploy \
				--app-dir='/app' \
				--root-dir="${root_dir}" \
				--cache-dir="${cache_dir}" \
				--no-build-dependencies \
				"${build_dir}"
	then
		# NOTE: This assumes nothing is installed into root_dir
		# outside root_dir/app, which should hold as long as
		# HALCYON_PREFIX is /app.

		copy_dir_into "${root_dir}/app" "${build_dir}" || return 1
		copy_file "${BUILDPACK_TOP_DIR}/profile.d/buildpack.sh" "${build_dir}/.profile.d/buildpack.sh" || return 1

		if [[ ! -f "${build_dir}/Procfile" ]]; then
			local executable
			if ! executable=$( detect_executable "${build_dir}" ); then
				log_warning 'No executable detected'
			else
				expect_existing "${build_dir}/bin/${executable}"

				echo "web: /app/bin/${executable}" >"${build_dir}/Procfile" || return 1
			fi
		fi

		help_deploy_succeeded
	else
		# NOTE: There is no access to the Heroku cache from one-off
		# dynos.  Hence, the cache is included in the slug, to speed
		# up the next step--building the app on a one-off dyno.

		copy_dir_over "${cache_dir}" "${build_dir}/.buildpack/cache" || return 1

		help_deploy_failed
	fi

	copy_dir_over "${BUILDPACK_TOP_DIR}" "${build_dir}/.buildpack" || return 1
	copy_file '/tmp/source.tar.gz' "${build_dir}/.buildpack/source.tar.gz" || return 1

	rm -rf "${root_dir}" || return 1
}


buildpack_build () {
	expect_existing '/app/.buildpack'

	local source_dir
	source_dir=$( get_tmp_dir 'buildpack-source' ) || return 1

	log 'Restoring source directory'

	extract_archive_over '/app/.buildpack/source.tar.gz' "${source_dir}" || return 1

	set_halcyon_vars
	if [[ "${HALCYON_PREFIX}" != "${HALCYON_APP_DIR}" ]]; then
		log_error "Unexpected prefix: ${HALCYON_PREFIX}"
		log_error "Expected default prefix: ${HALCYON_APP_DIR}"
		return 1
	fi
	if ! private_storage; then
		log_error 'Expected private storage'
		help_configure_private_storage
		return 1
	fi

	log
	log
	HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
	HALCYON_INTERNAL_NO_PURGE_APP_DIR=1 \
	HALCYON_INTERNAL_NO_ANNOUNCE_DEPLOY=1 \
		halcyon_main deploy "$@" \
			--app-dir='/app' \
			--cache-dir='/app/.buildpack/cache' \
			"${source_dir}" || return 1

	help_build_succeeded

	rm -rf "${source_dir}" || return 1
}


buildpack_restore () {
	expect_existing '/app/.buildpack'

	local source_dir
	source_dir=$( get_tmp_dir 'buildpack-source' ) || return 1

	log 'Restoring source directory'

	extract_archive_over '/app/.buildpack/source.tar.gz' "${source_dir}" || return 1

	set_halcyon_vars
	if [[ "${HALCYON_PREFIX}" != "${HALCYON_APP_DIR}" ]]; then
		log_error "Unexpected prefix: ${HALCYON_PREFIX}"
		log_error "Expected default prefix: ${HALCYON_APP_DIR}"
		return 1
	fi

	log
	log
	HALCYON_INTERNAL_FORCE_RESTORE_ALL=1 \
	HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
	HALCYON_INTERNAL_NO_PURGE_APP_DIR=1 \
	HALCYON_INTERNAL_NO_ANNOUNCE_DEPLOY=1 \
		halcyon_main deploy "$@" \
			--app-dir='/app' \
			--cache-dir='/app/.buildpack/cache' \
			--no-build-dependencies \
			--no-archive \
			"${source_dir}" || return 1

	help_restore_succeeded

	rm -rf "${source_dir}" || return 1
}
