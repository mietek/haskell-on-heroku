function help_configure_private_storage () {
	quote <<-EOF
		To configure private storage:
		$ heroku config:set HALCYON_AWS_ACCESS_KEY_ID=...
		$ heroku config:set HALCYON_AWS_SECRET_ACCESS_KEY=...
		$ heroku config:set HALCYON_S3_BUCKET=...
EOF
}


function help_configure_storage () {
	help_configure_private_storage
	quote <<-EOF

		To configure public storage:
		$ heroku config:set HALCYON_PUBLIC=1
EOF
}


function help_deploy_succeeded () {
	quote <<-EOF
		To see the app, spin up at least one web dyno:
		$ heroku ps:scale web=1
		$ heroku open

		To run GHCi, restore layers on a one-off dyno:
		$ heroku run bash
		$ restore
		$ cd .halcyon/app
		$ cabal repl
EOF
}


function help_deploy_failed () {
	quote <<-EOF
		To build layers, use a one-off PX dyno:
		$ heroku run --size=PX build
EOF
}


function help_build_succeeded () {
	quote <<-EOF
		To deploy again, commit a change and push; for example:
		$ git commit --allow-empty --allow-empty-message -m ''
		$ git push heroku master
EOF
}


function help_restore_succeeded () {
	quote <<-EOF
		To run GHCi:
		$ cd .halcyon/app
		$ cabal repl
EOF
}


function help_add_explicit_constraints () {
	local constraints
	expect_args constraints -- "$@"

	quote <<-EOF
		To use explicit constraints, add a cabal.config and push again:
		$ cat >cabal.config <<EOF
EOF
	format_constraints <<<"${constraints}" >&2 || die
	echo 'EOF' >&2
	quote <<-EOF
		$ git add cabal.config
		$ git commit -m 'Use explicit constraints' cabal.config
		$ git push heroku master
EOF
}
