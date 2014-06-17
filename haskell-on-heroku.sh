#!/usr/bin/env bash


export HALCYON_DIR='/app/.halcyon'

declare buildpack_dir
buildpack_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P )
source "${buildpack_dir}/src/halcyon.sh"




function package_buildpack () {
	expect_vars buildpack_dir
	expect "${buildpack_dir}"

	local build_dir
	expect_args build_dir -- "$@"

	expect_no "${build_dir}/.haskell-on-heroku"
	mkdir -p "${build_dir}/.haskell-on-heroku" || die
	cp -R "${buildpack_dir}/"* "${build_dir}/.haskell-on-heroku" || die

	mkdir -p "${build_dir}/.profile.d" || die
	(
		cat >"${build_dir}/.profile.d/haskell-on-heroku.sh" <<-EOF
			source '/app/.haskell-on-heroku/haskell-on-heroku.sh'
			export PATH="/app/.haskell-on-heroku/bin:\${PATH}"
EOF
	) || die
}


function package_app () {
	expect '/app/.halcyon/install'

	local build_dir
	expect_args build_dir -- "$@"

	expect_no "${build_dir}/.halcyon/install"
	mkdir -p "${build_dir}/.halcyon/install" || die
	cp -R '/app/.halcyon/install/'* "${build_dir}/.halcyon/install" || die

	if ! [ -f "${build_dir}/Procfile" ]; then
		local app_executable
		app_executable=$( detect_app_executable "${build_dir}" ) || die
		expect "${build_dir}/.halcyon/install/bin/${app_executable}"

		echo "web: /app/.halcyon/install/bin/${app_executable}" \
			>"${build_dir}/Procfile" || die
	fi

	expect_no "${build_dir}/.ghc" "${build_dir}/.cabal" "${build_dir}/.cabal-sandbox"
	rm -rf "${build_dir}/cabal.sandbox.config" "${build_dir}/dist"
}




function log_install_succeeded_help () {
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


function log_install_failed_help () {
	log_file_indent <<-EOF
		To prepare dependencies, use a one-off PX dyno:
		$ heroku run --size=PX prepare
EOF
}


function log_prepare_succeeded_help () {
	log_file_indent <<-EOF
		To install again, commit a change and push, or rebuild:
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
