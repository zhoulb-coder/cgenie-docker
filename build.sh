#!/bin/bash
set -e
echo '========================================'
echo 'Building cGENIE with Al Cycle Module'
echo '========================================'
docker build -t cgenie-al:latest .
echo ''
echo 'Build complete!'
echo 'Run interactive:  docker run -it --rm cgenie-al:latest'
echo 'Run LPIA:         docker run -v ./output:/data/output cgenie-al:latest /opt/cgenie/scripts/run-lpia.sh'
