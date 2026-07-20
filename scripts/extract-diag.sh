#!/bin/bash
OUTDIR=/data/output
echo '[extract-diag] Extracting diagnostics...'
ls -la $OUTDIR/*.nc 2>/dev/null || echo 'No NetCDF files yet'
echo '[extract-diag] Done.'
