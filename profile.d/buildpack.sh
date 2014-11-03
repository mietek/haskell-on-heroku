if ! (( ${BUILDPACK_INTERNAL_PATHS:-0} )); then
	export BUILDPACK_INTERNAL_PATHS=1

	export PATH="/app/.buildpack/bin:/app/.buildpack/lib/halcyon:${PATH}"
	export PATH="/app/.halcyon/slug/bin:${PATH}"
fi
