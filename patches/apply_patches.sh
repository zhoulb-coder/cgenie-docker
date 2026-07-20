#!/bin/bash
# =============================================================================
# apply_patches.sh - Apply Aluminium Cycle Module patches to cGENIE
# =============================================================================
# This script modifies the cGENIE Fortran source code to add:
#   1. Dissolved aluminium tracer (io_Al)
#   2. Dust-derived Al input
#   3. AEBP biological effects (PUE, inhibition, sinking)
#   4. Diagnostic output variables
#
# Usage: cd /opt/cgenie && ./patches/apply_patches.sh
# =============================================================================

set -e  # Exit on error

echo "========================================"
echo "cGENIE Aluminium Cycle Module Patcher"
echo "========================================"
echo ""

CGENIE_ROOT=${CGENIE_ROOT:-/opt/cgenie}
PATCH_DIR="$CGENIE_ROOT/patches"

cd "$CGENIE_ROOT"

# ============================================================================
# Step 1: Register Al tracer in biogem_tracer.f90
# ============================================================================
echo "[1/6] Registering Al tracer in biogem_tracer.f90..."

BIOTRACER="$CGENIE_ROOT/genie-biogem/src/fortran/biogem_tracer.f90"

if [ -f "$BIOTRACER" ]; then
    # Backup original
    cp "$BIOTRACER" "$BIOTRACER.backup"

    # Add Al tracer index after the last io_ definition
    # We use a sed command to add the Al tracer definition
    sed -i '/^  integer,parameter::io_PO4/a \
  ! Aluminium tracer (added by AEBP module)\
  integer,parameter::io_Al = ntrac + 1' "$BIOTRACER" 2>/dev/null || \
        echo "  Note: Al tracer may already be defined or file structure differs"

    echo "  Done."
else
    echo "  WARNING: $BIOTRACER not found. Skipping tracer registration."
fi

# ============================================================================
# Step 2: Add Al to biogem_lib.f90
# ============================================================================
echo "[2/6] Adding Al variables to biogem_lib.f90..."

BIOLIB="$CGENIE_ROOT/genie-biogem/src/fortran/biogem_lib.f90"

if [ -f "$BIOLIB" ]; then
    cp "$BIOLIB" "$BIOLIB.backup"

    # Add Al to the go_rec type if it exists
    sed -i '/type go_rec/a \
  real:: Al                                ! Dissolved Al concentration\
  real:: Al_part                           ! Particulate Al concentration\
  real:: f_diss_Al                         ! Al dissolution fraction' "$BIOLIB" 2>/dev/null || \
        echo "  Note: go_rec type may have different structure"

    echo "  Done."
else
    echo "  WARNING: $BIOLIB not found. Skipping lib modification."
fi

# ============================================================================
# Step 3: Include Al module in biogem.f90
# ============================================================================
echo "[3/6] Including Al module in biogem.f90..."

BIOGEM="$CGENIE_ROOT/genie-biogem/src/fortran/biogem.f90"

if [ -f "$BIOGEM" ]; then
    cp "$BIOGEM" "$BIOGEM.backup"

    # Add use statement at the top of the module
    sed -i '/USE biogem_lib/a \
  USE biogem_al' "$BIOGEM" 2>/dev/null || \
        echo "  Note: USE biogem_al may need manual insertion"

    # Add initialization call
    sed -i '/sub_init_biogem()/a \
    call sub_init_al()' "$BIOGEM" 2>/dev/null || \
        echo "  Note: init call may need manual insertion"

    echo "  Done."
else
    echo "  WARNING: $BIOGEM not found. Skipping main module modification."
fi

# ============================================================================
# Step 4: Copy Al module source file
# ============================================================================
echo "[4/6] Installing Al module source file..."

cp "$PATCH_DIR/biogem_al.f90" \
   "$CGENIE_ROOT/genie-biogem/src/fortran/biogem_al.f90"

echo "  Done."

# ============================================================================
# Step 5: Modify Makefile to include Al module
# ============================================================================
echo "[5/6] Modifying Makefile for Al module..."

MAKEFILE="$CGENIE_ROOT/genie-main/Makefile"

if [ -f "$MAKEFILE" ]; then
    cp "$MAKEFILE" "$MAKEFILE.backup"

    # Add biogem_al.o to the object list
    sed -i 's/biogem_box.o/biogem_box.o biogem_al.o/' "$MAKEFILE" 2>/dev/null || \
        echo "  Note: Makefile may use different object list format"

    # Add compilation rule for biogem_al.f90
    cat >> "$MAKEFILE" << 'EOF'

# Aluminium cycle module (added by AEBP)
biogem_al.o: $(SRC_PATH)/fortran/biogem_al.f90
	$(F90) $(F90FLAGS) -c $(SRC_PATH)/fortran/biogem_al.f90 -o $(OBJ_PATH)/biogem_al.o
EOF

    echo "  Done."
else
    echo "  WARNING: Makefile not found. Manual compilation rule needed."
fi

# ============================================================================
# Step 6: Add Al to data save routines
# ============================================================================
echo "[6/6] Configuring Al diagnostic output..."

DIAG="$CGENIE_ROOT/genie-biogem/src/fortran/biogem_data.f90"

if [ -f "$DIAG" ]; then
    cp "$DIAG" "$DIAG.backup"

    # Add Al to output variable list
    sed -i '/ctrl_data_save_slice_ocn/ a \
    if (ctrl_data_save_slice_ocn) then\
      call sub_save_data_ijk("ocn_Al",n_i,n_j,n_k,ocn(io_Al,:,:,:))\
    end if' "$DIAG" 2>/dev/null || \
        echo "  Note: Output configuration may need manual adjustment"

    echo "  Done."
else
    echo "  WARNING: $DIAG not found. Skipping output configuration."
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "========================================"
echo "Patch application complete."
echo "========================================"
echo ""
echo "Modified files:"
echo "  - genie-biogem/src/fortran/biogem_tracer.f90"
echo "  - genie-biogem/src/fortran/biogem_lib.f90"
echo "  - genie-biogem/src/fortran/biogem.f90"
echo "  - genie-biogem/src/fortran/biogem_al.f90 (NEW)"
echo "  - genie-biogem/src/fortran/biogem_data.f90"
echo "  - genie-main/Makefile"
echo ""
echo "Next step: cd genie-main && make clean && make"
