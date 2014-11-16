help_deploy_succeeded () {
	log
	log
	log 'Deploy finished'
	log
	log 'To see the deployed app, spin up at least one web dyno:'
	log_indent '$ heroku ps:scale web=1'
	log_indent '$ heroku open'
	log
	log 'To run GHCi, use a one-off dyno:'
	log_indent '$ heroku run bash'
	log_indent '$ restore'
	log_indent '$ cabal repl'
	log
	log
}


help_restore_succeeded () {
	log
	log
	log 'Restore finished'
	log
	log 'To run GHCi:'
	log_indent '$ cabal repl'
}


help_deploy_failed () {
	log
	log
	log 'Buildpack deployed'
	log
	log 'To build the app, use a one-off PX dyno:'
	log_indent '$ heroku run --size=PX build'
	log
	log_indent 'Next, deploy the app:'
	log_indent '$ git commit --amend -C HEAD'
	log_indent '$ git push -f heroku HEAD:master'
	log
	log
}


help_build_succeeded () {
	log
	log
	log 'Build finished'
	log
	log 'To deploy the app:'
	log_indent '$ git commit --amend -C HEAD'
	log_indent '$ git push -f heroku HEAD:master'
}


help_configure_private_storage () {
	log
	log 'To configure private storage:'
	log_indent '$ heroku config:set HALCYON_AWS_ACCESS_KEY_ID=...'
	log_indent '$ heroku config:set HALCYON_AWS_SECRET_ACCESS_KEY=...'
	log_indent '$ heroku config:set HALCYON_S3_BUCKET=...'
}
