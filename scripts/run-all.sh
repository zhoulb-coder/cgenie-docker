#!/bin/bash
for i in 1 2 3 4 5 6; do
  echo "========================================"
  echo "Running simulation $i/6"
  /opt/cgenie/scripts/run-sim.sh $i
done
echo 'All simulations complete!'
