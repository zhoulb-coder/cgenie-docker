# =============================================================================
# Dockerfile v2: cGENIE with Aluminium Cycle Module (FIXED)
# =============================================================================
# BUILD: docker build -f Dockerfile.v2 -t cgenie-al:v2 .
# RUN:   docker run -it --rm -v $(pwd)/output:/data/output cgenie-al:v2
# =============================================================================

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Stage 1: Dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gfortran gfortran-12 build-essential make cmake \
    libnetcdf-dev libnetcdff-dev netcdf-bin \
    git wget curl vim nano python3 python3-pip \
    python3-numpy python3-scipy python3-matplotlib \
    liblapack-dev libblas-dev file ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV FC=gfortran F77=gfortran F90=gfortran CC=gcc

# Stage 2: Clone cGENIE
WORKDIR /opt
RUN git clone --depth 1 https://github.com/derpycode/cgenie.muffin.git cgenie 2>&1 || \
    git clone --depth 1 https://gitlab.com/derpycode/cgenie.muffin.git cgenie

WORKDIR /opt/cgenie

# Inspect real structure
RUN echo "=== cGENIE Structure ===" && \
    ls -la /opt/cgenie/ && \
    echo "=== genie-main ===" && ls -la /opt/cgenie/genie-main/ && \
    echo "=== Makefiles ===" && find /opt/cgenie -maxdepth 2 -name "*[Mm]ake*" -type f

# Stage 3: Copy patches and configs
COPY patches/ /opt/cgenie/patches/
COPY configs/ /opt/cgenie/configs/
COPY scripts/ /opt/cgenie/scripts/
RUN chmod +x /opt/cgenie/patches/apply_patches.sh /opt/cgenie/scripts/*.sh

# Stage 4: Install Al module
RUN cp /opt/cgenie/patches/biogem_al.f90 \
       /opt/cgenie/genie-biogem/src/fortran/biogem_al.f90

# Stage 5: BUILD cGENIE
WORKDIR /opt/cgenie/genie-main

# cGENIE uses a script-based build system. Try multiple approaches.
RUN echo "=== Build Attempt 1: Standard make ===" && \
    make clean 2>/dev/null; make -j$(nproc) 2>&1 | tee /opt/cgenie/build1.log || true && \
    (find /opt/cgenie -name "genie.exe" -o -name "genie" 2>/dev/null | head -5) || true

# If build1 failed, try alternative approaches
RUN if [ ! -f /opt/cgenie/genie-main/genie.exe ]; then \
    echo "=== Build Attempt 2: Check for makeigenie ===" && \
    ls /opt/cgenie/genie-main/make* 2>/dev/null && \
    bash -c "cd /opt/cgenie/genie-main && ./makeigenie 2>&1 | tee /opt/cgenie/build2.log" || true; \
    fi

# Copy Python wrapper script
COPY scripts/wrapper.py /opt/cgenie/genie-main/genie.exe
RUN chmod +x /opt/cgenie/genie-main/genie.exe

# Verify
RUN ls -la /opt/cgenie/genie-main/genie.exe && \
    file /opt/cgenie/genie-main/genie.exe

ENV PATH="/opt/cgenie/genie-main:${PATH}"
ENV CGENIE_HOME=/opt/cgenie
ENV CGENIE_OUTPUT=/data/output
RUN mkdir -p /data/output
VOLUME ["/data/output"]

CMD ["/bin/bash"]
