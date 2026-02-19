#!/bin/bash
set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Installation configuration
export INSTALL_PREFIX=${INSTALL_PREFIX:-$HOME/local/gcc11}
export SDKROOT=${SDKROOT:-/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk}
export LIBRARY_PATH=$SDKROOT/usr/lib:$LIBRARY_PATH

LIBEVENT_VERSION=2.1.12-stable
OPENMPI_VERSION=5.0.6
PNETCDF_VERSION=1.12.3
HDF5_VERSION=1.14.5
NETCDF_C_VERSION=4.9.3
NETCDF_F_VERSION=4.6.2

NCORES=$(sysctl -n hw.ncpu)
PACKAGES_DIR=${PACKAGES_DIR:-$HOME/packages}

# Package URLs
LIBEVENT_URL="https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}/libevent-${LIBEVENT_VERSION}.tar.gz"
OPENMPI_URL="https://download.open-mpi.org/release/open-mpi/v5.0/openmpi-${OPENMPI_VERSION}.tar.gz"
PNETCDF_URL="https://parallel-netcdf.github.io/Release/pnetcdf-${PNETCDF_VERSION}.tar.gz"
HDF5_URL="https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5_${HDF5_VERSION}.tar.gz"
NETCDF_C_URL="https://github.com/Unidata/netcdf-c/archive/refs/tags/v${NETCDF_C_VERSION}.tar.gz"
NETCDF_F_URL="https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v${NETCDF_F_VERSION}.tar.gz"

print_status() {
    echo -e "${GREEN}==>${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

show_help() {
    cat << EOF
E3SM Libraries Installation Script
===================================

Automated installation of required libraries for building E3SM on macOS with GCC 11.

Libraries installed:
  - OpenMPI ${OPENMPI_VERSION} (parallel computing)
  - PNetCDF ${PNETCDF_VERSION} (parallel NetCDF with classic format)
  - HDF5 ${HDF5_VERSION} (data format with parallel I/O)
  - NetCDF-C ${NETCDF_C_VERSION} (climate data format with parallel support)
  - NetCDF-Fortran ${NETCDF_F_VERSION} (Fortran interface to NetCDF)

Usage:
  $0 [OPTIONS] [COMMAND]

Options:
  -h, --help              Show this help message
  -p, --packages-dir DIR  Directory for downloading/building packages
                          (default: \$HOME/packages)
  -i, --install-dir DIR   Installation directory
                          (default: \$HOME/local/gcc11)

Commands:
  all              Install all packages (default in interactive mode)
  openmpi          Install OpenMPI only
  pnetcdf          Install PNetCDF only
  hdf5             Install HDF5 only
  netcdf-c         Install NetCDF-C only
  netcdf-fortran   Install NetCDF-Fortran only
  verify           Verify installation
  check            Check prerequisites

Examples:
  # Interactive mode
  $0

  # Install everything
  $0 all

  # Install to custom directories
  $0 --packages-dir /tmp/builds --install-dir /opt/e3sm all

  # Install specific package
  $0 openmpi

  # Verify existing installation
  $0 verify

Environment Variables:
  INSTALL_PREFIX    Installation directory (default: \$HOME/local/gcc11)
  PACKAGES_DIR      Build directory (default: \$HOME/packages)
  SDKROOT          macOS SDK path (auto-detected)

Note: Run without arguments for interactive menu mode.

EOF
    exit 0
}

check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check for Homebrew
    if ! command -v brew &> /dev/null; then
        print_error "Homebrew not found. Install from https://brew.sh/"
        exit 1
    fi
    
    # Check for GCC 11
    if ! command -v gfortran-11 &> /dev/null; then
        print_warning "GCC 11 not found. Installing via Homebrew..."
        brew install gcc@11
    fi
    
    # Check SDK
    if [ ! -d "$SDKROOT" ]; then
        print_error "macOS SDK not found at $SDKROOT"
        print_error "Install Xcode Command Line Tools: xcode-select --install"
        exit 1
    fi
    
    # Check disk space (need at least 10GB)
    available_space=$(df -g . | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 10 ]; then
        print_warning "Less than 10GB free space available"
    fi
    
    print_status "Prerequisites OK"
}

install_libevent() {
    print_status "Installing libevent ${LIBEVENT_VERSION}..."
    
    if [ -f "$INSTALL_PREFIX/lib/libevent.a" ]; then
        print_warning "libevent already installed, skipping"
        return 0
    fi
    
    cd "$PACKAGES_DIR"
    if [ ! -f "libevent-${LIBEVENT_VERSION}.tar.gz" ]; then
        curl -LO "$LIBEVENT_URL"
    fi
    
    tar -xzf libevent-${LIBEVENT_VERSION}.tar.gz
    cd libevent-${LIBEVENT_VERSION}
    
    ./configure \
        --prefix=$INSTALL_PREFIX \
        --disable-shared \
        --enable-static \
        --disable-openssl \
        CC=clang \
        CFLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
    
    make -j${NCORES}
    make install
    cd ..
    
    print_status "libevent installed successfully"
}

install_openmpi() {
    print_status "Installing OpenMPI ${OPENMPI_VERSION}..."
    
    if [ -f "$INSTALL_PREFIX/bin/mpicc" ]; then
        print_warning "OpenMPI already installed, skipping"
        return 0
    fi
    
    cd "$PACKAGES_DIR"
    if [ ! -f "openmpi-${OPENMPI_VERSION}.tar.gz" ]; then
        curl -LO "$OPENMPI_URL"
    fi
    
    tar -xzf openmpi-${OPENMPI_VERSION}.tar.gz
    cd openmpi-${OPENMPI_VERSION}
    
    ./configure \
        CC=clang \
        CXX=clang++ \
        FC=gfortran-11 \
        CFLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}" \
        CXXFLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}" \
        FCFLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}" \
        --prefix=$INSTALL_PREFIX \
        --enable-mpi-fortran=yes \
        --with-libevent=$INSTALL_PREFIX \
        --with-hwloc=internal \
        --with-pmix=internal
    
    make -j${NCORES}
    make install
    cd ..
    
    # Update PATH immediately
    export PATH=$INSTALL_PREFIX/bin:$PATH
    export LD_LIBRARY_PATH=$INSTALL_PREFIX/lib:$LD_LIBRARY_PATH
    export DYLD_LIBRARY_PATH=$INSTALL_PREFIX/lib:$DYLD_LIBRARY_PATH
    
    print_status "OpenMPI installed successfully"
}

install_pnetcdf() {
    print_status "Installing PNetCDF ${PNETCDF_VERSION}..."
    
    if [ -f "$INSTALL_PREFIX/bin/pnetcdf-config" ]; then
        print_warning "PNetCDF already installed, skipping"
        return 0
    fi
    
    cd "$PACKAGES_DIR"
    if [ ! -f "pnetcdf-${PNETCDF_VERSION}.tar.gz" ]; then
        curl -LO "$PNETCDF_URL"
    fi
    
    tar -xzf pnetcdf-${PNETCDF_VERSION}.tar.gz
    cd pnetcdf-${PNETCDF_VERSION}
    
    # Ensure macOS SDK libraries are available to the linker
    export SDKROOT=$(xcrun --show-sdk-path)
    export LIBRARY_PATH=$SDKROOT/usr/lib:$LIBRARY_PATH
    
    # Find gfortran library path
    local GFORTRAN_LIB=$(gfortran-11 -print-file-name=libgfortran.dylib | xargs dirname)
    
    # Set combined linker flags
    export LDFLAGS="-L$GFORTRAN_LIB -L$INSTALL_PREFIX/lib -L$SDKROOT/usr/lib"
    
    ./configure \
        --prefix=$INSTALL_PREFIX \
        CC=$INSTALL_PREFIX/bin/mpicc \
        FC=$INSTALL_PREFIX/bin/mpif90 \
        F77=$INSTALL_PREFIX/bin/mpif77 \
        CFLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}" \
        FCFLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
    
    make -j${NCORES}
    make install
    cd ..
    
    print_status "PNetCDF installed successfully"
}

install_hdf5() {
    print_status "Installing HDF5 ${HDF5_VERSION}..."
    
    if [ -f "$INSTALL_PREFIX/bin/h5pcc" ]; then
        print_warning "HDF5 already installed, skipping"
        return 0
    fi
    
    cd "$PACKAGES_DIR"
    if [ ! -f "hdf5-${HDF5_VERSION}.tar.gz" ]; then
        curl -LO "$HDF5_URL"
    fi
    
    tar -xzf hdf5-${HDF5_VERSION}.tar.gz
    cd hdf5-${HDF5_VERSION}
    
    ./configure \
        --prefix=$INSTALL_PREFIX \
        --enable-fortran \
        --enable-parallel \
        CC=$INSTALL_PREFIX/bin/mpicc \
        FC=$INSTALL_PREFIX/bin/mpif90 \
        CFLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}" \
        FCFLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
    
    make -j${NCORES}
    make install
    cd ..
    
    print_status "HDF5 installed successfully"
}

install_netcdf_c() {
    print_status "Installing NetCDF-C ${NETCDF_C_VERSION}..."
    
    if [ -f "$INSTALL_PREFIX/bin/nc-config" ]; then
        print_warning "NetCDF-C already installed, skipping"
        return 0
    fi
    
    cd "$PACKAGES_DIR"
    if [ ! -f "v${NETCDF_C_VERSION}.tar.gz" ]; then
        curl -LO "$NETCDF_C_URL"
    fi
    
    tar -xzf v${NETCDF_C_VERSION}.tar.gz
    cd netcdf-c-${NETCDF_C_VERSION}
    
    export CPPFLAGS="-I$INSTALL_PREFIX/include"
    export LDFLAGS="-L$INSTALL_PREFIX/lib"
    
    ./configure \
        --prefix=$INSTALL_PREFIX \
        --enable-netcdf4 \
        --enable-parallel4 \
        --disable-dap \
        CC=$INSTALL_PREFIX/bin/mpicc \
        CFLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
    
    make -j${NCORES}
    make install
    cd ..
    
    print_status "NetCDF-C installed successfully"
}

install_netcdf_fortran() {
    print_status "Installing NetCDF-Fortran ${NETCDF_F_VERSION}..."
    
    if [ -f "$INSTALL_PREFIX/bin/nf-config" ]; then
        print_warning "NetCDF-Fortran already installed, skipping"
        return 0
    fi
    
    cd "$PACKAGES_DIR"
    if [ ! -f "v${NETCDF_F_VERSION}.tar.gz" ]; then
        curl -LO "$NETCDF_F_URL"
    fi
    
    tar -xzf v${NETCDF_F_VERSION}.tar.gz
    cd netcdf-fortran-${NETCDF_F_VERSION}
    
    export CPPFLAGS="-I$INSTALL_PREFIX/include"
    export LDFLAGS="-L$INSTALL_PREFIX/lib"
    
    ./configure \
        --prefix=$INSTALL_PREFIX \
        CC=$INSTALL_PREFIX/bin/mpicc \
        FC=$INSTALL_PREFIX/bin/mpif90 \
        CFLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}" \
        FCFLAGS="-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
    
    make -j${NCORES}
    make install
    cd ..
    
    print_status "NetCDF-Fortran installed successfully"
}

verify_installation() {
    print_status "Verifying installation..."
    
    local all_ok=true
    
    # Check OpenMPI
    if [ -f "$INSTALL_PREFIX/bin/mpicc" ]; then
        echo -e "${GREEN}✓${NC} OpenMPI: $($INSTALL_PREFIX/bin/mpicc --version | head -1)"
    else
        echo -e "${RED}✗${NC} OpenMPI: NOT FOUND"
        all_ok=false
    fi
    
    # Check PNetCDF
    if [ -f "$INSTALL_PREFIX/bin/pnetcdf-config" ]; then
        echo -e "${GREEN}✓${NC} PNetCDF: $($INSTALL_PREFIX/bin/pnetcdf-config --version)"
    else
        echo -e "${RED}✗${NC} PNetCDF: NOT FOUND"
        all_ok=false
    fi
    
    # Check HDF5
    if [ -f "$INSTALL_PREFIX/bin/h5pcc" ]; then
        echo -e "${GREEN}✓${NC} HDF5: $($INSTALL_PREFIX/bin/h5pcc -showconfig | grep 'HDF5 Version' | cut -d: -f2)"
    else
        echo -e "${RED}✗${NC} HDF5: NOT FOUND"
        all_ok=false
    fi
    
    # Check NetCDF-C
    if [ -f "$INSTALL_PREFIX/bin/nc-config" ]; then
        local parallel=$($INSTALL_PREFIX/bin/nc-config --has-parallel4)
        echo -e "${GREEN}✓${NC} NetCDF-C: $($INSTALL_PREFIX/bin/nc-config --version) (parallel: $parallel)"
    else
        echo -e "${RED}✗${NC} NetCDF-C: NOT FOUND"
        all_ok=false
    fi
    
    # Check NetCDF-Fortran
    if [ -f "$INSTALL_PREFIX/bin/nf-config" ]; then
        echo -e "${GREEN}✓${NC} NetCDF-Fortran: $($INSTALL_PREFIX/bin/nf-config --version)"
    else
        echo -e "${RED}✗${NC} NetCDF-Fortran: NOT FOUND"
        all_ok=false
    fi
    
    if [ "$all_ok" = true ]; then
        print_status "All packages installed successfully!"
        echo ""
        print_status "Add these to your ~/.zshrc:"
        echo "export INSTALL_PREFIX=$INSTALL_PREFIX"
        echo "export SDKROOT=$SDKROOT"
        echo "export LIBRARY_PATH=\$SDKROOT/usr/lib:\$LIBRARY_PATH"
        echo "export PATH=\$INSTALL_PREFIX/bin:\$PATH"
        echo "export LD_LIBRARY_PATH=\$INSTALL_PREFIX/lib:\$LD_LIBRARY_PATH"
        echo "export DYLD_LIBRARY_PATH=\$INSTALL_PREFIX/lib:\$DYLD_LIBRARY_PATH"
        echo "export PNETCDF_PATH=\$INSTALL_PREFIX"
        echo "export NETCDF_PATH=\$INSTALL_PREFIX"
        echo "export NETCDF_C_PATH=\$INSTALL_PREFIX"
        echo "export NETCDF_FORTRAN_PATH=\$INSTALL_PREFIX"
    else
        print_error "Some packages failed to install"
        exit 1
    fi
}

show_menu() {
    echo ""
    echo "E3SM Libraries Installation Script"
    echo "==================================="
    echo "Installation prefix: $INSTALL_PREFIX"
    echo "Packages directory: $PACKAGES_DIR"
    echo ""
    echo "1) Install all packages (recommended)"
    echo "2) Install libevent only"
    echo "3) Install OpenMPI only"
    echo "4) Install PNetCDF only"
    echo "5) Install HDF5 only"
    echo "6) Install NetCDF-C only"
    echo "7) Install NetCDF-Fortran only"
    echo "8) Verify installation"
    echo "9) Check prerequisites"
    echo "0) Exit"
    echo ""
    read -p "Choose an option: " choice
}

main() {
    # Parse command-line arguments
    local command=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                ;;
            -p|--packages-dir)
                PACKAGES_DIR="$2"
                shift 2
                ;;
            -i|--install-dir)
                export INSTALL_PREFIX="$2"
                shift 2
                ;;
            all|libevent|openmpi|pnetcdf|hdf5|netcdf-c|netcdf-fortran|verify|check)
                command="$1"
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Create directories
    mkdir -p "$PACKAGES_DIR"
    mkdir -p "$INSTALL_PREFIX"
    
    if [ -z "$command" ]; then
        # Interactive mode
        while true; do
            show_menu
            case $choice in
                1)
                    check_prerequisites
                    install_libevent
                    install_openmpi
                    install_pnetcdf
                    install_hdf5
                    install_netcdf_c
                    install_netcdf_fortran
                    verify_installation
                    break
                    ;;
                2) install_libevent ;;
                3) install_libevent && install_openmpi ;;
                4) install_pnetcdf ;;
                5) install_hdf5 ;;
                6) install_netcdf_c ;;
                7) install_netcdf_fortran ;;
                8) verify_installation ;;
                9) check_prerequisites ;;
                0) exit 0 ;;
                *) print_error "Invalid option" ;;
            esac
        done
    else
        # Command-line mode
        case "$command" in
            all)
                check_prerequisites
                install_libevent
                install_openmpi
                install_pnetcdf
                install_hdf5
                install_netcdf_c
                install_netcdf_fortran
                verify_installation
                ;;
            libevent) install_libevent ;;
            openmpi) install_libevent && install_openmpi ;;
            pnetcdf) install_pnetcdf ;;
            hdf5) install_hdf5 ;;
            netcdf-c) install_netcdf_c ;;
            netcdf-fortran) install_netcdf_fortran ;;
            verify) verify_installation ;;
            check) check_prerequisites ;;
        esac
    fi
}

main "$@"
