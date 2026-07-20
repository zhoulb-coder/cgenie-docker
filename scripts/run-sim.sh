#!/bin/bash
SIM=$1
if [ -z "$SIM" ]; then
  echo 'Usage: run-sim N (N=1-6)'
  exit 1
fi
cd /opt/cgenie/genie-main
CONFIGS=("" LPIA-Al-baseline LPIA-Al-sim2-short LPIA-Al-sim3-carbonate LPIA-Al-sim4-volcanic LPIA-Al-sim5-greenhouse LPIA-Al-sim6-precambrian)
CFG="${CONFIGS[$SIM]}"
echo "[run-sim] Starting simulation $SIM with config: $CFG"
./genie.exe ../configs/${CFG}.config 2>&1 | tee /data/output/sim-${SIM}.log
echo "[run-sim] Sim $SIM complete."
