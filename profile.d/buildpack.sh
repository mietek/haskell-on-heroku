if ! (( ${BUILDPACK_INTERNAL_PATHS:-0} )); then
	export BUILDPACK_INTERNAL_PATHS=1

	export PATH="/app/.buildpack/bin:/app/.buildpack/lib/halcyon:${PATH:-}"

	source <( HALCYON_NO_AUTOUPDATE=1 halcyon show-paths )
fi
