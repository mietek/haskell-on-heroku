unset POSIXLY_CORRECT

set -o pipefail

export BUILDPACK_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P )


install_halcyon () {
	if [[ -d "${BUILDPACK_DIR}/lib/halcyon" ]]; then
		eval "$( HALCYON_NO_SELF_UPDATE="${BUILDPACK_NO_SELF_UPDATE:-0}" "${BUILDPACK_DIR}/lib/halcyon/halcyon" paths )" || return 1
		BASHMENOT_NO_SELF_UPDATE=1 \
			source "${BUILDPACK_DIR}/lib/halcyon/lib/bashmenot/src.sh" || return 1
		return 0
	fi

	local url base_url branch
	url="${HALCYON_URL:-https://github.com/mietek/halcyon}"
	base_url="${url%#*}"
	branch="${url#*#}"
	if [[ "${branch}" == "${base_url}" ]]; then
		branch='master'
	fi

	printf -- '-----> Installing Halcyon...' >&2

	local commit_hash
	if ! commit_hash=$(
		git clone -q "${base_url}" "${BUILDPACK_DIR}/lib/halcyon" >'/dev/null' 2>&1 &&
		cd "${BUILDPACK_DIR}/lib/halcyon" &&
		git checkout -q "${branch}" >'/dev/null' 2>&1 &&
		git log -n 1 --pretty='format:%h'
	); then
		echo ' error' >&2
		return 1
	fi
	echo " done, ${commit_hash}" >&2

	eval "$( HALCYON_NO_SELF_UPDATE=1 "${BUILDPACK_DIR}/lib/halcyon/halcyon" paths )" || return 1
	BASHMENOT_NO_SELF_UPDATE=1 \
		source "${BUILDPACK_DIR}/lib/halcyon/lib/bashmenot/src.sh" || return 1
}


if ! install_halcyon; then
	echo '   *** ERROR: Failed to install Halcyon' >&2
	exit 1
fi

source "${BUILDPACK_DIR}/src/buildpack.sh"


buildpack_self_update () {
	if (( ${BUILDPACK_NO_SELF_UPDATE:-0} )) ||
		[[ ! -d "${BUILDPACK_DIR}/.git" ]]
	then
		return 0
	fi

	local now candidate_time
	now=$( get_current_time )
	if candidate_time=$( get_modification_time "${BUILDPACK_DIR}" ) &&
		(( candidate_time + 60 >= now ))
	then
		return 0
	fi

	local url
	url="${BUILDPACK_URL:-https://github.com/mietek/haskell-on-heroku}"

	log_begin 'Self-updating buildpack...'

	local commit_hash
	if ! commit_hash=$( git_update_into "${url}" "${BUILDPACK_DIR}" ); then
		log_end 'error'
		return 0
	fi
	log_end "done, ${commit_hash}"

	touch "${BUILDPACK_DIR}" || return 1

	BUILDPACK_NO_SELF_UPDATE=1 \
		source "${BUILDPACK_DIR}/src.sh"
}


if ! buildpack_self_update; then
	log_error 'Failed to self-update buildpack'
	exit 1
fi
