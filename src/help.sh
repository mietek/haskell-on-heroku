help_install_succeeded () {
	log
	log
	log 'Install succeeded'
	log
	log 'To see the app, spin up at least one web dyno:'
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
	log 'Restore succeeded'
	log
	log 'To run GHCi:'
	log_indent '$ cabal repl'
}


help_install_failed () {
	log
	log
	log_warning 'Install failed'
	log
	log 'To build the app, use a one-off PX dyno:'
	log_indent '$ heroku run --size=PX build'
	log
	log_indent 'Next, install the app:'
	log_indent '$ git commit --amend --no-edit'
	log_indent '$ git push -f heroku master'
	log
	log
}


help_build_succeeded () {
	log
	log
	log 'Build succeeded'
	log
	log 'To install the app:'
	log_indent '$ git commit --amend --no-edit'
	log_indent '$ git push -f heroku master'
}
