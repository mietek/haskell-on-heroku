buildpack_compile () {
	expect_vars BUILDPACK_TOP_DIR
	expect_existing "${BUILDPACK_TOP_DIR}"

	# NOTE: Files copied into build_dir will be present in /app on a dyno.

	local build_dir cache_dir env_dir
	expect_args build_dir cache_dir env_dir -- "$@"
	expect_existing "${build_dir}"
	expect_no_existing "${build_dir}/.buildpack"

	log 'Archiving app source'
	create_archive "${build_dir}" '/tmp/buildpack-app-source.tar.gz' || die

	local install_dir success
	install_dir=$( get_tmp_dir 'buildpack-install' ) || die
	success=0

	set_halcyon_vars
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

	copy_dir_over "${BUILDPACK_TOP_DIR}" "${build_dir}/.buildpack" || die
	copy_file '/tmp/buildpack-app-source.tar.gz' "${build_dir}/.buildpack/buildpack-app-source.tar.gz" || die
	copy_file "${BUILDPACK_TOP_DIR}/profile.d/buildpack.sh" "${build_dir}/.profile.d/buildpack.sh" || die

	if (( success )); then
		copy_dir_into "${install_dir}/app" "${build_dir}" || die

		if [[ ! -f "${build_dir}/Procfile" ]]; then
			local app_executable
			if app_executable=$( detect_app_executable "${build_dir}" ); then
				expect_existing "${build_dir}/.halcyon/slug/bin/${app_executable}"

				echo "web: /app/.halcyon/slug/bin/${app_executable}" >"${build_dir}/Procfile" || die
			else
				log_warning 'No app executable detected'
			fi
		fi

		help_deploy_succeeded
	else
		help_deploy_failed
	fi

	rm -rf "${install_dir}" || die
}


buildpack_build () {
	expect_existing '/app/.buildpack'

	# NOTE: Files copied into build_dir in buildpack_compile are present in /app on a
	# one-off dyno. This includes files which should not contribute to source_hash.

	local source_dir
	source_dir=$( get_tmp_dir 'buildpack-source' ) || die

	log 'Restoring app source'
	extract_archive_over '/app/.buildpack/buildpack-app-source.tar.gz' "${source_dir}" || die
	log
	log

	# NOTE: There is no access to the cache used in buildpack_compile from a one-off dyno.

	set_halcyon_vars
	if ! private_storage; then
		log_error 'Expected private storage'
		help_configure_private_storage
		die
	fi
	halcyon_deploy "$@"                          \
		--halcyon-dir='/app/.halcyon'        \
		--no-copy-local-source               \
		--no-cache                           \
		--no-announce-deploy                 \
		"${source_dir}" || die

	help_build_succeeded

	rm -rf "${source_dir}" || die
}


buildpack_restore () {
	expect_existing '/app/.buildpack'

	# NOTE: Files copied into build_dir in buildpack_compile are present in /app on a
	# one-off dyno. This includes files which should not contribute to source_hash.

	local source_dir
	source_dir=$( get_tmp_dir 'buildpack-source' ) || die

	log 'Restoring app source'
	extract_archive_over '/app/.buildpack/buildpack-app-source.tar.gz' "${source_dir}" || die
	log
	log

	# NOTE: There is no access to the cache used in buildpack_compile from a one-off dyno.

	set_halcyon_vars
	halcyon_deploy "$@"                          \
		--halcyon-dir='/app/.halcyon'        \
		--no-copy-local-source               \
		--no-build-dependencies              \
		--no-archive                         \
		--no-cache                           \
		--force-restore-all                  \
		--no-announce-deploy                 \
		"${source_dir}" || die

	# NOTE: All build products are normally kept in HALCYON_DIR/app.  Forcing the slug to
	# build and copying the build products is intended to help the user interact with the app.

	if [[ -d '/app/.halcyon/app' ]]; then
		copy_dir_into '/app/.halcyon/app' '/app' || die
	fi

	help_restore_succeeded

	rm -rf "${source_dir}" || die
}
