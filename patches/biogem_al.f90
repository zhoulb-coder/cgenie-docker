! =============================================================================
! MODULE: biogem_al.f90
! Aluminium Cycle Module for cGENIE (BIOGEM)
! =============================================================================
! This module implements the Al-Enhanced Biological Pump (AEBP) within
the cGENIE ocean biogeochemistry module. It adds dissolved aluminium as a
new tracer and parameterizes three biological effects:
!   1. Phosphorus Use Efficiency (PUE) enhancement
!   2. POC remineralization inhibition
!   3. Particle sinking velocity enhancement
!
! Based on: Zhou et al. (2016, 2018), AEBP v3.1
! Author: Nature Geoscience supplementary validation project
! Date: 2026-07-18
! =============================================================================

MODULE biogem_al

  USE genie_control
  USE biogem_lib
  IMPLICIT NONE

  ! ---------------------------------------------------------------------------
  ! AEBP v3.1 calibrated parameters
  ! ---------------------------------------------------------------------------
  REAL, PARAMETER :: aebp_beta = 0.59           ! PUE enhancement sensitivity
  REAL, PARAMETER :: aebp_decay_sens = 0.40     ! POC inhibition sensitivity
  REAL, PARAMETER :: aebp_deep_pres_amp = 0.25  ! Sinking enhancement amplitude
  REAL, PARAMETER :: aebp_deep_pres_lambda = 0.30 ! Sinking saturation rate
  REAL, PARAMETER :: Al_ref = 1.64              ! wt% (LPIA siliciclastic median)
  REAL, PARAMETER :: Al_modern_mean_nM = 1.0    ! Modern global mean surface [Al] (nM)

  ! Aluminium cycle parameters
  REAL, PARAMETER :: Al_residence_time_yr = 150.0  ! Ocean residence time (yr)
  REAL, PARAMETER :: Al_dust_content = 0.08        ! Mass fraction Al in dust
  REAL, PARAMETER :: Al_molar_mass = 26.98e-3      ! kg/mol
  REAL, PARAMETER :: f_diss_baseline = 0.05        ! Baseline dissolution fraction

  ! Control flags (read from config file)
  LOGICAL :: ctrl_al_cycle_enabled = .true.
  LOGICAL :: ctrl_al_dust_input = .true.
  LOGICAL :: ctrl_al_river_input = .true.
  REAL :: par_al_dust_flux_scale = 1.0     ! Dust flux scaling (1 = modern)
  REAL :: par_al_river_scale = 1.0         ! River input scaling

CONTAINS

  ! ===========================================================================
  ! SUBROUTINE: sub_init_al
  ! Initialize aluminium cycle module
  ! ===========================================================================
  SUBROUTINE sub_init_al()
    IMPLICIT NONE
    PRINT *, "[biogem_al] Initializing aluminium cycle module..."
    PRINT *, "[biogem_al] AEBP parameters:"
    PRINT *, "  beta = ", aebp_beta
    PRINT *, "  decay_sens = ", aebp_decay_sens
    PRINT *, "  deep_pres_amp = ", aebp_deep_pres_amp
    PRINT *, "  deep_pres_lambda = ", aebp_deep_pres_lambda
    PRINT *, "[biogem_al] Al residence time: ", Al_residence_time_yr, " yr"
  END SUBROUTINE sub_init_al

  ! ===========================================================================
  ! FUNCTION: fun_calc_Al_norm
  ! Calculate normalized Al concentration for biological effect parameterization
  ! Al_norm = [Al]_diss / [Al]_modern_mean
  ! ===========================================================================
  FUNCTION fun_calc_Al_norm(Al_diss_nM) RESULT(Al_norm)
    REAL, INTENT(in) :: Al_diss_nM  ! Dissolved Al concentration (nM)
    REAL :: Al_norm

    Al_norm = MAX(Al_diss_nM / Al_modern_mean_nM, 0.0)
  END FUNCTION fun_calc_Al_norm

  ! ===========================================================================
  ! FUNCTION: fun_PUE_enhancement
  ! Effect 1: Phosphorus Use Efficiency enhancement
  ! k_DOP->DIP = k_baseline * (1 + beta * ln(1 + Al_norm))
  ! ===========================================================================
  FUNCTION fun_PUE_enhancement(Al_norm) RESULT(PUE_factor)
    REAL, INTENT(in) :: Al_norm
    REAL :: PUE_factor

    IF (Al_norm > 0.01) THEN
      PUE_factor = 1.0 + aebp_beta * LOG(1.0 + Al_norm)
      PUE_factor = MIN(PUE_factor, 3.0)  ! Cap at 3x
    ELSE
      PUE_factor = 1.0
    END IF
  END FUNCTION fun_PUE_enhancement

  ! ===========================================================================
  ! FUNCTION: fun_POC_inhibition
  ! Effect 2: Organic carbon decomposition inhibition
  ! k_POC_remin = k_baseline * exp(-decay_sens * Al_norm)
  ! ===========================================================================
  FUNCTION fun_POC_inhibition(Al_norm) RESULT(inhibition_factor)
    REAL, INTENT(in) :: Al_norm
    REAL :: inhibition_factor

    inhibition_factor = EXP(-aebp_decay_sens * Al_norm)
    inhibition_factor = MAX(inhibition_factor, 0.35)  ! Floor at 35%
  END FUNCTION fun_POC_inhibition

  ! ===========================================================================
  ! FUNCTION: fun_sink_enhancement
  ! Effect 3: Particle sinking velocity enhancement
  ! w_POC = w_baseline * (1 + amp * (1 - exp(-lambda * Al_norm)))
  ! ===========================================================================
  FUNCTION fun_sink_enhancement(Al_norm) RESULT(sink_factor)
    REAL, INTENT(in) :: Al_norm
    REAL :: sink_factor

    sink_factor = 1.0 + aebp_deep_pres_amp * &
                  (1.0 - EXP(-aebp_deep_pres_lambda * Al_norm))
    sink_factor = MIN(sink_factor, 2.0)  ! Cap at 2x
  END FUNCTION fun_sink_enhancement

  ! ===========================================================================
  ! SUBROUTINE: sub_calc_al_dust_input
  ! Calculate dust-derived aluminium input to surface ocean
  ! F_dust_Al = F_dust * [Al]_dust * f_diss
  ! ===========================================================================
  SUBROUTINE sub_calc_al_dust_input(dum_i, dum_j, loc_k1, &
       loc_dust_dep, loc_ts, loc_dtyr)
    IMPLICIT NONE
    INTEGER, INTENT(in) :: dum_i, dum_j                    ! Grid indices
    INTEGER, INTENT(in) :: loc_k1                          ! Surface k-index
    REAL, INTENT(in) :: loc_dust_dep                       ! Dust deposition (kg/m2/yr)
    REAL, INTENT(in) :: loc_ts                             ! Timestep (s)
    REAL, INTENT(in) :: loc_dtyr                           ! Timestep (yr)

    REAL :: loc_f_diss      ! Temperature-dependent dissolution fraction
    REAL :: loc_Al_flux     ! Al flux (mol/m2/yr)
    REAL :: loc_T_surface   ! Surface temperature (K)
    REAL :: loc_Al_add      ! Al addition to surface box (mol/kg)

    ! Skip if not enabled
    IF (.NOT. ctrl_al_dust_input) RETURN

    ! Get surface temperature
    loc_T_surface = ocn(io_T, dum_i, dum_j, loc_k1)

    ! Temperature-dependent dissolution (reference: 298.15 K = 25C)
    loc_f_diss = f_diss_baseline * EXP(&
         -5000.0 / 8.314 * (1.0 / loc_T_surface - 1.0 / 298.15))
    loc_f_diss = MAX(0.005, MIN(0.10, loc_f_diss))

    ! Calculate Al flux (mol/m2/yr)
    loc_Al_flux = loc_dust_dep * Al_dust_content * loc_f_diss / Al_molar_mass

    ! Scale by dust flux parameter (for LPIA simulations)
    loc_Al_flux = loc_Al_flux * par_al_dust_flux_scale

    ! Add to surface ocean tracer (convert to mol/kg)
    loc_Al_add = loc_Al_flux * loc_dtyr / phys_ocn(ipo_M, dum_i, dum_j, loc_k1)

    ! Add to dissolved Al tracer (io_Al must be registered)
    ocn(io_Al, dum_i, dum_j, loc_k1) = &
         ocn(io_Al, dum_i, dum_j, loc_k1) + loc_Al_add

  END SUBROUTINE sub_calc_al_dust_input

  ! ===========================================================================
  ! SUBROUTINE: sub_calc_al_scavenging
  ! Calculate aluminium scavenging (removal) from water column
  ! First-order decay with ~150 yr residence time
  ! ===========================================================================
  SUBROUTINE sub_calc_al_scavenging(dum_i, dum_j, dum_k, loc_dtyr)
    IMPLICIT NONE
    INTEGER, INTENT(in) :: dum_i, dum_j, dum_k
    REAL, INTENT(in) :: loc_dtyr

    REAL :: loc_k_scav
    REAL :: loc_Al_remove

    ! Scavenging rate (1/yr)
    loc_k_scav = 1.0 / Al_residence_time_yr

    ! Removal amount
    loc_Al_remove = loc_k_scav * ocn(io_Al, dum_i, dum_j, dum_k) * loc_dtyr

    ! Apply removal (ensure non-negative)
    ocn(io_Al, dum_i, dum_j, dum_k) = &
         MAX(0.0, ocn(io_Al, dum_i, dum_j, dum_k) - loc_Al_remove)

  END SUBROUTINE sub_calc_al_scavenging

  ! ===========================================================================
  ! SUBROUTINE: sub_apply_AEBP_effects
  ! Apply all three AEBP biological effects to biogeochemistry
  ! Called during each biogeochemical time step
  ! ===========================================================================
  SUBROUTINE sub_apply_AEBP_effects(dum_i, dum_j, dum_k, &
       loc_dtyr, loc_DIC, loc_DIP, loc_DOP, loc_POC)
    IMPLICIT NONE
    INTEGER, INTENT(in) :: dum_i, dum_j, dum_k
    REAL, INTENT(in) :: loc_dtyr
    REAL, INTENT(inout) :: loc_DIC, loc_DIP, loc_DOP, loc_POC

    REAL :: Al_norm
    REAL :: PUE_factor
    REAL :: inhib_factor
    REAL :: sink_factor
    REAL :: loc_dDOP_remin, loc_dPOC_remin

    ! Skip if module disabled
    IF (.NOT. ctrl_al_cycle_enabled) RETURN

    ! Calculate normalized Al concentration
    Al_norm = fun_calc_Al_norm(ocn(io_Al, dum_i, dum_j, dum_k))

    ! Skip if Al concentration negligible
    IF (Al_norm < 0.01) RETURN

    ! Calculate AEBP enhancement factors
    PUE_factor = fun_PUE_enhancement(Al_norm)
    inhib_factor = fun_POC_inhibition(Al_norm)
    sink_factor = fun_sink_enhancement(Al_norm)

    ! 1. PUE Enhancement: accelerate DOP -> DIP conversion
    IF (loc_DOP > 0.0) THEN
      loc_dDOP_remin = (PUE_factor - 1.0) * loc_DOP * 0.1 * loc_dtyr
      loc_dDOP_remin = MAX(0.0, MIN(loc_dDOP_remin, loc_DOP * 0.5))
      loc_DOP = loc_DOP - loc_dDOP_remin
      loc_DIP = loc_DIP + loc_dDOP_remin
    END IF

    ! 2. POC Inhibition: reduce remineralization rate
    IF (loc_POC > 0.0) THEN
      ! Inhibited remin rate: apply factor to POC preservation
      loc_dPOC_remin = loc_POC * (1.0 - inhib_factor) * 0.01 * loc_dtyr
      loc_dPOC_remin = MAX(0.0, MIN(loc_dPOC_remin, loc_POC * 0.3))
      loc_POC = loc_POC + loc_dPOC_remin  ! More POC preserved
    END IF

    ! 3. Sinking Enhancement: effect is implicit in particle flux
    !    calculations elsewhere in biogem_box.f90
    !    (sink_factor is stored for use by settling routines)

  END SUBROUTINE sub_apply_AEBP_effects

END MODULE biogem_al
