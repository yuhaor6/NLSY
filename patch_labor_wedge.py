"""
Patch Labor_Wedge_Estimation.do:
Replace old reduced-form Part 2 + Part 3 with full IV estimation of eta^P_r.
"""

import sys

filepath = r"do file\Labor_Wedge_Estimation.do"

with open(filepath, "r", encoding="utf-8", errors="replace") as f:
    content = f.read()

# Find exact boundaries
PART2_MARKER = "\n/*==============================================================================\nPART 2: EXTENSIVE MARGIN"
PART4_MARKER = "\n/*==============================================================================\nPART 4: DYNAMIC"

p2 = content.find(PART2_MARKER)
p4 = content.find(PART4_MARKER)

if p2 == -1 or p4 == -1:
    print("ERROR: markers not found", p2, p4)
    sys.exit(1)

print(f"Part 2 start: {p2}, Part 4 start: {p4}, old section length: {p4-p2}")

# Build the new Part 2 + Part 3 section
NEW_SECTION = r"""
/*==============================================================================
PART 2: EXTENSIVE MARGIN - PARTICIPATION ELASTICITY eta^P_r (FULL IV)
================================================================================
Uses the FULL paired sample from Two_Period_Analysis.do WITHOUT the $10K real
income floor that filtered the intensive margin sample (Part 1).

KEY INSIGHT: In Two_Period_Analysis.do the TAXSIM counterfactual (applying
year t+3 tax law to inflated year t income) was run on ALL paired observations
BEFORE the $10K income floor was applied; predicted_rates_annual.dta therefore
contains the Gruber-Saez instrument for near-workers ($500-$10K) too.

SAMPLE: Everyone with real income >= $500 (1984$) at year t, stable marital
        status over the 3-year window. Includes:
          Near-workers : $500 - $10,000 real  (the participation margin)
          Main workers : >= $10,000 real       (also in Part 1 intensive sample)

OUTCOME: d_worked = worked_t3 - 1
          worked_t3 = 1 if real_income_t3 >= $500,  else 0
          d_worked = 0 (stayer) or -1 (exiter)

INSTRUMENT: log_ntr_instrument_p = log(1-MTR_pred/100) - log(1-MTR_t/100)
  MTR_pred = year t+3 tax law applied to year t income (inflated)
  MTR_t    = actual year t marginal tax rate (from TAXSIM)

This matches Sztutman (2024) Section 5.2.2 and applies it to NLSY79.
LIFECYCLE NOTE: NLSY79 annual workers (ages 17-35) are NOT at the retirement
margin. eta^P_r for this cohort may be close to zero or negative because
labour market exits at young ages are often temporary (schooling, childcare).
==============================================================================*/

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
    else { scalar eta_P_near = . }
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
    else { scalar eta_P_main = . }
}

/*==============================================================================
PART 3: COMPUTE chi = 1 + eps^w_r / eta^P_r (FULL IV)
================================================================================
Combines intensive wage elasticity eps^w_r (Part 1) with participation
semi-elasticity eta^P_r (Part 2) to compute the labor wedge chi.

Formula (Sztutman 2024, Equation 17):
  chi(y) = 1 + eps^w_r(y) / eta^P_r(y)
  tau_p(y) = 1 - chi(y)

LIFECYCLE CAVEAT:
  NLSY79 annual workers (ages 17-35) are not at the retirement margin.
  eta^P_r may be close to zero, making chi non-finite.
  In that case, use the structural tau_p = delta/alpha from Phase 5
  as the primary identification route for NLSY79.
==============================================================================*/

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
        di as error "SCRUTINY: chi = " %8.4f chi_full " outside plausible range [0,5]"
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
"""

# Assemble the new file content
new_content = content[:p2] + NEW_SECTION + "\n" + content[p4:]

with open(filepath, "w", encoding="utf-8") as f:
    f.write(new_content)

print("File patched successfully!")
print(f"Old section: {p4-p2} bytes, New section: {len(NEW_SECTION)} bytes")
print(f"Old file: {len(content)} bytes, New file: {len(new_content)} bytes")
