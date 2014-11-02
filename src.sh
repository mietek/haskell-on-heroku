set -o pipefail

export BUILDPACK_TOP_DIR
BUILDPACK_TOP_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P )


quote () {
	sed 's/^/       /' >&2 || return 0
}


buildpack_source_halcyon () {
	if [[ -d "${BUILDPACK_TOP_DIR}/lib/halcyon" ]]; then
		HALCYON_NO_AUTOUPDATE="${BUILDPACK_NO_AUTOUPDATE:-0}" \
			source "${BUILDPACK_TOP_DIR}/lib/halcyon/src.sh" || return 1
		return 0
	fi

	local urloid url branch
	urloid="${HALCYON_URL:-https://github.com/mietek/halcyon.git}"
	url="${urloid%#*}"
	branch="${urloid#*#}"
	if [[ "${branch}" == "${url}" ]]; then
		branch='master'
	fi

	echo '-----> Installing Halcyon' >&2

	git clone "${url}" "${BUILDPACK_TOP_DIR}/lib/halcyon" |& quote || return 1
	git -C "${BUILDPACK_TOP_DIR}/lib/halcyon" checkout "${branch}" |& quote || return 1

	HALCYON_NO_AUTOUPDATE=1 \
		source "${BUILDPACK_TOP_DIR}/lib/halcyon/src.sh" || return 1
}


if ! buildpack_source_halcyon; then
	echo '   *** ERROR: Cannot source Halcyon' >&2
fi


source "${BUILDPACK_TOP_DIR}/src/buildpack.sh"
source "${BUILDPACK_TOP_DIR}/src/help.sh"


buildpack_autoupdate () {
	if (( ${BUILDPACK_NO_AUTOUPDATE:-0} )); then
		return 0
	fi

	if [[ ! -d "${BUILDPACK_TOP_DIR}/.git" ]]; then
		return 1
	fi

	local urloid url branch
	urloid="${BUILDPACK_URL:-https://github.com/mietek/haskell-on-heroku.git}"
	url="${urloid%#*}"
	branch="${urloid#*#}"
	if [[ "${branch}" == "${url}" ]]; then
		branch='master'
	fi

	log 'Auto-updating buildpack'

	local git_url must_update
	must_update=0
	git_url=$( git -C "${BUILDPACK_TOP_DIR}" ls-remote --get-url 'origin' ) || return 1
	if [[ "${git_url}" != "${url}" ]]; then
		git -C "${HALCYON_TOP_DIR}" remote set-url 'origin' "${url}" |& quote || return 1
		must_update=1
	fi

	if ! (( must_update )); then
		local mark_time current_time
		mark_time=$( get_modification_time "${BUILDPACK_TOP_DIR}" ) || return 1
		current_time=$( date +'%s' ) || return 1
		if (( mark_time > current_time - 60 )); then
			return 0
		fi
	fi

	git -C "${BUILDPACK_TOP_DIR}" fetch 'origin' |& quote || return 1
	git -C "${BUILDPACK_TOP_DIR}" reset --hard "origin/${branch}" |& quote || return 1

	BUILDPACK_NO_AUTOUPDATE=1 \
		source "${BUILDPACK_TOP_DIR}/src.sh" || return 1
}


if ! buildpack_autoupdate; then
	log_warning 'Cannot auto-update buildpack'
fi
