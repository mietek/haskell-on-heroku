function help_deploy_succeeded () {
	log
	log
	log 'Finished deploying app'
	log
	log 'To see the deployed app, spin up at least one web dyno:'
	log_indent '$ heroku ps:scale web=1'
	log_indent '$ heroku open'
	log
	log 'To run GHCi, use a one-off dyno to restore the app environment:'
	log_indent '$ heroku run bash'
	log_indent '$ restore'
	log_indent '$ cabal repl'
	log
	log
}


function help_restore_succeeded () {
	log
	log
	log 'Finished restoring app'
	log
	log 'To run GHCi:'
	log_indent '$ cabal repl'
}


function help_deploy_failed () {
	log
	log
	log 'Buildpack deployed'
	log
	log 'Use a one-off PX dyno to build the app:'
	log_indent '$ heroku run --size=PX build'
	log
	log_indent 'Next, push a commit to deploy the app:'
	log_indent '$ git commit --allow-empty --allow-empty-message -m ""'
	log_indent '$ git push heroku master'
	log
	log
}


function help_build_succeeded () {
	log
	log
	log 'Push a commit to deploy the app:'
	log_indent '$ git commit --allow-empty --allow-empty-message -m ""'
	log_indent '$ git push heroku master'
}


function help_configure_private_storage () {
	log
	log 'To configure private storage:'
	log_indent '$ heroku config:set HALCYON_AWS_ACCESS_KEY_ID=...'
	log_indent '$ heroku config:set HALCYON_AWS_SECRET_ACCESS_KEY=...'
	log_indent '$ heroku config:set HALCYON_S3_BUCKET=...'
}
