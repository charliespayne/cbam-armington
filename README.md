# CBAM Armington Proof of Concept

This repository contains a minimal 2-country, 2-sector Armington /
Caliendo–Parro proof of concept.

The goal is to calibrate tariff-equivalent CBAM wedges that reproduce
upstream steel and aluminum price changes from Colmer et al., and to
use those wedges as inputs into a macro trade model.

## Model Setup
- Countries: EU, non-EU
- Sectors: Steel, Aluminum
- Demand: CES Armington
- Solution method: Exact-hat algebra with market clearing in wages

## Calibration Logic
1. Impose CBAM as a tariff-like wedge on non-EU exports into the EU.
2. Solve for equilibrium wage changes.
3. Compute EU sectoral price index changes.
4. Calibrate sector-specific wedges so model-implied price changes
   match Colmer et al. upstream estimates.

## Files
- `poc_2country_cbam.m`  
  Main script: defines the economy, applies CBAM wedges, solves the model,
  and performs calibration.

- `DEK_TRF_SYSTEM_N1.m`  
  Equilibrium system implementing the exact-hat Armington structure.

- `compute_prices.m`  
  Helper function used for sector-specific CBAM calibration.

## Notes
This is a toy proof of concept intended to validate the modeling strategy
before scaling to WIOD-based multi-country, multi-sector analysis.
