* Labor_Wedge_Estimation.do
* Estimates the labor wedge chi = 1/(1 - tau_L) from combined ETI and
* participation elasticity. Uses reform x income interactions as instruments.
* Input:  data/nlsy_long_pre_taxsim.dta, TAXSIM outputs
* Output: Phase2 labor wedge tables

clear all
set more off
capture log close _all

global projdir "D:\Stata Data\labor_signaling_project"
global datadir "${projdir}\data"
global outdir  "${projdir}\output"

log using "${outdir}\Labor_Wedge_log.txt", replace text

di ""
di "=============================================================================="
di "LABOR WEDGE ESTIMATION (PHASE 2)"
di "=============================================================================="
di "χ(y) = 1 + ε^w_r / η^P_r"
di "Pigouvian correction: τ_p(y) = 1 − χ(y)"
di "Start time: $S_DATE $S_TIME"
di ""

* --- Part 0: VERIFY INPUTS ---

di "=============================================================================="
di "PART 0: VERIFY INPUTS"
di "=============================================================================="

foreach f in "analysis_annual" "analysis_biennial" "nlsy_long_pre_taxsim" {
    capture confirm file "${datadir}\\`f'.dta"
    if _rc != 0 {
        di as error "ERROR: `f'.dta not found."
        if "`f'" == "analysis_annual" | "`f'" == "analysis_biennial" {
            di as error "  Run Two_Period_Analysis.do first."
        }
        log close
        error 601
    }
}
di "All required input files confirmed."
di ""

use "${datadir}\BLS_CPI.dta", clear
qui sum CPI if year == 1984
global cpi_1984 = r(mean)

* --- Part 1: INTENSIVE MARGIN — WAGE ELASTICITY ε^w_r BY INCOME DECILE ---

di "=============================================================================="
di "PART 1: INTENSIVE WAGE ELASTICITY ε^w_r BY INCOME DECILE AND PERIOD"
di "=============================================================================="

*--- 1.1: Annual period ---
di ""
di "1.1 ANNUAL PERIOD (1978-1993): ε^w_r"
di "-------------------------------------"

use "${datadir}\analysis_annual.dta", clear
di "Loaded analysis_annual.dta: " _N " obs"

* Assign income deciles by baseline income
xtile inc_decile = log_income_t, nq(10)
label var inc_decile "Income decile (log income at base year)"

* Assign career stage quartiles
xtile career_q = age_t, nq(4)
label var career_q "Career stage (age quartile)"

* Full-sample ETI (intensive margin = ε^w_r)
di ""
di "Full-sample ε^w_r (intensive wage elasticity):"
ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 married i.year_t ///
    [aweight=income_weight], cluster(taxsimid)
est store eps_annual_full

scalar eps_w_annual = _b[log_ntr_change]
scalar se_eps_annual = _se[log_ntr_change]

di "  ε^w_r (annual) = " %7.4f eps_w_annual ///
   "  SE = " %6.4f se_eps_annual

* First-stage F-stat (critical for validity)
qui regress log_ntr_change log_ntr_instrument ///
    log_income_t spline1-spline9 married i.year_t ///
    [aweight=income_weight], cluster(taxsimid)
qui test log_ntr_instrument
scalar F_annual = r(F)
di "  First-stage F = " %7.2f F_annual
if F_annual < 10 {
    di as error "  WARNING: Weak instrument (F < 10). IV estimates unreliable."
}
else {
    di "  GOOD: F-stat > 10"
}

* By income decile
di ""
di "ε^w_r by income decile (annual period):"
di "Decile  ε^w_r     SE        t     N"
di "------  --------- --------- ----- ----"

forvalues d = 1/10 {
    qui count if inc_decile == `d'
    local n_d = r(N)
    if `n_d' >= 50 {
        qui ivregress 2sls log_income_change ///
            (log_ntr_change = log_ntr_instrument) ///
            log_income_t spline1-spline9 married i.year_t ///
            if inc_decile == `d' [aweight=income_weight], robust
        scalar eps_d`d'_ann = _b[log_ntr_change]
        scalar se_d`d'_ann  = _se[log_ntr_change]
        est store eps_ann_d`d'
        di "  D" %02.0f `d' "    " %7.4f eps_d`d'_ann ///
           "   " %7.4f se_d`d'_ann ///
           "   " %5.2f eps_d`d'_ann/se_d`d'_ann ///
           "   " %5.0f `n_d'
    }
    else {
        di "  D" %02.0f `d' "    [< 50 obs, skipped]"
        scalar eps_d`d'_ann = .
        scalar se_d`d'_ann = .
    }
}

* By career stage (age quartile)
di ""
di "ε^w_r by career stage / age quartile (annual period):"
di "Stage   ε^w_r     SE        t     Age range"
di "------  --------- --------- ----- ---------"

forvalues q = 1/4 {
    qui count if career_q == `q'
    if r(N) >= 50 {
        qui sum age_t if career_q == `q'
        local age_min = r(min)
        local age_max = r(max)

        capture qui ivregress 2sls log_income_change ///
            (log_ntr_change = log_ntr_instrument) ///
            log_income_t spline1-spline9 married i.year_t ///
            if career_q == `q' [aweight=income_weight], robust
        if _rc != 0 {
            di "  Q`q'     [identification failure in subsample r(_rc)=" _rc "]"
            scalar eps_q`q'_ann = .
            scalar se_q`q'_ann  = .
        }
        else {
            scalar eps_q`q'_ann = _b[log_ntr_change]
            scalar se_q`q'_ann  = _se[log_ntr_change]
            est store eps_ann_q`q'

            di "  Q`q'     " %7.4f eps_q`q'_ann ///
               "   " %7.4f se_q`q'_ann ///
               "   " %5.2f eps_q`q'_ann/se_q`q'_ann ///
               "   " %2.0f `age_min' "-" %2.0f `age_max'
        }
    }
    else {
        di "  Q`q'     [< 50 obs, skipped]"
        scalar eps_q`q'_ann = .
    }
}

save "${datadir}\analysis_annual_augmented.dta", replace

*--- 1.2: Biennial period ---
di ""
di "1.2 BIENNIAL PERIOD (1995-2019): ε^w_r"
di "---------------------------------------"

use "${datadir}\analysis_biennial.dta", clear
di "Loaded analysis_biennial.dta: " _N " obs"

xtile inc_decile = log_income_t, nq(10)
xtile career_q = age_t, nq(4)

* Full-sample biennial ETI
ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 married i.year_t ///
    [aweight=income_weight], cluster(taxsimid)
est store eps_biennial_full

scalar eps_w_biennial = _b[log_ntr_change]
scalar se_eps_biennial = _se[log_ntr_change]

di "  ε^w_r (biennial) = " %7.4f eps_w_biennial ///
   "  SE = " %6.4f se_eps_biennial

qui regress log_ntr_change log_ntr_instrument ///
    log_income_t spline1-spline9 married i.year_t ///
    [aweight=income_weight], cluster(taxsimid)
qui test log_ntr_instrument
scalar F_biennial = r(F)
di "  First-stage F = " %7.2f F_biennial

* By career stage (age quartile, biennial)
di ""
di "ε^w_r by career stage (biennial period):"

forvalues q = 1/4 {
    qui count if career_q == `q'
    if r(N) >= 50 {
        qui sum age_t if career_q == `q'
        local age_min = r(min)
        local age_max = r(max)

        capture qui ivregress 2sls log_income_change ///
            (log_ntr_change = log_ntr_instrument) ///
            log_income_t spline1-spline9 married i.year_t ///
            if career_q == `q' [aweight=income_weight], robust
        if _rc != 0 {
            di "  Q`q'     [identification failure r(_rc)=" _rc "]"
            scalar eps_q`q'_bien = .
            scalar se_q`q'_bien  = .
        }
        else {
            scalar eps_q`q'_bien = _b[log_ntr_change]
            scalar se_q`q'_bien  = _se[log_ntr_change]

            di "  Q`q'     " %7.4f eps_q`q'_bien ///
               "   " %7.4f se_q`q'_bien ///
               "   Ages " %2.0f `age_min' "-" %2.0f `age_max'
        }
    }
    else {
        scalar eps_q`q'_bien = .
    }
}

save "${datadir}\analysis_biennial_augmented.dta", replace

* --- Part 2: EXTENSIVE MARGIN - PARTICIPATION ELASTICITY eta^P_r (FULL IV) ---

di ""
di "=============================================================================="
di "PART 2: EXTENSIVE MARGIN - PARTICIPATION ELASTICITY eta^P_r (FULL IV)"
di "=============================================================================="
di ""
di "Loading full paired sample (near-workers + main workers, no $10K floor)..."
di ""

use "${datadir}\paired_annual_with_inflation.dta", clear
di "  Loaded paired_annual_with_inflation: " _N " obs"

*--- Merge in counterfactual predicted rates (run for ALL pairs before floor) ---
merge 1:1 taxsimid year_t using "${datadir}\predicted_rates_annual.dta", ///
    keep(match master) nogen
di "  After merge with predicted_rates: " _N " obs"

*--- Construct broad income at t and t+3 (matching Two_Period_Analysis.do A6) ---
foreach var in pwages swages psemp ssemp pui sui gssi pensions nonprop {
    capture replace `var'_t  = 0 if missing(`var'_t)
    capture replace `var'_t3 = 0 if missing(`var'_t3)
}

gen broad_income_t  = pwages_t  + swages_t  + psemp_t  + ssemp_t  + ///
                      pui_t  + sui_t  + gssi_t  + pensions_t  + nonprop_t
gen broad_income_t3 = pwages_t3 + swages_t3 + psemp_t3 + ssemp_t3 + ///
                      pui_t3 + sui_t3 + gssi_t3 + pensions_t3 + nonprop_t3

*--- Real income in 1984 dollars ---
gen real_income_t  = broad_income_t  * (${cpi_1984} / cpi_t)
gen real_income_t3 = broad_income_t3 * (${cpi_1984} / cpi_t3)

*--- Sample composition before filters ---
di ""
di "Sample composition at baseline year:"
count if real_income_t < 500 | missing(real_income_t)
di "  Below threshold (<$500 real): " r(N) " (excluded)"
count if real_income_t >= 500 & real_income_t < 10000 & !missing(real_income_t)
local n_near = r(N)
di "  Near-workers ($500 - $10K real): `n_near'"
count if real_income_t >= 10000 & !missing(real_income_t)
local n_main = r(N)
di "  Main workers (>= $10K real): `n_main'"

*--- Keep base-year participants ---
keep if real_income_t >= 500 & !missing(real_income_t)

*--- Marital stability (same as Part 1 intensive sample) ---
keep if mstat_t == mstat_t3

*--- Participation outcome at t+3 ---
gen worked_t3 = (real_income_t3 >= 500 & !missing(real_income_t3))
gen d_worked  = worked_t3 - 1   // 0=stayer, -1=exiter

di ""
di "Exit rates by income group:"
qui sum d_worked if real_income_t < 10000, meanonly
di "  Near-workers : exit rate = " %5.1f abs(r(mean))*100 " %"
qui sum d_worked if real_income_t >= 10000, meanonly
di "  Main workers : exit rate = " %5.1f abs(r(mean))*100 " %"

*--- Drop invalid MTR observations ---
drop if missing(mtr_fed_t) | missing(mtr_fed_predicted)
drop if mtr_fed_t < -10 | mtr_fed_predicted < -10

*--- Build Gruber-Saez instrument for participation sample ---
* Use _p suffix to avoid name collisions with Part 1 variables (no longer in memory)
gen ntr_t_p         = max(0.01, 1 - mtr_fed_t/100)
gen ntr_predicted_p = max(0.01, 1 - mtr_fed_predicted/100)
gen ntr_end_p       = max(0.01, 1 - mtr_fed_t3/100)

gen log_ntr_t_p          = ln(ntr_t_p)
gen log_ntr_predicted_p  = ln(ntr_predicted_p)
gen log_ntr_end_p        = ln(ntr_end_p)

gen log_ntr_instrument_p = log_ntr_predicted_p - log_ntr_t_p
gen log_ntr_change_p     = log_ntr_end_p       - log_ntr_t_p

*--- Controls ---
gen log_income_t_p = ln(max(broad_income_t, 1))
gen married        = (mstat_t == 2)

*--- 10-piece income spline for participation sample ---
quietly _pctile log_income_t_p, p(10 20 30 40 50 60 70 80 90)
forval i = 1/9 {
    local pknot`i' = r(r`i')
    gen pspline`i' = max(0, log_income_t_p - `pknot`i'')
}

di ""
di "Participation sample after all filters: " _N " obs"
di "Instrument summary:"
sum log_ntr_instrument_p log_ntr_change_p d_worked
di ""

save "${datadir}\participation_sample_annual.dta", replace

*--- 2.3: First-stage F-stat for participation IV ---
di ""
di "PARTICIPATION FIRST STAGE:"
qui regress log_ntr_change_p log_ntr_instrument_p ///
    log_income_t_p pspline1-pspline9 married i.year_t ///
    [aweight=broad_income_t], cluster(taxsimid)
qui test log_ntr_instrument_p
scalar F_fs_part = r(F)
di "  First-stage F = " %7.2f F_fs_part
if F_fs_part < 10 {
    di as error "  WARNING: Weak first stage for participation IV (F < 10)"
}
else {
    di "  GOOD: First-stage F > 10"
}

*--- 2.4: IV estimate of eta^P_r ---
di ""
di "eta^P_r FULL SAMPLE (2SLS):"
ivregress 2sls d_worked ///
    (log_ntr_change_p = log_ntr_instrument_p) ///
    log_income_t_p pspline1-pspline9 married i.year_t ///
    [aweight=broad_income_t], cluster(taxsimid)
est store eta_P_full

scalar eta_P_annual    = _b[log_ntr_change_p]
scalar se_eta_P_annual = _se[log_ntr_change_p]

di ""
di "  eta^P_r (annual, IV) = " %8.4f eta_P_annual ///
   "  SE = " %7.4f se_eta_P_annual ///
   "  N = " e(N)
di ""
di "  Sztutman (HRS 2yr) : eta^P_r = +0.10"
di "  Sztutman (HRS 4yr) : eta^P_r = +0.01"
di "  Sztutman (HRS 6yr) : eta^P_r = +0.03"
di ""
if eta_P_annual > 0 {
    di "  SIGN CHECK PASS: eta^P_r > 0 -- tax cut retains more workers"
}
else {
    di "  SIGN CHECK: eta^P_r < 0 -- income effect may dominate for young workers"
    di "  Note: NLSY79 workers (ages 17-35) are not at the retirement margin."
    di "  Near-zero or negative eta^P_r is theoretically plausible for this cohort."
}

*--- 2.5: eta^P_r by income group ---
di ""
di "eta^P_r by income group:"

qui count if real_income_t < 10000
if r(N) >= 50 {
    capture ivregress 2sls d_worked ///
        (log_ntr_change_p = log_ntr_instrument_p) ///
        log_income_t_p pspline1-pspline9 married i.year_t ///
        if real_income_t < 10000 [aweight=broad_income_t], robust
    if _rc == 0 {
        di "  Near-workers ($500-$10K): eta^P_r = " %7.4f _b[log_ntr_change_p] ///
           "  SE = " %7.4f _se[log_ntr_change_p] "  N=" e(N)
        scalar eta_P_near = _b[log_ntr_change_p]
    }
    else {
        scalar eta_P_near = .
    }
}

qui count if real_income_t >= 10000
if r(N) >= 50 {
    capture ivregress 2sls d_worked ///
        (log_ntr_change_p = log_ntr_instrument_p) ///
        log_income_t_p pspline1-pspline9 married i.year_t ///
        if real_income_t >= 10000 [aweight=broad_income_t], robust
    if _rc == 0 {
        di "  Main workers (>=$10K):    eta^P_r = " %7.4f _b[log_ntr_change_p] ///
           "  SE = " %7.4f _se[log_ntr_change_p] "  N=" e(N)
        scalar eta_P_main = _b[log_ntr_change_p]
    }
    else {
        scalar eta_P_main = .
    }
}

* --- Part 3: COMPUTE chi = 1 + eps^w_r / eta^P_r (FULL IV) ---

di ""
di "=============================================================================="
di "PART 3: LABOR WEDGE chi = 1 + eps^w_r / eta^P_r"
di "=============================================================================="
di ""
di "  eps^w_r (annual, IV) = " %8.4f eps_w_annual  "  SE = " %6.4f se_eps_annual
di "  eta^P_r (annual, IV) = " %8.4f eta_P_annual  "  SE = " %6.4f se_eta_P_annual
di ""

if abs(eta_P_annual) < 0.0001 | missing(eta_P_annual) {
    di as error "NEAR-ZERO eta^P_r: chi = 1 + eps/eta is non-finite."
    di as error "  eta^P_r = " %8.4f eta_P_annual
    di as error "  Setting chi = . (undefined)"
    scalar chi_full    = .
    scalar tau_p_wedge = .
    * Floor for downstream part 6 computations
    scalar eta_P_annual = 0.0001
}
else {
    scalar chi_full    = 1 + eps_w_annual / eta_P_annual
    scalar tau_p_wedge = 1 - chi_full

    di "  chi = 1 + eps/eta   = " %8.4f chi_full
    di "  tau_p = 1 - chi     = " %8.4f tau_p_wedge
    di ""
    di "  COMPARISON TO SZTUTMAN (2024, HRS, 4yr horizon):"
    di "    Sztutman eps^w_r = -0.16,  eta^P_r = 0.01"
    di "    Sztutman chi (full-sample ratio) = 1 + (-0.16/0.01) = -15"
    di "    Sztutman chi (local polynomial Figure 3) = 0.5 - 1.0"
    di "    Sztutman tau_p average ~5% (from local polynomial)"
    di ""

    if chi_full < 0 | chi_full > 5 {
        di as error "Check: chi = " %8.4f chi_full " outside plausible range [0,5]"
        di as error "  Likely cause: eta^P_r near zero for ages 17-35 workers."
        di as error "  The full-sample pooled ratio eps/eta blows up when eta -> 0."
        di as error "  This matches Sztutman's own experience: his Figure 3 uses local"
        di as error "  polynomial methods precisely to handle this blow-up."
        di as error "  PRIMARY IDENTIFICATION: Use structural tau_p = delta/alpha (Phase 5)."
        di as error "  The chi computation here is COMPLEMENTARY."
    }
    else if chi_full < 1 {
        di "RESULT: chi < 1 -- POSITIVE SIGNALING EXTERNALITY"
        di "  Workers paid " %5.1f (1-chi_full)*100 "% more than marginal product"
        di "  Pigouvian tax: tau_p = " %5.1f tau_p_wedge*100 "%"
    }
    else {
        di "RESULT: chi >= 1 -- No signaling externality from wage-wedge channel"
        di "  Consistent with: young workers not yet at retirement margin"
        di "  See Phase 5 structural tau_p for preferred estimate."
    }
}


* --- Part 4: DYNAMIC WEDGE PROFILE χ BY CAREER STAGE ---

di ""
di "=============================================================================="
di "PART 4: DYNAMIC WEDGE PROFILE BY CAREER STAGE"
di "=============================================================================="
di ""
di "Combining annual (young) and biennial (older) periods to trace χ over career"
di ""

* Build unified career-stage elasticity table
* Annual period provides age groups 1-4 (younger workers)
* Biennial period provides age groups 1-4 (older workers)
* Together they span the full career arc

di "Career-stage ε^w_r profile (annual + biennial periods):"
di ""
di "Stage  Period    Age Range  ε^w_r    SE"
di "------ --------- ---------- -------- --------"

forvalues q = 1/4 {
    capture scalar e_a = eps_q`q'_ann
    if !missing(eps_q`q'_ann) {
        di "  Q`q'   Annual    [see log] " %8.4f eps_q`q'_ann ///
           "   " %6.4f se_q`q'_ann
    }
}

di ""
forvalues q = 1/4 {
    capture scalar e_b = eps_q`q'_bien
    if !missing(eps_q`q'_bien) {
        di "  Q`q'   Biennial  [see log] " %8.4f eps_q`q'_bien ///
           "   " %6.4f se_q`q'_bien
    }
}

di ""
di "INTERPRETATION:"
di "  If ε^w_r is larger in annual period (young workers) than biennial (older):"
di "  → Young workers are MORE responsive to tax changes"
di "  → In Sztutman framework: higher ε → lower χ (larger distortion) for young"
di "  → Consistent with employer uncertainty being greatest early career"
di ""
di "  Pareto case: ε^w_r should be approximately CONSTANT across career stages"
di "  (labor supply elasticity is a preference parameter, not career-stage specific)"

* --- Part 5: COMPREHENSIVE χ PROFILE — FIGURES AND TABLES ---

di ""
di "=============================================================================="
di "PART 5: FIGURES AND TABLES"
di "=============================================================================="

*--- Table 1: ε^w_r estimates by decile and period ---
use "${datadir}\analysis_annual_augmented.dta", clear
est restore eps_annual_full

capture noisily esttab eps_annual_full eps_biennial_full ///
    using "${outdir}\Phase2_Table3_Elasticities.rtf", replace ///
    keep(log_ntr_change) ///
    b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N, fmt(%12.0fc) labels("Observations")) ///
    mtitles("Annual (ε^w_r)" "Biennial (ε^w_r)") ///
    title("Table 3: Intensive Wage Elasticity ε^w_r by Period") ///
    note("2SLS using Gruber-Saez simulated MTR instrument." ///
         "Annual period: 1978-1993, 3-year differences." ///
         "Biennial period: 1995-2019, 2-year differences.")
if _rc != 0 di "WARNING: esttab failed. Install estout: ssc install estout"

*--- Figure 1: ε^w_r by income decile (annual) ---
preserve
clear
set obs 10
gen decile = _n
gen eps_w = .
gen eps_lo = .
gen eps_hi = .
forvalues d = 1/10 {
    capture {
        replace eps_w  = eps_d`d'_ann                         in `d'
        replace eps_lo = eps_d`d'_ann - 1.96 * se_d`d'_ann   in `d'
        replace eps_hi = eps_d`d'_ann + 1.96 * se_d`d'_ann   in `d'
    }
}

capture noisily twoway ///
    (rcap eps_hi eps_lo decile, lcolor(navy) lwidth(thin)) ///
    (connected eps_w decile, ///
        lcolor(navy) lwidth(medium) msymbol(circle) mcolor(navy)), ///
    yline(0, lcolor(gs8) lpattern(dash)) ///
    title("Wage Elasticity (eps^w_r) by Income Decile" ///
          "Annual Period 1978-1993", size(medium)) ///
    subtitle("Note: eps^w_r combined with eta^P_r to compute chi = 1 + eps^w_r/eta^P_r") ///
    xtitle("Income Decile (base-year income)") ///
    ytitle("eps^w_r = d log(income) / d log(1-tau)") ///
    xlabel(1(1)10) legend(off) ///
    note("2SLS, Gruber-Saez instrument. 95% confidence intervals shown.")
capture noisily graph export "${outdir}\Phase2_Fig1_EpsWProfile.png", replace width(1400)
restore

*--- Figure 2: ε^w_r by career stage — annual vs biennial ---
preserve
clear
set obs 8
gen period_q = _n
gen eps_w = .
gen eps_lo = .
gen eps_hi = .
gen period_label = ""

forvalues q = 1/4 {
    local row_a = `q'
    local row_b = `q' + 4
    capture replace eps_w    = eps_q`q'_ann                      in `row_a'
    capture replace eps_lo   = eps_q`q'_ann - 1.96*se_q`q'_ann  in `row_a'
    capture replace eps_hi   = eps_q`q'_ann + 1.96*se_q`q'_ann  in `row_a'
    capture replace eps_w    = eps_q`q'_bien                     in `row_b'
    capture replace eps_lo   = eps_q`q'_bien - 1.96*se_q`q'_bien in `row_b'
    capture replace eps_hi   = eps_q`q'_bien + 1.96*se_q`q'_bien in `row_b'
}
replace period_label = "Annual Q" + string(period_q) if period_q <= 4
replace period_label = "Bienial Q" + string(period_q-4) if period_q > 4

gen period = (period_q > 4)  // 0=annual, 1=biennial

capture noisily twoway ///
    (rcap eps_hi eps_lo period_q if period == 0, lcolor(navy)) ///
    (connected eps_w period_q if period == 0, ///
        lcolor(navy) msymbol(circle) mcolor(navy) lwidth(medium)) ///
    (rcap eps_hi eps_lo period_q if period == 1, lcolor(maroon)) ///
    (connected eps_w period_q if period == 1, ///
        lcolor(maroon) msymbol(square) mcolor(maroon) lwidth(medium)), ///
    yline(0, lcolor(gs8) lpattern(dash)) ///
    title("Dynamic Wage Elasticity Profile" ///
          "eps^w_r by Career Stage Quarter and Survey Period", size(medium)) ///
    subtitle("NLSY contribution: full career arc not available in HRS") ///
    xtitle("Career Stage Quartile (within period)") ///
    ytitle("eps^w_r = d log(income) / d log(1-tau)") ///
    legend(order(2 "Annual period (ages ~17-35)" 4 "Biennial period (ages ~31-62)") ///
           pos(1) ring(0) rows(2)) ///
    xlabel(1 "Q1" 2 "Q2" 3 "Q3" 4 "Q4" 5 "Q1" 6 "Q2" 7 "Q3" 8 "Q4") ///
    note("95% CIs shown. Flat profile implies constant elasticity (Pareto case).")
capture noisily graph export "${outdir}\Phase2_Fig2_DynamicEps.png", replace width(1400)
restore

* --- Part 6: PRELIMINARY PIGOUVIAN TAX PROFILE ---

di ""
di "=============================================================================="
di "PART 6: PRELIMINARY PIGOUVIAN TAX PROFILE"
di "=============================================================================="
di ""
di "τ_p(y) = 1 − χ(y) = −ε^w_r(y) / η^P_r(y)"
di ""
di "Note: Using full-sample η^P_r approximation from Part 3."
di "      Decile-specific η^P_r: FUTURE EXTENSION (needs TAXSIM re-run)."
di ""

* Assuming η^P_r is roughly constant across deciles (simplifying assumption)
* This gives τ_p(y) profile driven by ε^w_r(y) variation

di "Preliminary Pigouvian tax profile by income decile:"
di "(Assumes constant η^P_r; update after TAXSIM expansion)"
di ""
di "Decile  ε^w_r     χ(approx)  τ_p(approx)"
di "------  --------- ---------- ----------"

preserve
clear
set obs 10
gen decile = _n
gen eps_w = .
gen chi_approx = .
gen tau_p = .

forvalues d = 1/10 {
    capture replace eps_w      = eps_d`d'_ann                          in `d'
    capture replace chi_approx = 1 + eps_d`d'_ann / eta_P_annual      in `d'
    capture replace tau_p      = 1 - (1 + eps_d`d'_ann/eta_P_annual)  in `d'
}

list decile eps_w chi_approx tau_p, clean noobs

export delimited using "${outdir}\Phase2_Table4_Pigouvian.csv", replace
restore

* --- Summary ---

di ""
di "=============================================================================="
di "Summary"
di "=============================================================================="
di ""

di "CRITICAL CHECKS:"
di ""
di "CHECK 1 — ε^w_r sign and magnitude"
if eps_w_annual > 0 {
    di "  PASS: ε^w_r > 0 (wages rise when net-of-tax rate rises)"
    di "  Annual:   " %7.4f eps_w_annual
    di "  Biennial: " %7.4f eps_w_biennial
}
else {
    di "  CAUTION: ε^w_r < 0. Wages falling when retention rises is unusual."
    di "  Possible cause: income effect dominates substitution effect"
    di "  Check: are top-bracket workers actually cutting hours? (Saez et al. 2012)"
}

di ""
di "CHECK 2 — First-stage validity"
di "  Annual F-stat:   " %7.2f F_annual
di "  Biennial F-stat: " %7.2f F_biennial
if F_annual > 10 & F_biennial > 10 {
    di "  PASS: Both first stages are strong"
}
else {
    di "  CONCERN: Weak instrument in one or both periods"
    di "  Consider: (a) restrict to pure tax-cut reform windows"
    di "             (b) use broader income bandwidth"
    di "             (c) check if simulated MTR actually varies in NLSY sample"
}

di ""
di "CHECK 3 — ε^w_r stability across career stages"
di "  Annual Q1:  " %7.4f eps_q1_ann "  Q4: " %7.4f eps_q4_ann
di "  If Q1 ≈ Q4 → consistent with Pareto constant-elasticity case"
di "  If Q1 > Q4 → younger workers more elastic → dynamic model"

di ""
di "CHECK 4 — η^P_r quality"
di "  STATUS: FULL IV estimated in Part 2 (near-workers + main-workers)"
di "  eta^P_r (annual, IV) = " %7.4f eta_P_annual "  SE = " %7.4f se_eta_P_annual
di "  Participation first-stage F = " %7.2f F_fs_part
di "  Compare Sztutman (HRS 4yr): eta^P_r = +0.01"
di "  Compare Sztutman (HRS 2yr): eta^P_r = +0.10"

di ""
di "Next steps:"
di ""
if eps_w_annual > 0 & F_annual > 10 {
    di "  ε^w_r is identified. Proceed to Phase 3 (advantageous selection)."
    di "  When Phase 3 confirms selection: χ < 1 interpretation is credible."
    di "  When Phase 1 γ confirms pattern: structural δ recovery is credible."
    di ""
    di "  NEXT STEPS FOR THIS FILE:"
    di "  1. DONE: eta^P_r estimated via full IV in Part 2"
    di "  2. Run local polynomial chi(y) profile (Sztutman Figure 3 replication)"
    di "  3. Compare tau_p(y) by income group to Sztutman"
    di "  4. Phase 5 remains the primary structural identification for tau_p"
}
else {
    di "  ISSUES WITH IDENTIFICATION — Escalate before Phase 3."
}

di ""
di "=============================================================================="
di "OUTPUT FILES CREATED"
di "=============================================================================="
di ""
di "Tables (${outdir}):"
di "  Phase2_Table3_Elasticities.rtf    : ε^w_r by period"
di "  Phase2_Table4_Pigouvian.csv       : Preliminary τ_p by decile"
di ""
di "Figures (${outdir}):"
di "  Phase2_Fig1_EpsWProfile.png       : ε^w_r by income decile"
di "  Phase2_Fig2_DynamicEps.png        : ε^w_r by career stage, both periods"
di ""
di "Log (${outdir}):"
di "  Labor_Wedge_log.txt"
di ""
di "=============================================================================="
di "PHASE 2 COMPLETE (PRELIMINARY)"
di "=============================================================================="
di "End time: $S_DATE $S_TIME"
di ""
di "CRITICAL NEXT STEP:"
di "  Expand TAXSIM to near-worker sample to enable full η^P_r estimation."
di "  This is necessary for precise χ and τ_p computation."

log close
