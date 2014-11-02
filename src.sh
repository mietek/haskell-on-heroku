export BUILDPACK_TOP_DIR
BUILDPACK_TOP_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P )

if [[ ! -d "${BUILDPACK_TOP_DIR}/lib/halcyon" ]]; then
	if ! git clone --depth=1 --quiet 'https://github.com/mietek/halcyon.git' "${BUILDPACK_TOP_DIR}/lib/halcyon"; then
		echo '   *** ERROR: Cannot clone Halcyon' >&2
		exit 1
	fi
fi

if [[ ! -d "${BUILDPACK_TOP_DIR}/lib/halcyon/lib/bashmenot" ]]; then
	if ! git clone --depth=1 --quiet 'https://github.com/mietek/bashmenot.git' "${BUILDPACK_TOP_DIR}/lib/halcyon/lib/bashmenot"; then
		echo '   *** ERROR: Cannot clone bashmenot' >&2
		exit 1
	fi
fi

source "${BUILDPACK_TOP_DIR}/lib/halcyon/src.sh"

source "${BUILDPACK_TOP_DIR}/src/buildpack.sh"
source "${BUILDPACK_TOP_DIR}/src/help.sh"
