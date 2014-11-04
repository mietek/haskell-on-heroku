if [[ "${DYNO%.*}" != 'run' ]]; then
	export BUILDPACK_NO_AUTOUPDATE=1
	export HALCYON_NO_AUTOUPDATE=1
	export BASHMENOT_NO_AUTOUPDATE=1
fi

if ! (( ${BUILDPACK_INTERNAL_PATHS:-0} )); then
	export BUILDPACK_INTERNAL_PATHS=1

	echo '-----> Setting buildpack paths' >&2

	export PATH="/app/.buildpack/bin:${PATH:-}"
	export PATH="/app/.buildpack/lib/halcyon:${PATH}"

	source <( halcyon show-paths )
else
	echo '-----> Buildpack paths already set' >&2
fi
