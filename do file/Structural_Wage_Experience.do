/*==============================================================================
STRUCTURAL_WAGE_EXPERIENCE.DO
================================================================================
Purpose: Estimate structural return to cumulative hours (γ) across career stages
         and recover implied information asymmetry parameter δ.

Framework: Sztutman (2024) length-of-resume model, Pareto case:
    log(w_it) = α_i + γ·log(cumhrs_it) + β·X_it + u_it
    where γ = δ / (1 − δ + ε)   →   δ = γ(1 + ε) / (1 + γ)

KEY TESTS:
  1. Is γ constant across career stages? (Pareto case → constant τ_p)
     Reject → history-dependent labor wedge → general dynamic model
  2. Is γ_OLS > γ_FE? (between-person selection > within-person accumulation)
     Large gap → signaling dominates; small gap → human capital dominates
  3. Is δ ∈ (0,1)? (model consistent with data)

SCRUTINY CHECKPOINTS:
  - γ_FE must be positive and significant
  - γ_OLS should exceed γ_FE (upward selection bias)
  - γ should not increase with career stage (that would contradict model)
  - δ must be in (0,1); values outside signal model misfit or bad ETI

INPUT:  data\nlsy_long_pre_taxsim.dta
        output\two_period_summary.dta  (for ETI estimate; optional)
OUTPUT: output\Phase1_Table1_GammaByStage.rtf
        output\Phase1_Table2_OLSvsFE.rtf
        output\Phase1_Table3_Structural.rtf
        output\Phase1_Fig1_GammaProfile.png
        output\Phase1_Fig2_SelectionDecomp.png
        output\Structural_Wage_Experience_log.txt

Author: [Research team]
Date:   2026-04-10
Version 1.0
==============================================================================*/

clear all
set more off
capture log close _all

global projdir "D:\Stata Data\labor_signaling_project"
global datadir "${projdir}\data"
global outdir  "${projdir}\output"

log using "${outdir}\Structural_Wage_Experience_log.txt", replace text

di ""
di "=============================================================================="
di "STRUCTURAL WAGE-EXPERIENCE ANALYSIS (PHASE 1)"
di "=============================================================================="
di "Framework: Sztutman (2024) Dynamic Signaling — Pareto Case"
di "γ = δ/(1−δ+ε)   →   Test: Is γ constant across career stages?"
di "Start time: $S_DATE $S_TIME"
di ""

/*==============================================================================
PART 0: DATA LOADING AND VERIFICATION
==============================================================================*/

di "=============================================================================="
di "PART 0: DATA LOADING AND VERIFICATION"
di "=============================================================================="

use "${datadir}\nlsy_long_pre_taxsim.dta", clear
di "Loaded nlsy_long_pre_taxsim.dta: " _N " observations"

*--- Required variable checks ---
local required_vars pwages cumhrs pot_exp pot_exp2 afqt_std educ_years year taxsimid page
foreach v of local required_vars {
    capture confirm variable `v'
    if _rc != 0 {
        di as error "ERROR: Variable `v' not found. Run Data_process.do first."
        log close
        error 111
    }
}
di "All required variables confirmed."

*--- Create derived variables ---
capture drop log_pwages
gen log_pwages = ln(pwages) if pwages > 0
label var log_pwages "Log primary wages"

capture drop log_cumhrs
gen log_cumhrs = ln(cumhrs) if cumhrs > 0
label var log_cumhrs "Log cumulative hours worked"

*--- Analysis sample ---
* Mirrors Skill_vs_Signal_Analysis.do sample definition
capture drop phase1_sample
gen phase1_sample = (pwages > 0         ///
                   & cumhrs > 0         ///
                   & !missing(pot_exp)  ///
                   & pot_exp >= 0       ///
                   & pot_exp <= 40      ///
                   & !missing(afqt_std) ///
                   & page >= 18         ///
                   & page <= 65)
label var phase1_sample "Sample for Phase 1 structural analysis"

di ""
di "Analysis sample definition:"
di "  - pwages > 0"
di "  - cumhrs > 0 (valid cumulative hours for log transform)"
di "  - pot_exp 0–40"
di "  - Non-missing afqt_std"
di "  - Age 18–65"
tab phase1_sample
di ""

* Summary stats on sample
di "Sample summary statistics:"
tabstat pwages cumhrs pot_exp afqt_std if phase1_sample == 1, ///
    stat(n mean sd p10 p50 p90) col(stat)

* Check cumhrs monotonicity within person (sanity check)
di ""
di "SCRUTINY: Checking cumhrs monotonicity within person..."
bysort taxsimid (year): gen cumhrs_drop = (cumhrs < cumhrs[_n-1]) ///
    if _n > 1 & !missing(cumhrs) & !missing(cumhrs[_n-1])
count if cumhrs_drop == 1
local n_drops = r(N)
if `n_drops' > 0 {
    di "WARNING: `n_drops' person-years where cumhrs falls — check interpolation"
}
else {
    di "GOOD: cumhrs is monotonically non-decreasing within every person"
}
drop cumhrs_drop

/*==============================================================================
PART 1: CAREER-STAGE γ PROFILES
================================================================================
Test of the Pareto case: γ should be constant across career stages if the model
is Pareto. Declining γ → employer learning completing (general dynamic model).
Rising γ → inconsistent with signaling framework; would suggest human capital
accumulation accelerating (unusual).
==============================================================================*/

di ""
di "=============================================================================="
di "PART 1: CAREER-STAGE γ PROFILES"
di "=============================================================================="
di ""
di "THEORY: Under Pareto length-of-resume model, γ is constant across career."
di "        γ declining → learning completing (history-dependent χ)"
di "        γ constant  → Pareto case (constant Pigouvian tax τ_p = δ/α)"
di ""

*--- 1.1: Define career stages by potential experience quintile ---
di "1.1 DEFINE CAREER STAGES"
di "------------------------"

* Use xtile on the working sample
capture drop exp_quintile
xtile exp_quintile = pot_exp if phase1_sample == 1, nq(5)

* Report quintile boundaries
di ""
di "Career stage boundaries (experience quintiles):"
tabstat pot_exp if phase1_sample == 1, by(exp_quintile) stat(min max n) ///
    nototal col(stat)

label define exp_q_lbl ///
    1 "Q1: Early (0-5yr)" ///
    2 "Q2 (6-9yr)"        ///
    3 "Q3 (10-14yr)"      ///
    4 "Q4 (15-20yr)"      ///
    5 "Q5: Late (21+yr)"
label values exp_quintile exp_q_lbl

*--- 1.2: Set panel structure ---
xtset taxsimid year

*--- 1.3: FE regression of log_pwages on log_cumhrs by career stage ---
di ""
di "1.2 WITHIN-PERSON (FE) γ ESTIMATES BY CAREER STAGE"
di "---------------------------------------------------"
di ""
di "Specification: xtreg log_pwages log_cumhrs pot_exp pot_exp2 i.year, fe"
di ""

forvalues q = 1/5 {
    qui count if phase1_sample == 1 & exp_quintile == `q'
    di "--- Career Stage Q`q' (N = `r(N)') ---"

    xtreg log_pwages log_cumhrs pot_exp pot_exp2 i.year ///
        if phase1_sample == 1 & exp_quintile == `q', fe cluster(taxsimid)
    est store fe_gamma_q`q'

    local g`q' = _b[log_cumhrs]
    local se`q' = _se[log_cumhrs]
    local t`q' = `g`q'' / `se`q''
    di "  γ = " %7.4f `g`q'' "  SE = " %6.4f `se`q'' "  t = " %5.2f `t`q''
    di ""
}

*--- 1.4: Full-sample FE estimate ---
di "--- FULL CAREER (all stages combined) ---"
xtreg log_pwages log_cumhrs pot_exp pot_exp2 i.year ///
    if phase1_sample == 1, fe cluster(taxsimid)
est store fe_gamma_full

local gamma_fe_full = _b[log_cumhrs]
local se_fe_full    = _se[log_cumhrs]
di "  γ_full = " %7.4f `gamma_fe_full' "  SE = " %6.4f `se_fe_full'
di ""

*--- 1.5: Wald test of γ equality across career stages ---
di ""
di "1.3 WALD TEST: IS γ CONSTANT ACROSS CAREER STAGES?"
di "---------------------------------------------------"
di "H0: γ_Q1 = γ_Q2 = γ_Q3 = γ_Q4 = γ_Q5 (Pareto case)"
di ""

* Career-stage interacted specification using factor variable notation
* Each quintile gets its own γ coefficient: i.exp_quintile#c.log_cumhrs
* i.exp_quintile provides intercept shifters (absorbed by FE but needed for test)
xtreg log_pwages i.exp_quintile#c.log_cumhrs i.exp_quintile ///
    pot_exp pot_exp2 i.year ///
    if phase1_sample == 1, fe cluster(taxsimid)
est store fe_gamma_interacted

di ""
di "Stage-interacted coefficients on log_cumhrs:"
di "  Q1 (Early):  " %7.4f _b[1.exp_quintile#c.log_cumhrs]
di "  Q2:          " %7.4f _b[2.exp_quintile#c.log_cumhrs]
di "  Q3:          " %7.4f _b[3.exp_quintile#c.log_cumhrs]
di "  Q4:          " %7.4f _b[4.exp_quintile#c.log_cumhrs]
di "  Q5 (Late):   " %7.4f _b[5.exp_quintile#c.log_cumhrs]

* Formal test: all stage-specific γ equal (H0: Pareto case, γ constant)
test (2.exp_quintile#c.log_cumhrs = 1.exp_quintile#c.log_cumhrs) ///
     (3.exp_quintile#c.log_cumhrs = 1.exp_quintile#c.log_cumhrs) ///
     (4.exp_quintile#c.log_cumhrs = 1.exp_quintile#c.log_cumhrs) ///
     (5.exp_quintile#c.log_cumhrs = 1.exp_quintile#c.log_cumhrs)

local wald_F = r(F)
local wald_p = r(p)

di ""
di "============================================================"
di "WALD TEST RESULT: γ equality across career stages"
di "  F-statistic: " %8.3f `wald_F'
di "  p-value:     " %8.4f `wald_p'
di ""

if `wald_p' < 0.05 {
    di "RESULT: REJECT γ equality (p < 0.05)"
    di "  γ varies across career stages — history-dependent wedge χ(h)"
    di "  Implication: Pigouvian tax should be history-dependent"
    di "  Use: general dynamic Sztutman model (not just Pareto special case)"
}
else if `wald_p' < 0.10 {
    di "RESULT: MARGINAL REJECTION (0.05 < p < 0.10)"
    di "  Weak evidence against constant γ — borderline Pareto case"
}
else {
    di "RESULT: FAIL TO REJECT γ equality (p ≥ 0.10)"
    di "  Consistent with PARETO CASE: constant γ across career"
    di "  Implication: Pigouvian tax τ_p = δ/α is constant and history-independent"
}
di "============================================================"

*--- 1.6: Monotonicity check ---
di ""
di "1.4 MONOTONICITY SCRUTINY"
di "-------------------------"
di "PREDICTION: γ should weakly decline (employer learning completes over career)"
di ""

local prev_g = `g1'
local monotone = 1
forvalues q = 2/5 {
    if `g`q'' > `prev_g' + 2*`se`q'' {
        local monotone = 0
        di "NOTE: γ rises from Q`=`q'-1' (" %5.3f `prev_g' ") to Q`q' (" %5.3f `g`q'' ")"
        di "      This is INCONSISTENT with learning-completion interpretation"
    }
    local prev_g = `g`q''
}

if `monotone' == 1 {
    di "GOOD: γ is weakly decreasing across career stages"
    di "      Consistent with employer learning completing over time"
}

*--- 1.7: Store γ profile for graphing ---
di ""
di "1.5 γ PROFILE SUMMARY"
di "---------------------"
di ""
di "Stage    γ_FE       SE        t-stat"
di "-------- ---------- --------- ------"
forvalues q = 1/5 {
    di "Q`q'      " %8.4f `g`q'' "   " %7.4f `se`q'' "   " %5.2f `t`q''
}
di "Full     " %8.4f `gamma_fe_full' "   " %7.4f `se_fe_full'

/*==============================================================================
PART 2: OLS vs FE DECOMPOSITION
================================================================================
The gap γ_OLS − γ_FE identifies the share of the return to cumhrs that is
between-person selection vs. within-person learning-by-doing.

In Sztutman's framework:
- γ_FE = causal effect of hours accumulation on wage (within-person)
- γ_OLS = γ_FE + selection bias (high-ability workers work more)
- Large gap → signaling/selection matters; small gap → human capital dominates
==============================================================================*/

di ""
di "=============================================================================="
di "PART 2: OLS vs FE DECOMPOSITION (BETWEEN- vs WITHIN-PERSON)"
di "=============================================================================="
di ""
di "THEORY: γ_OLS = γ_FE + selection bias"
di "  Large gap: High-ability workers work more AND earn more (signaling selection)"
di "  Small gap: Experience effect is mostly causal (human capital)"
di ""

*--- 2.1: OLS (cross-sectional + between variation, includes selection) ---
di "2.1 OLS ESTIMATE (with AFQT to absorb observed ability)"
di "------------------------------------------------------"

regress log_pwages log_cumhrs pot_exp pot_exp2 educ_years afqt_std i.year ///
    if phase1_sample == 1, cluster(taxsimid)
est store ols_gamma

local gamma_ols = _b[log_cumhrs]
local se_ols    = _se[log_cumhrs]
di "  γ_OLS (with AFQT) = " %7.4f `gamma_ols' "  SE = " %6.4f `se_ols'

*--- 2.2: OLS without AFQT (selection fully uncontrolled) ---
di ""
di "2.2 OLS ESTIMATE (without AFQT — raw selection)"
di "------------------------------------------------"

regress log_pwages log_cumhrs pot_exp pot_exp2 educ_years i.year ///
    if phase1_sample == 1, cluster(taxsimid)
est store ols_gamma_noafqt

local gamma_ols_noafqt = _b[log_cumhrs]
di "  γ_OLS (no AFQT)   = " %7.4f `gamma_ols_noafqt' "  SE = " %6.4f _se[log_cumhrs]

*--- 2.3: FE estimate (within-person, all time-invariant selection removed) ---
di ""
di "2.3 FE ESTIMATE (within-person, all selection removed)"
di "------------------------------------------------------"

xtreg log_pwages log_cumhrs pot_exp pot_exp2 i.year ///
    if phase1_sample == 1, fe cluster(taxsimid)
est store fe_gamma_full2

* Should equal fe_gamma_full from Part 1
di "  γ_FE               = " %7.4f `gamma_fe_full' " (from Part 1)"
di "  [Re-estimated here: " %7.4f _b[log_cumhrs] "]"

*--- 2.4: Selection decomposition ---
di ""
di "2.4 SELECTION DECOMPOSITION"
di "---------------------------"

local selection_raw  = `gamma_ols_noafqt' - `gamma_fe_full'
local selection_obs  = `gamma_ols' - `gamma_fe_full'       // observable selection
local selection_unobs = `gamma_ols_noafqt' - `gamma_ols'   // unobservable (removed by AFQT)
local fe_share = `gamma_fe_full' / `gamma_ols_noafqt'

di ""
di "============================================================"
di "SELECTION DECOMPOSITION RESULTS"
di "============================================================"
di ""
di "  γ_OLS (no AFQT):     " %7.4f `gamma_ols_noafqt'
di "  γ_OLS (with AFQT):   " %7.4f `gamma_ols'
di "  γ_FE:                " %7.4f `gamma_fe_full'
di ""
di "  Total selection bias:           " %7.4f `selection_raw'
di "    - Observable (absorbed AFQT): " %7.4f `selection_unobs'
di "    - Residual (unobserved):      " %7.4f `selection_obs'
di ""
di "  Within-person share (γ_FE / γ_OLS): " %5.1f `fe_share'*100 "%"
di ""

if `fe_share' > 0.7 {
    di "RESULT: γ is primarily WITHIN-PERSON accumulation"
    di "  Returns to cumhrs are mostly causal — learning-by-doing dominates"
}
else if `fe_share' < 0.4 {
    di "RESULT: γ is primarily BETWEEN-PERSON selection"
    di "  High-ability workers work more; signaling/selection dominates"
    di "  The return to cumhrs in cross-section is largely spurious"
}
else {
    di "RESULT: MIXED — both within-person and selection channels matter"
    di "  " %4.1f `fe_share'*100 "% is causal; " %4.1f (1-`fe_share')*100 "% is selection"
}
di "============================================================"

*--- 2.5: Career-stage OLS vs FE comparison ---
di ""
di "2.5 SELECTION BY CAREER STAGE"
di "-----------------------------"
di "Does selection bias decrease as career progresses?"
di "(Prediction: Yes, if employer learning means later-career OLS ≈ FE)"
di ""

forvalues q = 1/5 {
    qui regress log_pwages log_cumhrs pot_exp pot_exp2 educ_years i.year ///
        if phase1_sample == 1 & exp_quintile == `q', cluster(taxsimid)
    local ols_q`q' = _b[log_cumhrs]

    local selection_q`q' = `ols_q`q'' - `g`q''
    local fe_share_q`q' = `g`q'' / `ols_q`q''

    di "Q`q': OLS=" %6.3f `ols_q`q'' "  FE=" %6.3f `g`q'' ///
        "  Selection=" %6.3f `selection_q`q'' ///
        "  FE-share=" %4.1f `fe_share_q`q''*100 "%"
}

/*==============================================================================
PART 3: STRUCTURAL PARAMETER RECOVERY
================================================================================
From Sztutman (2024) Pareto case: γ = δ / (1 − δ + ε)
Solving for δ: δ = γ(1 + ε) / (1 + γ)

Where:
  γ = FE coefficient on log_cumhrs (from Part 1)
  ε = labor supply elasticity (proxied by ETI from Two_Period_Analysis.do)

NOTE: ETI measures elasticity of taxable income (extensive + intensive margins).
      Using ETI as ε overstates the intensive margin. The δ estimate below
      should be treated as an upper bound; a pure intensive-margin ETI would
      give a lower δ. Report range: δ using annual ETI, biennial ETI.
==============================================================================*/

di ""
di "=============================================================================="
di "PART 3: STRUCTURAL PARAMETER RECOVERY"
di "=============================================================================="
di ""
di "Formula: δ = γ(1 + ε) / (1 + γ)"
di "Where γ = γ_FE (full career), ε = ETI from Two_Period_Analysis"
di ""

*--- 3.1: Load ETI estimates ---
capture confirm file "${outdir}\two_period_summary.dta"
if _rc == 0 {
    preserve
    use "${outdir}\two_period_summary.dta", clear
    qui sum ETI if strpos(period, "Annual") > 0
    global eti_annual  = r(mean)
    qui sum ETI if strpos(period, "Biennial") > 0
    global eti_biennial = r(mean)
    restore
    di "ETI loaded from two_period_summary.dta:"
    di "  Annual ETI:   " %7.4f $eti_annual
    di "  Biennial ETI: " %7.4f $eti_biennial
}
else {
    di "WARNING: two_period_summary.dta not found."
    di "  Run Two_Period_Analysis.do first for precise ETI."
    di "  Using placeholder ε = 0.4 (midpoint of typical ETI literature range)"
    global eti_annual  = 0.4
    global eti_biennial = 0.4
}

*--- 3.2: Compute δ for each ETI ---
local eti_a = $eti_annual
local eti_b = $eti_biennial

* Using full-career γ_FE
local delta_annual   = `gamma_fe_full' * (1 + `eti_a') / (1 + `gamma_fe_full')
local delta_biennial = `gamma_fe_full' * (1 + `eti_b') / (1 + `gamma_fe_full')
local delta_mid = (`delta_annual' + `delta_biennial') / 2

* Using early-career γ (Q1)
local delta_early = `g1' * (1 + `eti_a') / (1 + `g1')

* Using late-career γ (Q5)
local delta_late  = `g5' * (1 + `eti_a') / (1 + `g5')

di ""
di "============================================================"
di "STRUCTURAL PARAMETER RESULTS"
di "============================================================"
di ""
di "  γ_FE (full career):       " %7.4f `gamma_fe_full'
di ""
di "  Using Annual ETI (ε = " %5.3f `eti_a' "):"
di "    δ (full career):        " %7.4f `delta_annual'
di "    δ (early career, Q1):   " %7.4f `delta_early'
di "    δ (late career, Q5):    " %7.4f `delta_late'
di ""
di "  Using Biennial ETI (ε = " %5.3f `eti_b' "):"
di "    δ (full career):        " %7.4f `delta_biennial'
di ""
di "  Midpoint estimate: δ ≈ " %6.4f `delta_mid'
di ""

* Validate δ
if `delta_annual' < 0 | `delta_annual' > 1 {
    di as error "SCRUTINY FAILURE: δ outside (0,1)"
    di as error "  This indicates either:"
    di as error "  - γ_FE is negative (re-check cumhrs variable quality)"
    di as error "  - ETI is too large relative to γ (model misfit)"
    di as error "  - Sample restrictions are too aggressive"
}
else if `delta_annual' > 0.7 {
    di "NOTE: δ > 0.7 suggests very high information asymmetry."
    di "      Cross-check against Altonji-Pierret results in Skill_vs_Signal_Analysis.do"
}
else {
    di "RESULT: δ ∈ (0,1) — model-consistent information asymmetry estimate"
    di ""
    di "INTERPRETATION:"
    di "  δ = " %5.3f `delta_mid' " means approximately " %4.1f `delta_mid'*100 "% of wage"
    di "  growth comes from the signaling/information channel."
    di "  Remaining " %4.1f (1-`delta_mid')*100 "% is human capital accumulation."
}
di "============================================================"

*--- 3.3: Sensitivity table ---
di ""
di "3.3 SENSITIVITY OF δ TO ASSUMED ε"
di "----------------------------------"
di ""
di "  ε (ETI)  γ_FE      δ_implied"
di "  -------- --------- ---------"
foreach eps_x in 0.2 0.3 0.4 0.5 0.6 0.8 {
    local d_x = `gamma_fe_full' * (1 + `eps_x') / (1 + `gamma_fe_full')
    di "  " %6.2f `eps_x' "   " %7.4f `gamma_fe_full' "   " %7.4f `d_x'
}

/*==============================================================================
PART 4: RECENT vs CUMULATIVE HOURS — DYNAMIC DECOMPOSITION
================================================================================
Build on Skill_vs_Signal Part 2 with career-stage split.
Prediction: Recent hours should matter MORE in early career (when signaling
dominates), while cumulative hours should matter MORE in late career (once
learning completes and track record speaks for itself).
==============================================================================*/

di ""
di "=============================================================================="
di "PART 4: RECENT vs CUMULATIVE HOURS BY CAREER STAGE"
di "=============================================================================="
di ""
di "THEORY: Signaling → Recent hours (face time) matter more when employer"
di "        uncertainty is high (early career)."
di "        Learning-by-doing → Cumulative hours matter throughout career."
di ""

* Check for recent_hrs_annual — use local flag to avoid goto/label issues
local run_part4 = 1
capture confirm variable recent_hrs_annual
if _rc != 0 {
    capture confirm variable recent_hrs
    if _rc == 0 {
        capture confirm variable year_span
        if _rc == 0 {
            gen recent_hrs_annual = recent_hrs / year_span if year_span > 0
            replace recent_hrs_annual = recent_hrs if year_span == 1 | missing(year_span)
        }
        else {
            gen recent_hrs_annual = recent_hrs
        }
    }
    else {
        di "WARNING: recent_hrs not found. Skipping Part 4."
        local run_part4 = 0
    }
}

if `run_part4' {

    capture drop log_recent_annual
    gen log_recent_annual = ln(recent_hrs_annual) if recent_hrs_annual > 0

    di "4.1 HORSE RACE BY CAREER STAGE"
    di "------------------------------"
    di ""
    di "Stage    γ_cumhrs   γ_recent   Ratio (cum/rec)  Signal/HC"
    di "-------- ---------- ---------- ---------------  ---------"

    forvalues q = 1/5 {
        qui count if phase1_sample == 1 & exp_quintile == `q' ///
                  & cumhrs > 0 & recent_hrs_annual > 0
        if r(N) > 500 {
            qui xtreg log_pwages log_cumhrs log_recent_annual pot_exp pot_exp2 i.year ///
                if phase1_sample == 1 & exp_quintile == `q' ///
                & cumhrs > 0 & recent_hrs_annual > 0, fe cluster(taxsimid)
            local gc`q' = _b[log_cumhrs]
            local gr`q' = _b[log_recent_annual]
            local ratio_q`q' = `gc`q'' / max(abs(`gr`q''), 0.001)

            local interp = "Mixed"
            if `gc`q'' > abs(`gr`q'') * 2 {
                local interp = "HC"
            }
            else if abs(`gr`q'') > `gc`q'' * 2 {
                local interp = "Signal"
            }
            di "Q`q'      " %8.4f `gc`q'' "   " %8.4f `gr`q'' ///
                "   " %8.3f `ratio_q`q'' "         `interp'"
        }
        else {
            di "Q`q'      [insufficient obs]"
        }
    }

    label drop _all  // avoid label conflicts if re-run

} // end if run_part4

/*==============================================================================
PART 5: OUTPUT — FORMATTED TABLES AND GRAPHS
==============================================================================*/

di ""
di "=============================================================================="
di "PART 5: OUTPUT"
di "=============================================================================="

*--- Table 1: γ by career stage ---
capture noisily esttab fe_gamma_q1 fe_gamma_q2 fe_gamma_q3 fe_gamma_q4 fe_gamma_q5 fe_gamma_full ///
    using "${outdir}\Phase1_Table1_GammaByStage.rtf", replace ///
    keep(log_cumhrs pot_exp pot_exp2) ///
    order(log_cumhrs pot_exp pot_exp2) ///
    b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2_w, fmt(%12.0fc %9.3f) labels("Observations" "Within R²")) ///
    mtitles("Q1 Early" "Q2" "Q3" "Q4" "Q5 Late" "Full Career") ///
    title("Table 1: Structural Return to Cumulative Hours γ by Career Stage") ///
    note("FE estimator. Std. errors clustered by individual. γ = log_cumhrs coefficient." ///
         "Pareto case predicts γ constant across career stages.")
if _rc != 0 di "WARNING: esttab Table1 failed. Install estout: ssc install estout"

*--- Table 2: OLS vs FE decomposition ---
capture noisily esttab ols_gamma_noafqt ols_gamma fe_gamma_full ///
    using "${outdir}\Phase1_Table2_OLSvsFE.rtf", replace ///
    keep(log_cumhrs pot_exp pot_exp2 afqt_std educ_years) ///
    order(log_cumhrs pot_exp pot_exp2 afqt_std educ_years) ///
    b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observations" "R²")) ///
    mtitles("OLS (no AFQT)" "OLS (with AFQT)" "FE") ///
    title("Table 2: Selection Decomposition — OLS vs FE on log(cumhrs)") ///
    note("OLS-FE gap identifies between-person selection vs within-person accumulation." ///
         "Large gap supports signaling; small gap supports human capital.")
if _rc != 0 di "WARNING: esttab Table2 failed"

*--- Table 3: Structural parameters ---
* Build a small dataset with δ estimates for display
di ""
di "Phase1_Table3_Structural.csv: Writing structural parameter summary"
tempfile struct_out
preserve
clear
set obs 4
gen description = ""
replace description = "gamma_FE_full" in 1
replace description = "delta_annual_ETI" in 2
replace description = "delta_biennial_ETI" in 3
replace description = "delta_midpoint" in 4
gen value = .
replace value = `gamma_fe_full' in 1
replace value = `delta_annual'   in 2
replace value = `delta_biennial' in 3
replace value = `delta_mid'      in 4
gen se = .
replace se = `se_fe_full' in 1
gen ETI_used = .
replace ETI_used = `eti_a' in 2
replace ETI_used = `eti_b' in 3
export delimited using "${outdir}\Phase1_Table3_Structural.csv", replace
list, clean noobs
restore

*--- Figure 1: γ profile across career stages ---
di ""
di "Saving Phase1_Fig1_GammaProfile.png"
preserve
clear
set obs 5
gen stage = _n
gen gamma = .
gen gamma_lo = .
gen gamma_hi = .
forvalues q = 1/5 {
    replace gamma    = `g`q''                    in `q'
    replace gamma_lo = `g`q'' - 1.96 * `se`q'' in `q'
    replace gamma_hi = `g`q'' + 1.96 * `se`q'' in `q'
}
gen gamma_full_line = `gamma_fe_full'

twoway ///
    (rcap gamma_hi gamma_lo stage, lcolor(navy) lwidth(medium)) ///
    (connected gamma stage, ///
        lcolor(navy) lwidth(thick) msymbol(circle) mcolor(navy) msize(large)) ///
    (line gamma_full_line stage, lcolor(maroon) lpattern(dash) lwidth(medium)), ///
    title("Return to Cumulative Hours {it:γ} by Career Stage", size(medium)) ///
    subtitle("Test of Pareto Case: Constant {it:γ} implies history-independent Pigouvian tax") ///
    xtitle("Career Stage (Potential Experience Quintile)") ///
    ytitle("{it:γ} = log(wage) / log(cumhrs) elasticity") ///
    xlabel(1 "Q1: Early" 2 "Q2" 3 "Q3" 4 "Q4" 5 "Q5: Late", angle(30)) ///
    legend(order(2 "γ by stage" 3 "Full-career γ") pos(1) ring(0) rows(2)) ///
    note("Bars = 95% confidence intervals. FE within-person estimator." ///
         "Flat profile → Pareto case; declining → history-dependent wedge.")
graph export "${outdir}\Phase1_Fig1_GammaProfile.png", replace width(1400)
restore

*--- Figure 2: Selection decomposition ---
di "Saving Phase1_Fig2_SelectionDecomp.png"
preserve
clear
set obs 5
gen stage = _n
gen gamma_ols = .
gen gamma_fe  = .
forvalues q = 1/5 {
    replace gamma_ols = `ols_q`q'' in `q'
    replace gamma_fe  = `g`q''     in `q'
}

twoway ///
    (connected gamma_ols stage, ///
        lcolor(maroon) lwidth(medium) msymbol(square) mcolor(maroon)) ///
    (connected gamma_fe stage, ///
        lcolor(navy) lwidth(medium) msymbol(circle) mcolor(navy)), ///
    title("OLS vs FE Return to Cumulative Hours by Career Stage", size(medium)) ///
    subtitle("Gap = between-person selection (signaling); FE = within-person (human capital)") ///
    xtitle("Career Stage (Potential Experience Quintile)") ///
    ytitle("{it:γ} = log(wage) / log(cumhrs) elasticity") ///
    xlabel(1 "Q1: Early" 2 "Q2" 3 "Q3" 4 "Q4" 5 "Q5: Late", angle(30)) ///
    legend(order(1 "OLS (selection + accumulation)" 2 "FE (within-person only)") ///
           pos(1) ring(0) rows(2)) ///
    note("OLS includes between-person ability selection. FE removes time-invariant confounds.")
graph export "${outdir}\Phase1_Fig2_SelectionDecomp.png", replace width(1400)
restore

/*==============================================================================
PART 6: COMPREHENSIVE SCRUTINY SUMMARY
==============================================================================*/

di ""
di "=============================================================================="
di "PART 6: SCRUTINY SUMMARY"
di "=============================================================================="
di ""
di "CHECK 1 — γ_FE positive and significant?"
if `gamma_fe_full' > 0 & `gamma_fe_full'/`se_fe_full' > 1.96 {
    di "  PASS: γ_FE = " %6.4f `gamma_fe_full' " (t=" %5.2f `gamma_fe_full'/`se_fe_full' ")"
}
else if `gamma_fe_full' <= 0 {
    di "  FAIL: γ_FE ≤ 0. cumhrs may be mismeasured. Check Data_process.do Fix #2."
}
else {
    di "  WEAK: γ_FE positive but not significant. Noisy estimates."
}

di ""
di "CHECK 2 — γ_OLS > γ_FE (positive selection)?"
if `gamma_ols_noafqt' > `gamma_fe_full' {
    di "  PASS: γ_OLS=" %6.4f `gamma_ols_noafqt' " > γ_FE=" %6.4f `gamma_fe_full'
}
else {
    di "  FAIL: γ_OLS < γ_FE — unusual (negative selection)."
    di "        Possible causes: attrition, sample restriction issues."
    di "        Investigate before proceeding to Phase 2."
}

di ""
di "CHECK 3 — δ ∈ (0,1)?"
if `delta_annual' > 0 & `delta_annual' < 1 {
    di "  PASS: δ = " %6.4f `delta_annual' " (using annual ETI)"
}
else {
    di "  FAIL: δ = " %6.4f `delta_annual' " — outside (0,1)"
    di "        Diagnose ETI estimate or γ_FE before proceeding."
}

di ""
di "CHECK 4 — Wald test on γ equality?"
di "  F = " %8.3f `wald_F' "  p = " %8.4f `wald_p'
if `wald_p' < 0.05 {
    di "  RESULT: Reject constant γ → use general dynamic model for Phase 2"
}
else {
    di "  RESULT: Fail to reject constant γ → Pareto case appropriate for Phase 2"
}

di ""
di "CHECK 5 — Monotonicity of γ across stages?"
di "  Q1=" %5.3f `g1' "  Q2=" %5.3f `g2' "  Q3=" %5.3f `g3' ///
   "  Q4=" %5.3f `g4' "  Q5=" %5.3f `g5'
if `g1' >= `g5' {
    di "  PASS: γ_early ≥ γ_late (employer learning completing)"
}
else {
    di "  NOTE: γ_late > γ_early — investigate before structural interpretation"
}

di ""
di "STEERING DECISION FOR PHASE 2:"
di ""
if `wald_p' < 0.05 {
    di "  PRIORITIZE: Dynamic (history-dependent) wedge χ(h) estimation"
    di "  REASON: γ is not constant — Pigouvian tax varies over career"
    di "  In Phase 2: Estimate χ separately by career stage quartile"
    di "  Expected: χ_early < χ_late (larger distortion when employer"
    di "            uncertainty is greatest)"
}
else {
    di "  APPROACH: Pareto constant-wedge estimation is appropriate"
    di "  REASON: γ does not significantly vary across career stages"
    di "  In Phase 2: Estimate single χ (or χ by income decile)"
    di "  Then: τ_p = 1 − χ should be approximately constant"
}

/*==============================================================================
PART 7: CLEAN UP AND CLOSE
==============================================================================*/

* Drop temporary interaction dummies
capture drop i_q1 i_q2 i_q3 i_q4 i_q5
capture drop exp_quintile
capture drop log_recent_annual
capture drop phase1_sample
capture drop log_pwages log_cumhrs

di ""
di "=============================================================================="
di "OUTPUT FILES CREATED"
di "=============================================================================="
di ""
di "Tables (${outdir}):"
di "  Phase1_Table1_GammaByStage.rtf    : γ by career quintile (FE)"
di "  Phase1_Table2_OLSvsFE.rtf         : Selection decomposition"
di "  Phase1_Table3_Structural.csv      : δ estimates and structural params"
di ""
di "Figures (${outdir}):"
di "  Phase1_Fig1_GammaProfile.png      : γ profile with 95% CIs"
di "  Phase1_Fig2_SelectionDecomp.png   : OLS vs FE by career stage"
di ""
di "Log (${outdir}):"
di "  Structural_Wage_Experience_log.txt"
di ""
di "=============================================================================="
di "PHASE 1 COMPLETE"
di "=============================================================================="
di "End time: $S_DATE $S_TIME"
di ""
di "NEXT STEPS:"
di "  1. Review γ profile — is it flat (Pareto) or declining (dynamic)?"
di "  2. Check δ estimate against priors from Skill_vs_Signal_Analysis"
di "  3. Run Advantageous_Selection_Test.do (Phase 3)"
di "  4. Feed Pareto/dynamic decision into Labor_Wedge_Estimation.do (Phase 2)"

log close
