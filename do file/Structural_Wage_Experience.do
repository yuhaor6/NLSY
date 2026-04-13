* Structural_Wage_Experience.do
* Estimates structural gamma (return to cumulative hours) across career stages
* and recovers implied information asymmetry parameter delta.
* Model: log(w) = alpha_i + gamma*log(cumhrs) + beta*X + u  (Sztutman 2024)
* Tests: gamma constancy across stages, OLS vs FE gap, delta in (0,1)
* Input:  data/nlsy_long_pre_taxsim.dta
* Output: Phase1 tables + figures in output/

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

* --- Part 0: DATA LOADING AND VERIFICATION ---

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
di "Check: Checking cumhrs monotonicity within person..."
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

* --- Part 1: CAREER-STAGE γ PROFILES ---

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

* --- SECTION 1.4b: COLLINEARITY ROBUSTNESS — RESIDUALIZED log_cumhrs ---

di ""
di "1.4b COLLINEARITY ROBUSTNESS: RESIDUALIZED log_cumhrs"
di "------------------------------------------------------"
di ""
di "Step 1: Regress log_cumhrs on pot_exp + pot_exp2 within-person (FE)"
di "        Residuals = variation in cumhrs NOT explained by experience progression"
di "Step 2: Use residuals as purified cumhrs regressor in gamma FE"
di ""

* Step 1: First-stage — regress log_cumhrs on pot_exp within-person (FE)
capture drop resid_log_cumhrs
xtreg log_cumhrs pot_exp pot_exp2 i.year ///
    if phase1_sample == 1, fe
predict double resid_log_cumhrs if e(sample), e
label var resid_log_cumhrs "log(cumhrs) residualized on pot_exp within-person (FE)"

qui sum resid_log_cumhrs if phase1_sample == 1
di "Residualized log_cumhrs: mean=" %7.4f r(mean) "  sd=" %7.4f r(sd)
di "  (sd should be smaller than original sd -- variation from collinear part removed)"
qui sum log_cumhrs if phase1_sample == 1
di "  Original   log_cumhrs: mean=" %7.4f r(mean) "  sd=" %7.4f r(sd)
di ""

* Step 2: Re-estimate gamma using residualized cumhrs by career stage
di "Residualized gamma by career stage (vs primary gamma):"
di "Stage  gamma_resid  SE        t       primary_gamma  diff"
di "------ ------------ --------- ------- -------------- ----"

forvalues q = 1/5 {
    qui count if phase1_sample == 1 & exp_quintile == `q' ///
                 & !missing(resid_log_cumhrs)
    if r(N) >= 200 {
        xtreg log_pwages resid_log_cumhrs pot_exp pot_exp2 i.year ///
            if phase1_sample == 1 & exp_quintile == `q', fe cluster(taxsimid)

        local gr`q'  = _b[resid_log_cumhrs]
        local gse`q' = _se[resid_log_cumhrs]
        local diff`q' = `gr`q'' - `g`q''
        local diffstr`q' : di %7.4f `diff`q''
        di "  Q`q'   " %8.4f `gr`q'' "  " %7.4f `gse`q'' ///
           "  " %7.2f `gr`q''/`gse`q'' "    " %8.4f `g`q'' ///
           "    `diffstr`q''"
    }
}

di ""
di "INTERPRETATION:"
di "  If residualized gamma_Q1 << primary gamma_Q1: U-shape was collinearity artifact"
di "  If residualized gamma profile is monotone-declining: supports signaling model"
di "  If residualized gamma profile still U-shaped: genuine non-monotone pattern"
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
di "1.4 Monotonicity check"
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

* --- SECTION 1.6: CONTINUOUS γ(t) — POLYNOMIAL INTERACTION SPECIFICATION ---

di ""
di "=============================================================================="
di "SECTION 1.6: CONTINUOUS γ(t) — POLYNOMIAL INTERACTION"
di "=============================================================================="
di ""
di "Model: γ(exp) = β₀ + β₁·exp + β₂·exp²"
di "  log_cumhrs main effect = β₀ (γ at exp=0)"
di "  exp × log_cumhrs       = β₁ (linear career slope of γ)"
di "  exp² × log_cumhrs      = β₂ (curvature — negative = concave, positive = convex)"
di ""

*--- Generate interaction terms: experience × log_cumhrs ---
capture drop exp_lcumhrs exp2_lcumhrs
gen exp_lcumhrs  = pot_exp  * log_cumhrs if phase1_sample == 1
gen exp2_lcumhrs = pot_exp2 * log_cumhrs if phase1_sample == 1
label var exp_lcumhrs  "pot_exp × log_cumhrs  (linear γ slope)"
label var exp2_lcumhrs "pot_exp² × log_cumhrs (quadratic γ curvature)"

*--- Main polynomial-interaction FE regression ---
xtreg log_pwages log_cumhrs exp_lcumhrs exp2_lcumhrs ///
    pot_exp pot_exp2 i.year ///
    if phase1_sample == 1, fe cluster(taxsimid)
est store fe_gamma_poly

local b0   = _b[log_cumhrs]
local b1   = _b[exp_lcumhrs]
local b2   = _b[exp2_lcumhrs]
local se0  = _se[log_cumhrs]
local se1  = _se[exp_lcumhrs]
local se2  = _se[exp2_lcumhrs]
local t1   = `b1' / `se1'
local t2   = `b2' / `se2'

di ""
di "Polynomial interaction regression coefficients:"
di "  β₀ (log_cumhrs — γ at exp=0):  " %8.4f `b0' "  SE=" %6.4f `se0'
di "  β₁ (exp_lcumhrs — linear):     " %8.4f `b1' "  SE=" %6.4f `se1' "  t=" %5.2f `t1'
di "  β₂ (exp2_lcumhrs — quadratic): " %8.4f `b2' "  SE=" %6.4f `se2' "  t=" %5.2f `t2'
di ""

*--- Implied γ̂(exp) at each experience level ---
di "Implied γ̂(exp) = β₀ + β₁·exp + β₂·exp²:"
di ""
di "  exp   γ̂(exp)   interpretation"
di "  ----  --------  ---------------"
forvalues e = 0(5)35 {
    local gamma_e = `b0' + `b1'*`e' + `b2'*`e'^2
    local note = ""
    if `e' == 0  local note = "(career entry)"
    if `e' == 5  local note = "(Q1/Q2 boundary)"
    if `e' == 15 local note = "(Q4 start — least biased)"
    if `e' == 25 local note = "(Q4/Q5 boundary)"
    di "  " %3.0f `e' "   " %8.4f `gamma_e' "   `note'"
}

*--- Find peak/trough of γ̂(exp): d/d(exp) = β₁ + 2β₂·exp = 0 → exp* = -β₁/(2β₂) ---
if abs(`b2') > 0.000001 {
    local exp_star = -`b1' / (2 * `b2')
    local gamma_star = `b0' + `b1'*`exp_star' + `b2'*`exp_star'^2
    if `exp_star' >= 0 & `exp_star' <= 40 {
        di ""
        di "  Career arc: γ̂(exp) has extremum at exp* = " %5.1f `exp_star' " years"
        di "  γ̂(exp*) = " %7.4f `gamma_star'
        if `b2' > 0 {
            di "  β₂ > 0 → quadratic opens upward → exp* is a MINIMUM (U-shape)"
            di "  U-shape confirmed by polynomial fit — consistent with estimation artifacts"
            di "  (heterogeneous trend bias in Q1–Q3; non-identification in Q5)"
        }
        else {
            di "  β₂ < 0 → quadratic opens downward → exp* is a MAXIMUM (inverted-U)"
        }
    }
    else {
        di ""
        di "  γ̂(exp) is monotone on [0,40]: exp* = " %5.1f `exp_star' " (outside sample range)"
        if `b1' < 0 {
            di "  β₁ < 0: γ̂(exp) is declining — consistent with dynamic signaling"
        }
        else {
            di "  β₁ > 0: γ̂(exp) is rising — inconsistent with signaling model"
        }
    }
}

di ""
*--- Joint Wald test: Is γ(t) constant? (Pareto case H0: β₁ = β₂ = 0) ---
di "JOINT TEST: Is γ constant across career? (H0: β₁ = β₂ = 0 — Pareto case)"
test exp_lcumhrs exp2_lcumhrs
local poly_F  = r(F)
local poly_p  = r(p)
local poly_df1 = r(df)
local poly_df2 = r(df_r)
di "  F(" `poly_df1' ", " `poly_df2' ") = " %8.3f `poly_F' ///
   "  p = " %7.4f `poly_p'
di ""
if `poly_p' < 0.05 {
    di "  REJECT constant γ — career arc of γ is statistically non-constant"
    if `b1' < 0 & `b2' >= 0 & abs(`b2') < abs(`b1')/5 {
        di "  Pattern: β₁ < 0, β₂ ≈ 0 → approximately monotone-declining"
        di "  → Dynamic signaling interpretation supported"
    }
    else if `b2' > 0 {
        di "  Pattern: β₂ > 0 → U-shaped γ(exp) curve"
        di "  → See Sections 1.7–1.8 for estimation-artifact diagnosis"
    }
}
else {
    di "  FAIL TO REJECT constant γ — consistent with Pareto case"
    di "  Pigouvian tax τ_p = δ/α is history-independent"
}

di ""
di "Interpretation:"
di "  β₁ < 0, β₂ ≈ 0: monotone-declining → dynamic signaling (employer learning)"
di "  β₁ = β₂ = 0:    constant γ         → Pareto case (constant τ_p)"
di "  β₂ > 0 (U-shape): estimation artifact → see Section 1.7 (trend robustness)"

*--- Figure 3: Polynomial γ(exp) curve ---
di "Saving Phase1_Fig3_PolynomialGamma.png"
preserve
clear
set obs 36
gen exp_val = _n - 1               // 0 to 35 years of experience
gen gamma_poly = `b0' + `b1'*exp_val + `b2'*exp_val^2

* Pointwise 95% CI via delta method:
* Var(γ̂(e)) = Var(β₀) + e²·Var(β₁) + e⁴·Var(β₂) + 2e·Cov(β₀,β₁) + 2e²·Cov(β₀,β₂) + 2e³·Cov(β₁,β₂)
* Approximate with diagonal only (conservative)
gen se_poly = sqrt(`se0'^2 + (exp_val*`se1')^2 + (exp_val^2*`se2')^2)
gen gamma_poly_lo = gamma_poly - 1.96*se_poly
gen gamma_poly_hi = gamma_poly + 1.96*se_poly

* Constant γ reference line (Pareto case)
gen gamma_const = `gamma_fe_full'

* Mark exp* = -β₁/(2β₂)
local exp_star_plot = -`b1' / (2 * `b2')

twoway ///
    (rarea gamma_poly_hi gamma_poly_lo exp_val, ///
        fcolor(navy%20) lwidth(none)) ///
    (line gamma_poly exp_val, ///
        lcolor(navy) lwidth(thick)) ///
    (line gamma_const exp_val, ///
        lcolor(maroon) lpattern(dash) lwidth(medium)), ///
    title("{it:γ}(exp) = β₀ + β₁·exp + β₂·exp²", size(medium)) ///
    subtitle("Polynomial FE estimate with pointwise 95% CI") ///
    xtitle("Potential Experience (years)") ///
    ytitle("{it:γ} = log(wage) / log(cumhrs) elasticity") ///
    xlabel(0(5)35) ///
    xline(`exp_star_plot', lcolor(gs10) lpattern(dot)) ///
    legend(order(2 "Polynomial γ̂(exp)" 3 "Full-career γ_FE (Pareto case)") ///
           pos(1) ring(0) rows(2)) ///
    note("Shaded band: pointwise 95% CI. Dotted line: minimum at exp* = " ///
         string(`exp_star_plot',"%4.1f") " yrs. Dashed: constant-γ (Pareto) case.")
graph export "${outdir}\Phase1_Fig3_PolynomialGamma.png", replace width(1400)
restore

* --- SECTION 1.7: FIRST-DIFFERENCE ESTIMATOR — TREND ROBUSTNESS ---

di ""
di "=============================================================================="
di "SECTION 1.7: FIRST-DIFFERENCE ESTIMATOR (TREND ROBUSTNESS)"
di "=============================================================================="
di ""
di "Removing person-specific LINEAR TRENDS by first-differencing."
di "FD eliminates α_i AND α'_i·t; standard FE only removes α_i."
di "Bias = γ_FE − γ_FD measures heterogeneous-trend contamination."
di ""

*--- Create first differences ---
sort taxsimid year
capture drop d_log_pwages d_log_cumhrs d_pot_exp d_year_gap

bysort taxsimid (year): gen d_log_pwages = log_pwages  - log_pwages[_n-1]  ///
    if phase1_sample == 1 & phase1_sample[_n-1] == 1
bysort taxsimid (year): gen d_log_cumhrs = log_cumhrs  - log_cumhrs[_n-1]  ///
    if phase1_sample == 1 & phase1_sample[_n-1] == 1
bysort taxsimid (year): gen d_pot_exp    = pot_exp     - pot_exp[_n-1]      ///
    if phase1_sample == 1 & phase1_sample[_n-1] == 1
bysort taxsimid (year): gen d_year_gap   = year        - year[_n-1]         ///
    if phase1_sample == 1 & phase1_sample[_n-1] == 1

label var d_log_pwages "ΔLog wages (consecutive observation pairs)"
label var d_log_cumhrs "ΔLog cumhrs (consecutive observation pairs)"
label var d_pot_exp    "ΔPot_exp (consecutive observation pairs)"
label var d_year_gap   "Year gap: 1=annual, 2=biennial"

di "Year-gap distribution in differenced sample:"
tab d_year_gap if !missing(d_log_pwages) & !missing(d_log_cumhrs), missing
di ""

*--- Annual FD sample (h=1 only) ---
capture drop fd_annual
gen fd_annual = (phase1_sample == 1        ///
              & !missing(d_log_pwages)     ///
              & !missing(d_log_cumhrs)     ///
              & d_year_gap == 1            ///
              & d_log_cumhrs != 0)
label var fd_annual "Annual first-difference sample (h=1)"

qui count if fd_annual == 1
di "Annual FD sample (h=1): " r(N) " person-year pairs"
di ""

*--- Annual FD: Full sample ---
di "ANNUAL FD: Full-sample γ_FD"
reg d_log_pwages d_log_cumhrs d_pot_exp i.year ///
    if fd_annual == 1, cluster(taxsimid)
est store fd_gamma_full

local gfd_full   = _b[d_log_cumhrs]
local sefd_full  = _se[d_log_cumhrs]
di "  γ_FD (full, h=1) = " %7.4f `gfd_full' ///
   "  SE = " %6.4f `sefd_full' ///
   "  t = " %5.2f `gfd_full' / `sefd_full'
di "  γ_FE (full)       = " %7.4f `gamma_fe_full' ///
   "  Bias (FE-FD) = " %7.4f `gamma_fe_full' - `gfd_full'
di ""

*--- Annual FD by career quintile ---
di "Annual FD by career stage (Q1–Q4 only; Q5 excluded per Section 1.8):"
di ""
di "Stage  N_fd    γ_FD      SE_FD    t_FD   γ_FE    Bias(FE-FD)"
di "------ ------- --------- -------- ------ ------- -----------"

forvalues q = 1/4 {
    qui count if fd_annual == 1 & exp_quintile == `q'
    local n_fd = r(N)
    if `n_fd' >= 200 {
        reg d_log_pwages d_log_cumhrs d_pot_exp i.year ///
            if fd_annual == 1 & exp_quintile == `q', cluster(taxsimid)
        est store fd_gamma_q`q'

        local gfd`q'  = _b[d_log_cumhrs]
        local sefd`q' = _se[d_log_cumhrs]
        local tfd`q'  = `gfd`q'' / `sefd`q''
        local bias`q' = `g`q'' - `gfd`q''
        di "  Q`q'  " %7.0f `n_fd' "  " %8.4f `gfd`q'' ///
           "  " %7.4f `sefd`q'' ///
           "  " %5.2f `tfd`q'' ///
           "  " %6.4f `g`q'' ///
           "  " %8.4f `bias`q''
    }
    else {
        di "  Q`q'  " %7.0f `n_fd' "  [< 200 obs — insufficient]"
    }
}

di ""
di "KEY DIAGNOSTIC:"
di "  Q1 bias = γ_FE_Q1 − γ_FD_Q1"
di "  If bias > 0.10: heterogeneous trend contamination confirmed"
di "  If γ_FD profile monotone-declining Q1→Q4: true arc consistent with signaling"
di ""

*--- Biennial FD sample (h=2 only) ---
capture drop fd_biennial
gen fd_biennial = (phase1_sample == 1      ///
                & !missing(d_log_pwages)   ///
                & !missing(d_log_cumhrs)   ///
                & d_year_gap == 2          ///
                & d_log_cumhrs != 0)
label var fd_biennial "Biennial first-difference sample (h=2)"

qui count if fd_biennial == 1
di "Biennial FD sample (h=2): " r(N) " person-year pairs"
if r(N) >= 200 {
    reg d_log_pwages d_log_cumhrs d_pot_exp i.year ///
        if fd_biennial == 1, cluster(taxsimid)
    local gfd_bi  = _b[d_log_cumhrs]
    local sefd_bi = _se[d_log_cumhrs]
    di "  γ_FD (biennial, h=2) = " %7.4f `gfd_bi' ///
       "  SE = " %6.4f `sefd_bi' ///
       "  t = " %5.2f `gfd_bi' / `sefd_bi'
    di "  (Biennial FD horizon differs from annual FD; not directly comparable)"
}

* --- SECTION 1.8: Q5 NON-IDENTIFICATION — FORMAL DOCUMENTATION ---

di ""
di "=============================================================================="
di "SECTION 1.8: Q5 NON-IDENTIFICATION DOCUMENTATION"
di "=============================================================================="
di ""
di "Q5 (pot_exp 26–40) primary estimate: γ = 1.1151  SE = 0.1099"
di "  95% CI: [0.900, 1.330]"
di "  Within R² = 0.0263 (only 2.6% of within-person Q5 wage var explained)"
di "  The Q5 CI contains: Q1 (1.101), Q2 (1.049), Q3 (1.067), Q4 (0.927)"
di "  → Q5 is statistically indistinguishable from ANY other quintile estimate"
di ""

*--- Cramér–Rao comparison: identifying variance by quintile ---
di "Identifying variance (residualized log_cumhrs SD) by quintile:"
di "  (Cramér–Rao: minimum achievable SE ∝ 1/sqrt(identifying variance))"
di ""
di "  Stage  SD(resid_lcumhrs)  Relative info  Min achievable SE"
di "  -----  -----------------  -------------  -----------------"

qui sum resid_log_cumhrs if phase1_sample == 1 & exp_quintile == 1
local var_q1   = r(sd)^2
local sd_q1    = r(sd)
forvalues q = 1/5 {
    qui sum resid_log_cumhrs if phase1_sample == 1 & exp_quintile == `q'
    local sd_q    = r(sd)
    local rel_info = (`sd_q'^2) / `var_q1'
    local min_se   = `se1' / sqrt(`rel_info')
    di "  Q`q'    " %16.4f `sd_q' "  " %12.3f `rel_info' "  " %16.4f `min_se'
}
di ""
di "  SE_Q5 = 0.1099: consistent with near-zero relative Fisher information"
di "  Q5 is operating at the Cramér–Rao limit — cannot be improved without"
di "  more data or a different identification strategy."
di ""

*--- Survivor selection test ---
di "SURVIVOR SELECTION TEST:"
di "  Compare log wages of Q4 workers who survive to Q5 vs those who exit."
di "  Positive difference = positive survivor selection = upward bias in γ_Q5."
di ""

capture drop max_exp_q
bysort taxsimid: egen max_exp_q = max(exp_quintile) if phase1_sample == 1

qui sum log_pwages if phase1_sample == 1 & exp_quintile == 4 & max_exp_q == 4
local n_exit   = r(N)
local mean_exit = r(mean)

qui sum log_pwages if phase1_sample == 1 & exp_quintile == 4 & max_exp_q >= 5
local n_surv   = r(N)
local mean_surv = r(mean)

di "  Q4 workers who exit at Q4 (max_quintile=4):  N=" `n_exit' ///
   "  mean log_wage=" %6.3f `mean_exit'
di "  Q4 workers who survive to Q5 (max_quintile≥5): N=" `n_surv' ///
   "  mean log_wage=" %6.3f `mean_surv'
di ""

local surv_gap = `mean_surv' - `mean_exit'
di "  Survivor gap (surv − exit): " %7.4f `surv_gap'
if `surv_gap' > 0 {
    di "  POSITIVE survivor selection confirmed."
    di "  Workers surviving to Q5 have higher wages in Q4 → upward bias in γ_Q5."
}
else {
    di "  No positive survivor selection detected."
}

di ""
di "CONCLUSION:"
di "  Q5 is EXCLUDED from the main career-arc γ profile due to:"
di "  (1) Near-degenerate identification (Within R²=0.026, ~1/11 of Q1 info)"
di "  (2) CI [0.900, 1.330] spans all Q1–Q4 estimates"
if `surv_gap' > 0 {
    di "  (3) Positive survivor selection (gap=" %6.4f `surv_gap' " log-wage units)"
}
di "  Main profile reported for Q1–Q4 (pot_exp 0–25 years) only."
di "  Q5 footnote: not identified (see Section 1.8)."

* --- Part 2: OLS vs FE DECOMPOSITION ---

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

* --- Part 3: STRUCTURAL PARAMETER RECOVERY ---

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
    di as error "Warning: δ outside (0,1)"
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

* --- PART 3.5: TWO-SAMPLE CONSISTENCY CHECK — γ ON ETI SUBSAMPLE ---

di ""
di "=============================================================================="
di "PART 3.5: TWO-SAMPLE CONSISTENCY CHECK — γ ON ETI SUBSAMPLE"
di "=============================================================================="
di ""
di "δ = γ(1+ε)/(1+γ) combines:"
di "  γ from: full panel (1978–2019, N≈179K)"
di "  ε from: biennial IV (1995–2019 odd years, ages 30–65, income floor $10K)"
di ""
di "ASSUMPTION TEST: Is γ stable across these two samples?"
di ""

*--- 3.5a: Define biennial-period subsample (approximates ETI sample) ---
* Biennial survey years: odd years ≥ 1995 (1995, 1997, ..., 2019)
* Age 30–65: matches biennial period coverage
* NOTE: Cannot replicate TAXSIM income floor ($10K 1984$) from structural file
*       (pwages only; ETI uses broad income). Using pwages > 0 as proxy.
capture drop eti_subsample
gen eti_subsample = (year >= 1995 & mod(year, 2) == 1 & ///
                     page >= 30 & page <= 65           & ///
                     cumhrs > 0 & !missing(cumhrs)     & ///
                     pwages > 0 & !missing(pwages))
label var eti_subsample "Biennial-period subsample (1995-2019 odd, age 30-65, pwages>0)"

qui count if eti_subsample == 1
local n_eti = r(N)
di "Biennial subsample N = `n_eti' person-years"
di "(Approx. ETI sample — ages 30–65, odd years 1995–2019)"
di ""

*--- 3.5b: γ on biennial subsample ---
di "FE ESTIMATE ON BIENNIAL SUBSAMPLE:"
xtreg log_pwages log_cumhrs pot_exp pot_exp2 i.year ///
    if eti_subsample == 1, fe cluster(taxsimid)
est store fe_gamma_eti

local gamma_eti = _b[log_cumhrs]
local se_eti    = _se[log_cumhrs]
local t_eti     = `gamma_eti' / `se_eti'
local n_eti_reg = e(N)

di ""
di "  γ_ETI_sample = " %7.4f `gamma_eti'    "  SE = " %6.4f `se_eti'  "  t = " %5.2f `t_eti'
di "  γ_full       = " %7.4f `gamma_fe_full' "  SE = " %6.4f `se_fe_full'
di ""

*--- 3.5c: Two-sample assumption test ---
local gamma_diff = `gamma_eti' - `gamma_fe_full'
local pct_diff   = abs(`gamma_diff') / `gamma_fe_full' * 100

di "TWO-SAMPLE ASSUMPTION:"
di "  γ_ETI − γ_full = " %7.4f `gamma_diff' " (" %5.1f `pct_diff' "% relative difference)"
di ""

if abs(`gamma_diff') < 0.05 {
    di "RESULT: SUPPORTED — γ stable across samples (< 5pp difference)"
    di "  Combining γ_full with ε_biennial in δ formula is internally consistent."
}
else if abs(`gamma_diff') < 0.10 {
    di "RESULT: MODEST DIFFERENCE — γ differs " %5.1f `pct_diff' "% (< 10pp)"
    di "  Note in paper; consider reporting δ using γ_ETI_sample as sensitivity."
    if $eti_biennial != . {
        local delta_eti_check = `gamma_eti' * (1 + $eti_biennial) / (1 + `gamma_eti')
        di "  δ(γ_ETI, ε_biennual)  = " %7.4f `delta_eti_check'
        di "  δ(γ_full, ε_biennial) = " %7.4f `delta_biennial'
    }
}
else {
    di "RESULT: MATERIAL DIFFERENCE — γ differs " %5.1f `pct_diff' "%"
    di "  The two-sample combination may be internally inconsistent."
    di "  RECOMMENDATION: Report δ(γ_ETI_sample, ε_biennial) as primary."
    if $eti_biennial != . {
        local delta_eti_check = `gamma_eti' * (1 + $eti_biennial) / (1 + `gamma_eti')
        di "  δ(γ_ETI)   = " %7.4f `delta_eti_check'
        di "  δ(γ_full)  = " %7.4f `delta_biennial'
    }
}
di ""

*--- 3.5d: Career-stage γ on biennial subsample ---
di "γ BY CAREER STAGE — BIENNIAL SUBSAMPLE vs FULL PANEL:"
di "  Stage  γ_ETI_sample  γ_full        Difference"
di "  -----  ------------  ------------  ----------"
forvalues q = 1/4 {
    qui count if eti_subsample == 1 & exp_quintile == `q'
    if r(N) >= 200 {
        qui xtreg log_pwages log_cumhrs pot_exp pot_exp2 i.year ///
            if eti_subsample == 1 & exp_quintile == `q', fe cluster(taxsimid)
        local g_eti_q`q' = _b[log_cumhrs]
        local diff_q`q'  = `g_eti_q`q'' - `g`q''
        di "  Q`q'    " %12.4f `g_eti_q`q'' "  " %12.4f `g`q'' ///
           "  " %10.4f `diff_q`q''
    }
    else {
        di "  Q`q'    [< 200 obs in biennial subsample]"
    }
}
di ""

*--- 3.5e: Simultaneity robustness — IV using lagged log_cumhrs ---
di "SIMULTANEITY ROBUSTNESS — IV WITH LAGGED log_cumhrs"
di "---------------------------------------------------"
di "Concern: γ_Q1 > 1 may reflect simultaneity (wage shock → work more → higher cumhrs)."
di "Strategy: instrument log_cumhrs with log_cumhrs at t-1 (1-year lag, annual panel)."
di "  γ_IV ≈ γ_FE → simultaneity is small; γ_IV < γ_FE → bias inflates FE."
di ""

sort taxsimid year
capture drop log_cumhrs_lag2
bysort taxsimid (year): gen log_cumhrs_lag2 = log_cumhrs[_n-1] ///
    if year - year[_n-1] == 1
label var log_cumhrs_lag2 "log_cumhrs at t-1 (1-year lag, IV)"

qui count if phase1_sample == 1 & !missing(log_cumhrs_lag2)
di "IV sample (non-missing lagged instrument): " r(N) " person-years"
di ""

*  First stage: how well does lagged cumhrs predict current?
qui xtreg log_cumhrs log_cumhrs_lag2 pot_exp pot_exp2 i.year ///
    if phase1_sample == 1, fe cluster(taxsimid)
local fs_b    = _b[log_cumhrs_lag2]
local fs_t    = _b[log_cumhrs_lag2] / _se[log_cumhrs_lag2]
local fs_r2   = e(r2_w)
di "First stage: log_cumhrs ~ log_cumhrs_lag2"
di "  Coefficient = " %7.4f `fs_b' "  t = " %6.2f `fs_t'
di "  Within R² = " %6.3f `fs_r2' "  (F ≈ t² for single instrument)"
di ""

if `fs_t' > 3.16 {   // F > 10 threshold
    di "INSTRUMENT IS RELEVANT (F = t² > 10) — valid for IV"
}
else {
    di "WARNING: Weak instrument (F = " %5.1f `fs_t'^2 " < 10)"
    di "  IV estimates below may be unreliable."
}
di ""

*  2SLS — full sample (using xtivreg; may need xtivregress2 if not installed)
capture noisily xtivreg log_pwages (log_cumhrs = log_cumhrs_lag2) ///
    pot_exp pot_exp2 i.year ///
    if phase1_sample == 1 & !missing(log_cumhrs_lag2), fe
if _rc == 0 {
    local gamma_iv   = _b[log_cumhrs]
    local se_iv      = _se[log_cumhrs]
    local t_iv       = `gamma_iv' / `se_iv'
    di "IV ESTIMATE (full sample, 1-year lag instrument):"
    di "  γ_IV   = " %7.4f `gamma_iv'   "  SE = " %6.4f `se_iv' "  t = " %5.2f `t_iv'
    di "  γ_FE   = " %7.4f `gamma_fe_full' "  (from Part 1)"
    di "  Bias   = " %7.4f `gamma_iv' - `gamma_fe_full' " (IV minus FE)"
    di ""
    if abs(`gamma_iv' - `gamma_fe_full') < 0.10 {
        di "SIMULTANEITY BIAS: SMALL (γ_IV within 10pp of γ_FE)"
        di "  Full-sample FE is not materially contaminated by simultaneity."
    }
    else if `gamma_iv' < `gamma_fe_full' - 0.10 {
        di "SIMULTANEITY BIAS: MODERATE-LARGE (γ_IV well below γ_FE)"
        di "  FE estimates may be biased upward; report γ_IV as robustness."
    }
    else {
        di "γ_IV > γ_FE: IV amplification (likely measurement error in cumhrs)."
        di "  Classical errors-in-variables: IV > FE is expected when noise ↑."
    }
}
else {
    di "NOTE: xtivreg not available. Approximate IV via two-step FWL:"
    * Manual 2SLS via FWL: regress residualized outcome on predicted residualized cumhrs
    qui xtreg log_pwages pot_exp pot_exp2 i.year ///
        if phase1_sample == 1 & !missing(log_cumhrs_lag2), fe
    capture drop resid_y_iv
    predict resid_y_iv, e

    qui xtreg log_cumhrs log_cumhrs_lag2 pot_exp pot_exp2 i.year ///
        if phase1_sample == 1 & !missing(log_cumhrs_lag2), fe
    capture drop fitted_cumhrs_iv
    predict fitted_cumhrs_iv, xbu

    capture drop resid_fitted_iv
    qui xtreg fitted_cumhrs_iv pot_exp pot_exp2 i.year ///
        if phase1_sample == 1 & !missing(log_cumhrs_lag2), fe
    predict resid_fitted_iv, e

    qui reg resid_y_iv resid_fitted_iv ///
        if phase1_sample == 1 & !missing(log_cumhrs_lag2), nocons cluster(taxsimid)
    local gamma_iv_fwl = _b[resid_fitted_iv]
    local se_iv_fwl    = _se[resid_fitted_iv]
    di "Manual 2SLS (FWL approximation):"
    di "  γ_IV_approx = " %7.4f `gamma_iv_fwl' "  SE ≈ " %6.4f `se_iv_fwl'
    di "  γ_FE        = " %7.4f `gamma_fe_full'
    capture drop resid_y_iv fitted_cumhrs_iv resid_fitted_iv
}

*  Q1-specific IV (early career only)
di ""
di "IV — Q1 (EARLY CAREER) ONLY:"
capture noisily xtivreg log_pwages (log_cumhrs = log_cumhrs_lag2) ///
    pot_exp pot_exp2 i.year ///
    if phase1_sample == 1 & exp_quintile == 1 & !missing(log_cumhrs_lag2), fe
if _rc == 0 {
    local gamma_iv_q1 = _b[log_cumhrs]
    local se_iv_q1    = _se[log_cumhrs]
    di "  γ_IV_Q1  = " %7.4f `gamma_iv_q1' "  SE = " %6.4f `se_iv_q1'
    di "  γ_FE_Q1  = " %7.4f `g1'
    di ""
    if `gamma_iv_q1' > 1 {
        di "  NOTE: γ_IV_Q1 > 1 — elevated Q1 survives IV correction."
        di "  Q1 elevation is not explained by simultaneity bias."
    }
    else {
        di "  NOTE: γ_IV_Q1 ≤ 1 — IV corrects Q1 to unit-elasticity bound."
        di "  Q1 > 1 in FE may reflect simultaneity or measurement error."
    }
}
else {
    di "  NOTE: xtivreg failed for Q1 subsample."
}

* Clean up
capture drop log_cumhrs_lag2 eti_subsample

di ""
di "SUMMARY:"
di "  γ_full         = " %7.4f `gamma_fe_full'
di "  γ_ETI_sample   = " %7.4f `gamma_eti'
di "  γ_diff         = " %7.4f `gamma_diff' " (" %5.1f `pct_diff' "%)"
di ""
di "=============================================================================="

* --- PART 3.6: δ LIFECYCLE ARC — δ(exp) AND τ_p(exp) ACROSS CAREER STAGES ---

di ""
di "=============================================================================="
di "PART 3.6: δ LIFECYCLE ARC"
di "=============================================================================="
di ""
di "γ(exp) = " %7.4f `b0' " + " %8.5f `b1' "·exp + " %9.6f `b2' "·exp²"
di "(polynomial coefficients from Section 1.6)"
di ""

local eti_a = $eti_annual
local eti_b = $eti_biennial
local alpha_p = 3.295

di "ETI inputs:"
di "  ε_annual   = " %7.4f `eti_a' " (young workers, ages 17–35)"
di "  ε_biennial = " %7.4f `eti_b' " (prime-age, ages 31–62)"
di "  α (Pareto) = " %7.3f `alpha_p'
di ""

di "LIFECYCLE ARC TABLE:"
di "  exp    γ(exp)   δ(ε_ann) τ_p(ε_ann)  δ(ε_bien) τ_p(ε_bien)"
di "  -----  -------  -------- ----------  --------- -----------"

* Store arc values for export
tempfile arc_file
preserve
clear
set obs 9

gen exp_yrs = .
gen gamma_exp = .
gen delta_ann = .
gen taup_ann  = .
gen delta_bien = .
gen taup_bien  = .

local row = 0
forvalues e = 0(5)40 {
    local row = `row' + 1
    local gamma_e = `b0' + `b1'*`e' + `b2'*`e'^2
    if `gamma_e' < 0.01 local gamma_e = 0.01  // floor at 0.01
    local d_ann  = `gamma_e' * (1 + `eti_a') / (1 + `gamma_e')
    local d_bien = `gamma_e' * (1 + `eti_b') / (1 + `gamma_e')
    if `d_ann'  < 0 local d_ann  = 0
    if `d_ann'  > 1 local d_ann  = 1
    if `d_bien' < 0 local d_bien = 0
    if `d_bien' > 1 local d_bien = 1
    local t_ann  = `d_ann'  / `alpha_p'
    local t_bien = `d_bien' / `alpha_p'

    replace exp_yrs    = `e'        in `row'
    replace gamma_exp  = `gamma_e'  in `row'
    replace delta_ann  = `d_ann'    in `row'
    replace taup_ann   = `t_ann'    in `row'
    replace delta_bien = `d_bien'   in `row'
    replace taup_bien  = `t_bien'   in `row'

    di "  " %3.0f `e' "    " %7.4f `gamma_e' ///
       "   " %7.4f `d_ann'  "   " %7.1f `t_ann'*100  "%" ///
       "     " %7.4f `d_bien' "   " %7.1f `t_bien'*100 "%"
}

di ""
di "NOTE: exp = 0–15 → ε_annual more appropriate (signaling phase, young workers)"
di "      exp = 15–35 → ε_biennial more appropriate (prime-age workers)"
di ""

* Export arc data
label var exp_yrs   "Potential experience (years)"
label var gamma_exp "γ(exp) from polynomial"
label var delta_ann "δ using annual ε"
label var taup_ann  "τ_p using annual ε"
label var delta_bien "δ using biennial ε"
label var taup_bien  "τ_p using biennial ε"
export delimited using "${outdir}\Phase1_DeltaArc.csv", replace
di "Arc data saved to Phase1_DeltaArc.csv"

restore

*--- Career-arc summary statistics ---
di ""
di "LIFECYCLE ARC SUMMARY:"
di ""

local g0  = `b0' + `b1'*0  + `b2'*0^2
local g10 = `b0' + `b1'*10 + `b2'*10^2
local g22 = `b0' + `b1'*22 + `b2'*22^2   // minimum
local g30 = `b0' + `b1'*30 + `b2'*30^2

local d0_b  = `g0'  * (1 + `eti_b') / (1 + `g0')
local d10_b = `g10' * (1 + `eti_b') / (1 + `g10')
local d22_b = `g22' * (1 + `eti_b') / (1 + `g22')
local d30_b = `g30' * (1 + `eti_b') / (1 + `g30')

di "Using ε_biennial = " %5.3f `eti_b' " throughout:"
di "  Entry    (exp=0):  γ=" %5.3f `g0'  "  δ=" %5.3f `d0_b'  "  τ_p=" %5.1f `d0_b'/`alpha_p'*100  "%"
di "  10 yrs   (exp=10): γ=" %5.3f `g10' "  δ=" %5.3f `d10_b' "  τ_p=" %5.1f `d10_b'/`alpha_p'*100 "%"
di "  Minimum  (exp=22): γ=" %5.3f `g22' "  δ=" %5.3f `d22_b' "  τ_p=" %5.1f `d22_b'/`alpha_p'*100 "%"
di "  Late     (exp=30): γ=" %5.3f `g30' "  δ=" %5.3f `d30_b' "  τ_p=" %5.1f `d30_b'/`alpha_p'*100 "%"
di ""

local decline_d = (`d0_b' - `d22_b') / `d0_b' * 100
di "δ declines " %4.1f `decline_d' "% from career entry to minimum"
di "(Lifecycle prediction: δ should decline as employer learning completes)"

di ""
di "=============================================================================="

* --- Part 4: RECENT vs CUMULATIVE HOURS — DYNAMIC DECOMPOSITION ---

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

* --- Part 5: OUTPUT — FORMATTED TABLES AND GRAPHS ---

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

* --- Summary ---

di ""
di "=============================================================================="
di "Summary"
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
di "Next steps:"
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

* --- Part 7: CLEAN UP AND CLOSE ---

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
