######## Please don't edit from here ########
case $(lsb_release -is) in
    Debian)
        DIST_KIND=debian
	DIST_FULL_VER="$(lsb_release -rs)"
	DIST_VER="${DIST_FULL_VER:0:1}"
	INTERNAL_MACHINE=1
        ;;
    Ubuntu)
        DIST_KIND=ubuntu
	DIST_VER="$(lsb_release -rs)"
        ;;
    *)
        echo 1>&2 "config.sh: error: unknown distribution: $(lsb_release -is)"
        exit 1
        ;;
esac

case $(uname -m) in
    x86_64)
        ARCH_BITS=64
        ;;
    x86|i[3-6]86)
        ARCH_BITS=32
        ;;
    *)
        echo 1>&2 "config.sh: error: unknown architecture: $(uname -m)"
        exit 1
        ;;
esac

BUILD_GOOGLE_TEST=ON

err_report() {
    echo "Error on line $2:$1"
    echo "Stopping the script $(basename "$3")."
}