if ! (( ${BUILDPACK_INTERNAL_PATHS:-0} )); then
	export BUILDPACK_INTERNAL_PATHS=1

	export PATH="/app/.buildpack/bin:${PATH:-}"

	HALCYON_NO_AUTOUPDATE=1 source <( halcyon show-paths )
fi
