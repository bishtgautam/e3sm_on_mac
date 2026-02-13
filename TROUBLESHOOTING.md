# E3SM on macOS: Troubleshooting Quick Reference

Quick solutions for common E3SM build and run issues on macOS.

## Build Errors

### ❌ `library not found for -lSystem`

**Fix:**
```bash
export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
```

---

### ❌ `File 'mpi.mod' is not a GNU Fortran module file`

**Cause:** Homebrew's mpi.mod built with different GCC version

**Fix:**
```bash
# Ensure gcc11/bin is FIRST in PATH
export PATH=$HOME/local/gcc11/bin:$PATH

# Or temporarily:
sudo mv /opt/homebrew/include/mpi.mod /opt/homebrew/include/mpi.mod.bak
# (Restore after build: sudo mv /opt/homebrew/include/mpi.mod.bak /opt/homebrew/include/mpi.mod)
```

---

### ❌ `intrinsic operator '==' not found in module 'ieee_arithmetic'`

**Cause:** GCC 11 on macOS has incomplete IEEE support

**Fix:** Ensure CMake macros and source modification from [02-cime-configuration.md](02-cime-configuration.md):
1. Add `-DNO_IEEE_ARITHMETIC` to CMake flags
2. Modify `share/util/shr_infnan_mod.F90.in` with conditional

---

### ❌ `Line truncated at (1) [-Werror=line-truncation]`

**Fix:** Add to CMake macros:
```cmake
string(APPEND CMAKE_Fortran_FLAGS " -ffree-line-length-none")
```

---

### ❌ `Cannot find NetCDF`

**Fix:**
```bash
export NETCDF_PATH=$HOME/local/gcc11
export NETCDF_C_PATH=$HOME/local/gcc11
export NETCDF_FORTRAN_PATH=$HOME/local/gcc11
```

---

### ❌ `FCI_GLOBAL: macro not defined`

**Cause:** Empty `cmake_fortran_c_interface.h`

**Fix:** Manually add to the file:
```c
#ifndef FCI_GLOBAL
#define FCI_GLOBAL(name,NAME) name##_
#define FCI_GLOBAL_(name,NAME) name##_
#define FCI_MODULE(mod_name,name, mod_NAME,NAME) __##mod_name##_MOD_##name
#define FCI_MODULE_(mod_name,name, mod_NAME,NAME) __##mod_name##_MOD_##name
#endif
```

---

### ❌ `nc-config: command not found`

**Cause:** PATH doesn't include gcc11/bin or wrong nc-config found

**Fix:**
```bash
# Check which nc-config is found
which nc-config

# Should be: $HOME/local/gcc11/bin/nc-config
# If not, fix PATH:
export PATH=$HOME/local/gcc11/bin:$PATH
```

---

### ❌ Build succeeds but takes forever

**Causes:**
- Debug mode enabled
- Too many parallel jobs for CPU count
- Running on battery (laptop throttled)

**Fixes:**
```bash
# Disable debug mode
./xmlchange DEBUG=FALSE
./case.build --clean-all && ./case.build

# Adjust parallel jobs
./xmlquery GMAKE_J
./xmlchange GMAKE_J=4  # Match your CPU core count

# Plug in laptop to AC power
```

---

## Run Errors

### ❌ Run crashes immediately

**Diagnose:**
```bash
# Check coupler log
tail -50 ~/scratch/CASE/run/cpl.log.*

# Check for errors
grep -i "error\|abort" ~/scratch/CASE/run/*.log.*
```

**Common fixes:**
```bash
# Missing input data
./check_input_data --check

# Regenerate namelists
./preview_namelists

# Ensure fresh run (not restart)
./xmlchange CONTINUE_RUN=FALSE
```

---

### ❌ `NetCDF: file not found` during run

**Fix:** Download missing input files:
```bash
./check_input_data --download
```

---

### ❌ Run hangs (no progress)

**Fix:** Kill and restart with fewer tasks:
```bash
pkill e3sm.exe

./xmlchange NTASKS=2
./case.setup --reset
./case.submit
```

---

### ❌ Run too slow

**Check throughput:**
```bash
grep "simulated years per day" ~/scratch/CASE/run/cpl.log.* | tail -1
```

**Speed up:**
1. Use single-point grid instead of global
2. Disable debug: `./xmlchange DEBUG=FALSE`
3. Reduce output frequency
4. Use more cores: `./xmlchange NTASKS=8`
5. Close other applications

**Typical laptop performance:**
- Single-point land: 10-50 sim years/day
- Regional atmosphere: 0.5-2 sim years/day
- Global coupled: 0.01-0.1 sim years/day (very slow!)

---

### ❌ `Segmentation fault` during run

**Diagnose:**
```bash
# Check memory usage
top

# Check disk space
df -h ~/scratch
```

**Fixes:**
```bash
# Reduce memory usage
./xmlchange NTASKS=2  # Fewer tasks = less memory

# Free up disk space
rm -rf ~/scratch/old_case

# Reduce history output
cat >> user_nl_elm << EOF
hist_nhtfrq = -720  # Write less often
hist_empty_htapes = .true.
hist_fincl1 = 'GPP'  # Fewer variables
EOF
```

---

## Environment Issues

### ❌ `command not found: mpicc` / `mpif90`

**Fix:**
```bash
export PATH=$HOME/local/gcc11/bin:$PATH
which mpicc mpif90  # Verify
```

---

### ❌ Homebrew packages interfering

**Symptom:** Wrong versions of tools being used

**Fix:** Ensure correct PATH order in `~/.zshrc`:
```bash
# gcc11 MUST be FIRST, before /opt/homebrew/bin
export PATH=$HOME/local/gcc11/bin:$PATH
export PATH=$PATH:/opt/homebrew/bin  # If needed for other tools
```

Reload:
```bash
source ~/.zshrc
which mpicc nc-config  # Verify correct tools
```

---

### ❌ CIME doesn't recognize my machine

**Check:**
```bash
hostname
# Must match NODENAME_REGEX in ~/.cime/config_machines.xml
```

**Fix:** Either:
1. Update `NODENAME_REGEX` to match your hostname, OR
2. Force machine name: `./create_newcase --machine YOUR_MACHINE ...`

---

## Complete Environment Checklist

Before building, verify all environment variables:

```bash
# Print all values
cat << EOF
INSTALL_PREFIX: $INSTALL_PREFIX
SDKROOT: $SDKROOT
PATH first entry: ${PATH%%:*}
NETCDF_PATH: $NETCDF_PATH
NETCDF_C_PATH: $NETCDF_C_PATH
NETCDF_FORTRAN_PATH: $NETCDF_FORTRAN_PATH
LIBRARY_PATH: $LIBRARY_PATH
EOF

# Check tools
which mpicc mpif90 nc-config nf-config gfortran-11

# Verify NetCDF has parallel support
nc-config --has-parallel4  # Should output: yes
```

**Expected values:**
- `INSTALL_PREFIX`: `$HOME/local/gcc11`
- `SDKROOT`: `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`
- `PATH first entry`: `$HOME/local/gcc11/bin`
- All NetCDF paths: `$HOME/local/gcc11`

---

## Nuclear Options (When All Else Fails)

### Complete Case Rebuild

```bash
cd ~/cases/my_case
./case.build --clean-all
rm -rf bld
./case.setup --reset
./case.build
```

### Complete Library Rebuild

```bash
cd ~/packages
rm -rf $HOME/local/gcc11

# Start over from:
# 01-package-installation.md
```

### Complete Fresh Start

```bash
# Backup any important data first!

# Remove all cases
rm -rf ~/projects/e3sm/cases/*

# Remove scratch
rm -rf ~/projects/e3sm/scratch/*

# Rebuild from fresh E3SM clone
cd ~/projects/e3sm
git clone https://github.com/E3SM-Project/E3SM.git e3sm-fresh
cd e3sm-fresh/cime/scripts
./create_newcase ...
```

---

## Getting More Help

### Check Build Logs

```bash
# Find latest build log
ls -lrt ~/cases/CASE/bld/*.bldlog.* | tail -1

# Search for errors
grep -i error ~/cases/CASE/bld/COMPONENT.bldlog.*

# Show last 100 lines
tail -100 ~/cases/CASE/bld/COMPONENT.bldlog.*
```

### Check Run Logs

```bash
# Coupler log (main log)
tail -100 ~/scratch/CASE/run/cpl.log.*

# Component logs
tail -100 ~/scratch/CASE/run/lnd.log.*
tail -100 ~/scratch/CASE/run/atm.log.*

# Search all logs for errors
cd ~/scratch/CASE/run
grep -i "error\|abort\|fatal" *.log.*
```

### Enable Verbose Output

```bash
# More detailed build output
./case.build --skip-provenance-check 2>&1 | tee build_verbose.log

# More detailed run output
cd ~/scratch/CASE/run
mpirun -v -np 1 ../bld/e3sm.exe
```

### Ask for Help

When posting to forums, include:

1. **macOS version:** `sw_vers`
2. **GCC version:** `gfortran-11 --version`
3. **MPI version:** `$HOME/local/gcc11/bin/mpif90 --version`
4. **Error message:** Relevant log excerpts
5. **What you tried:** Steps already attempted
6. **Configuration:** Compset, resolution, machine name

---

## Prevention Tips

### Before Every Build

```bash
# 1. Source environment (or ensure in ~/.zshrc)
source ~/setup_e3sm_env.sh

# 2. Verify PATH order
echo $PATH | tr ':' '\n' | head -5
# First entry should be $HOME/local/gcc11/bin

# 3. Verify compilers
which mpicc mpif90 gfortran-11

# 4. Verify NetCDF
nc-config --has-parallel4  # Should say "yes"

# 5. Check SDKROOT
echo $SDKROOT  # Should show SDK path
```

### After Every macOS Update

macOS updates can break SDK paths and command line tools.

```bash
# Reinstall Xcode Command Line Tools
sudo rm -rf /Library/Developer/CommandLineTools
xcode-select --install

# Verify SDKROOT still works
ls -la $SDKROOT  # Should exist
```

### Keep Notes

Document your setup:
```bash
# Create setup script
cat > ~/setup_e3sm_env.sh << 'EOF'
#!/bin/bash
export INSTALL_PREFIX=$HOME/local/gcc11
export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
export PATH=$INSTALL_PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$INSTALL_PREFIX/lib:$LD_LIBRARY_PATH
export DYLD_LIBRARY_PATH=$INSTALL_PREFIX/lib:$DYLD_LIBRARY_PATH
export LIBRARY_PATH=$SDKROOT/usr/lib:$LIBRARY_PATH
export NETCDF_PATH=$INSTALL_PREFIX
export NETCDF_C_PATH=$INSTALL_PREFIX
export NETCDF_FORTRAN_PATH=$INSTALL_PREFIX

echo "E3SM environment configured:"
echo "  Compilers: $(which mpicc mpif90)"
echo "  NetCDF: $(which nc-config)"
echo "  SDK: $SDKROOT"
EOF

chmod +x ~/setup_e3sm_env.sh

# Use before building
source ~/setup_e3sm_env.sh
```

---

## Summary

Most issues stem from:
1. **Missing SDKROOT** → linking failures
2. **Wrong PATH order** → wrong compilers/tools used
3. **Missing NetCDF environment variables** → CIME can't find NetCDF
4. **Homebrew conflicts** → MPI module version mismatches
5. **IEEE arithmetic** → requires source modification

✅ **Fix these five things and 90% of problems disappear!**

---

*For detailed explanations, see the main guides in this repository.*
