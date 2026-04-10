/*==============================================================================
PIGOUVIAN_TAX_QUANTIFICATION.DO
================================================================================
Purpose: Quantify the optimal Pigouvian tax correction from the signaling model.
         Combines structural estimates from Phases 1-4 to compute τ_p(y).

FINAL DELIVERABLE:
  τ_p(y) = 1 − χ(y) = −ε^w_r(y) / η^P_r(y)

  In the Pareto case: τ_p = δ/α
    δ = information asymmetry (from Phase 1 structural recovery)
    α = Pareto tail parameter (from income distribution)
    τ_p should match 1 − χ_full from Phase 2

CROSS-PHASE CONSISTENCY CHECK (MOST IMPORTANT SCRUTINY STEP):
  Two independent estimates of δ:
    δ_1: From γ and ε: δ_1 = γ_FE × (1 + ε) / (1 + γ_FE)
    δ_2: From τ_p and α: δ_2 = τ_p × α = (1 − χ) × α

  If |δ_1 − δ_2| > 0.05: model misfit — diagnose before publication
  Possible causes: (a) Pareto assumption fails; (b) ETI ≠ ε (different margins);
                   (c) χ estimate is biased (weak η^P_r)

STRUCTURE:
  Part 1: Load estimates from Phases 1-4
  Part 2: Pareto tail parameter α from income distribution
  Part 3: Pigouvian tax by income decile τ_p(y)
  Part 4: Dynamic Pigouvian tax by career stage τ_p(y, career)
  Part 5: Cross-phase consistency check
  Part 6: Sector-specific Pigouvian correction (if Phase 4 findings support it)
  Part 7: Summary table for paper

INPUT:  output\Phase1_Table3_Structural.csv
        output\Phase2_Table4_Pigouvian.csv
        output\two_period_summary.dta   (or output\two_period_summary.csv)
        data\nlsy_long_pre_taxsim.dta   (for income distribution)
        data\analysis_annual.dta        (for income distribution in sample)
OUTPUT: output\Phase5_Table1_MainResults.rtf
        output\Phase5_Table2_DynamicTau.rtf
        output\Phase5_Fig1_TauProfile.png
        output\Phase5_Fig2_ConsistencyCheck.png
        output\Phase5_Table3_Summary.csv
        output\Pigouvian_Tax_log.txt

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

log using "${outdir}\Pigouvian_Tax_log.txt", replace text

di ""
di "=============================================================================="
di "PIGOUVIAN TAX QUANTIFICATION (PHASE 5)"
di "=============================================================================="
di "τ_p(y) = 1 − χ(y)   |   Pareto case: τ_p = δ/α"
di "Cross-phase consistency: δ from γ vs. δ from τ_p × α"
di "Start time: $S_DATE $S_TIME"
di ""

/*==============================================================================
PART 0: VERIFY PHASE 1-4 OUTPUTS EXIST
==============================================================================*/

di "=============================================================================="
di "PART 0: VERIFY PREREQUISITE OUTPUTS"
di "=============================================================================="
di ""

local prereqs_ok = 1

capture confirm file "${outdir}\Phase1_Table3_Structural.csv"
if _rc == 0 {
    di "FOUND: Phase1_Table3_Structural.csv (δ from Phase 1)"
    global phase1_ready = 1
}
else {
    di "MISSING: Phase1_Table3_Structural.csv"
    di "  Run Structural_Wage_Experience.do (Phase 1) first."
    global phase1_ready = 0
    local prereqs_ok = 0
}

capture confirm file "${outdir}\Phase2_Table4_Pigouvian.csv"
if _rc == 0 {
    di "FOUND: Phase2_Table4_Pigouvian.csv (χ from Phase 2)"
    global phase2_ready = 1
}
else {
    di "MISSING: Phase2_Table4_Pigouvian.csv"
    di "  Run Labor_Wedge_Estimation.do (Phase 2) first."
    global phase2_ready = 0
    local prereqs_ok = 0
}

capture confirm file "${outdir}\two_period_summary.dta"
if _rc == 0 {
    global eti_ready = 1
}
else {
    global eti_ready = 0
}

if `prereqs_ok' == 0 {
    di ""
    di "One or more prerequisite outputs missing."
    di "This file will run with available inputs and note gaps."
    di "For full results, run Phases 1-4 first."
}

di ""

/*==============================================================================
PART 1: COLLECT ESTIMATES FROM PRIOR PHASES
==============================================================================*/

di "=============================================================================="
di "PART 1: COLLECT CROSS-PHASE ESTIMATES"
di "=============================================================================="
di ""

*--- From Phase 1: γ_FE, δ estimates ---
if $phase1_ready == 1 {
    import delimited using "${outdir}\Phase1_Table3_Structural.csv", clear

    di "Phase 1 structural estimates:"
    list, clean noobs

    * Extract key scalars
    qui sum value if description == "gamma_FE_full"
    global gamma_fe = r(mean)

    qui sum value if description == "delta_midpoint"
    global delta_p1 = r(mean)

    di ""
    di "  γ_FE (full career):      " %7.4f $gamma_fe
    di "  δ (Phase 1 estimate):    " %7.4f $delta_p1
}
else {
    di "Phase 1 not available. Using placeholder values."
    global gamma_fe = 0.15    // placeholder
    global delta_p1 = 0.10    // placeholder
    di "  [PLACEHOLDER] γ_FE = " $gamma_fe "  δ = " $delta_p1
}

*--- From Phase 2: χ(y) and τ_p(y) by decile ---
if $phase2_ready == 1 {
    import delimited using "${outdir}\Phase2_Table4_Pigouvian.csv", clear

    di ""
    di "Phase 2 Pigouvian tax estimates (preliminary):"
    list, clean noobs

    * If chi_approx is missing (Phase 2 placeholder), note this
    qui count if missing(chi_approx)
    if r(N) > 0 {
        di "NOTE: Some χ estimates are missing — Phase 2 needs full η^P_r"
    }
}

*--- From Two_Period_Analysis: ETI ---
if $eti_ready == 1 {
    use "${outdir}\two_period_summary.dta", clear
    qui sum ETI if strpos(period, "Annual") > 0
    global eti_annual  = r(mean)
    qui sum ETI if strpos(period, "Biennial") > 0
    global eti_biennial = r(mean)
    di ""
    di "ETI estimates:"
    di "  Annual:   " %7.4f $eti_annual
    di "  Biennial: " %7.4f $eti_biennial
    di "  Average:  " %7.4f ($eti_annual + $eti_biennial)/2
    global eti_avg = ($eti_annual + $eti_biennial) / 2
}
else {
    global eti_annual   = 0.4
    global eti_biennial = 0.3
    global eti_avg      = 0.35
    di "ETI: using literature midpoints (0.3-0.4) as placeholders"
}

di ""

/*==============================================================================
PART 2: PARETO TAIL PARAMETER α
================================================================================
Estimate the Pareto tail index from the top of the wage distribution.
Method: Log-rank regression on the top 20% of income in the analysis sample.
  log(1 − F(w)) = c − α·log(w)   ←   slope = −α (Pareto tail parameter)
Alternatively: use Hill estimator.
==============================================================================*/

di "=============================================================================="
di "PART 2: PARETO TAIL PARAMETER α"
di "=============================================================================="
di ""
di "Method: Log-rank regression on top 20% of income distribution"
di "  log(1 − F(w)) = c − α·log(w)    → slope gives α"
di ""

capture confirm file "${datadir}\analysis_annual.dta"
if _rc == 0 {
    use "${datadir}\analysis_annual.dta", clear

    * Work with broad income at baseline
    * Keep top 20% (top 2 deciles) for Pareto tail estimation
    quietly _pctile log_income_t, p(80)
    local p80 = r(r1)

    keep if log_income_t >= `p80' & !missing(log_income_t)
    sort log_income_t
    gen rank_n = _n
    gen total_n = _N
    gen log_rank = ln(1 - (rank_n - 0.5) / total_n)

    di "Pareto tail sample: top 20% of annual income distribution"
    di "N = " _N " observations in tail"

    reg log_rank log_income_t, robust
    scalar alpha_est = abs(_b[log_income_t])
    scalar alpha_se  = _se[log_income_t]
    scalar alpha_r2  = e(r2)

    di ""
    di "Pareto tail fit:"
    di "  α = " %7.4f alpha_est "  SE = " %6.4f alpha_se
    di "  R² = " %6.4f alpha_r2
    di ""

    if alpha_r2 < 0.85 {
        di "CAUTION: Low R² — Pareto fit may be poor"
        di "  The income distribution in NLSY may not follow a clean Pareto tail"
        di "  Alternative: use percentile-based τ_p without structural Pareto"
    }
    else {
        di "GOOD: R² suggests reasonable Pareto fit"
    }

    * Typical range: α ∈ [1.5, 3.5] for US earnings
    if alpha_est < 1 | alpha_est > 5 {
        di as error "SCRUTINY: α = " %6.3f alpha_est " is outside typical range [1, 5]"
        di as error "  Check: (1) income variable is correct (not log income by mistake)"
        di as error "         (2) sufficient top-income variation in annual sample"
    }
    else {
        di "GOOD: α ∈ typical range for US earnings distribution"
        di "  For reference: US top income shares → α ≈ 1.5-2.5 typically"
    }

    global alpha_pareto = alpha_est

}
else {
    di "analysis_annual.dta not available. Using literature α = 2.0 as placeholder."
    global alpha_pareto = 2.0
    di "  [PLACEHOLDER] α = " $alpha_pareto
}

/*==============================================================================
PART 3: PIGOUVIAN TAX COMPUTATION
================================================================================
Combining Phase 1 (δ) and Phase 2 (ε^w_r) estimates:

  Method A (Pareto structural):
    τ_p = δ / α
    where δ = γ(1+ε)/(1+γ) from Phase 1
          α = Pareto tail from Part 2

  Method B (Direct from χ):
    τ_p(y) = 1 − χ(y) = −ε^w_r(y) / η^P_r
    From Phase 2 (preliminary, needs full η^P_r)
==============================================================================*/

di ""
di "=============================================================================="
di "PART 3: PIGOUVIAN TAX COMPUTATION"
di "=============================================================================="
di ""

*--- Method A: Pareto structural ---
local tau_p_a = $delta_p1 / $alpha_pareto

di "METHOD A — Pareto Structural: τ_p = δ / α"
di "  δ = " %6.4f $delta_p1 "  α = " %6.4f $alpha_pareto
di "  τ_p (Pareto) = " %7.4f `tau_p_a'
di ""

if `tau_p_a' < 0 {
    di as error "SCRUTINY FAILURE: τ_p < 0 from Method A"
    di as error "  δ or α is misestimated. Check Phase 1 δ value."
}
else if `tau_p_a' > 0.5 {
    di "NOTE: τ_p > 50% is large. Compare to Sztutman's HRS estimates for benchmark."
}
else if `tau_p_a' > 0 {
    di "RESULT: Optimal Pigouvian correction ≈ " %4.1f `tau_p_a'*100 " percentage points"
    di "  Interpretation: The signaling externality warrants a Pigouvian tax of"
    di "  approximately " %4.1f `tau_p_a'*100 "pp on top of the Mirrleesian optimal tax."
}

*--- Method A: Sensitivity to δ and α ---
di ""
di "3.1 SENSITIVITY TABLE: τ_p = δ/α"
di "---------------------------------"
di "        α=1.5    α=2.0    α=2.5    α=3.0"
foreach d_val in 0.05 0.10 0.15 0.20 0.25 0.30 {
    di "δ=" %4.2f `d_val' ":  " ///
       %7.4f `d_val'/1.5 "  " ///
       %7.4f `d_val'/2.0 "  " ///
       %7.4f `d_val'/2.5 "  " ///
       %7.4f `d_val'/3.0
}

*--- ETI-range sensitivity ---
di ""
di "3.2 SENSITIVITY OF δ TO ETI (at γ_FE = " %5.3f $gamma_fe ")"
di "------------------------------------------"
di "  ε (ETI)    δ_implied    τ_p (at α=" %4.2f $alpha_pareto ")"
foreach e_val in 0.20 0.30 0.40 0.50 0.60 {
    local d_e = $gamma_fe * (1 + `e_val') / (1 + $gamma_fe)
    local t_e = `d_e' / $alpha_pareto
    di "  " %6.2f `e_val' "      " %7.4f `d_e' "      " %7.4f `t_e'
}

/*==============================================================================
PART 4: DYNAMIC PIGOUVIAN TAX BY CAREER STAGE
================================================================================
If Phase 1 rejects constant γ (i.e., the Wald test is significant),
then τ_p is history-dependent. We compute τ_p for each career stage.

  τ_p(career stage s) = δ_s / α
  where δ_s = γ_s(1 + ε) / (1 + γ_s) from Phase 1 career-stage estimates

Key predictions:
  - τ_p_early > τ_p_late: larger distortion early in career
    (employer uncertainty greatest → largest positive externality)
  - Convergence: τ_p → 0 as career progresses (employer learning completes)
==============================================================================*/

di ""
di "=============================================================================="
di "PART 4: DYNAMIC PIGOUVIAN TAX BY CAREER STAGE"
di "=============================================================================="
di ""
di "NOTE: Career-stage γ values required from Phase 1 log output."
di "      Update scalars g1-g5 below with Phase 1 results before final run."
di ""
di "Placeholder: Using full-career γ as constant for all stages."
di "Update after running Phase 1 and reading γ by career quintile."
di ""

* INSTRUCTION: After running Phase 1, replace these placeholders:
* Read career-stage γ values from Structural_Wage_Experience_log.txt
* and update these scalars:
*   scalar g1 = [Q1 γ from Phase 1 log]
*   scalar g2 = [Q2 γ from Phase 1 log]
*   scalar g3 = [Q3 γ from Phase 1 log]
*   scalar g4 = [Q4 γ from Phase 1 log]
*   scalar g5 = [Q5 γ from Phase 1 log]

* For now: placeholder from full-career estimate
scalar g1 = $gamma_fe * 1.2   // Hypothetical: 20% higher early career
scalar g2 = $gamma_fe * 1.1
scalar g3 = $gamma_fe
scalar g4 = $gamma_fe * 0.9
scalar g5 = $gamma_fe * 0.8   // 20% lower late career

di "Dynamic τ_p by career stage (PLACEHOLDER — update with Phase 1 results):"
di ""
di "Stage  γ_FE     δ_implied  τ_p       Interpretation"
di "------ -------- ---------- --------- ---------------"

forvalues q = 1/5 {
    local gq = g`q'
    local dq = `gq' * (1 + $eti_avg) / (1 + `gq')
    local tq = `dq' / $alpha_pareto

    local interp = "Moderate distortion"
    if `tq' > `tau_p_a' * 1.2 local interp = "ABOVE average — higher Pigouvian needed"
    if `tq' < `tau_p_a' * 0.8 local interp = "Below average — lower Pigouvian"

    di "  Q`q'    " %7.4f `gq' "   " %7.4f `dq' "   " %7.4f `tq' ///
       "   `interp'"
}

di ""
di "[PLACEHOLDER NOTE]"
di "Replace g1-g5 scalars above with actual Phase 1 career-stage γ estimates."
di "Then this table will show the true dynamic Pigouvian tax profile."

/*==============================================================================
PART 5: CROSS-PHASE CONSISTENCY CHECK (CRITICAL SCRUTINY)
================================================================================
The most important diagnostic: are the two independent δ estimates consistent?

  δ_1 from Phase 1:  δ_1 = γ_FE × (1 + ETI) / (1 + γ_FE)
  δ_2 from Phase 2:  δ_2 = τ_p × α = (1 − χ) × α

  If |δ_1 − δ_2| > 0.05: model is internally inconsistent; investigate before citing

  This test is the "smoking gun" for whether the model is coherent:
  - If consistent: both the structural approach (Phase 1) and the reduced-form
    approach (Phase 2) point to the same information asymmetry δ
  - If inconsistent: one of the identifying assumptions is violated
==============================================================================*/

di ""
di "=============================================================================="
di "PART 5: CROSS-PHASE CONSISTENCY CHECK"
di "=============================================================================="
di ""
di "δ_1 (Phase 1, structural): " %7.4f $delta_p1
di "  From: δ = γ_FE(1 + ε)/(1 + γ_FE)"
di ""
di "δ_2 (Phase 2 + α): τ_p × α"
di "  τ_p (Phase 2 preliminary): " %7.4f `tau_p_a' " [currently = δ/α from Phase 1]"
di "  α (Pareto): " %7.4f $alpha_pareto
di "  δ_2 = τ_p × α = " %7.4f `tau_p_a' * $alpha_pareto
di ""
di "NOTE: When Phase 2 has full η^P_r and proper χ(y), compute:"
di "  δ_2_proper = (1 − χ_full) × α"
di "  and compare with δ_1 from Phase 1."
di ""
di "CONSISTENCY INTERPRETATION (from literature):"
di "  |δ_1 − δ_2| < 0.02: Excellent fit — model is internally consistent"
di "  |δ_1 − δ_2| ∈ [0.02, 0.05]: Acceptable — minor identification issues"
di "  |δ_1 − δ_2| > 0.05: Investigate — likely model misfit or biased estimator"
di ""
di "COMMON CAUSES OF INCONSISTENCY:"
di "  1. ETI ≠ labor supply ε: ETI includes avoidance/evasion; ε is pure supply"
di "     → Fix: use intensive-margin-only ETI (controlling for income shifting)"
di "  2. Pareto assumption fails: Income distribution is not Pareto at top"
di "     → Fix: use non-parametric τ_p(y) from Phase 2 without Pareto"
di "  3. χ is biased: η^P_r approximation in Phase 2 is poor"
di "     → Fix: expand TAXSIM sample to near-workers"
di "  4. γ_FE is contaminated: cumhrs endogenous even within-person"
di "     → Fix: instrument for cumhrs using past hours or reform-year variation"

/*==============================================================================
PART 6: SUMMARY TABLE FOR PAPER
================================================================================
The final output to be included in the paper:
Main estimates of τ_p under different assumptions and methods.
==============================================================================*/

di ""
di "=============================================================================="
di "PART 6: SUMMARY TABLE"
di "=============================================================================="

clear
set obs 8
gen method = ""
gen estimate = .
gen lower = .
gen upper = .
gen notes = ""

replace method = "Phase 1: Pareto (ETI annual)"     in 1
replace method = "Phase 1: Pareto (ETI biennial)"   in 2
replace method = "Phase 1: Pareto (ETI average)"    in 3
replace method = "Phase 2: Direct χ (prelim)"       in 4
replace method = "Sensitivity: α=1.5"               in 5
replace method = "Sensitivity: α=2.5"               in 6
replace method = "Sensitivity: α=3.0"               in 7
replace method = "Literature comparison (Sztutman)" in 8

local delta_a = $gamma_fe * (1 + $eti_annual)  / (1 + $gamma_fe)
local delta_b = $gamma_fe * (1 + $eti_biennial) / (1 + $gamma_fe)
local delta_c = $gamma_fe * (1 + $eti_avg)      / (1 + $gamma_fe)

replace estimate = `delta_a' / $alpha_pareto   in 1
replace estimate = `delta_b' / $alpha_pareto   in 2
replace estimate = `delta_c' / $alpha_pareto   in 3
replace estimate = `tau_p_a'                   in 4  // placeholder
replace estimate = `delta_c' / 1.5            in 5
replace estimate = `delta_c' / 2.5            in 6
replace estimate = `delta_c' / 3.0            in 7
replace estimate = .                           in 8   // fill from paper

* Rough confidence intervals (±30% of point estimate as placeholder)
replace lower = estimate * 0.7
replace upper = estimate * 1.3

replace notes = "Primary estimate" in 3
replace notes = "Placeholder — needs full η^P_r" in 4
replace notes = "Robustness" in 5
replace notes = "Robustness" in 6
replace notes = "Robustness" in 7
replace notes = "HRS-based estimate from paper" in 8

di ""
di "SUMMARY: Pigouvian Tax Estimates"
di "(Percent of income)"
di ""
list method estimate lower upper notes, clean noobs

* Convert to percentage
replace estimate = estimate * 100
replace lower    = lower * 100
replace upper    = upper * 100

export delimited using "${outdir}\Phase5_Table3_Summary.csv", replace

*--- Figure: τ_p profile ---
preserve
keep if !missing(estimate) & _n <= 7
gen idx = _n

twoway ///
    (rcap upper lower idx, lcolor(navy) lwidth(medium)) ///
    (scatter estimate idx, msymbol(circle) mcolor(navy) msize(large)), ///
    title("Optimal Pigouvian Tax Correction" ///
          "Point Estimates and Uncertainty Ranges", size(medium)) ///
    subtitle("tau_p = 1 - chi(y) = delta/alpha (Pareto case)") ///
    ytitle("Pigouvian tax (% of income)") ///
    xtitle("") ///
    xlabel(1 "Ann ETI" 2 "Bien ETI" 3 "Avg ETI" ///
           4 "Direct chi" 5 "alpha=1.5" 6 "alpha=2.5" 7 "alpha=3.0", ///
           angle(30) labsize(small)) ///
    yline(0, lcolor(gs10) lpattern(dash)) ///
    legend(off) ///
    note("Ranges = +-30% interval (placeholder -- update with bootstrap SEs)." ///
         "Phase 2 direct chi estimate requires expanded TAXSIM for eta^P_r.")
graph export "${outdir}\Phase5_Fig1_TauProfile.png", replace width(1400)
restore

/*==============================================================================
PART 7: FINAL SCRUTINY AND RESEARCH READINESS ASSESSMENT
==============================================================================*/

di ""
di "=============================================================================="
di "PART 7: RESEARCH READINESS ASSESSMENT"
di "=============================================================================="
di ""
di "STATUS OF EACH PHASE:"
di ""

* Phase 1
if $phase1_ready == 1 {
    di "  Phase 1 (Structural γ):    COMPLETE ✓"
    di "    Key result: γ_FE = " %6.4f $gamma_fe ", δ ≈ " %6.4f $delta_p1
}
else {
    di "  Phase 1 (Structural γ):    PENDING — Run Structural_Wage_Experience.do"
}

* Phase 2
if $phase2_ready == 1 {
    di "  Phase 2 (Labor Wedge χ):   PRELIMINARY — needs full η^P_r"
    di "    Action: Expand Two_Period_Analysis.do to include near-workers"
}
else {
    di "  Phase 2 (Labor Wedge χ):   PENDING — Run Labor_Wedge_Estimation.do"
}

di "  Phase 3 (AFQT Selection):   Check Advantageous_Selection_log.txt"
di "  Phase 4 (Sector Hetero):    Check Sector_Heterogeneity_log.txt"
di "  Phase 5 (Pigouvian τ_p):    PRELIMINARY (depends on Phases 1-2)"
di ""
di "WHAT IS NEEDED FOR A SUBMISSION-READY PAPER:"
di ""
di "  SHORT-RUN (can complete now):"
di "  □ Run all 4 phases and check scrutiny checkpoints"
di "  □ Update Phase 5 with actual career-stage γ from Phase 1"
di "  □ Verify AFQT selection test finds advantageous selection (Phase 3)"
di "  □ Check Pareto α and whether Pareto case is supported (Phase 1 Wald test)"
di ""
di "  MEDIUM-RUN (requires data work):"
di "  □ Expand Two_Period_Analysis.do to near-workers (income $1K-$10K real)"
di "  □ Re-run TAXSIM on expanded sample"
di "  □ Estimate full η^P_r by income decile and career stage"
di "  □ Compute precise χ(y) and τ_p(y) from Phase 2"
di ""
di "  FOR ROBUSTNESS (paper polish):"
di "  □ Bootstrap standard errors for τ_p (Phase 5 confidence intervals)"
di "  □ Cross-phase consistency check (δ_1 vs δ_2) once Phase 2 is complete"
di "  □ Sector-specific τ_p from Phase 4 findings"
di "  □ Comparison with Sztutman HRS estimates (own code vs literature)"

di ""
di "=============================================================================="
di "OUTPUT FILES CREATED"
di "=============================================================================="
di ""
di "Tables (${outdir}):"
di "  Phase5_Table3_Summary.csv       : Main τ_p estimates"
di ""
di "Figures (${outdir}):"
di "  Phase5_Fig1_TauProfile.png      : τ_p profile with uncertainty"
di ""
di "Log (${outdir}):"
di "  Pigouvian_Tax_log.txt"
di ""
di "=============================================================================="
di "PHASE 5 COMPLETE"
di "=============================================================================="
di "End time: $S_DATE $S_TIME"
di ""
di "RECOMMENDED NEXT ACTION:"
di "  1. Run all phases in order: Phase 1 → Phase 3 → Phase 2 → Phase 4 → Phase 5"
di "  2. Read each phase's log and scrutiny section before proceeding"
di "  3. Update Phase 5 g1-g5 scalars with Phase 1 career-stage γ values"
di "  4. Schedule time to expand TAXSIM sample for Phase 2 full estimation"

log close
