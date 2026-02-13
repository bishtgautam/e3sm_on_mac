# E3SM on macOS: Input Data Management

This guide covers downloading and managing input data for E3SM cases.

## Overview

E3SM requires extensive input data:
- **Atmospheric forcing** - meteorological data
- **Initial conditions** - starting state for components
- **Surface datasets** - land surface properties, topography
- **Domain files** - grid definitions
- **Parameter files** - model constants and tuning parameters

Data requirements vary by:
- Grid resolution (single-point: ~1GB, global: ~50-200GB)
- Compset (land-only: smaller, fully coupled: larger)
- Simulation length (longer runs need more forcing data)

## Data Directory Structure

E3SM expects data in `DIN_LOC_ROOT` (defined in `config_machines.xml`):

```bash
# Default from our configuration
~/projects/e3sm/inputdata/
├── atm/              # Atmospheric forcing and initial conditions
│   ├── cam/
│   └── datm7/
├── lnd/              # Land surface datasets
│   ├── clm2/
│   └── dlnd7/
├── ocn/              # Ocean forcing and initial conditions
├── ice/              # Sea ice forcing
├── glc/              # Land ice data
├── rof/              # River routing data
├── wav/              # Wave model data
├── share/            # Shared datasets (domain files, mapping files)
└── cpl/              # Coupler datasets
```

## Method 1: Automatic Download (Recommended)

E3SM provides a tool to automatically download required data.

### Check Required Data

After setting up a case:

```bash
cd ~/projects/e3sm/cases/my_first_case
./check_input_data --list
```

This shows all required input files and which are missing.

### Download Missing Data

```bash
# Preview what will be downloaded
./check_input_data --list | grep "NOT FOUND" | wc -l

# Download all missing files
./check_input_data --download

# This may take 10 minutes to several hours depending on:
# - Your internet speed
# - Grid resolution
# - Number of components
```

### Download with SVN (Alternative)

If `--download` doesn't work, use SVN directly:

```bash
./check_input_data --svn-loc https://svn-ccsm-inputdata.cgd.ucar.edu/trunk/inputdata
```

## Method 2: Manual Download

For better control or when automatic download fails.

### Find Required Files

```bash
cd ~/projects/e3sm/cases/my_first_case
./preview_namelists

# Lists all required files with full paths
./check_input_data --list > required_files.txt
```

### Download from NERSC Portal

E3SM hosts input data at: https://web.lcrc.anl.gov/public/e3sm/inputdata/

Navigate the directory structure and download files manually.

### Create Directories and Place Files

```bash
# Create necessary subdirectories
mkdir -p ~/projects/e3sm/inputdata/{atm,lnd,ocn,ice,glc,rof,share,cpl}

# Place downloaded files in correct locations
# Match the structure shown by check_input_data
```

## Method 3: Using Pre-Downloaded Data

If you have access to a machine with E3SM data already downloaded:

### Copy from Another Machine

```bash
# From a machine with E3SM installed (e.g., NERSC, LCRC)
rsync -av --progress \
  user@remote:/path/to/inputdata/ \
  ~/projects/e3sm/inputdata/
```

### Selective Sync

For specific compsets, sync only needed directories:

```bash
# Land-only case (I1850ELM)
rsync -av --progress user@remote:/path/to/inputdata/lnd/ \
  ~/projects/e3sm/inputdata/lnd/
rsync -av --progress user@remote:/path/to/inputdata/share/ \
  ~/projects/e3sm/inputdata/share/
rsync -av --progress user@remote:/path/to/inputdata/atm/datm7/ \
  ~/projects/e3sm/inputdata/atm/datm7/
```

### Use Symlinks (Same Filesystem Only)

If data exists on an external drive:

```bash
ln -s /Volumes/ExternalDrive/e3sm_inputdata ~/projects/e3sm/inputdata
```

## Data Requirements by Configuration

### Single-Point Land Model (1x1_brazil, I1850ELM)

**Size:** ~500 MB - 2 GB

**Required data:**
- Land surface data for Brazil point
- Atmospheric forcing (CRUNCEP or GSWP3)
- Domain file for 1x1_brazil grid
- CLM parameter files

```bash
# Quick download for single point
./check_input_data --download
# Typically completes in 5-15 minutes
```

### Regional Atmospheric Model (ne4_oQU240, F2010)

**Size:** ~5-10 GB

**Required data:**
- Low-resolution atmospheric initial conditions
- SST and sea ice forcing
- Topography data
- Ozone data

### Global Coupled Model (ne30, WCYCL1850)

**Size:** ~50-200 GB

This is typically too large for laptop storage. Consider:
- Using single-point or regional configurations
- Storing data on external drive
- Using cloud storage with selective sync

## Verifying Downloaded Data

### Check All Files Present

```bash
cd ~/projects/e3sm/cases/my_first_case
./check_input_data --check
```

Should output: `All inputdata files found!`

### Verify File Integrity

Compare file sizes:

```bash
# List downloaded files with sizes
find ~/projects/e3sm/inputdata -type f -exec ls -lh {} \; > downloaded_files.txt

# Check for suspiciously small files (possible download failures)
find ~/projects/e3sm/inputdata -type f -size -1k
```

### Test with Preview Namelists

```bash
./preview_namelists

# If successful, namelists are created in: CaseDocs/
ls -lh CaseDocs/*.in
```

## Managing Data Storage

### Check Data Size

```bash
du -sh ~/projects/e3sm/inputdata
du -h ~/projects/e3sm/inputdata/* | sort -h
```

### Clean Unused Data

After multiple cases, clean up:

```bash
# Find files not accessed in 90 days
find ~/projects/e3sm/inputdata -type f -atime +90

# Remove them (BE CAREFUL!)
find ~/projects/e3sm/inputdata -type f -atime +90 -delete
```

### Use Multiple Data Roots

For limited laptop storage, use external drive for bulk data:

```bash
# Edit case after creation
cd ~/projects/e3sm/cases/my_first_case
./xmlchange DIN_LOC_ROOT=/Volumes/ExternalDrive/e3sm_inputdata

# Or modify ~/.cime/config_machines.xml to point to external drive
```

## Data for Multiple Cases

### Shared Data Directory

All cases can share the same `DIN_LOC_ROOT`:

```bash
# Case 1
./create_newcase --case case1 ...
# Uses: ~/projects/e3sm/inputdata

# Case 2  
./create_newcase --case case2 ...
# Uses: ~/projects/e3sm/inputdata (same location)

# Data downloaded for case1 is available to case2
```

### Case-Specific Data

If you need isolated data for testing:

```bash
./xmlchange DIN_LOC_ROOT=~/projects/e3sm/cases/my_first_case/inputdata_local
./check_input_data --download
```

## Common Issues

### Issue: Download Times Out

Large files may timeout on slow connections.

**Solution:**

Download in chunks:
```bash
# Download just atmospheric data first
cd ~/projects/e3sm/inputdata
wget --recursive --no-parent --no-host-directories --cut-dirs=3 \
  https://web.lcrc.anl.gov/public/e3sm/inputdata/atm/datm7/

# Then download land data
wget --recursive --no-parent --no-host-directories --cut-dirs=3 \
  https://web.lcrc.anl.gov/public/e3sm/inputdata/lnd/clm2/
```

### Issue: Insufficient Disk Space

**Solutions:**

1. Use external drive for data
2. Choose smaller resolution (single-point vs. global)
3. Use shorter forcing datasets
4. Delete old case directories after archiving results

### Issue: Wrong Data Version

E3SM versions may require specific data versions.

**Solution:**

Check E3SM release notes:
```bash
cat $E3SM_ROOT/README.md
# Look for "Input Data" section
```

Use matching data version from: https://github.com/E3SM-Project/E3SM/releases

### Issue: Data Files Corrupted

**Symptoms:**
- Case fails during initialization
- Error: "NetCDF error"
- Segmentation faults

**Solution:**

Re-download suspicious files:
```bash
# Remove corrupted file
rm ~/projects/e3sm/inputdata/path/to/file

# Re-download
./check_input_data --download
```

## Advanced: Custom Input Data

### Using Your Own Forcing Data

To use custom atmospheric forcing:

1. **Prepare data in DATM format** (NetCDF with specific variable names)
2. **Create domain file** for your grid
3. **Modify user_nl_datm** to point to your data:

```bash
cat >> user_nl_datm << EOF
datapath = '/path/to/my/custom/data'
streams = 'my_custom_stream.txt'
EOF
```

### Creating Single-Point Datasets

For new single-point locations, create surface dataset:

```bash
cd $E3SM_ROOT/components/elm/tools/mksurfdata_map

# Edit namelist
vi mkmapdata.sh

# Generate surface dataset
./mkmapdata.sh
```

See E3SM documentation for detailed instructions.

## Data Provenance and Citation

E3SM input datasets come from various sources:

- **CRUNCEP/GSWP3:** Atmospheric forcing (cite original papers)
- **SST/Ice:** From obs datasets (NOAA/NCAR)
- **Land Surface:** From remote sensing (MODIS, etc.)

When publishing results, check data provenance:

```bash
# Many datasets include metadata with citations
ncdump -h ~/projects/e3sm/inputdata/lnd/clm2/surfdata/FILE.nc | grep -i "reference"
```

## Summary Checklist

Before running a case, verify:

- ✅ `DIN_LOC_ROOT` directory exists
- ✅ `./check_input_data --check` shows all files found
- ✅ `./preview_namelists` completes without errors
- ✅ Sufficient disk space for run output
- ✅ Data matches your E3SM version

## Next Steps

With input data ready:
- Proceed to run your case (see `05-running-cases.md`)
- Monitor run progress and analyze output

## Quick Reference

```bash
# Check what's needed
./check_input_data --list

# Download missing data
./check_input_data --download

# Verify everything is ready
./check_input_data --check

# Preview configuration
./preview_namelists

# Check data size
du -sh ~/projects/e3sm/inputdata
```
