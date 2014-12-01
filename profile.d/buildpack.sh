if [[ "${DYNO%.*}" != 'run' ]]; then
	export BUILDPACK_NO_SELF_UPDATE=1
	export HALCYON_NO_SELF_UPDATE=1
	export BASHMENOT_NO_SELF_UPDATE=1
fi

if ! (( ${BUILDPACK_INTERNAL_PATHS:-0} )); then
	export BUILDPACK_INTERNAL_PATHS=1

	export PATH="/app/.buildpack/bin:${PATH:-}"

	source <( HALCYON_NO_SELF_UPDATE=1 /app/.buildpack/lib/halcyon/halcyon paths )
fi

if [[ -n "${BUILDPACK_SSH_PRIVATE_KEY}" ]]; then
	mkdir -p '/app/.ssh'
	echo "${BUILDPACK_SSH_PRIVATE_KEY}" >'/app/.ssh/id_rsa'
	echo -e 'Host *\n  StrictHostKeyChecking no\n  UserKnownHostsFile=/dev/null' >'/app/.ssh/config'
	unset BUILDPACK_SSH_PRIVATE_KEY
fi
