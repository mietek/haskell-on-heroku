export BUILDPACK_DIR='/app/.buildpack'


# NOTE: Self-updating is disabled on worker dynos.
if [[ "${DYNO%.*}" != 'run' ]]; then
	export BUILDPACK_NO_SELF_UPDATE=1
	export HALCYON_NO_SELF_UPDATE=1
	export BASHMENOT_NO_SELF_UPDATE=1
fi


if [[ -n "${BUILDPACK_SSH_PRIVATE_KEY}" ]]; then
	mkdir -p '/app/.ssh'

	echo "${BUILDPACK_SSH_PRIVATE_KEY}" >'/app/.ssh/id_rsa'
	unset BUILDPACK_SSH_PRIVATE_KEY

	chmod 700 '/app/.ssh'
	chmod 600 '/app/.ssh/id_rsa'

	cat <<-EOF >'/app/.ssh/config'
		Host *
		  StrictHostKeyChecking no
		  UserKnownHostsFile=/dev/null
EOF
fi


if ! (( ${BUILDPACK_INTERNAL_PATHS:-0} )); then
	export BUILDPACK_INTERNAL_PATHS=1

	export PATH="${BUILDPACK_DIR}/bin:${PATH:-}"

	source <( HALCYON_NO_SELF_UPDATE=1 "${BUILDPACK_DIR}/lib/halcyon/halcyon" paths )
fi
