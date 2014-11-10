if [[ "${DYNO%.*}" != 'run' ]]; then
	export BUILDPACK_NO_AUTOUPDATE=1
	export HALCYON_NO_AUTOUPDATE=1
	export BASHMENOT_NO_AUTOUPDATE=1
fi

if ! (( ${BUILDPACK_INTERNAL_PATHS:-0} )); then
	export BUILDPACK_INTERNAL_PATHS=1

	export PATH="/app/.buildpack/bin:${PATH:-}"

	source <( /app/.buildpack/lib/halcyon/halcyon paths )
fi

if [[ "${DYNO%.*}" != 'run' ]] && (( ${BUILDPACK_KEEP_ENV:-0} )); then
	restore
fi
