# cGENIE with Aluminium Cycle Module — Docker Container

Complete Docker-based deployment of the cGENIE Earth system model with the Al-Enhanced Biological Pump (AEBP) module for validating five boundary conditions of the LPIA triangular covariance network.

---

## Quick Start

```bash
# 1. Clone or copy this directory
cd cgenie-docker

# 2. Build the container (~15-20 min)
./build.sh
# or: docker build -t cgenie-al:latest .

# 3. Run interactively
docker run -it --rm -v $(pwd)/output:/data/output cgenie-al:latest

# Inside container:
run-lpia          # Run LPIA baseline (Sim 1)
run-sim 2         # Run simulation 2 (Short glaciation)
run-sim 3         # Run simulation 3 (Carbonate)
run-all           # Run all six simulations

# 4. Or run LPIA directly as batch
docker run -v $(pwd)/output:/data/output cgenie-al:latest /opt/cgenie/scripts/run-lpia.sh

# 5. Or use docker-compose
docker-compose up cgenie-al              # Interactive
docker-compose --profile batch up cgenie-lpia-run   # Batch LPIA
docker-compose --profile all up cgenie-all          # All 6 sims
```

---

## Project Structure

```
cgenie-docker/
├── Dockerfile                          # Main container definition
├── docker-compose.yml                  # Multi-service orchestration
├── build.sh                            # One-command build script
├── README.md                           # This file
│
├── patches/                            # cGENIE source code modifications
│   ├── biogem_al.f90                   # Al cycle module (NEW Fortran module)
│   └── apply_patches.sh               # Automated patch application script
│
├── configs/                            # LPIA simulation configurations
│   ├── LPIA-Al-baseline.config        # Sim 1: LPIA (5/5 conditions)
│   ├── LPIA-Al-sim2-short.config      # Sim 2: Short glaciation (4/5)
│   ├── LPIA-Al-sim3-carbonate.config  # Sim 3: Carbonate (3/5)
│   ├── LPIA-Al-sim4-volcanic.config   # Sim 4: Volcanic (4/5)
│   ├── LPIA-Al-sim5-greenhouse.config # Sim 5: Greenhouse (3/5)
│   └── LPIA-Al-sim6-precambrian.config# Sim 6: Precambrian (4/5)
│
├── scripts/                            # Convenience scripts
│   ├── run-lpia.sh                    # Run LPIA baseline
│   ├── run-sim.sh                     # Run specific simulation (1-6)
│   ├── run-all.sh                     # Run all six simulations
│   ├── extract-diag.sh                # Extract diagnostic outputs
│   └── cgenie-status.sh               # Check simulation status
│
└── output/                             # Simulation outputs (mounted volume)
```

---

## System Requirements

| Requirement | Minimum | Recommended |
|------------|---------|-------------|
| Docker | 20.10+ | 24.0+ |
| CPU cores | 4 | 8+ |
| RAM | 8 GB | 16 GB |
| Disk space | 10 GB | 20 GB |
| OS | Linux/macOS/Windows (WSL2) | Ubuntu 22.04 |

---

## Six Simulation Scenarios

| Sim | Name | Dust Flux | Lithology | Duration | Fidelity | Biosphere | Conditions | Expected |
|-----|------|-----------|-----------|----------|----------|-----------|------------|----------|
| 1 | LPIA | 1000x | Siliciclastic | 30 Myr | High | Present | 5/5 | **Network reproduced** |
| 2 | Short | 1000x | Siliciclastic | 1 Myr | High | Present | 4/5 | Fragmented |
| 3 | Carbonate | 1000x | Carbonate | 30 Myr | Low | Present | 3/5 | No signal |
| 4 | Volcanic | 100x | Siliciclastic | 30 Myr | High | Present | 4/5 | Weak signal |
| 5 | Greenhouse | 1x | Siliciclastic | 0 Myr | High | Present | 3/5 | Partial |
| 6 | Precambrian | 1000x | Siliciclastic | 30 Myr | High | Absent | 4/5 | No signal |

---

## AEBP v3.1 Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `beta` | 0.59 | PUE enhancement sensitivity |
| `decay_sens` | 0.40 | POC remineralization inhibition |
| `deep_pres_amp` | 0.25 | Sinking velocity enhancement amplitude |
| `deep_pres_lambda` | 0.30 | Sinking velocity saturation rate |
| `Al_residence_time` | 150 yr | Ocean Al residence time |
| `Al_dust_content` | 8% | Mass fraction Al in dust |
| `f_diss_baseline` | 5% | Baseline Al dissolution fraction |

---

## Detailed Build Instructions

### Option A: Docker (recommended)

```bash
# Build
docker build -t cgenie-al:latest .

# Interactive shell
docker run -it --rm -v $(pwd)/output:/data/output cgenie-al:latest

# Batch LPIA
docker run --name cgenie-lpia -v $(pwd)/output:/data/output \
  cgenie-al:latest /opt/cgenie/scripts/run-lpia.sh
```

### Option B: Podman (rootless)

```bash
podman build -t cgenie-al:latest .
podman run -it --rm -v $(pwd)/output:/data/output:Z cgenie-al:latest
```

### Option C: docker-compose

```bash
# Interactive
docker-compose up cgenie-al

# Run LPIA batch
docker-compose --profile batch up cgenie-lpia-run

# Run all 6 simulations
docker-compose --profile all up cgenie-all

# View logs
docker-compose logs -f
```

---

## Modifying cGENIE Source Code

The patch system uses `patches/apply_patches.sh` to automatically modify cGENIE Fortran source files during the Docker build. Key modifications:

1. **biogem_tracer.f90** — Registers `io_Al` tracer index
2. **biogem_lib.f90** — Adds Al variables to `go_rec` type
3. **biogem.f90** — Includes `biogem_al` module and init call
4. **biogem_al.f90** — NEW: Complete Al cycle module with AEBP effects
5. **biogem_data.f90** — Adds Al to diagnostic output
6. **Makefile** — Adds `biogem_al.o` compilation rule

To modify patches, edit `patches/biogem_al.f90` and rebuild:
```bash
docker build --no-cache -t cgenie-al:latest .
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Build fails at `apt-get` | Check network; try `docker build --network=host` |
| cGENIE clone fails | Check GitHub access; may need proxy |
| Make fails | Check gfortran version: `docker run cgenie-al gfortran --version` |
| No output files | Ensure volume mount: `-v $(pwd)/output:/data/output` |
| Permission denied | Use `sudo` or add user to `docker` group |
| Out of memory | Increase Docker memory limit to 8GB+ |

---

## Computational Cost

| Task | CPU-hours | Wall time (8 cores) |
|------|-----------|---------------------|
| Docker build | N/A | ~15-20 min |
| Sim 1 (LPIA, 50 kyr) | ~50 | ~6 hours |
| Sim 2 (Short, 1 kyr) | ~5 | ~40 min |
| Sims 3-6 (various) | ~30-50 each | ~4-6 hours each |
| **All 6 simulations** | **~250** | **~32 hours (parallelizable)** |

---

## Output Files

Simulation outputs are written to `./output/`:

```
output/
├── lpia-baseline.log          # Sim 1 stdout log
├── sim-1.log through sim-6.log # Simulation logs
├── ocn_*.nc                    # Ocean 3D fields (NetCDF)
├── surf_*.nc                   # Surface fields
├── ben_*.nc                    # Benthic fields
├── diag_*.nc                   # Diagnostic variables including Al
└── biogem_year_*.txt           # ASCII timeseries output
```

---

## Scientific Reference

This Docker container implements the aluminium cycle validation framework described in:

> **Continental aluminium as a geological modulator of the ocean biological pump: a surrogate-model validation of five boundary conditions**
>
> Nature Geoscience supplementary materials, 2026.

Key references:
- Zhou et al. (2016, 2018) — AEBP hypothesis
- Ridgwell et al. (2007) — cGENIE model
- Rasmussen & Williams (2006) — Gaussian Processes
- Saltelli (2002) — Sensitivity analysis

---

## License

The cGENIE model is distributed under its original license. The Al cycle module and Docker configuration are provided for academic research use.

---

*Generated: 2026-07-18*
