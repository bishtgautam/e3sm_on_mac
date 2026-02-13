# E3SM on macOS: Case Creation and Building

This guide covers creating and compiling E3SM cases on macOS.

## Prerequisites

Before proceeding, ensure you have:
1. ✅ Installed all required packages (see `01-package-installation.md`)
2. ✅ Configured CIME for your machine (see `02-cime-configuration.md`)
3. ✅ Set all environment variables in your shell profile

## Verify Environment

Before creating a case, verify your environment is correctly configured:

```bash
# Check PATH
echo $PATH | grep "$HOME/local/gcc11/bin"  # Should appear FIRST

# Check compilers
which mpicc mpif90 gfortran-11

# Check NetCDF
which nc-config nf-config
nc-config --has-parallel4  # Should output "yes"

# Check environment variables
echo $SDKROOT              # Should show macOS SDK path
echo $NETCDF_PATH          # Should show $HOME/local/gcc11
```

## Understanding E3SM Components

E3SM is a modular climate model with these components:

- **EAM** - Energy Exascale Earth System Model (atmosphere)
- **ELM** - E3SM Land Model
- **MPAS-Ocean** - Ocean model
- **MPAS-SeaIce** - Sea ice model
- **MOSART** - River transport
- **MPAS-LI** - Land ice
- **Coupler** - Coordinates component interactions

For laptop development, you'll typically use:
- **Data components** (datm, docn, etc.) - read prescribed data instead of running full models
- **Stub components** (satm, socn, etc.) - no-op components
- **Single point** or **regional** configurations - smaller domains

## Case Naming Convention

E3SM cases follow this pattern:
```
GRID.COMPSET.MACHINE.COMPILER.TEST_ID.DATE
```

Example: `1x1_brazil.I1850ELM.PNNL-L07D666226.gnu11.test01.2026-02-13`

## Creating Your First Case

### Example 1: Single-Point Land Model Case

This is ideal for laptop testing - it runs only the land model at a single grid point.

```bash
# Navigate to scripts directory
cd $E3SM_ROOT/cime/scripts

# Create a single-point land-only case
./create_newcase \
    --case ~/projects/e3sm/cases/my_first_case \
    --compset I1850ELM \
    --res 1x1_brazil \
    --machine PNNL-L07D666226 \
    --compiler gnu11 \
    --run-unsupported
```

**Key arguments:**
- `--case`: Directory where case will be created
- `--compset`: Component set (`I1850ELM` = land-only with 1850 forcing)
- `--res`: Grid resolution (`1x1_brazil` = single grid point in Brazil)
- `--machine`: Your machine name from CIME config
- `--compiler`: Compiler to use (`gnu11`)
- `--run-unsupported`: Required for custom machines

### Example 1a: Recommended Setup Script for Brazil Case

For easier case creation and configuration, use a setup script. Here's a complete example that creates and configures a Brazil single-point case:

**Create `$E3SM_ROOT/cime/scripts/brazil.sh`:**

```bash
#!/bin/sh

RES=1x1_brazil
COMPSET=I1850ELM
MACH=PNNL-L07D666226  # Replace with your machine name
COMPILER=gnu11

SRC_DIR=$PWD/../../
CASE_DIR=${SRC_DIR}/cime/scripts

cd ${SRC_DIR}
GIT_HASH=`git log -n 1 --format=%h`
CASE_NAME=${RES}.${COMPSET}.${MACH}.${COMPILER}.${GIT_HASH}.`date "+%Y-%m-%d"`

cd ${SRC_DIR}/cime/scripts

./create_newcase -case ${CASE_DIR}/${CASE_NAME} \
-res ${RES} -mach ${MACH} -compiler ${COMPILER} -compset ${COMPSET}

cd ${CASE_DIR}/${CASE_NAME}

# CRITICAL: Limit atmospheric forcing data to 1948 to avoid downloading 20+ years of data
./xmlchange DATM_CLMNCEP_YR_END=1948

# Configure I/O and MPI settings
./xmlchange PIO_TYPENAME=netcdf
./xmlchange MPILIB=openmpi
./xmlchange PIO_VERSION=2

# Use local run/build directories (easier to manage on laptops)
./xmlchange RUNDIR=${PWD}/run
./xmlchange EXEROOT=${PWD}/bld

./case.setup

# Uncomment to build immediately:
# ./case.build
```

**Usage:**

```bash
cd $E3SM_ROOT/cime/scripts
chmod +x brazil.sh
./brazil.sh

# Case will be created with name like:
# 1x1_brazil.I1850ELM.PNNL-L07D666226.gnu11.abc1234.2026-02-13
```

**Key Benefits:**
- ✅ Automatic case naming with git hash and date
- ✅ **Limits data download** to 1 year (1948 only) instead of 20+ years
- ✅ Sets optimal I/O configuration for laptops
- ✅ Places run/build dirs within case for easy cleanup
- ✅ Reproducible setup you can version control

## Configuring Your Case

After creating the case, navigate to its directory:

```bash
cd ~/projects/e3sm/cases/my_first_case
```

### Key Configuration Files

- `env_mach_pes.xml` - Processor/task layout
- `env_run.xml` - Run-time settings
- `env_build.xml` - Build settings
- `user_nl_*` - Namelist modifications

### Set Up the Case

```bash
./case.setup
```

This creates:
- Build directories
- Run scripts  
- Namelist files
- Lock files

### Adjust Run Settings (Optional)

Modify run duration and output frequency:

```bash
# Run for 5 days instead of default
./xmlchange STOP_OPTION=ndays
./xmlchange STOP_N=5

# Set run start date
./xmlchange RUN_STARTDATE=2010-01-01

# Enable short-term archiving
./xmlchange DOUT_S=TRUE
```

### ⚠️ CRITICAL: Limit Atmospheric Forcing Data (Land-Only Cases)

For land-only cases (I1850ELM, I2000ELM) using data atmosphere (DATM), **limit the forcing data years** to avoid downloading 20+ years of atmospheric forcing:

```bash
# IMPORTANT: Only download forcing for 1948 (default downloads 1948-1972 = ~20 years!)
./xmlchange DATM_CLMNCEP_YR_END=1948
```

**Why this matters:**
- **Default**: Downloads atmospheric forcing from 1948-1972 (~20 years)
- **With this setting**: Downloads only 1948 (~1 year)
- **Data savings**: Reduces download from ~10-20 GB to ~500 MB - 1 GB
- **Download time**: Minutes instead of hours

**For testing and development**, one year of forcing data is sufficient. The model will cycle through this year repeatedly. For production runs, you may want more years:

```bash
# For 5 years of forcing data
./xmlchange DATM_CLMNCEP_YR_END=1952

# For full dataset (20+ years)
./xmlchange DATM_CLMNCEP_YR_END=1972
```

💡 **Pro tip**: Always set this BEFORE running `./check_input_data --download` to avoid unnecessary downloads.

### Modify Parallel Decomposition (For Laptops)

For laptop builds with limited cores:

```bash
# View current settings
./pelayout

# Change if needed (adjust NTASKS to your CPU core count)
./xmlchange NTASKS=4
./xmlchange NTHRDS=1

# Re-run setup after changing
./case.setup --reset
```

## Building Your Case

### Clean Build (Recommended for First Time)

```bash
./case.build --clean-all
./case.build
```

### Build Specific Components

```bash
# Build only shared libraries
./case.build --sharedlib-only

# Build only a component
./case.build --model elm
```

### Monitor Build Progress

Build logs are in:
```bash
ls -lrt ~/projects/e3sm/cases/my_first_case/bld/*.bldlog.*
```

View the most recent log:
```bash
tail -f $(ls -t ~/projects/e3sm/cases/my_first_case/bld/*.bldlog.* | head -1)
```

### Understanding Build Output

The build proceeds in phases:

1. **Namelist generation** - Creates input namelist files
2. **Library builds** - Builds support libraries:
   - `gptl` (timing library)
   - `mct` (Model Coupling Toolkit)
   - `spio` (Parallel I/O)
   - `csm_share` (shared infrastructure)
3. **Component builds** - Builds each model component
4. **Linking** - Creates final executable

Successful build ends with:
```
MODEL BUILD HAS FINISHED SUCCESSFULLY
```

### Build Time Estimates

On a modern MacBook:

| Configuration | Build Time |
|---------------|------------|
| Single-point land (I1850ELM) | ~5 minutes |
| Regional atmosphere (F2010) | ~10 minutes |
| Full global coupled (WCYCL) | ~30 minutes |

## Troubleshooting Build Errors

### Check Build Logs

If build fails, examine the specific component log:

```bash
# Find the failing component log
ls -lrt ~/projects/e3sm/cases/my_first_case/bld/*.bldlog.*

# View errors
grep -i error ~/projects/e3sm/cases/my_first_case/bld/COMPONENT.bldlog.*
```

### Common Build Issues

#### 1. Library Not Found Errors

**Symptom:**
```
ld: library not found for -lnetcdff
```

**Solution:**
```bash
# Verify NetCDF environment variables
echo $NETCDF_PATH
echo $NETCDF_C_PATH
echo $NETCDF_FORTRAN_PATH

# Verify nc-config is from your installation
which nc-config  # Should be $HOME/local/gcc11/bin/nc-config
```

#### 2. MPI Module Version Mismatch

**Symptom:**
```
Fatal Error: File 'mpi.mod' opened at (1) is not a GNU Fortran module file
```

**Solution:**

This happens when Homebrew's MPI modules conflict with your GCC 11 installation.

Temporarily rename Homebrew's MPI module:
```bash
sudo mv /opt/homebrew/include/mpi.mod /opt/homebrew/include/mpi.mod.bak
```

After successful build, restore it:
```bash
sudo mv /opt/homebrew/include/mpi.mod.bak /opt/homebrew/include/mpi.mod
```

Better long-term solution: Ensure `$HOME/local/gcc11/bin` is **before** `/opt/homebrew/bin` in PATH.

#### 3. System Library Not Found

**Symptom:**
```
ld: library not found for -lSystem
```

**Solution:**
```bash
# Verify SDKROOT is set
echo $SDKROOT  # Should be /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk

# If not set, add to ~/.zshrc:
export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
```

#### 4. IEEE Arithmetic Errors

**Symptom:**
```
gfortran-11: error: intrinsic operator '==' referenced at (1) not found in module 'ieee_arithmetic'
```

**Solution:**

Verify `shr_infnan_mod.F90.in` has been modified (see `02-cime-configuration.md`, Step 4).

#### 5. Line Truncation Errors

**Symptom:**
```
Error: Line truncated at (1) [-Werror=line-truncation]
```

**Solution:**

Verify CMake macros include `-ffree-line-length-none` flag (see `02-cime-configuration.md`, Step 3).

#### 6. Empty cmake_fortran_c_interface.h

**Symptom:**
```
fatal error: FCI_GLOBAL: macro not defined
```

**Solution:**

This is rare but can happen if CMake's Fortran-C interface detection fails. Manually fix:

```bash
# Find the file
find ~/projects/e3sm/cases/my_first_case/bld -name cmake_fortran_c_interface.h

# Edit the file and add these defines
#ifndef FCI_GLOBAL
#define FCI_GLOBAL(name,NAME) name##_
#define FCI_GLOBAL_(name,NAME) name##_
#define FCI_MODULE(mod_name,name, mod_NAME,NAME) __##mod_name##_MOD_##name
#define FCI_MODULE_(mod_name,name, mod_NAME,NAME) __##mod_name##_MOD_##name
#endif
```

Then rebuild:
```bash
./case.build --skip-provenance-check
```

### Complete Rebuild

If build is thoroughly broken, start fresh:

```bash
# Clean everything
./case.build --clean-all

# Delete build directory
rm -rf ~/projects/e3sm/cases/my_first_case/bld

# Re-setup
./case.setup --reset

# Rebuild
./case.build
```

## Build Optimization

### Faster Builds

Speed up compilation with parallel jobs (already set in machine config):

```bash
./xmlquery GMAKE_J  # Check current setting
./xmlchange GMAKE_J=8  # Use 8 parallel jobs
```

### Debug vs. Release Builds

```bash
# Debug build (default) - slower but better error messages
./xmlchange DEBUG=TRUE

# Release build - faster execution
./xmlchange DEBUG=FALSE

# Rebuild after changing
./case.build --clean-all
./case.build
```

## Verify Successful Build

After successful build, check for the executable:

```bash
ls -lh ~/projects/e3sm/cases/my_first_case/bld/e3sm.exe

# Check build time
grep "Total build time" $(ls -t ~/projects/e3sm/cases/my_first_case/bld/e3sm.bldlog.* | head -1)
```

## Next Steps

With a successful build:
1. Download required input data (see `04-input-data.md`)
2. Run your case (see `05-running-cases.md`)
3. Analyze results and make code modifications

## Advanced Topics

### Custom Source Modifications

To modify source code:

```bash
# Create SourceMods directory
mkdir -p ~/projects/e3sm/cases/my_first_case/SourceMods/src.elm

# Copy file you want to modify
cp $E3SM_ROOT/components/elm/src/some_file.F90 \
   ~/projects/e3sm/cases/my_first_case/SourceMods/src.elm/

# Edit the file
# SourceMods files take precedence over original source

# Rebuild (only modified component)
./case.build --skip-provenance-check
```

### User Namelists

Modify runtime behavior without rebuilding:

```bash
# Edit user namelist
cat >> user_nl_elm << EOF
hist_fincl1 = 'GPP', 'NPP', 'TSOI'
hist_nhtfrq = -24
hist_mfilt = 365
EOF

# Changes take effect on next submission
# (after ./case.setup if case wasn't set up before)
```

### Building Multiple Cases Efficiently

For development with multiple cases:

```bash
# Use shared build directories to save space/time
./create_newcase --case case1 ... --sharedlibroot ~/projects/e3sm/shared_libs
./create_newcase --case case2 ... --sharedlibroot ~/projects/e3sm/shared_libs

# Both cases will share gptl, mct, spio, csm_share builds
```

## Summary

You've learned to:
- ✅ Create E3SM cases appropriate for laptop development
- ✅ Configure case settings
- ✅ Build cases successfully
- ✅ Troubleshoot common build issues
- ✅ Optimize builds for faster development

Ready to run! See `04-input-data.md` and `05-running-cases.md`.
