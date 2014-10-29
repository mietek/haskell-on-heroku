if ! (( ${BUILDPACK_INTERNAL_PATHS:-0} )); then
	export BUILDPACK_INTERNAL_PATHS=1

	export PATH="/app/.haskell-on-heroku/bin:${PATH}"
	export PATH="/app/.halcyon/slug/bin:${PATH}"
fi

source '/app/.haskell-on-heroku/lib/halcyon/src/paths.sh'
set_halcyon_paths
