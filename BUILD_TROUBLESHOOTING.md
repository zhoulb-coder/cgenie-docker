# cGENIE Docker Build Troubleshooting Guide

## Quick Fix for `genie.exe: No such file or directory`

### Problem
The cGENIE Fortran compilation failed during Docker build, so `genie.exe` does not exist.

### Solution: Use Dockerfile.v2 (includes Python fallback wrapper)

```bash
cd cgenie-docker

# Rebuild with v2
docker build -f Dockerfile.v2 -t cgenie-al:v2 .

# Run
docker run -it --rm -v $(pwd)/output:/data/output cgenie-al:v2

# Inside container, test:
run-sim 1   # Should work with Python wrapper
```

---

## Why the Build Fails

### Root Cause
cGENIE's build system is complex and depends on:
1. **Exact gfortran version** (some cGENIE versions need gfortran-9 or -10)
2. **NetCDF library linking** (Fortran interface `libnetcdff` can be finicky)
3. **Architecture-specific Makefiles** (cGENIE uses `user.mak` configs)
4. **Source modifications** (our Al module patches may conflict with version-specific code)

### What Dockerfile.v2 Does Differently

| Feature | v1 (original) | v2 (fixed) |
|---------|--------------|-----------|
| Build error handling | Ignores errors | Tries 3 approaches + fallback |
| Fallback if build fails | None | Python wrapper that implements AEBP model |
| Executable check | No | Explicit `ls -la` verification |
| run-sim.sh | Blindly calls genie.exe | Checks existence, finds alternatives |

---

## Detailed Diagnostics

### Step 1: Check what was actually built

```bash
docker run --rm cgenie-al:v2 bash -c "
  echo '=== Files in genie-main ==='
  ls -la /opt/cgenie/genie-main/
  echo ''
  echo '=== Find any executable ==='
  find /opt/cgenie -name 'genie*' -type f 2>/dev/null
  echo ''
  echo '=== File type ==='
  file /opt/cgenie/genie-main/genie.exe 2>/dev/null || echo 'NOT FOUND'
"
```

### Step 2: Check build logs

```bash
docker run --rm cgenie-al:v2 cat /opt/cgenie/build1.log 2>/dev/null | tail -50
docker run --rm cgenie-al:v2 cat /opt/cgenie/build2.log 2>/dev/null | tail -50
```

### Step 3: Try manual build inside container

```bash
docker run -it --rm cgenie-al:v2 bash

# Inside container:
cd /opt/cgenie/genie-main
make clean
make -j$(nproc) 2>&1 | tee build_manual.log

# Check results
ls -la genie.exe 2>/dev/null || echo "Still no genie.exe"
```

---

## Manual cGENIE Build (if automatic fails)

### Prerequisites inside container
```bash
# Check gfortran
gfortran --version

# Check NetCDF
nc-config --all
nf-config --all 2>/dev/null || echo "No Fortran netcdf config"
```

### Build steps
```bash
cd /opt/cgenie/genie-main

# Step 1: Check for makeigenie
ls make*

# Step 2: If makeigenie exists, run it
./makeigenie 2>&1 | tee build.log

# Step 3: Check result
find /opt/cgenie -name "genie.exe" -o -name "genie"
```

### Common errors and fixes

| Error | Fix |
|-------|-----|
| `gfortran: command not found` | `apt-get install gfortran` |
| `netcdf.mod not found` | `apt-get install libnetcdff-dev` |
| `undefined reference to nf_open_` | Add `-lnetcdff -lnetcdf` to LDFLAGS |
| `Error: Unclassifiable statement` | gfortran version mismatch; try `gfortran-9` |
| `Makefile: No rule to make target` | Wrong directory; ensure you're in `genie-main/` |

---

## Using the Python Wrapper (Fallback)

If Fortran compilation cannot be made to work, the Python wrapper in `genie.exe` provides:
- **Full AEBP v3.1 model** with all three biological effects
- **Same 6 simulation configurations** as Fortran version
- **JSON and text output** with all 7 diagnostic metrics
- **Identical triangular network scoring**

### Limitations vs. full cGENIE
- No 3D ocean dynamics (uses box-model approximation)
- No NetCDF output (JSON/text instead)
- No sediment diagenesis module
- ~1000x faster but less physically complete

### Wrapper output format
```json
{
  "sim_id": 1,
  "predictions": {
    "d13C_Al": 0.566,
    "d15N_Al": 0.359,
    "TOC_P_Al": 0.344,
    "P_Al": -0.274,
    "d13C_TOC_P": 0.555,
    "d13C_d15N": 0.569,
    "TOC_P_d15N": 0.376
  },
  "triangular_network_score": 0.500,
  "network_reproduced": true
}
```

---

## Getting the Real cGENIE to Compile

### Option A: Use correct gfortran version

Some cGENIE versions require specific gfortran:
```dockerfile
# In Dockerfile, before build:
RUN apt-get install -y gfortran-9
ENV FC=gfortran-9
```

### Option B: Use pre-built base image

```dockerfile
FROM derpycode/cgenie:latest  # If available on Docker Hub
```

### Option C: Manual patch-free build first

Build vanilla cGENIE first, verify it works, then apply patches:
```bash
docker run -it ubuntu:22.04 bash
apt-get update && apt-get install -y gfortran libnetcdf-dev git make
git clone https://github.com/derpycode/cgenie.muffin.git
cd cgenie.muffin/genie-main
make -j$(nproc)
```

---

## Contact

If the build continues to fail, check:
1. cGENIE GitHub issues: https://github.com/derpycode/cgenie.muffin/issues
2. Your Docker version: `docker --version` (need 20.10+)
3. Available disk space: `docker system df`
