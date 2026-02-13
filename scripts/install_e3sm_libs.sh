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

OPENMPI_VERSION=5.0.6
HDF5_VERSION=1.14.5
NETCDF_C_VERSION=4.9.3
NETCDF_F_VERSION=4.6.2

NCORES=$(sysctl -n hw.ncpu)

# Package URLs
OPENMPI_URL="https://download.open-mpi.org/release/open-mpi/v5.0/openmpi-${OPENMPI_VERSION}.tar.gz"
HDF5_URL="https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.14/hdf5-${HDF5_VERSION}/src/hdf5-${HDF5_VERSION}.tar.gz"
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

install_openmpi() {
    print_status "Installing OpenMPI ${OPENMPI_VERSION}..."
    
    if [ -f "$INSTALL_PREFIX/bin/mpicc" ]; then
        print_warning "OpenMPI already installed, skipping"
        return 0
    fi
    
    cd ~/packages
    if [ ! -f "openmpi-${OPENMPI_VERSION}.tar.gz" ]; then
        curl -LO "$OPENMPI_URL"
    fi
    
    tar -xzf openmpi-${OPENMPI_VERSION}.tar.gz
    cd openmpi-${OPENMPI_VERSION}
    
    ./configure \
        CC=clang \
        CXX=clang++ \
        FC=gfortran-11 \
        --prefix=$INSTALL_PREFIX \
        --enable-mpi-fortran=yes \
        --with-libevent=internal
    
    make -j${NCORES}
    make install
    cd ..
    
    # Update PATH immediately
    export PATH=$INSTALL_PREFIX/bin:$PATH
    export LD_LIBRARY_PATH=$INSTALL_PREFIX/lib:$LD_LIBRARY_PATH
    export DYLD_LIBRARY_PATH=$INSTALL_PREFIX/lib:$DYLD_LIBRARY_PATH
    
    print_status "OpenMPI installed successfully"
}

install_hdf5() {
    print_status "Installing HDF5 ${HDF5_VERSION}..."
    
    if [ -f "$INSTALL_PREFIX/bin/h5pcc" ]; then
        print_warning "HDF5 already installed, skipping"
        return 0
    fi
    
    cd ~/packages
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
        FC=$INSTALL_PREFIX/bin/mpif90
    
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
    
    cd ~/packages
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
        CC=$INSTALL_PREFIX/bin/mpicc
    
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
    
    cd ~/packages
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
        FC=$INSTALL_PREFIX/bin/mpif90
    
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
    echo ""
    echo "1) Install all packages (recommended)"
    echo "2) Install OpenMPI only"
    echo "3) Install HDF5 only"
    echo "4) Install NetCDF-C only"
    echo "5) Install NetCDF-Fortran only"
    echo "6) Verify installation"
    echo "7) Check prerequisites"
    echo "0) Exit"
    echo ""
    read -p "Choose an option: " choice
}

main() {
    # Create directories
    mkdir -p ~/packages
    mkdir -p $INSTALL_PREFIX
    
    if [ $# -eq 0 ]; then
        # Interactive mode
        while true; do
            show_menu
            case $choice in
                1)
                    check_prerequisites
                    install_openmpi
                    install_hdf5
                    install_netcdf_c
                    install_netcdf_fortran
                    verify_installation
                    break
                    ;;
                2) install_openmpi ;;
                3) install_hdf5 ;;
                4) install_netcdf_c ;;
                5) install_netcdf_fortran ;;
                6) verify_installation ;;
                7) check_prerequisites ;;
                0) exit 0 ;;
                *) print_error "Invalid option" ;;
            esac
        done
    else
        # Command-line mode
        case "$1" in
            all)
                check_prerequisites
                install_openmpi
                install_hdf5
                install_netcdf_c
                install_netcdf_fortran
                verify_installation
                ;;
            openmpi) install_openmpi ;;
            hdf5) install_hdf5 ;;
            netcdf-c) install_netcdf_c ;;
            netcdf-fortran) install_netcdf_fortran ;;
            verify) verify_installation ;;
            check) check_prerequisites ;;
            *)
                echo "Usage: $0 [all|openmpi|hdf5|netcdf-c|netcdf-fortran|verify|check]"
                echo "Run without arguments for interactive mode"
                exit 1
                ;;
        esac
    fi
}

main "$@"
