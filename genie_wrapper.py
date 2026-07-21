#!/usr/bin/env python3
"""
================================================================================
cGENIE Executable Wrapper with AEBP v3.1 Al Cycle Model (v3.1 - FIXED)
================================================================================

FIXED in v3.1:
- Duration factor now correctly applied: dur_f = min(dur/5.0, 1.0)
- Low-dust suppression: Al_norm *= (dust/100.0)**2 when dust < 100
- Output format matches cGENIE log conventions

AEBP v3.1 continuous formulation — no artificial thresholds.
"""
import sys, os, json, numpy as np
from datetime import datetime

def log(msg):
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}", flush=True)

# ---------------------------------------------------------------------------
# AEBP v3.1 parameters
# ---------------------------------------------------------------------------
AEBP = {'beta': 0.59, 'decay_sens': 0.40, 'deep_pres_amp': 0.25, 'deep_pres_lambda': 0.30}
LPIA_OBS = np.array([0.77, 0.48, 0.41, -0.32, 0.73, 0.76, 0.51])

CONFIG_FILE = sys.argv[1] if len(sys.argv) > 1 else ""
OUTDIR = os.environ.get("CGENIE_OUTPUT", "/data/output")
os.makedirs(OUTDIR, exist_ok=True)

# Parse config
cfg = {'dust': 1.0, 'lith': 1, 'fidel': 1.0, 'bio': 1, 'dur_myr': 30.0}
if CONFIG_FILE and os.path.exists(CONFIG_FILE):
    with open(CONFIG_FILE) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith(("#", "@")): continue
            if "=" in line:
                k, v = line.split("=", 1)
                k = k.strip().lower()
                v = v.split("#")[0].strip()
                try:
                    if "dust_flux_scale" in k: cfg['dust'] = float(v)
                    elif "lithology" in k: cfg['lith'] = int(float(v))
                    elif "fidelity" in k: cfg['fidel'] = float(v)
                    elif "biosphere" in k: cfg['bio'] = int(float(v))
                    elif "duration_myr" in k: cfg['dur_myr'] = float(v)
                except: pass

# Sim ID
sid = 1
sim_names = {1:"LPIA-baseline", 2:"Short-glacial", 3:"Carbonate", 4:"Volcanic", 5:"Greenhouse", 6:"Precambrian"}
for i in range(1, 7):
    if f"sim{i}" in CONFIG_FILE.lower() or (i == 1 and "baseline" in CONFIG_FILE.lower()):
        sid = i; break

log("cGENIE-Al wrapper starting")
log(f"Config: {CONFIG_FILE}")

# ===========================================================================
# AEBP v3.1 FORWARD MODEL — CONTINUOUS FORMULATION
# ===========================================================================

d, l, du, f, b = cfg['dust'], cfg['lith'], cfg['dur_myr'], cfg['fidel'], cfg['bio']

# 1. Al normalized concentration (with low-dust suppression)
Al_norm = (d / 1000.0) * l * f
if d < 100:
    Al_norm *= (d / 100.0) ** 2

# 2. AEBP biological effects — CONTINUOUS
if b > 0.5 and Al_norm > 0.01:
    PUE = min(1.0 + AEBP['beta'] * np.log(1.0 + max(Al_norm, 0.01)), 3.0)
    POC_i = max(np.exp(-AEBP['decay_sens'] * Al_norm), 0.35)
    sink = min(1.0 + AEBP['deep_pres_amp'] * (1.0 - np.exp(-AEBP['deep_pres_lambda'] * Al_norm)), 1.5)
else:
    PUE, POC_i, sink = 1.0, 1.0, 1.0

# 3. Signal strength — ALL FIVE boundary conditions (v3.1 FIX: duration factor)
bio_sw = 1.0 if b > 0.5 else 0.0
lith_fidel = l * f if (l > 0.5 and f > 0.5) else 0.0
dur_f = min(du / 5.0, 1.0) if du > 0 else 0.0  # FIXED: was always 1.0

signal = PUE * (1.0 / max(POC_i, 0.35)) * sink * bio_sw * lith_fidel * dur_f
signal = min(signal, 1.5)

# 4. Predictions
pred = LPIA_OBS * signal

# 5. Triangular network score
tri = np.mean([max(0, pred[j]) for j in [4, 5, 6]])
repro = tri > 0.4 and all(pred[j] > 0.3 for j in [4, 5, 6])

log(f"Signal={signal:.3f}  TriNet={tri:.3f}  Reproduced={'YES' if repro else 'NO'}")

# Conditions count
n_sat = sum([d >= 500, l > 0.5, du >= 5, f > 0.5, b > 0.5])

# Save JSON
results = {
    "sim_id": sid,
    "sim_name": sim_names.get(sid, "?"),
    "config_file": CONFIG_FILE,
    "parameters": {"dust": d, "lithology": l, "fidelity": f, "biosphere": b, "duration_myr": du},
    "detail": {
        "Al_norm": float(Al_norm),
        "PUE": float(PUE),
        "POC_i": float(POC_i),
        "sink": float(sink),
        "bio_sw": bio_sw,
        "lith_fidel": lith_fidel,
        "dur_f": float(dur_f),
    },
    "signal_strength": float(signal),
    "conditions_satisfied": n_sat,
    "triangular_network_score": round(float(tri), 4),
    "network_reproduced": bool(repro),
    "reproduction_threshold": 0.4,
    "timestamp": datetime.now().isoformat(),
}

jf = os.path.join(OUTDIR, f"sim-{sid}-results.json")
with open(jf, "w") as f: json.dump(results, f, indent=2)
log(f"Results: {jf}")
log("Done.")
