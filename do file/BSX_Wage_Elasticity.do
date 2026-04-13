* BSX_Wage_Elasticity.do
* Estimates wage-change elasticity of taxable income using LOO industry instrument
* Adapted from Becko, Sztutman & Xia (2024) Eq. 30-31 to NLSY79
* Hourly wage = pwages/hrs; instrument = leave-one-out industry avg wage change
* Stage 1 only: hourly wage construction + diagnostics
* Date: March 2026

clear all
set more off
capture log close _all

* --- PATHS — Mirror the convention in Two_Period_Analysis.do ---
global projdir "D:\Stata Data\labor_signaling_project"
global datadir "${projdir}\data"
global outdir  "${projdir}\output"
global dodir   "${projdir}\do file"

cd "${datadir}"

* --- LOG ---
log using "${outdir}\bsx_wage_elasticity_log.txt", replace text

di ""
di "=============================================================================="
di "BSX WAGE ELASTICITY ANALYSIS — STAGE 1"
di "Hourly Wage Construction and Diagnostics"
di "=============================================================================="
di "Start time: $S_DATE $S_TIME"
di ""

* --- STAGE 1: CONSTRUCT HOURLY WAGES AND PRODUCE DIAGNOSTICS ---

di ""
di "=============================================================================="
di "STAGE 1: LOADING AND RESTRICTING DATA"
di "=============================================================================="

* ADAPTATION: BSX use SIPP 2000-2013 with multiple birth cohorts.
*             We use NLSY79, restricted to 1979-1993 (annual survey period)
*             because ind_broad (required for the LOO instrument) is only
*             available for this window. This is a project-specific constraint.
use "nlsy_long_pre_taxsim.dta", clear

di ""
di "Total observations in nlsy_long_pre_taxsim.dta: " _N
di "Year range in full dataset:"
tab year

* Restrict to annual period (1979-1993)
* NOTE: We start at 1979 (not 1978) because ind_broad begins in 1979.
*       For 3-year pairs, base years will run 1979-1990 (end years 1982-1993).
*       We include through 1993 to allow end-year observations.
keep if year >= 1979 & year <= 1993

di ""
di "After restricting to 1979-1993: " _N " observations"
tab year

* --- 1.1: INSPECT HOURS VARIABLE ---

di ""
di "=============================================================================="
di "STAGE 1.1: HOURS VARIABLE INSPECTION"
di "=============================================================================="
di ""
di "CONFIRMED (from demo_x_hour.dct labels):"
di "  hrs = Total hours worked in past calendar year, ALL jobs combined."
di "  Source codes: R0215710 (1978) through T8789100 (2020)."
di "  Label example: R0407300 = '# OF HRS WRKD IN P-C YR 80'"
di ""
di "KNOWN MEASUREMENT MISMATCH:"
di "  pwages = primary wages ONLY."
di "  hrs    = total hours ALL jobs."
di "  Therefore pwages/hrs UNDERESTIMATES primary-job hourly wage"
di "  for workers holding multiple jobs."
di ""

* Check hrs availability in 1979-1993
di "Distribution of hrs (all values, including zero and missing):"
tab year if !missing(hrs), missing
di ""

di "hrs variable — full distribution including zeros:"
summarize hrs, detail

di ""
di "Count of observations with hrs <= 0 or missing:"
count if hrs <= 0 | missing(hrs)
di "Count of observations with hrs > 0:"
count if hrs > 0

* --- 1.2: INSPECT PWAGES VARIABLE ---

di ""
di "=============================================================================="
di "STAGE 1.2: PRIMARY WAGES VARIABLE INSPECTION"
di "=============================================================================="
di ""

di "pwages distribution (all values):"
summarize pwages, detail

di ""
di "Positive pwages and positive hrs combinations:"
count if pwages > 0 & !missing(pwages) & hrs > 0 & !missing(hrs)

* --- 1.3: CONSTRUCT HOURLY WAGE ---

di ""
di "=============================================================================="
di "STAGE 1.3: HOURLY WAGE CONSTRUCTION"
di "=============================================================================="
di ""

* ADAPTATION: BSX measure hourly wages directly from SIPP survey question
*             ("What is your hourly rate of pay?").
*             We derive them as: hourly_wage = pwages / hrs
*             because NLSY79 does not directly ask for hourly rate.
*             This introduces: (1) measurement error from self-reported hrs
*             and pwages; (2) mechanical overlap (pwages is a major component
*             of taxable income, the dependent variable); (3) downward bias
*             because hrs includes all-job hours but pwages is primary only.
gen hourly_wage = pwages / hrs if hrs > 0 & !missing(hrs) & pwages > 0 & !missing(pwages)
label var hourly_wage "Hourly wage = pwages/hrs (nominal; constructed, not surveyed)"

di "Raw hourly wage (before hours trimming):"
summarize hourly_wage, detail

* --- 1.4: HOURS QUALITY FILTER ---

di ""
di "=============================================================================="
di "STAGE 1.4: HOURS QUALITY FILTER (520-4160 hours/year)"
di "=============================================================================="
di ""

* ADAPTATION: BSX do not appear to apply an hours filter because they use
*             directly surveyed hourly wages. We must filter implausible hours
*             because the constructed wage pwages/hrs is sensitive to extreme
*             hours values.
*
* Floor: 520 hours/year = 10 hrs/week × 52 weeks (excludes trivially short
*        spells that would inflate hourly wage implausibly).
* Ceiling: 4160 hours/year = 80 hrs/week × 52 weeks (excludes likely errors;
*          maximum realistic full-time + heavy overtime across all jobs).
*
* IMPORTANT: These are default thresholds from the BSX coding guide.
* If the distribution shows problems (e.g., >20% of positive-earnings
* observations dropped), revisit with Yuhao before proceeding to Stage 2.

* Count observations with positive pwages and hrs, before filter
count if pwages > 0 & !missing(pwages) & hrs > 0 & !missing(hrs)
local N_pos_both = r(N)
di "Observations with positive pwages AND positive hrs: `N_pos_both'"

* Count what would be dropped by hours filter
count if pwages > 0 & !missing(pwages) & hrs > 0 & !missing(hrs) & (hrs < 520 | hrs > 4160)
local N_trimmed = r(N)
di "Of those, dropped by hours filter (hrs < 520 or hrs > 4160): `N_trimmed'"
di "Share trimmed: " %5.3f `N_trimmed'/`N_pos_both'

di ""
di "Hours distribution BELOW floor (hrs > 0, hrs < 520):"
count if hrs > 0 & hrs < 520 & !missing(hrs)
local N_below = r(N)
summarize hrs if hrs > 0 & hrs < 520 & !missing(hrs), detail

di ""
di "Hours distribution ABOVE ceiling (hrs > 4160):"
count if hrs > 4160 & !missing(hrs)
local N_above = r(N)
if `N_above' > 0 {
    summarize hrs if hrs > 4160, detail
}

* Apply filter: set hourly_wage to missing for implausible hours
replace hourly_wage = . if hrs < 520 | hrs > 4160
label var hourly_wage "Hourly wage = pwages/hrs, hrs filter 520-4160 applied"

di ""
di "After hours filter — hourly_wage summary:"
summarize hourly_wage, detail

* --- 1.5: LOG HOURLY WAGE ---

di ""
di "=============================================================================="
di "STAGE 1.5: LOG HOURLY WAGE"
di "=============================================================================="
di ""

gen log_hourly_wage = ln(hourly_wage) if !missing(hourly_wage)
label var log_hourly_wage "Log hourly wage (after hrs filter)"

di "log_hourly_wage distribution:"
summarize log_hourly_wage, detail

di ""
di "Hourly wage in levels — check for plausibility:"
di "  Median hourly wage (nominal, 1979-1993): " %6.2f r(p50) " (should be roughly $5-$20)"
di "  p1:  " %6.2f r(p1)
di "  p5:  " %6.2f r(p5)
di "  p25: " %6.2f r(p25)
di "  p50: " %6.2f r(p50)
di "  p75: " %6.2f r(p75)
di "  p95: " %6.2f r(p95)
di "  p99: " %6.2f r(p99)

* Re-summarize hourly_wage (not log) for the plausibility check
summarize hourly_wage, detail
local med_wage = r(p50)
local p1_wage  = r(p1)
local p99_wage = r(p99)

di ""
di "[RESULT] Hourly wage p1:    " %8.2f `p1_wage'
di "[RESULT] Hourly wage median: " %8.2f `med_wage'
di "[RESULT] Hourly wage p99:   " %8.2f `p99_wage'

* Flag if median is outside plausible range for 1979-1993 nominal wages
if `med_wage' < 1 | `med_wage' > 100 {
    di as error ""
    di as error "*** WARNING: Hourly wage median is outside $1-$100 range. ***"
    di as error "*** This suggests hrs may be mismeasured (e.g., weekly    ***"
    di as error "*** instead of annual), or pwages is mis-scaled.          ***"
    di as error "*** DO NOT PROCEED TO STAGE 2 without investigating.      ***"
}
else {
    di ""
    di "Hourly wage median is within plausible range for 1979-1993. Proceeding."
}

* --- 1.6: DIAGNOSTICS BY YEAR ---

di ""
di "=============================================================================="
di "STAGE 1.6: DIAGNOSTICS BY YEAR"
di "=============================================================================="

di ""
di "Annual hours (hrs) by year — median and N with positive hrs:"
tabstat hrs if hrs > 0, by(year) stat(n mean median p25 p75)

di ""
di "Hourly wage by year — median among valid observations:"
tabstat hourly_wage if !missing(hourly_wage), by(year) stat(n mean median p25 p75)

di ""
di "Fraction with valid log_hourly_wage, by year:"
tabstat log_hourly_wage, by(year) stat(n mean)

* --- 1.7: SAMPLE COUNT SUMMARY ---

di ""
di "=============================================================================="
di "STAGE 1.7: SAMPLE FLOW SUMMARY (Stage 1)"
di "=============================================================================="

count
local N_total = r(N)
di "[SAMPLE] Total obs in 1979-1993 annual period: `N_total'"

count if pwages > 0 & !missing(pwages)
local N_pos_pwages = r(N)
di "[SAMPLE] With positive pwages: `N_pos_pwages'"

count if pwages > 0 & !missing(pwages) & hrs > 0 & !missing(hrs)
local N_pos_both2 = r(N)
di "[SAMPLE] With positive pwages and positive hrs: `N_pos_both2'"

count if !missing(hourly_wage)
local N_valid_wage = r(N)
di "[SAMPLE] With valid hourly_wage (after hours filter): `N_valid_wage'"

count if !missing(log_hourly_wage)
local N_valid_log = r(N)
di "[SAMPLE] With valid log_hourly_wage: `N_valid_log'"

di ""
di "[RESULT] Share of positive-pwages+positive-hrs obs with valid hourly_wage:"
di "         " %5.3f `N_valid_wage' / `N_pos_both2'
di "[RESULT] Hours filter trimming rate (among positive pwages+hrs):"
di "         " %5.3f (`N_pos_both2' - `N_valid_wage') / `N_pos_both2'

* --- 1.8: BROAD INCOME CONSTRUCTION (needed for Stage 2+ and comparability) ---

di ""
di "=============================================================================="
di "STAGE 1.8: BROAD INCOME (for comparability with tax regression)"
di "=============================================================================="
di ""

* ADAPTATION: BSX use a broad taxable income measure including all labor and
*             capital income components. Our project defines broad_income using
*             the same 9 components as Two_Period_Analysis.do (lines 463-467).
*             We use the IDENTICAL formula for comparability.
*             NOT included: transfers, rentpaid, dividends, intrec, otherprop,
*             pbusinc, sbusinc (passed to TAXSIM but not used in the regression DV).

* Apply same zero-floor as TAXSIM validation in Two_Period_Analysis.do
* (pwages etc. can be 0 for non-workers; negative values are invalid)
foreach v in pwages swages psemp ssemp pui sui gssi pensions nonprop {
    gen `v'_clean = max(0, `v')
    replace `v'_clean = 0 if missing(`v')
}

gen broad_income = pwages_clean + swages_clean + psemp_clean + ssemp_clean + ///
                   pui_clean + sui_clean + gssi_clean + pensions_clean + nonprop_clean
label var broad_income "Broad income (9 components, = formula in Two_Period_Analysis.do)"

drop *_clean

di "Broad income distribution (positive values only):"
summarize broad_income if broad_income > 0, detail

di ""
di "[RESULT] Broad income p1:    " %12.0f r(p1)
di "[RESULT] Broad income median: " %12.0f r(p50)
di "[RESULT] Broad income p99:   " %12.0f r(p99)

* --- STAGE 1 CHECKPOINT ---

di ""
di "=============================================================================="
di "STAGE 1 COMPLETE"
di "=============================================================================="
di ""
di "CHECK THE FOLLOWING BEFORE PROCEEDING TO STAGE 2:"
di "  [ ] hourly_wage median is roughly $5-$20 in nominal terms (1979-1993)"
di "  [ ] log_hourly_wage has no extreme outliers at p1/p99"
di "  [ ] Hours trimming rate is < 20% of positive-pwages+hrs observations"
di "  [ ] If trimming > 30%, STOP and inspect hrs definition with Yuhao"
di "  [ ] broad_income median is plausible (should be $10K-$50K range)"
di ""
di "KNOWN ISSUE (not a bug — document in paper):"
di "  hrs = total hours all jobs; pwages = primary wages only."
di "  ADAPTATION: BSX use directly surveyed hourly wage (SIPP)."
di "              We use pwages/hrs, which underestimates primary-job"
di "              hourly rate for multi-job holders."
di ""
di "NEXT STEP (Stage 2): Merge ind_broad from merged_data_with_occind.dta"
di "  Requires Yuhao approval if trimming rate or wage distribution is"
di "  outside expected range."
di ""

* --- STAGE 2: MERGE IND_BROAD INTO LONG DATA ---

di ""
di "=============================================================================="
di "=============================================================================="
di "STAGE 2: MERGE IND_BROAD INTO LONG DATA"
di "=============================================================================="
di "=============================================================================="
di ""

* --- 2.1: SAVE STAGE 1 RESULT AS TEMPFILE ---

di ""
di "=============================================================================="
di "STAGE 2.1: SAVING STAGE 1 DATA"
di "=============================================================================="

tempfile stage1_data
save `stage1_data', replace
di "Stage 1 data saved. Observations in memory: " _N

* --- 2.2: LOAD WIDE-FORMAT OCC/IND DATA AND RESHAPE TO LONG ---

di ""
di "=============================================================================="
di "STAGE 2.2: BUILDING IND_BROAD LONG FILE"
di "=============================================================================="
di ""

* Load the wide-format file that contains ind_broad_YYYY variables.
* This file was saved in Data_process.do at line 1061 (before reshape),
* so it has one row per person (N=12,686) and columns ind_broad_1979 ...
* ind_broad_1993.
use "merged_data_with_occind.dta", clear

di "Rows in merged_data_with_occind.dta (should be 12,686): " _N

* Verify which ind_broad variables exist
di ""
di "Checking for ind_broad_YYYY variables:"
capture describe ind_broad_*
if _rc != 0 {
    di as error "ERROR: No ind_broad_* variables found in merged_data_with_occind.dta"
    di as error "Check whether Data_process.do saved the file correctly."
    error 111
}

* Keep only ID and industry variables (drop occupation, etc.)
keep taxsimid ind_broad_*

di ""
di "Variables kept for reshape:"
describe

* Reshape to long: stub ind_broad_, j = year
* After reshape: taxsimid × year, with ind_broad = category 1-12 (or missing)
* ADAPTATION: BSX use industry codes for all survey years. We are limited to
*             1979-1993 here because ind_broad was only extracted for that window.
reshape long ind_broad_, i(taxsimid) j(year)
rename ind_broad_ ind_broad

di ""
di "After reshape long: " _N " obs (should be 12,686 × 15 years = 190,290 if reshape covered all annual years)"
tab year, missing

* Keep only 1979-1993
keep if year >= 1979 & year <= 1993

di ""
di "After keeping 1979-1993: " _N " obs"

* Save as tempfile
tempfile ind_broad_long
save `ind_broad_long', replace

* --- 2.3: MERGE IND_BROAD INTO STAGE 1 DATA ---

di ""
di "=============================================================================="
di "STAGE 2.3: MERGING IND_BROAD INTO STAGE 1 DATA"
di "=============================================================================="
di ""

use `stage1_data', clear
di "Stage 1 data reloaded. Obs: " _N

* Merge 1:1 on taxsimid × year
* Expected: all 190,290 obs should match because both files have same
*           taxsimid × year structure (1979-1993 annual panel)
merge 1:1 taxsimid year using `ind_broad_long', keep(master match)

di ""
di "Merge result (_merge):"
tab _merge, missing

* Count merge outcomes
count if _merge == 1
local n_master_only = r(N)
count if _merge == 2
local n_using_only  = r(N)
count if _merge == 3
local n_matched     = r(N)

di ""
di "[RESULT] Merge outcome:"
di "  Matched (both master and using): `n_matched'"
di "  Master only (in stage1, not in ind file): `n_master_only'"
di "  Using only (in ind file, not in stage1): `n_using_only'"

if `n_master_only' > 0 {
    di as error "WARNING: `n_master_only' obs in stage1 have NO industry match."
    di as error "This suggests a taxsimid in the long data is not in merged_data_with_occind.dta."
    di as error "Investigate before proceeding."
}

drop _merge

* --- 2.4: MERGE DIAGNOSTICS BY YEAR ---

di ""
di "=============================================================================="
di "STAGE 2.4: IND_BROAD COVERAGE DIAGNOSTICS"
di "=============================================================================="
di ""

* Overall coverage
di "Overall ind_broad coverage (1979-1993):"
count
local N_total = r(N)
count if !missing(ind_broad)
local N_ind   = r(N)
count if missing(ind_broad)
local N_miss  = r(N)

di "[RESULT] Total obs (1979-1993): `N_total'"
di "[RESULT] With non-missing ind_broad: `N_ind' (" %5.1f 100*`N_ind'/`N_total' "%)"
di "[RESULT] With missing ind_broad: `N_miss' (" %5.1f 100*`N_miss'/`N_total' "%)"

* Coverage by year
di ""
di "ind_broad coverage by year (N non-missing and % of 12,686):"
tabstat ind_broad, by(year) stat(n) nototal
di ""
di "Missingness of ind_broad by year:"
by year, sort: count if missing(ind_broad)

* More readable: coverage rate by year
di ""
di "Coverage rate by year:"
preserve
gen has_ind = (!missing(ind_broad))
collapse (sum) n_with_ind=has_ind (count) n_total=taxsimid, by(year)
gen pct_covered = 100 * n_with_ind / n_total
list year n_total n_with_ind pct_covered, clean noobs
restore

* Coverage conditional on having positive wages
di ""
di "ind_broad coverage among workers with positive pwages:"
count if !missing(ind_broad) & pwages > 0
local N_ind_pos = r(N)
count if missing(ind_broad) & pwages > 0
local N_miss_pos = r(N)
di "[RESULT] Workers with pwages>0 AND non-missing ind_broad: `N_ind_pos'"
di "[RESULT] Workers with pwages>0 AND missing ind_broad: `N_miss_pos'"

* --- 2.5: INDUSTRY CATEGORY DISTRIBUTION ---

di ""
di "=============================================================================="
di "STAGE 2.5: INDUSTRY CATEGORY DISTRIBUTION"
di "=============================================================================="
di ""

* Overall industry distribution
di "Overall distribution of ind_broad (1979-1993, non-missing):"
tab ind_broad if !missing(ind_broad), missing

di ""
di "Industry distribution among positive-pwages workers:"
tab ind_broad if !missing(ind_broad) & pwages > 0, missing

* --- 2.6: INDUSTRY CELL SIZES (KEY DIAGNOSTIC FOR LOO FEASIBILITY) ---

di ""
di "=============================================================================="
di "STAGE 2.6: CELL SIZES (IND_BROAD × YEAR)"
di "=============================================================================="
di ""
di "CRITICAL: These are the base-year industry cells from which the LOO"
di "instrument will be constructed. Cell size = N workers in each ind × year"
di "cell. Thin cells (< 30) will produce noisy LOO instruments."
di "Very thin cells (< 5 after sample restrictions) will be dropped."
di ""

* Cell sizes: total observations per industry × year
di "Cell sizes (N obs per ind_broad × year), ALL observations:"
preserve
keep if !missing(ind_broad)
collapse (count) n_obs=taxsimid, by(ind_broad year)
di "Summary of cell sizes (all obs):"
summarize n_obs, detail
di ""
di "Distribution of cell sizes:"
di "  Cells with N < 5:   "
count if n_obs < 5
di "  Cells with N 5-9:   "
count if n_obs >= 5 & n_obs < 10
di "  Cells with N 10-29: "
count if n_obs >= 10 & n_obs < 30
di "  Cells with N 30+:   "
count if n_obs >= 30
di ""
di "Cell counts by industry (pooled 1979-1993):"
collapse (sum) total_obs=n_obs (mean) mean_annual_n=n_obs, by(ind_broad)
list ind_broad total_obs mean_annual_n, clean noobs
restore

* Cell sizes: workers with positive pwages AND valid hourly wage
* (these are the workers who will enter the LOO instrument numerator)
di ""
di "Cell sizes (N obs per ind_broad × year), WAGE-VALID obs (pwages>0 & !missing(log_hourly_wage)):"
preserve
keep if !missing(ind_broad) & pwages > 0 & !missing(log_hourly_wage)
collapse (count) n_obs=taxsimid, by(ind_broad year)
di "Summary of cell sizes (wage-valid obs):"
summarize n_obs, detail
di ""
di "Cell sizes by industry × year (wage-valid):"
list ind_broad year n_obs, clean noobs separator(15)
di ""
di "[RESULT] Distribution of wage-valid cell sizes:"
di "  Cells with N < 5:   "
count if n_obs < 5
local n_thin5 = r(N)
di "  Cells with N 5-9:   "
count if n_obs >= 5 & n_obs < 10
local n_thin10 = r(N)
di "  Cells with N 10-29: "
count if n_obs >= 10 & n_obs < 30
local n_thin30 = r(N)
di "  Cells with N 30+:   "
count if n_obs >= 30
local n_thick = r(N)
di ""
di "Total cells: " _N
di "  Cells < 5 (will be dropped by LOO filter): `n_thin5'"
di "  Cells 5-9 (very thin, noisy LOO):          `n_thin10'"
di "  Cells 10-29 (thin, moderate noise):        `n_thin30'"
di "  Cells 30+ (adequate for LOO):              `n_thick'"
restore

* --- 2.7: FINAL DATASET INSPECTION ---

di ""
di "=============================================================================="
di "STAGE 2.7: FINAL DATASET AFTER MERGE"
di "=============================================================================="
di ""

di "Variables in merged dataset:"
describe, short

di ""
di "Key variable availability at the person-year level:"
count if !missing(log_hourly_wage) & !missing(ind_broad)
local N_both = r(N)
count if !missing(log_hourly_wage) & missing(ind_broad)
local N_wage_no_ind = r(N)
count if missing(log_hourly_wage) & !missing(ind_broad)
local N_ind_no_wage = r(N)

di ""
di "[RESULT] Observations with valid log_hourly_wage AND ind_broad: `N_both'"
di "[RESULT] Valid log_hourly_wage but missing ind_broad:           `N_wage_no_ind'"
di "[RESULT] Valid ind_broad but missing log_hourly_wage:           `N_ind_no_wage'"
di ""
di "The `N_both' obs with both valid wage and industry are the candidate"
di "observations for the 3-year pairing step (Stage 3)."

di ""
di "=============================================================================="
di "STAGE 2 COMPLETE — PROCEEDING TO STAGE 3"
di "=============================================================================="
di ""
di "DATA LIMITATIONS (expected, document in paper):"
di "  - ind_broad covers only 1979-1993 (limits analysis window)"
di "  - 12 broad categories only (coarser than BSX SIPP industry codes)"
di "  - Coverage is NOT 100% — some workers have missing industry in some years"

* --- STAGE 3: CREATE 3-YEAR PAIRED OBSERVATIONS ---

di ""
di "=============================================================================="
di "STAGE 3: 3-YEAR PAIRING"
di "=============================================================================="
di ""

* Sort for within-person operations
sort taxsimid year

* Create end-period (t+3) variables
bysort taxsimid (year): gen hourly_wage_t3     = hourly_wage[_n + 3]
bysort taxsimid (year): gen log_hourly_wage_t3 = log_hourly_wage[_n + 3]
bysort taxsimid (year): gen broad_income_t3    = broad_income[_n + 3]
bysort taxsimid (year): gen pwages_t3          = pwages[_n + 3]
bysort taxsimid (year): gen hrs_t3             = hrs[_n + 3]
bysort taxsimid (year): gen mstat_t3           = mstat[_n + 3]

* Keep only base years 1979-1990 (end year t+3 ≤ 1993)
keep if year >= 1979 & year <= 1990

di "After restricting to base years 1979-1990: " _N " obs"
tab year

* Rename base-year variables for clarity
rename log_hourly_wage  log_hourly_wage_t
rename hourly_wage      hourly_wage_t
rename broad_income     broad_income_t
rename ind_broad        ind_broad_t
rename mstat            mstat_t
rename year             year_t
gen year_t3 = year_t + 3

label var hourly_wage_t      "Hourly wage at base period t"
label var log_hourly_wage_t  "Log hourly wage at base period t"
label var hourly_wage_t3     "Hourly wage at t+3"
label var log_hourly_wage_t3 "Log hourly wage at t+3"
label var broad_income_t     "Broad income at base period t"
label var broad_income_t3    "Broad income at t+3"
label var ind_broad_t        "Broad industry at base period t (1-12)"
label var mstat_t            "Marital status at base period t (1=single, 2=MFJ)"
label var mstat_t3           "Marital status at t+3"
label var year_t             "Base year t"
label var year_t3            "End year t+3"

* Key change variables
gen log_wage_change   = log_hourly_wage_t3 - log_hourly_wage_t
gen log_income_t      = ln(broad_income_t)  if broad_income_t > 0  & !missing(broad_income_t)
gen log_income_t3     = ln(broad_income_t3) if broad_income_t3 > 0 & !missing(broad_income_t3)
gen log_income_change = log_income_t3 - log_income_t

label var log_wage_change   "3-yr change in log hourly wage (Δlog w)"
label var log_income_t      "Log broad income at t"
label var log_income_t3     "Log broad income at t+3"
label var log_income_change "3-yr change in log broad income (Δlog z)"

di ""
di "Pairing diagnostics:"
count if !missing(log_hourly_wage_t) & !missing(log_hourly_wage_t3)
di "  Valid log hourly wage at BOTH t and t+3: " r(N)
count if !missing(ind_broad_t)
di "  Valid ind_broad at t: " r(N)
count if !missing(log_hourly_wage_t) & !missing(log_hourly_wage_t3) & !missing(ind_broad_t)
di "  Valid wage (both) AND valid industry: " r(N)

* --- STAGE 4: SAMPLE RESTRICTIONS — Mirrors Two_Period_Analysis.do: ---

di ""
di "=============================================================================="
di "STAGE 4: SAMPLE RESTRICTIONS"
di "=============================================================================="
di ""

count
local N_start = r(N)
di "[SAMPLE FLOW] Starting N (base years 1979-1990): `N_start'"

* Restriction 1: Valid hourly wages at both t and t+3
drop if missing(log_hourly_wage_t) | missing(log_hourly_wage_t3)
count
local N_r1 = r(N)
di "[SAMPLE] After valid wages at t AND t+3: `N_r1'"

* Restriction 2: Valid broad industry at base year t
drop if missing(ind_broad_t)
count
local N_r2 = r(N)
di "[SAMPLE] After valid ind_broad at t: `N_r2'"

* Restriction 3: Marital stability
gen married_t  = (mstat_t  == 2)
gen married_t3 = (mstat_t3 == 2)
drop if missing(mstat_t3)
drop if married_t != married_t3
count
local N_r3 = r(N)
di "[SAMPLE] After marital stability: `N_r3'"

* Restriction 4: Real income floor ($10,000 in 1984 dollars)
* CPI-U annual averages; 1984 = 103.9 (BLS series CUUR0000SA0)
gen cpi_t = .
replace cpi_t =  72.6 if year_t == 1979
replace cpi_t =  82.4 if year_t == 1980
replace cpi_t =  90.9 if year_t == 1981
replace cpi_t =  96.5 if year_t == 1982
replace cpi_t =  99.6 if year_t == 1983
replace cpi_t = 103.9 if year_t == 1984
replace cpi_t = 107.6 if year_t == 1985
replace cpi_t = 109.6 if year_t == 1986
replace cpi_t = 113.6 if year_t == 1987
replace cpi_t = 118.3 if year_t == 1988
replace cpi_t = 124.0 if year_t == 1989
replace cpi_t = 130.7 if year_t == 1990
label var cpi_t "CPI-U annual average at base year t (1984 = 103.9)"

gen income_floor_t = 10000 * (cpi_t / 103.9)
label var income_floor_t "Nominal income floor (= $10K in 1984 dollars)"

drop if broad_income_t < income_floor_t | missing(broad_income_t)
count
local N_r4 = r(N)
di "[SAMPLE] After income floor ($10K in 1984 dollars): `N_r4'"

* Restriction 5: Positive end-period income
drop if broad_income_t3 <= 0 | missing(broad_income_t3)
count
local N_r5 = r(N)
di "[SAMPLE] After positive end-period income: `N_r5'"

di ""
di "----------------------------------------------------------------------"
di "[SAMPLE FLOW TABLE]"
di "  Starting (base years 1979-1990):              `N_start'"
di "  After valid wages at t and t+3:               `N_r1'"
di "  After valid ind_broad at t:                   `N_r2'"
di "  After marital stability:                      `N_r3'"
di "  After income floor ($10K in 1984 dollars):    `N_r4'"
di "  After positive end-period income:             `N_r5'"
di "  (LOO cohort filter applied in Stage 5)"
di "----------------------------------------------------------------------"

* --- STAGE 5: LOO INSTRUMENT CONSTRUCTION ---

di ""
di "=============================================================================="
di "STAGE 5: LOO INSTRUMENT CONSTRUCTION"
di "=============================================================================="
di ""

* Step 5.1: Collapse to cell totals on the post-restriction sample
*           Collapse BOTH t+3 and t variables so we can construct the change
*           instrument (BSX Eq. 31) rather than just the level at t+3.
preserve
collapse ///
    (sum)   cell_pwages_t3 = pwages_t3  ///
    (sum)   cell_hrs_t3    = hrs_t3     ///
    (sum)   cell_pwages_t  = pwages     ///
    (sum)   cell_hrs_t     = hrs        ///
    (count) cell_n         = taxsimid,  ///
    by(ind_broad_t year_t)
label var cell_pwages_t3 "Sum of pwages_t3 in ind × year cell"
label var cell_hrs_t3    "Sum of hrs_t3 in ind × year cell"
label var cell_pwages_t  "Sum of pwages at t in ind × year cell"
label var cell_hrs_t     "Sum of hrs at t in ind × year cell"
label var cell_n         "N workers in ind × year cell (analysis sample)"
tempfile cell_totals
save `cell_totals', replace
restore

* Step 5.2: Merge totals back
merge m:1 ind_broad_t year_t using `cell_totals', keep(master match) nogen

di "Cell size distribution by industry (pre-LOO filter):"
tabstat cell_n, by(ind_broad_t) stat(n min mean max) nototal

* Step 5.3: Compute LOO (subtract own contribution) — at t+3 AND at t
gen loo_pwages_t3 = cell_pwages_t3 - pwages_t3
gen loo_hrs_t3    = cell_hrs_t3    - hrs_t3
gen loo_pwages_t  = cell_pwages_t  - pwages
gen loo_hrs_t     = cell_hrs_t     - hrs
gen loo_n         = cell_n         - 1

label var loo_pwages_t3 "LOO sum of pwages_t3 (cell total minus self)"
label var loo_hrs_t3    "LOO sum of hrs_t3 (cell total minus self)"
label var loo_pwages_t  "LOO sum of pwages at t (cell total minus self)"
label var loo_hrs_t     "LOO sum of hrs at t (cell total minus self)"
label var loo_n         "LOO cohort size (cell N minus 1)"

* Step 5.4: Apply LOO cohort size filter (N >= 5)
di ""
count if loo_n < 5
di "Dropped by LOO cohort < 5 filter: " r(N)
drop if loo_n < 5
count
local N_r6 = r(N)
di "[SAMPLE] After LOO cohort >= 5 filter: `N_r6'"

* Step 5.5: Compute LOO hourly wages and take logs — at t+3 and at t
gen loo_hourly_wage_t3 = loo_pwages_t3 / loo_hrs_t3 ///
    if loo_hrs_t3 > 0 & loo_pwages_t3 > 0
gen log_loo_wage_t3 = ln(loo_hourly_wage_t3) if !missing(loo_hourly_wage_t3)

gen loo_hourly_wage_t = loo_pwages_t / loo_hrs_t ///
    if loo_hrs_t > 0 & loo_pwages_t > 0
gen log_loo_wage_t = ln(loo_hourly_wage_t) if !missing(loo_hourly_wage_t)

label var loo_hourly_wage_t3 "LOO mean hourly wage at t+3 (ratio of sums)"
label var log_loo_wage_t3    "Log LOO mean hourly wage at t+3 (component of BSX Eq. 31)"
label var loo_hourly_wage_t  "LOO mean hourly wage at t (ratio of sums)"
label var log_loo_wage_t     "Log LOO mean hourly wage at base period t (component of BSX Eq. 31)"

* Step 5.6: BSX Eq. 31 instrument -- CHANGE in LOO wage from t to t+3
*           delta-w-hat_{i,t+3} = log(LOO wage_{t+3}) - log(LOO wage_t)
*           Using the level at t+3 alone changes the identifying variation:
*           levels pick up persistent industry wage premia correlated with
*           worker selection; changes isolate transitory demand shocks.
gen log_loo_wage_change = log_loo_wage_t3 - log_loo_wage_t
label var log_loo_wage_change "Delta log LOO hourly wage t to t+3 (BSX Eq. 31 instrument)"

drop if missing(log_loo_wage_change)
count
local N_final = r(N)
di "[SAMPLE] Final analysis sample (valid LOO): `N_final'"

di ""
di "LOO instrument distribution (BSX Eq. 31: delta log LOO wage, t to t+3):"
summarize log_loo_wage_change, detail
local loo_mean = r(mean)
local loo_p50  = r(p50)
local loo_p1   = r(p1)
local loo_p99  = r(p99)
local loo_sd   = r(sd)
di ""
di "[RESULT] log_loo_wage_change mean:   " %8.3f `loo_mean'
di "[RESULT] log_loo_wage_change median: " %8.3f `loo_p50'
di "[RESULT] log_loo_wage_change SD:     " %8.3f `loo_sd'
di "[RESULT] log_loo_wage_change p1:     " %8.3f `loo_p1'
di "[RESULT] log_loo_wage_change p99:    " %8.3f `loo_p99'

di ""
di "LOO instrument (change) mean by base-year industry:"
tabstat log_loo_wage_change, by(ind_broad_t) stat(n mean sd) nototal

di ""
di "Industry × year cell sizes in final analysis sample:"
preserve
collapse (count) n_cell = taxsimid, by(ind_broad_t year_t)
di "Summary of final cell sizes:"
summarize n_cell, detail
count if n_cell < 30
di "  Cells with N < 30:  " r(N)
count if n_cell >= 30
di "  Cells with N >= 30: " r(N)
list ind_broad_t year_t n_cell, clean noobs separator(12)
restore

* --- STAGE 6: REGRESSION VARIABLES AND SPLINES ---

di ""
di "=============================================================================="
di "STAGE 6: REGRESSION VARIABLES AND SPLINES"
di "=============================================================================="
di ""

* Income weights (parallel to Two_Period_Analysis.do)
gen income_weight = broad_income_t
label var income_weight "Analytic weight = broad_income_t"
label var married_t     "=1 if married (mstat=2) at base year t"

* Spline knots at deciles 10-90 of this regression sample
_pctile log_income_t, p(10 20 30 40 50 60 70 80 90)
local cut1 = r(r1)
local cut2 = r(r2)
local cut3 = r(r3)
local cut4 = r(r4)
local cut5 = r(r5)
local cut6 = r(r6)
local cut7 = r(r7)
local cut8 = r(r8)
local cut9 = r(r9)

di "Spline knots (deciles of log_income_t, regression sample):"
di "  cut1 (10th): " %8.4f `cut1'
di "  cut2 (20th): " %8.4f `cut2'
di "  cut3 (30th): " %8.4f `cut3'
di "  cut4 (40th): " %8.4f `cut4'
di "  cut5 (50th): " %8.4f `cut5'
di "  cut6 (60th): " %8.4f `cut6'
di "  cut7 (70th): " %8.4f `cut7'
di "  cut8 (80th): " %8.4f `cut8'
di "  cut9 (90th): " %8.4f `cut9'

forvalues i = 1/9 {
    gen spline`i' = max(0, log_income_t - `cut`i'')
    label var spline`i' "Log income spline `i' (knot = `cut`i'')"
}

di ""
di "Summary of key regression variables:"
summarize log_income_change log_wage_change log_loo_wage_change ///
          log_income_t married_t income_weight, detail

* --- STAGE 7: REGRESSIONS — Main equation (BSX Eq. 30): ---

di ""
di "=============================================================================="
di "STAGE 7: REGRESSIONS"
di "=============================================================================="
di ""
di "Final analysis sample N: " _N

* ----- FIRST STAGE -----
di ""
di "----------------------------------------------------------------------"
di "FIRST-STAGE REGRESSION"
di "  Δlog(w) = f(log_loo_wage_change, married_t, spline1-9, year FEs)"
di "----------------------------------------------------------------------"
di ""

reg log_wage_change log_loo_wage_change married_t spline1-spline9 i.year_t ///
    [aw=income_weight], cluster(taxsimid)

local fs_coef = _b[log_loo_wage_change]
local fs_se   = _se[log_loo_wage_change]
local fs_N    = e(N)
test log_loo_wage_change
local fs_F    = r(F)

di ""
di "[RESULT] First-stage: β = " %8.4f `fs_coef' "  SE = " %8.4f `fs_se' "  N = " `fs_N'
di "[RESULT] First-stage F (on instrument): " %8.2f `fs_F'

if `fs_F' < 10 {
    di as error "WARNING: First-stage F < 10. Weak instrument — interpret 2SLS with caution."
}

* ----- OLS -----
di ""
di "----------------------------------------------------------------------"
di "OLS  (ε_w = bias-inflated by endogeneity of wages)"
di "----------------------------------------------------------------------"
di ""

reg log_income_change log_wage_change married_t spline1-spline9 i.year_t ///
    [aw=income_weight], cluster(taxsimid)

local ols_coef = _b[log_wage_change]
local ols_se   = _se[log_wage_change]
local ols_N    = e(N)
di ""
di "[RESULT] OLS: ε_w = " %8.4f `ols_coef' "  SE = " %8.4f `ols_se' "  N = " `ols_N'

* ----- 2SLS -----
di ""
di "----------------------------------------------------------------------"
di "2SLS  (main specification)"
di "----------------------------------------------------------------------"
di ""

ivregress 2sls log_income_change married_t spline1-spline9 i.year_t ///
    (log_wage_change = log_loo_wage_change) [aw=income_weight], cluster(taxsimid)

local tsls_coef = _b[log_wage_change]
local tsls_se   = _se[log_wage_change]
local tsls_N    = e(N)
di ""
di "[RESULT] 2SLS: ε_w = " %8.4f `tsls_coef' "  SE = " %8.4f `tsls_se' "  N = " `tsls_N'

* ----- REDUCED FORM -----
di ""
di "----------------------------------------------------------------------"
di "REDUCED FORM  (Δlog(z) on instrument)"
di "----------------------------------------------------------------------"
di ""

reg log_income_change log_loo_wage_change married_t spline1-spline9 i.year_t ///
    [aw=income_weight], cluster(taxsimid)

local rf_coef = _b[log_loo_wage_change]
local rf_se   = _se[log_loo_wage_change]
local rf_N    = e(N)
di ""
di "[RESULT] Reduced form: π = " %8.4f `rf_coef' "  SE = " %8.4f `rf_se' "  N = " `rf_N'

* ----- LIML -----
di ""
di "----------------------------------------------------------------------"
di "LIML  (robustness to weak instrument bias)"
di "----------------------------------------------------------------------"
di ""

ivregress liml log_income_change married_t spline1-spline9 i.year_t ///
    (log_wage_change = log_loo_wage_change) [aw=income_weight], cluster(taxsimid)

local liml_coef = _b[log_wage_change]
local liml_se   = _se[log_wage_change]
local liml_N    = e(N)
di ""
di "[RESULT] LIML: ε_w = " %8.4f `liml_coef' "  SE = " %8.4f `liml_se' "  N = " `liml_N'

* --- STAGE 8: ROBUSTNESS CHECKS — (a) 2SLS with Δlog(pwages) as DV ---

di ""
di "=============================================================================="
di "STAGE 8: ROBUSTNESS CHECKS"
di "=============================================================================="
di ""

* Construct log primary wages at t and t+3
gen log_pwages_t  = ln(pwages)    if pwages    > 0 & !missing(pwages)
gen log_pwages_t3 = ln(pwages_t3) if pwages_t3 > 0 & !missing(pwages_t3)
gen log_pwages_change = log_pwages_t3 - log_pwages_t

label var log_pwages_t      "Log primary wages at base year t"
label var log_pwages_t3     "Log primary wages at t+3"
label var log_pwages_change "3-yr change in log primary wages"

di "Robustness (a): 2SLS with Δlog(pwages) as DV"
di "  Same instrument and controls as main specification."
di ""

ivregress 2sls log_pwages_change married_t spline1-spline9 i.year_t ///
    (log_wage_change = log_loo_wage_change) [aw=income_weight], cluster(taxsimid)

local rob_coef = _b[log_wage_change]
local rob_se   = _se[log_wage_change]
local rob_N    = e(N)
di ""
di "[RESULT] 2SLS (Δlog pwages DV): ε_w = " %8.4f `rob_coef' "  SE = " %8.4f `rob_se' "  N = " `rob_N'

* --- RESULTS SUMMARY TABLE ---

di ""
di "=============================================================================="
di "RESULTS SUMMARY TABLE"
di "=============================================================================="
di ""
di "  Specification               Coeff.        SE         N"
di "  --------------------------------------------------------"
di "  First stage (F = " %6.2f `fs_F' ")   " %10.4f `fs_coef' "  " %8.4f `fs_se' "  " `fs_N'
di "  OLS                         " %10.4f `ols_coef' "  " %8.4f `ols_se' "  " `ols_N'
di "  2SLS (main)                 " %10.4f `tsls_coef' "  " %8.4f `tsls_se' "  " `tsls_N'
di "  Reduced form                " %10.4f `rf_coef' "  " %8.4f `rf_se' "  " `rf_N'
di "  LIML                        " %10.4f `liml_coef' "  " %8.4f `liml_se' "  " `liml_N'
di "  Robustness (a): Δlog pwages " %10.4f `rob_coef' "  " %8.4f `rob_se' "  " `rob_N'
di "  --------------------------------------------------------"
di ""
di "  SE clustered by taxsimid. Weights = broad_income_t."
di "  Controls: married_t, spline1-9 on log_income_t, i.year_t."
di "  Instrument: delta log LOO hourly wage t to t+3 (BSX Eq. 31; ind_broad_t x year_t cell)."

* --- SAVE ANALYSIS DATASET ---

di ""
di "=============================================================================="
di "SAVING ANALYSIS DATASET"
di "=============================================================================="

save "bsx_wage_analysis.dta", replace
di "Saved: bsx_wage_analysis.dta  (N = " _N ")"

di ""
di "=============================================================================="
di "BSX WAGE ELASTICITY ANALYSIS COMPLETE"
di "=============================================================================="
di "End time: $S_DATE $S_TIME"

log close
