function help_deploy_succeeded () {
	log
	log
	log 'To see the app, spin up at least one web dyno:'
	log_indent '$ heroku ps:scale web=1'
	log_indent '$ heroku open'
	log
	log 'To run GHCi, restore layers on a one-off dyno:'
	log_indent '$ heroku run bash'
	log_indent '$ restore'
	log_indent '$ cabal repl'
	log
	log
}


function help_deploy_failed () {
	log
	log
	log 'To build layers, use a one-off PX dyno:'
	log_indent '$ heroku run --size=PX build'
	log
	log
}


function help_configure_private_storage () {
	log
	log
	log 'To configure private storage:'
	log_indent '$ heroku config:set HALCYON_AWS_ACCESS_KEY_ID=...'
	log_indent '$ heroku config:set HALCYON_AWS_SECRET_ACCESS_KEY=...'
	log_indent '$ heroku config:set HALCYON_S3_BUCKET=...'
}


function help_build_succeeded () {
	log
	log
	log 'To deploy again, commit a change and push; for example:'
	log_indent '$ git commit --allow-empty --allow-empty-message -m ""'
	log_indent '$ git push heroku master'
}


function help_restore_succeeded () {
	log
	log
	log 'To run GHCi:'
	log_indent '$ cabal repl'
}


function help_add_explicit_constraints () {
	local constraints
	expect_args constraints -- "$@"

	log
	log
	log 'To use explicit constraints, add a cabal.config and push again:'
	log_indent '$ cat >cabal.config <<EOF'
	format_constraints <<<"${constraints}" >&2 || die
	echo 'EOF' >&2
	log_indent '$ git add cabal.config'
	log_indent '$ git commit -m "Use explicit constraints" cabal.config'
	log_indent '$ git push heroku master'
}
