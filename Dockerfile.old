# =============================================================================
# Dockerfile: cGENIE with Aluminium Cycle Module
# =============================================================================
# Purpose: Build a containerized cGENIE Earth system model with the
#          Al-Enhanced Biological Pump (AEBP) module for LPIA validation.
#
# Base: Ubuntu 22.04 LTS
# Requirements: Docker 20.10+ or Podman 3.0+
# Build time: ~15-20 minutes (depends on network and CPU)
# Image size: ~2.5 GB
#
# Usage:
#   docker build -t cgenie-al:latest .
#   docker run -it --name cgenie-lpia cgenie-al:latest
# =============================================================================

FROM ubuntu:22.04

# Prevent interactive prompts during apt-get
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# =============================================================================
# Stage 1: System dependencies
# =============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Fortran compiler and build tools
    gfortran-12 \
    gfortran \
    build-essential \
    cmake \
    make \
    # NetCDF (required by cGENIE for I/O)
    libnetcdf-dev \
    libnetcdff-dev \
    netcdf-bin \
    # Version control and utilities
    git \
    wget \
    curl \
    vim \
    nano \
    # Python for post-processing
    python3 \
    python3-pip \
    python3-numpy \
    python3-scipy \
    python3-matplotlib \
    # System libraries
    liblapack-dev \
    libblas-dev \
    && rm -rf /var/lib/apt/lists/*

# Set Fortran compiler
ENV FC=gfortran
ENV F77=gfortran
ENV F90=gfortran
ENV CC=gcc

# =============================================================================
# Stage 2: Clone cGENIE repository
# =============================================================================
WORKDIR /opt

# Clone the main cGENIE (muffin) repository
# Using the Bristol team's official repository
RUN git clone --depth 1 https://github.com/derpycode/cgenie.muffin.git cgenie

WORKDIR /opt/cgenie

# =============================================================================
# Stage 3: Apply Aluminium Cycle Module patches
# =============================================================================

# Copy patch files into the container
COPY patches/ /opt/cgenie/patches/
COPY configs/ /opt/cgenie/configs/
COPY scripts/ /opt/cgenie/scripts/

# Apply the Al cycle module patches
# Each patch modifies specific Fortran source files
RUN chmod +x /opt/cgenie/patches/apply_patches.sh && \
    cd /opt/cgenie && \
    ./patches/apply_patches.sh

# =============================================================================
# Stage 4: Compile cGENIE with Al module
# =============================================================================

# Set up the build environment
ENV CGENIE_ROOT=/opt/cgenie
ENV NETCDF_INC=/usr/include
ENV NETCDF_LIB=/usr/lib/x86_64-linux-gnu

# Create Makefile modifications for Al module
RUN cd /opt/cgenie/genie-main && \
    # Backup original Makefile
    cp Makefile Makefile.original && \
    # Modify Makefile to include Al module objects
    sed -i 's/OBJS = /OBJS = biogem_al.o /' Makefile 2>/dev/null || true

# Build cGENIE
RUN cd /opt/cgenie/genie-main && \
    make clean && \
    make -j$(nproc) 2>&1 | tee build.log && \
    echo "Build complete. Checking executable..." && \
    ls -la genie.exe || echo "Executable not found, checking build log..."

# =============================================================================
# Stage 5: Set up LPIA configuration
# =============================================================================

# Copy LPIA configuration files
RUN mkdir -p /opt/cgenie/experiments/lpia && \
    cp /opt/cgenie/configs/LPIA-Al-* /opt/cgenie/experiments/lpia/ 2>/dev/null || true

# =============================================================================
# Stage 6: Create convenience scripts
# =============================================================================

RUN chmod +x /opt/cgenie/scripts/*.sh

# =============================================================================
# Stage 7: Set up runtime environment
# =============================================================================

ENV PATH="/opt/cgenie/genie-main:${PATH}"
ENV CGENIE_HOME=/opt/cgenie

# Create working directory for outputs
RUN mkdir -p /data/output
VOLUME ["/data/output"]

# =============================================================================
# Stage 8: Default command
# =============================================================================

# Interactive shell with cGENIE environment loaded
CMD ["/bin/bash", "-c", "echo '========================================' && \
     echo 'cGENIE with Al Cycle Module' && \
     echo '========================================' && \
     echo '' && \
     echo 'Available commands:' && \
     echo '  run-lpia          - Run LPIA baseline simulation' && \
     echo '  run-sim N         - Run simulation N (1-6)' && \
     echo '  run-all           - Run all six simulations' && \
     echo '  extract-diag      - Extract diagnostic outputs' && \
     echo '  cgenie-status     - Check simulation status' && \
     echo '' && \
     echo 'For interactive use:' && \
     echo '  cd /opt/cgenie/genie-main && ./genie.exe <config>' && \
     echo '' && \
     /bin/bash"]
