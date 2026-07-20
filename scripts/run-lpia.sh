#!/bin/bash
# Run LPIA baseline simulation (Sim 1)
cd /opt/cgenie/genie-main
echo '[run-lpia] Starting LPIA baseline simulation...'
./genie.exe ../configs/LPIA-Al-baseline.config 2>&1 | tee /data/output/lpia-baseline.log
echo '[run-lpia] Complete. Output: /data/output/'
