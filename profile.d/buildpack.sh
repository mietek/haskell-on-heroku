if ! (( ${BUILDPACK_INTERNAL_PATHS:-0} )); then
	export BUILDPACK_INTERNAL_PATHS=1

	export PATH="/app/.buildpack/bin:${PATH}"
	export PATH="/app/.halcyon/slug/bin:${PATH}"
fi

source '/app/.buildpack/lib/halcyon/src/paths.sh'
set_halcyon_paths
