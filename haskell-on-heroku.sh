#!/usr/bin/env bash


export HALCYON_DIR='/app/.halcyon'

declare self_dir
self_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "${self_dir}/src/halcyon.sh"




function slug_buildpack () {
	expect_vars HALCYON_DIR

	local buildpack_dir build_dir
	expect_args buildpack_dir build_dir -- "$@"
	expect "${buildpack_dir}" "${build_dir}"
	expect_no "${build_dir}/.profile.d/halcyon.sh"

	local slugged_halcyon_dir
	slugged_halcyon_dir="${build_dir}/.halcyon"
	expect_no "${slugged_halcyon_dir}"

	mkdir -p "${slugged_halcyon_dir}/buildpack" || die
	cp -R "${buildpack_dir}/"* "${slugged_halcyon_dir}/buildpack" || die

	mkdir -p "${build_dir}/.profile.d" || die
	echo "source \"${HALCYON_DIR}/buildpack/haskell-on-heroku.sh\"" >"${build_dir}/.profile.d/haskell-on-heroku.sh" || die
}


function slug_app () {
	expect_vars HALCYON_DIR
	expect "${HALCYON_DIR}/app"

	local build_dir
	expect_args build_dir -- "$@"
	expect_no "${build_dir}/.cabal" "${build_dir}/.ghc" "${build_dir}/dist"

	local slugged_halcyon_dir
	slugged_halcyon_dir="${build_dir}/.halcyon"
	expect "${slugged_halcyon_dir}"
	expect_no "${slugged_halcyon_dir}/app"

	cp -R "${HALCYON_DIR}/app" "${slugged_halcyon_dir}/app" || die

	if ! [ -f "${build_dir}/Procfile" ]; then
		local app_executable
		app_executable=$( detect_app_executable "${build_dir}" ) || die
		expect "${slugged_halcyon_dir}/app/bin/${app_executable}"

		echo "web: ${HALCYON_DIR}/app/bin/${app_executable}" >"${build_dir}/Procfile" || die
	fi
}




function log_compile_succeeded_help () {
	log_file_indent <<-EOF
		To see it, use at least one web dyno:
		$ heroku ps:scale web=1
		$ heroku open

		To use sandboxed GHCi, connect to a one-off dyno:
		$ heroku run bash
		$ restore
		$ cabal repl
EOF
}


function log_compile_failed_help () {
	log_file_indent <<-EOF
		To prepare, use a one-off PX dyno:
		$ heroku run --size=PX prepare
EOF
}


function log_prepare_succeeded_help () {
	log_file_indent <<-EOF
		To compile again, commit a change and push, or rebuild:
		$ heroku plugins:install https://github.com/heroku/heroku-repo.git
		$ heroku repo:rebuild
EOF
}


function log_restore_succeeded_help () {
	log_file_indent <<-EOF
		To use sandboxed GHCi:
		$ cabal repl
EOF
}




function log_add_config_help () {
	local sandbox_constraints
	expect_args sandbox_constraints -- "$@"

	log_file_indent <<-EOF
		To use explicit constraints, add cabal.config and push again:
		$ cat >cabal.config <<EOF
EOF
	echo_constraints <<<"${sandbox_constraints}" >&2 || die
	echo 'EOF' >&2
	log_file_indent <<-EOF
		$ git add cabal.config
		$ git commit -m 'Use explicit constraints' cabal.config
		$ git push heroku master
EOF
}
