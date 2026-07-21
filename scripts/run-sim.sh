#!/bin/bash
# =============================================================================
# run-sim.sh - Run a specific cGENIE simulation (1-6)
# =============================================================================
# Usage: run-sim N  (where N = 1, 2, 3, 4, 5, or 6)
#
# Simulations:
#   1 = LPIA baseline (5/5 conditions)
#   2 = Short glaciation (4/5)
#   3 = Carbonate platform (3/5)
#   4 = Volcanic interval (4/5)
#   5 = Greenhouse climate (3/5)
#   6 = Precambrian biosphere (4/5)
# =============================================================================

set -e

SIM=$1
if [ -z "$SIM" ]; then
    echo "ERROR: Usage: run-sim N (where N = 1-6)"
    echo ""
    echo "Available simulations:"
    echo "  1 = LPIA baseline (5/5 boundary conditions)"
    echo "  2 = Short glaciation (4/5 conditions)"
    echo "  3 = Carbonate platform (3/5 conditions)"
    echo "  4 = Volcanic interval (4/5 conditions)"
    echo "  5 = Greenhouse climate (3/5 conditions)"
    echo "  6 = Precambrian biosphere (4/5 conditions)"
    exit 1
fi

# Validate input
if ! [[ "$SIM" =~ ^[1-6]$ ]]; then
    echo "ERROR: Simulation ID must be 1-6, got: '$SIM'"
    exit 1
fi

# Check genie.exe exists
GENIE="/opt/cgenie/genie-main/genie.exe"
if [ ! -f "$GENIE" ]; then
    echo "ERROR: genie.exe not found at $GENIE"
    echo "This usually means the cGENIE build failed during Docker image creation."
    echo "The Python fallback wrapper should have been created instead."
    echo "Checking for alternative..."
    
    # Try to find any genie executable
    FOUND=$(find /opt/cgenie -name "genie*" -type f -executable 2>/dev/null | head -5)
    if [ -n "$FOUND" ]; then
        echo "Found alternatives:"
        echo "$FOUND"
        GENIE=$(echo "$FOUND" | head -1)
        echo "Using: $GENIE"
    else
        echo "No genie executable found anywhere in /opt/cgenie"
        echo "Please rebuild the Docker image with: docker build --no-cache -f Dockerfile.v2 -t cgenie-al:v2 ."
        exit 1
    fi
fi

# Determine config file
CONFIGS=("" "LPIA-Al-baseline" "LPIA-Al-sim2-short" "LPIA-Al-sim3-carbonate"
         "LPIA-Al-sim4-volcanic" "LPIA-Al-sim5-greenhouse" "LPIA-Al-sim6-precambrian")
CFG="${CONFIGS[$SIM]}"
CONFIG_FILE="/opt/cgenie/configs/${CFG}.config"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

# Setup output
OUTDIR="${CGENIE_OUTPUT:-/data/output}"
mkdir -p "$OUTDIR"

LOGFILE="$OUTDIR/sim-${SIM}.log"

echo "========================================"
echo "[run-sim] Simulation $SIM/6"
echo "[run-sim] Config: $CFG"
echo "[run-sim] Config file: $CONFIG_FILE"
echo "[run-sim] Executable: $GENIE"
echo "[run-sim] Output dir: $OUTDIR"
echo "[run-sim] Log file: $LOGFILE"
echo "========================================"

cd /opt/cgenie/genie-main

# Run simulation
echo "[run-sim] Starting at $(date -Iseconds)"
$GENIE "$CONFIG_FILE" 2>&1 | tee "$LOGFILE"
EXIT_CODE=${PIPESTATUS[0]}

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "[run-sim] Simulation $SIM completed successfully"
    echo "[run-sim] Results in: $OUTDIR/sim-${SIM}-results.*"
else
    echo "[run-sim] WARNING: Simulation exited with code $EXIT_CODE"
    echo "[run-sim] Check log: $LOGFILE"
fi
echo "[run-sim] Finished at $(date -Iseconds)"
