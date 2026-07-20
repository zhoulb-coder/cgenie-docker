#!/bin/bash
echo '=== cGENIE Status ==='
ps aux | grep genie.exe | grep -v grep || echo 'No running simulations'
echo ''
echo '=== Output files ==='
ls -la /data/output/ 2>/dev/null
