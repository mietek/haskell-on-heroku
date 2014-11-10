buildpack_compile () {
	expect_vars BUILDPACK_TOP_DIR
	expect_existing "${BUILDPACK_TOP_DIR}"

	# NOTE: Files copied into build_dir will be present in /app on a dyno.

	local build_dir cache_dir env_dir
	expect_args build_dir cache_dir env_dir -- "$@"
	expect_existing "${build_dir}"
	expect_no_existing "${build_dir}/.buildpack"

	log 'Archiving app source'
	create_archive "${build_dir}" '/tmp/buildpack-app-source.tar.gz' || return 1

	local install_dir success
	install_dir=$( get_tmp_dir 'buildpack-install' ) || return 1
	success=0

	set_halcyon_vars
	if HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
		halcyon_main deploy \
			--halcyon-dir='/app/.halcyon' \
			--cache-dir="${cache_dir}" \
			--install-dir="${install_dir}" \
			--no-build-dependencies \
			"${build_dir}"
	then
		success=1
	fi

	copy_dir_over "${BUILDPACK_TOP_DIR}" "${build_dir}/.buildpack" || return 1
	copy_file '/tmp/buildpack-app-source.tar.gz' "${build_dir}/.buildpack/buildpack-app-source.tar.gz" || return 1
	copy_file "${BUILDPACK_TOP_DIR}/profile.d/buildpack.sh" "${build_dir}/.profile.d/buildpack.sh" || return 1

	if (( success )); then
		copy_dir_into "${install_dir}/app" "${build_dir}" || return 1

		if (( BUILDPACK_KEEP_ENV )); then
			copy_dir_over "${cache_dir}" "${build_dir}/.buildpack/buildpack-cache" || return 1
		fi

		if [[ ! -f "${build_dir}/Procfile" ]]; then
			local app_executable
			if app_executable=$( detect_app_executable "${build_dir}" ); then
				expect_existing "${build_dir}/.halcyon/slug/bin/${app_executable}"

				echo "web: /app/.halcyon/slug/bin/${app_executable}" >"${build_dir}/Procfile" || return 1
			else
				log_warning 'No app executable detected'
			fi
		fi

		help_deploy_succeeded
	else
		copy_dir_over "${cache_dir}" "${build_dir}/.buildpack/buildpack-cache" || return 1

		help_deploy_failed
	fi

	rm -rf "${install_dir}" || return 1
}


buildpack_build () {
	expect_existing '/app/.buildpack'

	# NOTE: Files copied into build_dir in buildpack_compile are present in /app on a
	# one-off dyno. This includes files which should not contribute to source_hash, hence
	# the need to restore the app source.

	local source_dir
	source_dir=$( get_tmp_dir 'buildpack-source' ) || return 1

	log 'Restoring app source'
	extract_archive_over '/app/.buildpack/buildpack-app-source.tar.gz' "${source_dir}" || return 1
	log
	log

	# NOTE: There is no access to the cache used in buildpack_compile from a one-off dyno.

	set_halcyon_vars
	if ! private_storage; then
		log_error 'Expected private storage'
		help_configure_private_storage
		return 1
	fi
	HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
	HALCYON_INTERNAL_NO_ANNOUNCE_DEPLOY=1 \
		halcyon_main deploy "$@" \
			--halcyon-dir='/app/.halcyon' \
			--cache-dir='/app/.buildpack/buildpack-cache' \
			"${source_dir}" || return 1

	help_build_succeeded

	rm -rf "${source_dir}" || return 1
}


buildpack_restore () {
	expect_existing '/app/.buildpack'

	# NOTE: Files copied into build_dir in buildpack_compile are present in /app on a
	# one-off dyno. This includes files which should not contribute to source_hash, hence
	# the need to restore the app source.

	local source_dir
	source_dir=$( get_tmp_dir 'buildpack-source' ) || return 1

	log 'Restoring app source'
	extract_archive_over '/app/.buildpack/buildpack-app-source.tar.gz' "${source_dir}" || return 1
	log
	log

	# NOTE: There is no access to the cache used in buildpack_compile from a one-off dyno.

	set_halcyon_vars
	HALCYON_INTERNAL_NO_COPY_LOCAL_SOURCE=1 \
	HALCYON_INTERNAL_NO_ANNOUNCE_DEPLOY=1 \
		halcyon_main deploy "$@" \
			--halcyon-dir='/app/.halcyon' \
			--cache-dir='/app/.buildpack/buildpack-cache' \
			--no-build-dependencies \
			--no-archive \
			--force-restore-all \
			"${source_dir}" || return 1

	# NOTE: All build byproducts are normally kept in HALCYON_DIR/app.  Copying the build
	# byproducts to /app is intended to help the user interact with the app.

	if [[ -d '/app/.halcyon/app' ]]; then
		copy_dir_into '/app/.halcyon/app' '/app' || return 1
	fi

	help_restore_succeeded

	rm -rf "${source_dir}" || return 1
}
