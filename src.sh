export BUILDPACK_TOP_DIR
BUILDPACK_TOP_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P )

install_halcyon () {
	local dir
	dir="${BUILDPACK_TOP_DIR}/lib/halcyon"
	if [[ -d "${dir}" ]]; then
		if ! git -C "${dir}" fetch -q || ! git -C "${dir}" reset -q --hard '@{u}'; then
			echo '   *** ERROR: Cannot update Halcyon' >&2
			return 1
		fi
		return 0
	fi

	local urloid url branch
	urloid="${HALCYON_SOURCE_URL:-https://github.com/mietek/halcyon.git}"
	url="${urloid%#*}"
	branch="${urloid#*#}"
	if ! git clone -q "${url}" "${dir}"; then
		echo "   *** ERROR: Cannot clone ${url}" >&2
		return 1
	fi
	if [[ "${url}" != "${branch}" ]] && ! git -C "${dir}" checkout -q "${branch}"; then
		echo "   *** ERROR: Cannot checkout Halcyon ${branch}" >&2
		return 1
	fi
}

install_halcyon || exit 1

source "${BUILDPACK_TOP_DIR}/lib/halcyon/src.sh"

source "${BUILDPACK_TOP_DIR}/src/buildpack.sh"
source "${BUILDPACK_TOP_DIR}/src/help.sh"
