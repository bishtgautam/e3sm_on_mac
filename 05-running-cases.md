# E3SM on macOS: Running Cases

This guide covers submitting, monitoring, and managing E3SM simulation runs.

## Prerequisites

Before running a case:

1. ✅ Case is built successfully (`./case.build` completed)
2. ✅ All input data is downloaded (`./check_input_data --check` passed)
3. ✅ Namelists exist (`./preview_namelists` completed)

## Quick Start

For the impatient:

```bash
cd ~/projects/e3sm/cases/my_first_case
./case.submit
```

That's it! The model will run, but read on to understand what's happening and how to monitor it.

## Understanding the Run Directory

When you submit a case, E3SM creates a run directory:

```bash
# Default location (from config_machines.xml)
~/projects/e3sm/scratch/my_first_case/run/
```

This contains:
- **Input namelists** (`.in` files)
- **Restart files** (for continuing runs)
- **History files** (model output)
- **Log files** (component logs, coupler log)
- **Timing files** (performance data)

## Submitting a Run

### Basic Submission

```bash
cd ~/projects/e3sm/cases/my_first_case
./case.submit
```

On laptops (no batch system), the model runs immediately in the foreground.

### Background Submission

To run in background:

```bash
nohup ./case.submit > case_submit.log 2>&1 &

# Monitor progress
tail -f case_submit.log
```

### Submit with Custom Settings

Modify settings before submission:

```bash
# Run for 10 days instead of default
./xmlchange STOP_N=10
./xmlchange STOP_OPTION=ndays

# Submit
./case.submit
```

## Monitoring Your Run

### Check Job Status

Since laptops don't use batch systems, check if the process is running:

```bash
# Find E3SM process
ps aux | grep e3sm.exe

# More detailed
ps aux | grep e3sm.exe | grep -v grep
```

### Monitor Log Files

#### Coupler Log (Main Log)

```bash
# Find run directory
cd ~/projects/e3sm/scratch/my_first_case/run

# Watch coupler log in real-time
tail -f cpl.log.*
```

The coupler log shows:
- Initialization messages
- Model day/time progress
- Component communication
- Warnings and errors

Example output:
```
(seq_mct_drv) : Model initialization complete
  2010-01-01 00000 (seq_mct_drv) Model date is 2010-01-01
  2010-01-02 00001 (seq_mct_drv) Model date is 2010-01-02
  2010-01-03 00002 (seq_mct_drv) Model date is 2010-01-03
```

#### Component Logs

Each component writes its own log:

```bash
cd ~/projects/e3sm/scratch/my_first_case/run

# Atmosphere log
tail -f atm.log.*

# Land log
tail -f lnd.log.*

# Ocean log  
tail -f ocn.log.*
```

### Check Progress

Calculate how far along the run is:

```bash
# Get current model date from coupler log
grep "model date" ~/projects/e3sm/scratch/my_first_case/run/cpl.log.* | tail -1

# Compare to stop date
cd ~/projects/e3sm/cases/my_first_case
./xmlquery STOP_N,STOP_OPTION,RUN_STARTDATE
```

### Monitor Performance

Check simulation speed:

```bash
cd ~/projects/e3sm/scratch/my_first_case/run
grep "simulated years per day" cpl.log.* | tail -5
```

Typical laptop performance:
- **Single-point land:** 10-50 simulated years/day
- **Regional atmosphere:** 0.5-2 simulated years/day
- **Global coupled:** 0.01-0.1 simulated years/day (very slow!)

### Monitor Resource Usage

```bash
# CPU and memory usage
top

# Then press 'o' and type "COMMAND e3sm" to filter

# Or use htop (install via: brew install htop)
htop -p $(pgrep e3sm.exe)
```

## Run Status

### Check Run Status File

```bash
cd ~/projects/e3sm/cases/my_first_case
cat CaseStatus
```

Shows timeline of case operations:
```
2026-02-13 10:00:00: case.setup starting
2026-02-13 10:00:05: case.setup success
2026-02-13 10:05:00: case.build starting
2026-02-13 10:10:23: case.build success
2026-02-13 10:15:00: case.submit starting
2026-02-13 10:25:00: case.run success
```

### Check for Errors

```bash
# Look for errors in CaseStatus
grep -i error CaseStatus

# Check coupler log for errors
grep -i error ~/projects/e3sm/scratch/my_first_case/run/cpl.log.*

# Check component logs
cd ~/projects/e3sm/scratch/my_first_case/run
grep -i "error\|abort\|fatal" *.log.*
```

## Run Completion

### Successful Completion

When run completes successfully:

```bash
# CaseStatus shows success
tail CaseStatus
# ... case.run success

# Coupler log shows successful finish
tail ~/projects/e3sm/scratch/my_first_case/run/cpl.log.*
# ... SUCCESSFUL TERMINATION OF CPL7-CCSM
```

### Verify Output Files

Check that history files were created:

```bash
cd ~/projects/e3sm/scratch/my_first_case/run

# List history files
ls -lh *.h0.* *.h1.*

# Check file size (should not be 0)
du -sh *.h0.* *.h1.*
```

### Timing Information

After successful run, check performance:

```bash
cd ~/projects/e3sm/cases/my_first_case

# View timing summary
cat timing/e3sm_timing.*

# Key metrics:
# - Time per simulation day
# - Throughput (sim years/wall day)
# - Component costs
```

## Continuing Runs

### Resubmission for Longer Runs

To run longer than initial STOP_N:

```bash
cd ~/projects/e3sm/cases/my_first_case

# Set number of resubmissions
./xmlchange RESUBMIT=2

# Each submission runs for STOP_N, then resubmits
# Total run length = STOP_N * (RESUBMIT + 1)

./case.submit
```

### Manual Continuation

After one run completes, continue from where it left off:

```bash
# Don't change RUN_STARTDATE!
# Just extend the run

./xmlchange CONTINUE_RUN=TRUE
./xmlchange RESUBMIT=0
./case.submit
```

### Multi-Year Simulations

For long runs, use resubmission:

```bash
# Run 1 month at a time, 12 resubmissions = 1 year
./xmlchange STOP_OPTION=nmonths
./xmlchange STOP_N=1
./xmlchange RESUBMIT=11
./xmlchange REST_OPTION=nmonths
./xmlchange REST_N=1

./case.submit
```

## Output Data Management

### History Files

Model output is in "history files":

```bash
cd ~/projects/e3sm/scratch/my_first_case/run

# Monthly history files (h0)
ls -lh *.elm.h0.*.nc    # Land monthly
ls -lh *.cam.h0.*.nc    # Atmosphere monthly

# Daily history files (h1, if configured)
ls -lh *.elm.h1.*.nc

# Instantaneous history files (h2, h3, etc.)
```

### Archiving Output

Enable short-term archiving to organize output:

```bash
cd ~/projects/e3sm/cases/my_first_case
./xmlchange DOUT_S=TRUE
./xmlchange DOUT_S_ROOT=~/projects/e3sm/scratch/archive/my_first_case
```

After run completes, output is organized:

```bash
~/projects/e3sm/scratch/archive/my_first_case/
├── atm/         # Atmosphere history files
├── lnd/         # Land history files
├── ocn/         # Ocean history files
├── ice/         # Ice history files
├── rest/        # Restart files
├── logs/        # All log files
└── timing/      # Timing files
```

### Analyzing Output

Use NCO or CDO tools to analyze NetCDF output:

```bash
# Install tools
brew install nco
brew install cdo

# Quick look at variables
ncdump -h ~/projects/e3sm/scratch/my_first_case/run/my_first_case.elm.h0.2010-01.nc

# Calculate time mean
ncwa -O -a time input.nc output_timemean.nc

# Extract variable
ncks -v GPP input.nc gpp_only.nc

# View data in Python
python
>>> import netCDF4
>>> nc = netCDF4.Dataset('file.nc')
>>> print(nc.variables.keys())
```

## Restart Files and Checkpointing

### Understanding Restarts

Restart files save model state to continue runs:

```bash
cd ~/projects/e3sm/scratch/my_first_case/run
ls -lh *.r.*    # Restart files

# Each component has restart files:
# *.elm.r.*     - Land restart
# *.cam.r.*     - Atmosphere restart  
# *.cice.r.*    - Sea ice restart
# *.pop.r.*     - Ocean restart
# rpointer.*    - Pointers to current restart files
```

### Restart Frequency

Control how often restarts are written:

```bash
./xmlchange REST_OPTION=nmonths
./xmlchange REST_N=1    # Write restarts every month
```

More frequent restarts:
- ✅ Can recover from crashes with less lost work
- ❌ Take disk space
- ❌ Slow down the run (I/O overhead)

Less frequent restarts:
- ✅ Faster runs
- ✅ Less disk space
- ❌ More work lost if crash

### Restarting from Specific Date

```bash
# Get list of available restart dates
ls ~/projects/e3sm/scratch/my_first_case/run/*.elm.r.*.nc

# Set restart date
./xmlchange RUN_REFDATE=2010-06-01
./xmlchange RUN_STARTDATE=2010-06-01  
./xmlchange CONTINUE_RUN=TRUE

./case.submit
```

## Common Run Issues

### Issue: Run crashes immediately

**Check initialization in coupler log:**

```bash
grep -i "error\|abort" ~/projects/e3sm/scratch/my_first_case/run/cpl.log.*
```

**Common causes:**
- Missing input data
- Incorrect namelist settings
- Incompatible restart files

**Solutions:**
```bash
# Verify input data
./check_input_data --check

# Regenerate namelists
./preview_namelists

# Start fresh (not from restart)
./xmlchange CONTINUE_RUN=FALSE
```

### Issue: Run crashes after starting

**Check when crash occurred:**

```bash
tail -100 ~/projects/e3sm/scratch/my_first_case/run/cpl.log.*
tail -100 ~/projects/e3sm/scratch/my_first_case/run/*.log.*
```

**Common causes:**
- Numerical instability (timestep too large)
- Insufficient memory
- Disk full

**Solutions:**

Reduce timestep:
```bash
# Edit component namelist
cat >> user_nl_elm << EOF
dtime = 1800
EOF

./case.submit
```

Check resources:
```bash
# Check available memory
top
vm_stat

# Check disk space
df -h ~/projects/e3sm/scratch
```

### Issue: Run hangs (not progressing)

**Symptoms:**
- Process is running but coupler log not updating
- No new model dates in log

**Solutions:**

```bash
# Kill the run
pkill e3sm.exe

# Check for deadlock in logs
cd ~/projects/e3sm/scratch/my_first_case/run
tail -100 *.log.*

# Reduce MPI tasks
cd ~/projects/e3sm/cases/my_first_case
./xmlchange NTASKS=2
./case.setup --reset

./case.submit
```

### Issue: Run too slow

**Check throughput:**

```bash
cd ~/projects/e3sm/cases/my_first_case
grep "simulated years per day" ~/projects/e3sm/scratch/my_first_case/run/cpl.log.* | tail -1
```

**Solutions to speed up:**

1. **Reduce resolution** - use coarser grid
2. **Reduce output frequency** - write less often
3. **Use more cores** - increase NTASKS
4. **Optimize decomposition** - tune NTASKS/NTHRDS
5. **Debug mode off** - use release build

```bash
./xmlchange DEBUG=FALSE
./case.build --clean-all
./case.build
```

### Issue: Too much output data

**Solutions:**

Reduce output frequency:
```bash
cat >> user_nl_elm << EOF
hist_nhtfrq = -720    # Write every 30 days instead of monthly
hist_mfilt = 12       # 12 files per stream
EOF
```

Write fewer variables:
```bash
cat >> user_nl_elm << EOF
hist_fincl1 = 'TSOI', 'H2OSOI'   # Only these variables
hist_empty_htapes = .true.       # Start with empty history
EOF
```

## Performance Optimization

### Optimal Task Layout

For laptops, experiment with decomposition:

```bash
# Check CPU count
sysctl -n hw.ncpu

# Try different layouts
./xmlchange NTASKS=4,NTHRDS=1
./xmlchange NTASKS=2,NTHRDS=2
./xmlchange NTASKS=8,NTHRDS=1

./case.setup --reset
```

### Timing Analysis

After run, analyze component costs:

```bash
cd ~/projects/e3sm/cases/my_first_case/timing

# View timing summary
less e3sm_timing.*

# Look for:
# - CPL:RUN_LOOP - coupler overhead
# - <component>:RUN - component cost
# - Throughput - simulated years/wall day
```

### Memory Usage

Monitor and optimize memory:

```bash
# During run, check memory
top -pid $(pgrep e3sm.exe)

# If memory too high:
# - Reduce history output frequency
# - Reduce NTASKS
# - Close other applications
```

## Advanced Topics

### Custom Namelists

Full control over model behavior:

```bash
cd ~/projects/e3sm/cases/my_first_case

# Land model namelist
cat >> user_nl_elm << EOF
fsurdat = '/path/to/custom/surface/data.nc'
finidat = '/path/to/custom/initial/condition.nc'
hist_fincl1 = 'GPP','NPP','NEE'
hist_nhtfrq = -1
hist_mfilt = 365
EOF

# Preview changes
./preview_namelists
less CaseDocs/lnd_in
```

### Debugging Runs

Use debugger for crashes:

```bash
# Build with debug symbols
./xmlchange DEBUG=TRUE
./case.build --clean-all
./case.build

# Run with debugger
cd ~/projects/e3sm/scratch/my_first_case/run
mpirun -np 1 lldb ../bld/e3sm.exe
```

### Branch Runs

Create a new case from an existing run:

```bash
# Create new case as branch
./create_newcase --case new_case --clone old_case
cd new_case

# Point to restart files
./xmlchange RUN_TYPE=branch
./xmlchange RUN_REFCASE=old_case
./xmlchange RUN_REFDATE=2010-01-01
./xmlchange GET_REFCASE=FALSE

# Copy restart files
cp ~/projects/e3sm/scratch/old_case/run/*.r.* ~/projects/e3sm/scratch/new_case/run/

./case.setup
./case.build
./case.submit
```

## Summary Checklist

Before submitting:
- ✅ Case built successfully
- ✅ Input data downloaded and verified
- ✅ Run settings configured (STOP_N, etc.)
- ✅ Enough disk space for output
- ✅ Namelists previewed

During run:
- ✅ Monitor coupler log for progress
- ✅ Check for errors in logs
- ✅ Monitor resource usage

After run:
- ✅ Verify successful completion
- ✅ Check output files created
- ✅ Archive important results
- ✅ Review timing information

## Quick Reference

```bash
# Submit run
./case.submit

# Check status
cat CaseStatus

# Monitor progress
tail -f ~/projects/e3sm/scratch/CASE/run/cpl.log.*

# Check for errors
grep -i error ~/projects/e3sm/scratch/CASE/run/*.log.*

# Kill run
pkill e3sm.exe

# Continue run
./xmlchange CONTINUE_RUN=TRUE
./case.submit

# Analyze output
ncdump -h output.nc
```

## Next Steps

You're now running E3SM! Next:
- Analyze your results
- Modify model code (SourceMods)
- Create new cases with different configurations
- Contribute to E3SM development

Happy modeling! 🌍
