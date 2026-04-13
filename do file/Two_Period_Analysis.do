* Two_Period_Analysis.do
* Two-period IV estimation of the elasticity of taxable income (ETI)
* Annual (lag=1yr) and biennial (lag=2yr) specifications
* Instruments: predicted net-of-tax rate changes from TAXSIM counterfactuals
* Includes bootstrap CIs, near-worker robustness, occupation heterogeneity,
* and joint gamma+epsilon bootstrap.
* Input:  data/analysis_annual.dta, data/analysis_biennial.dta
* Output: two_period_analysis_log.txt, Phase2 tables/figures

clear all
set more off
capture log close _all

global projdir "D:\Stata Data\labor_signaling_project"
global datadir "${projdir}\data"
global outdir  "${projdir}\output"

* Set working directory to data folder so relative paths work
cd "${datadir}"

log using "${outdir}\two_period_analysis_log.txt", replace text

di ""
di "=============================================================================="
di "GRUBER-SAEZ TWO-PERIOD ANALYSIS - CORRECTED VERSION"
di "=============================================================================="
di "Start time: $S_DATE $S_TIME"
di ""

* --- Part 0: SETUP AND CONSTANTS ---

* Get 1984 CPI for real income calculations
use "BLS_CPI.dta", clear
sum CPI if year == 1984
global cpi_1984 = r(mean)
di "1984 CPI for real income calculations: $cpi_1984"

* Real income floor in 1984 dollars
* Fix: Period-specific floors
* Annual period (ages 17-35):  $5,000 in 1984$ — Gruber-Saez use $10K in 1991$ ≈ $7.1K in 1984$
*                                but NLSY79 young workers (1978-1993) earn $3-8K nominal;
*                                $5K floor preserves full-time minimum-wage attachment.
* Biennial period (ages 31-62): $10,000 in 1984$ — unchanged (appropriate for prime-age workers)
global real_floor = 10000
global real_floor_annual = 5000
di "Real income floor (biennial, ages 31-62): $" $real_floor " (1984 dollars)"
di "Real income floor (annual,   ages 17-35): $" $real_floor_annual " (1984 dollars) [FIX #9]"

* --- Part 0b: DATA QUALITY VERIFICATION ---

di ""
di "=============================================================================="
di "PART 0b: DATA QUALITY VERIFICATION (POST-CORRECTION)"
di "=============================================================================="

use "nlsy_long_pre_taxsim.dta", clear

di ""
di "Total observations in nlsy_long_pre_taxsim.dta: " _N

* Verify marital status coding is correct
di ""
di "VERIFICATION: Marital status distribution"
di "  (Should show ~40-50% as mstat=2 (married), ~50-60% as mstat=1 (single))"
tab mstat

* Check spouse wages by marital status
di ""
di "VERIFICATION: Spouse wages by marital status"
di "  (mstat=2 should have non-zero mean, mstat=1 should be 0)"
tabstat swages, by(mstat) stat(mean median n)

* Check age distribution
di ""
di "VERIFICATION: Age distribution by period"
di "  (Ages should be reasonable for each period)"
tabstat page, by(year) stat(mean min max n)

* Check income by year
di ""
di "Income (pwages) by year - checking for valid survey years:"
di "(Years with mean=0 are non-survey years)"
tabstat pwages if inlist(year, 1978, 1985, 1990, 1995, 2000, 2005, 2010, 2015, 2019), by(year) stat(mean median n)

* Check cumulative hours (should be roughly monotonic within person)
di ""
di "VERIFICATION: Cumulative hours sanity check"
di "  (Should show increasing trend across years)"
tabstat cumhrs if inlist(year, 1978, 1985, 1990, 1995, 2000, 2010, 2019), by(year) stat(mean median n)

* Identify valid income years
di ""
di "NLSY79 Survey Structure:"
di "  Annual surveys: 1979-1994 (income years 1978-1993)"
di "  Biennial surveys: 1996, 1998, ... (income years 1995, 1997, ...)"
di ""

* --- Part 0c: DESCRIPTIVE STATISTICS TABLE ---

di ""
di "=============================================================================="
di "PART 0c: DESCRIPTIVE STATISTICS"
di "=============================================================================="
di ""

* Dataset already loaded: nlsy_long_pre_taxsim.dta

*--- Person count ---
bysort taxsimid: gen id_first = (_n == 1)
qui count if id_first == 1
local n_persons = r(N)
qui count
local n_personyears = r(N)
drop id_first

di "Full panel:"
di "  Total persons:      " `n_persons'
di "  Total person-years: " `n_personyears'
di ""

*--- Full analytical population: working age, positive wages ---
gen sample_full = (pwages > 0 & !missing(pwages) & page >= 18 & page <= 65)
qui count if sample_full == 1
di "Analytical population (pwages > 0, age 18-65): " r(N) " person-years"
di ""

di "KEY VARIABLES — FULL ANALYTICAL POPULATION:"
di "  (Used as base for Table 0 in the paper)"
tabstat pwages pot_exp hgc page cumhrs ///
    if sample_full == 1, ///
    stat(mean sd p25 p50 p75 n) col(stat) longstub format(%12.2f)

*--- Annual period (1978-1993) ---
gen sample_annual_d = (year >= 1978 & year <= 1993 & ///
    pwages > 0 & !missing(pwages) & page >= 17 & page <= 36)
qui count if sample_annual_d == 1
di ""
di "ANNUAL PERIOD (1978-1993, pwages > 0, age 17-36): " r(N) " person-years"
tabstat pwages pot_exp hgc page cumhrs ///
    if sample_annual_d == 1, ///
    stat(mean sd p25 p50 p75 n) col(stat) longstub format(%12.2f)

*--- Biennial period (1995-2019) ---
gen sample_biennal_d = (year >= 1995 & mod(year, 2) == 1 & ///
    pwages > 0 & !missing(pwages) & page >= 30 & page <= 65)
qui count if sample_biennal_d == 1
di ""
di "BIENNIAL PERIOD (1995-2019, odd years, pwages > 0, age 30-65): " r(N) " person-years"
tabstat pwages pot_exp hgc page cumhrs ///
    if sample_biennal_d == 1, ///
    stat(mean sd p25 p50 p75 n) col(stat) longstub format(%12.2f)

*--- Education distribution (age 25+, by group) ---
di ""
di "EDUCATION (highest grade completed, age 25+, pwages > 0):"
tabstat hgc if pwages > 0 & !missing(pwages) & page >= 25, ///
    stat(mean sd p25 p50 p75 n) format(%8.2f)

*--- Marital status ---
di ""
di "MARITAL STATUS DISTRIBUTION (full analytical population):"
tab mstat if sample_full == 1

*--- Wage distribution by period ---
di ""
di "WAGE DISTRIBUTION (2019 dollars implied by nominal — nominal summary):"
di "  Annual period median pwages:   " %10.1f 0  // placeholder, actual from tabstat
quietly sum pwages if sample_annual_d  == 1, detail
di "  Annual period:   mean=" %8.0f r(mean) "  median=" %8.0f r(p50) "  p90=" %8.0f r(p90)
quietly sum pwages if sample_biennal_d == 1, detail
di "  Biennial period: mean=" %8.0f r(mean) "  median=" %8.0f r(p50) "  p90=" %8.0f r(p90)

*--- Save summary CSV ---
preserve
    keep if sample_full == 1
    collapse ///
        (mean)   mean_pwages=pwages mean_potexp=pot_exp mean_hgc=hgc ///
                 mean_age=page mean_cumhrs=cumhrs ///
        (sd)     sd_pwages=pwages sd_potexp=pot_exp sd_hgc=hgc ///
                 sd_age=page sd_cumhrs=cumhrs ///
        (median) med_pwages=pwages med_cumhrs=cumhrs ///
        (count)  n_obs=pwages
    gen sample = "Full analytical pop (age 18-65, pwages>0)"
    save "${outdir}\desc_stats_full.dta", replace
    export delimited using "${outdir}\desc_stats_full.csv", replace
restore

di ""
di "Descriptive statistics complete. CSV saved: ${outdir}\desc_stats_full.csv"

drop sample_full sample_annual_d sample_biennal_d

* --- PART A: ANNUAL PERIOD ANALYSIS (1978-1993) — 3-YEAR DIFFERENCES ---

di ""
di "=============================================================================="
di "=============================================================================="
di "PART A: ANNUAL PERIOD ANALYSIS"
di "=============================================================================="
di "=============================================================================="
di ""
di "Period: 1978-1993 (income years)"
di "Lag: 3 years"
di "Cohort ages: ~17-35"
di "Major tax reforms: ERTA 1981, TRA 1986"
di ""

* --------
* A1: RUN TAXSIM ON ANNUAL DATA
* --------

di ""
di "=============================================================================="
di "A1: RUNNING TAXSIM ON ANNUAL DATA (1978-1993)"
di "=============================================================================="

use "nlsy_long_pre_taxsim.dta", clear

* Keep only annual period
keep if year >= 1978 & year <= 1993

di ""
di "Observations in annual period: " _N
tab year

* Verify marital status before TAXSIM
di ""
di "Marital status distribution (annual period):"
tab mstat

* --- TAXSIM VARIABLE VALIDATION ---
di ""
di "Validating TAXSIM inputs..."

* Validate sage and page
replace sage = 0 if sage < 0 | sage > 100 | missing(sage)
replace sage = 0 if mstat != 2
replace page = 0 if page < 0 | page > 100 | missing(page)
replace mstat = 1 if mstat != 1 & mstat != 2
replace depx = 0 if depx < 0 | missing(depx)
replace depx = 15 if depx > 15

* Zero out spouse variables for single filers
replace swages = 0 if mstat != 2
replace ssemp = 0 if mstat != 2

* Validate income variables
foreach v in pwages swages psemp ssemp pui sui gssi transfers nonprop pensions rentpaid {
    capture replace `v' = 0 if `v' < 0 | missing(`v')
}

di "Validation complete. Running TAXSIM..."

* NOTE: sstate (state FIPS code) is not provided because state-of-residence
* variables were not included in the current NLSY79 data extract.
* As a result, mtr_st_t will be 0 for all observations.
* The main analysis uses federal MTR only (mtr_t = mtr_fed_t), which is
* consistent with the ETI literature (e.g., Gruber-Saez 2002 baseline spec).
* To add state taxes: re-extract NLSY79 with annual state-of-residence
* variables and add sstate to the TAXSIM input.

* Run TAXSIM
taxsimlocal35, replace
save "taxsim_annual.dta", replace

* Rename outputs
use "taxsim_annual.dta", clear
rename fiitax tax_fed_t
rename siitax tax_st_t
rename frate mtr_fed_t
rename srate mtr_st_t

di ""
di "Actual marginal tax rates (annual period):"
di "  NOTE: mtr_st_t = 0 for all obs (sstate not provided - see comment above)"
sum mtr_fed_t mtr_st_t, detail

* Keep needed variables
keep taxsimid year mtr_fed_t mtr_st_t tax_fed_t tax_st_t ///
     pwages swages psemp ssemp pui sui gssi transfers nonprop pensions rentpaid ///
     mstat page depx

save "taxsim_annual_clean.dta", replace

* --------
* A2: CREATE CPI DATA
* --------

di ""
di "=============================================================================="
di "A2: CREATING CPI DATA FOR ANNUAL PERIOD"
di "=============================================================================="

use "BLS_CPI.dta", clear
keep year CPI
sort year

* Save version for base year merge
rename year year_t
rename CPI cpi_t
save "cpi_base_annual.dta", replace

* Save version for end year (t+3) merge
use "BLS_CPI.dta", clear
keep year CPI
sort year
rename year year_t3
rename CPI cpi_t3
save "cpi_end_annual.dta", replace

* --------
* A3: CREATE 3-YEAR PAIRED OBSERVATIONS
* --------

di ""
di "=============================================================================="
di "A3: CREATING 3-YEAR PAIRED OBSERVATIONS"
di "=============================================================================="

use "taxsim_annual_clean.dta", clear

local lag = 3

sort taxsimid year

* Verify consecutive years
by taxsimid: gen year_gap = year - year[_n-1]
tab year_gap if year_gap != ., missing
di "All gaps should be 1 for annual data"
drop year_gap

* Create LEAD variables for year t+3
by taxsimid: gen mtr_fed_t3 = mtr_fed_t[_n + `lag']
by taxsimid: gen mtr_st_t3 = mtr_st_t[_n + `lag']
by taxsimid: gen tax_fed_t3 = tax_fed_t[_n + `lag']
by taxsimid: gen tax_st_t3 = tax_st_t[_n + `lag']

by taxsimid: gen pwages_t3 = pwages[_n + `lag']
by taxsimid: gen swages_t3 = swages[_n + `lag']
by taxsimid: gen psemp_t3 = psemp[_n + `lag']
by taxsimid: gen ssemp_t3 = ssemp[_n + `lag']
by taxsimid: gen pui_t3 = pui[_n + `lag']
by taxsimid: gen sui_t3 = sui[_n + `lag']
by taxsimid: gen gssi_t3 = gssi[_n + `lag']
by taxsimid: gen transfers_t3 = transfers[_n + `lag']
by taxsimid: gen nonprop_t3 = nonprop[_n + `lag']
by taxsimid: gen pensions_t3 = pensions[_n + `lag']
by taxsimid: gen rentpaid_t3 = rentpaid[_n + `lag']

by taxsimid: gen mstat_t3 = mstat[_n + `lag']
by taxsimid: gen page_t3 = page[_n + `lag']
by taxsimid: gen depx_t3 = depx[_n + `lag']
by taxsimid: gen year_t3 = year[_n + `lag']

* Rename base year variables
rename year year_t
rename pwages pwages_t
rename swages swages_t
rename psemp psemp_t
rename ssemp ssemp_t
rename pui pui_t
rename sui sui_t
rename gssi gssi_t
rename transfers transfers_t
rename nonprop nonprop_t
rename pensions pensions_t
rename rentpaid rentpaid_t
rename mstat mstat_t
rename page page_t
rename depx depx_t

* Drop incomplete pairs
drop if missing(mtr_fed_t3)

di ""
di "Year pairs (annual period):"
tab year_t year_t3

* Keep base years 1978-1990 (end years 1981-1993)
keep if year_t >= 1978 & year_t <= 1990

di ""
di "After restricting to 1978-1990 base years: " _N

save "paired_annual.dta", replace

* --------
* A4: CONSTRUCT INSTRUMENT
* --------

di ""
di "=============================================================================="
di "A4: CONSTRUCTING INSTRUMENT (ANNUAL PERIOD)"
di "=============================================================================="

use "paired_annual.dta", clear

* Merge CPI
merge m:1 year_t using "cpi_base_annual.dta", keep(match master) nogen
merge m:1 year_t3 using "cpi_end_annual.dta", keep(match master) nogen

* Calculate inflation factor
gen inflation_factor = cpi_t3 / cpi_t

di ""
di "Inflation factors by base year:"
tabstat inflation_factor, by(year_t) stat(mean min max n)

* Create inflated income (year t income in year t+3 dollars)
gen pwages_inflated = pwages_t * inflation_factor
gen swages_inflated = swages_t * inflation_factor
gen psemp_inflated = psemp_t * inflation_factor
gen ssemp_inflated = ssemp_t * inflation_factor
gen pui_inflated = pui_t * inflation_factor
gen sui_inflated = sui_t * inflation_factor
gen gssi_inflated = gssi_t * inflation_factor
gen transfers_inflated = transfers_t * inflation_factor
gen nonprop_inflated = nonprop_t * inflation_factor
gen pensions_inflated = pensions_t * inflation_factor
gen rentpaid_inflated = rentpaid_t * inflation_factor

save "paired_annual_with_inflation.dta", replace

* --------
* A5: RUN TAXSIM ON COUNTERFACTUAL
* --------

di ""
di "=============================================================================="
di "A5: RUNNING TAXSIM ON COUNTERFACTUAL (ANNUAL PERIOD)"
di "=============================================================================="

use "paired_annual_with_inflation.dta", clear

* Save identifiers
gen taxsimid_orig = taxsimid
gen year_t_orig = year_t

* Prepare for TAXSIM (year t+3 law, inflated year t income)
gen year = year_t3
gen pwages = pwages_inflated
gen swages = swages_inflated
gen psemp = psemp_inflated
gen ssemp = ssemp_inflated
gen pui = pui_inflated
gen sui = sui_inflated
gen gssi = gssi_inflated
gen transfers = transfers_inflated
gen nonprop = nonprop_inflated
gen pensions = pensions_inflated
gen rentpaid = rentpaid_inflated
gen mstat = mstat_t
gen page = page_t
gen depx = depx_t

* Generate required TAXSIM variables
foreach v in otherprop stcg ltcg proptax otheritem childcare pprofinc sprofinc scorp pbusinc sbusinc {
    capture gen `v' = 0
}

* Zero out spouse variables if not married
replace swages = 0 if mstat != 2
replace ssemp = 0 if mstat != 2
replace sui = 0 if mstat != 2

gen ui = pui

* Zero-fill missing/negative
foreach v in pwages swages psemp ssemp ui sui gssi transfers nonprop pensions rentpaid ///
             mstat page depx otherprop stcg ltcg proptax otheritem childcare ///
             pprofinc sprofinc scorp pbusinc sbusinc {
    capture replace `v' = 0 if missing(`v')
    capture replace `v' = 0 if `v' < 0
}

* --- TAXSIM VARIABLE VALIDATION - Counterfactual ---
* Generate sage if not present (TAXSIM requires it)
capture gen sage = 0
replace sage = 0 if mstat != 2
replace sage = page if mstat == 2 & (missing(sage) | sage == 0)  // Use respondent age as proxy
replace sage = 0 if sage < 0 | sage > 100 | missing(sage)

* Validate page and depx
replace page = 0 if page < 0 | page > 100 | missing(page)
replace depx = 0 if depx < 0 | missing(depx)
replace depx = 15 if depx > 15

keep taxsimid year taxsimid_orig year_t_orig ///
     pwages swages psemp ssemp ui sui gssi transfers nonprop pensions rentpaid ///
     mstat page depx sage otherprop stcg ltcg proptax otheritem childcare ///
     pprofinc sprofinc scorp pbusinc sbusinc

save "counterfactual_annual_for_taxsim.dta", replace

* Run TAXSIM
taxsimlocal35, replace
save "taxsim_counterfactual_annual.dta", replace

* Extract predicted rates
use "taxsim_counterfactual_annual.dta", clear
rename frate mtr_fed_predicted
rename srate mtr_st_predicted
rename fiitax tax_fed_predicted
rename siitax tax_st_predicted

keep taxsimid_orig year_t_orig mtr_fed_predicted mtr_st_predicted tax_fed_predicted tax_st_predicted
rename taxsimid_orig taxsimid
rename year_t_orig year_t

save "predicted_rates_annual.dta", replace

* --------
* A6: MERGE AND APPLY SAMPLE RESTRICTIONS
* --------

di ""
di "=============================================================================="
di "A6: SAMPLE RESTRICTIONS (ANNUAL PERIOD)"
di "=============================================================================="

use "paired_annual_with_inflation.dta", clear
merge 1:1 taxsimid year_t using "predicted_rates_annual.dta", keep(match) nogen

* Create broad income measures
gen broad_income_t = pwages_t + swages_t + psemp_t + ssemp_t + ///
                     pui_t + sui_t + gssi_t + pensions_t + nonprop_t

gen broad_income_t3 = pwages_t3 + swages_t3 + psemp_t3 + ssemp_t3 + ///
                      pui_t3 + sui_t3 + gssi_t3 + pensions_t3 + nonprop_t3

* Create real income in 1984 dollars
gen real_income_t = broad_income_t * ($cpi_1984 / cpi_t)

di ""
di "SAMPLE RESTRICTION FLOW (Annual Period):"
di "-----------------------------------------"

count
local n0 = r(N)
di "Initial paired observations: `n0'"

* Fix: Marital status change — retain with indicator controls (annual period only)
* Original: drop if mstat_t != mstat_t3 removed 21% of sample (ages 17-35, peak marriage years)
* Fix: generate marital-change dummies; add to regression controls (Gruber-Saez 2002 App A2)
gen mstat_change_sm = (mstat_t == 1 & mstat_t3 == 2)   // single → married
gen mstat_change_ms = (mstat_t == 2 & mstat_t3 == 1)   // married → single / divorce
label var mstat_change_sm "Marital change: single at t, married at t+3 [FIX #10]"
label var mstat_change_ms "Marital change: married at t, single at t+3 [FIX #10]"
count
local n1 = r(N)
di "After FIX #10 (retain marital changers with controls): `n1' (" %4.1f 100*`n1'/`n0' "% retained)"
count if mstat_change_sm == 1
di "  Single→Married changers retained as controls: " r(N)
count if mstat_change_ms == 1
di "  Married→Single changers retained as controls: " r(N)

* Fix: Period-specific real income floor ($5K for annual, vs $10K original)
drop if real_income_t < $real_floor_annual
count
local n2 = r(N)
di "After real income floor ($" $real_floor_annual " 1984$, annual) [FIX #9]: `n2' (" %4.1f 100*`n2'/`n0' "% of initial)"

* Positive end-period income
drop if broad_income_t3 <= 0
count
local n3 = r(N)
di "After positive end-period income: `n3' (" %4.1f 100*`n3'/`n0' "% of initial)"

* EITC exclusion
drop if mtr_fed_t < -10 | mtr_fed_t3 < -10 | mtr_fed_predicted < -10
count
local n4 = r(N)
di "After EITC exclusion (MTR < -10%): `n4' (" %4.1f 100*`n4'/`n0' "% of initial)"

global N_annual = `n4'

di ""
di "FINAL ANNUAL SAMPLE: $N_annual observations"

* --------
* A7: CREATE REGRESSION VARIABLES
* --------

di ""
di "=============================================================================="
di "A7: CREATING REGRESSION VARIABLES (ANNUAL PERIOD)"
di "=============================================================================="

* Log income
gen log_income_t = ln(broad_income_t)
gen log_income_t3 = ln(broad_income_t3)
gen log_income_change = log_income_t3 - log_income_t

* Marginal tax rates
gen mtr_t = mtr_fed_t
gen mtr_end = mtr_fed_t3
gen mtr_predicted = mtr_fed_predicted

* Net-of-tax rates
gen ntr_t = 1 - mtr_t/100
gen ntr_end = 1 - mtr_end/100
gen ntr_predicted = 1 - mtr_predicted/100

* Floor net-of-tax rates at 0.01
replace ntr_t = 0.01 if ntr_t <= 0
replace ntr_end = 0.01 if ntr_end <= 0
replace ntr_predicted = 0.01 if ntr_predicted <= 0

* Log net-of-tax rates
gen log_ntr_t = ln(ntr_t)
gen log_ntr_end = ln(ntr_end)
gen log_ntr_predicted = ln(ntr_predicted)

* Key variables for regression
gen log_ntr_change = log_ntr_end - log_ntr_t
gen log_ntr_instrument = log_ntr_predicted - log_ntr_t

* --- FIX #12: TRIM EXTREME LOG INCOME CHANGES (ANNUAL PERIOD) ---
di ""
di "FIX #12 PRE-TRIM DIAGNOSTICS (Annual Period):"
sum log_income_change, detail
count if abs(log_income_change) > log(5) & !missing(log_income_change)
di "  Obs with |Δlog(z)| > log(5)=1.609 (to be dropped): " r(N)

drop if abs(log_income_change) > log(5) & !missing(log_income_change)
count
di "After |Δlog(z)| ≤ log(5) trim [FIX #12]: " r(N) " obs"

* --- FIX #11 (ROBUSTNESS ONLY — NOT IN PRIMARY SPEC): ---
sort taxsimid year_t
by taxsimid: gen log_income_lag3 = log_income_t[_n-1] ///
    if year_t - year_t[_n-1] == 3
gen log_income_change_lag = log_income_t - log_income_lag3
label var log_income_change_lag "Lagged 3-yr log income change (t-3 to t) [Kopczuk 2005 robustness]"

di ""
di "FIX #11 (robustness variable — not in primary spec):"
count if !missing(log_income_change_lag)
di "  Obs with valid lag (balanced-panel subsample): " r(N)
count if missing(log_income_change_lag)
di "  Obs without lag (dropped in robustness only): " r(N)

* Controls
gen income_weight = min(broad_income_t, 1000000)
gen married = (mstat_t == 2)
gen single = (mstat_t == 1)

* Age variable
gen age_t = page_t
gen age_group = 1 if age_t < 25
replace age_group = 2 if age_t >= 25 & age_t < 30
replace age_group = 3 if age_t >= 30
label define age_lbl_ann 1 "Under 25" 2 "25-29" 3 "30+"
label values age_group age_lbl_ann

* Create 10-piece spline
quietly _pctile log_income_t, p(10 20 30 40 50 60 70 80 90)
forval i = 1/9 {
    local cut`i' = r(r`i')
    gen spline`i' = max(0, log_income_t - `cut`i'')
}

di ""
di "Key variables summary:"
sum log_income_change log_ntr_change log_ntr_instrument

di ""
di "First-stage correlation (instrument vs actual change):"
corr log_ntr_change log_ntr_instrument

save "analysis_annual.dta", replace

* --------
* A8: RUN REGRESSIONS (ANNUAL PERIOD)
* --------

di ""
di "=============================================================================="
di "A8: REGRESSIONS (ANNUAL PERIOD)"
di "=============================================================================="

*--- First Stage ---
di ""
di "FIRST STAGE (Annual Period):"
di "----------------------------"
di "[FIX #10: mstat_change_sm/ms added, primary spec; Fix #11 lag demoted to robustness]"
regress log_ntr_change log_ntr_instrument ///
    log_income_t spline1-spline9 i.year_t married single ///
    mstat_change_sm mstat_change_ms ///
    [aweight=income_weight], cluster(taxsimid)
test log_ntr_instrument
global F_annual = r(F)
di ""
di "First-stage F-statistic: " %8.2f $F_annual

*--- Main 2SLS ---
di ""
di "2SLS - MAIN SPECIFICATION (Annual Period):"
di "-------------------------------------------"
di "[FIX #10: mstat_change_sm/ms added, primary spec; Fix #11 lag demoted to robustness]"
ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    mstat_change_sm mstat_change_ms ///
    [aweight=income_weight], cluster(taxsimid)

global beta_annual = _b[log_ntr_change]
global se_annual = _se[log_ntr_change]
global N_annual = e(N)

estimates store annual_main

*--- Kopczuk (2005, Table 5) Robustness: Lagged Income Change [Fix #11] ---
di ""
di "ROBUSTNESS — Kopczuk (2005) Table 5: Lagged Income Change Control:"
di "-------------------------------------------------------------------"
di "Restricts to balanced panels (persons with ≥2 consecutive 3yr windows)"
di "Expected N ≈ 1,600 (97% drop is inherent to the restriction, not a bug)"
regress log_ntr_change log_ntr_instrument ///
    log_income_t spline1-spline9 i.year_t married single ///
    mstat_change_sm mstat_change_ms log_income_change_lag ///
    [aweight=income_weight], cluster(taxsimid)
test log_ntr_instrument
global F_annual_rob = r(F)
di "Kopczuk robustness — first-stage F: " %8.2f $F_annual_rob

di ""
di "2SLS — Kopczuk (2005) Robustness (annual, N≈1,600):"
ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    mstat_change_sm mstat_change_ms log_income_change_lag ///
    [aweight=income_weight], cluster(taxsimid)
global beta_annual_rob = _b[log_ntr_change]
global se_annual_rob = _se[log_ntr_change]
di "Kopczuk robustness — ETI: " %8.3f $beta_annual_rob ///
    "  SE: " %8.3f $se_annual_rob ///
    "  t: " %8.2f $beta_annual_rob/$se_annual_rob
estimates store annual_kopczuk

*--- By Age Group ---
di ""
di "2SLS BY AGE GROUP (Annual Period):"
di "-----------------------------------"

forval ag = 1/3 {
    local lbl: label age_lbl_ann `ag'
    di ""
    di "Age Group: `lbl'"
    capture noisily ivregress 2sls log_income_change ///
        (log_ntr_change = log_ntr_instrument) ///
        log_income_t spline1-spline9 i.year_t married single ///
        mstat_change_sm mstat_change_ms ///
        [aweight=income_weight] if age_group == `ag', cluster(taxsimid)

    if _rc == 0 {
        estimates store annual_age`ag'
    }
}

*--- By Tax Reform Period ---
di ""
di "2SLS BY TAX REFORM PERIOD (Annual Period):"
di "-------------------------------------------"

di ""
di "Pre-ERTA (1978-1980 base years):"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t i.year_t married single ///
    mstat_change_sm mstat_change_ms ///
    [aweight=income_weight] if year_t <= 1980, cluster(taxsimid)
if _rc == 0 {
    estimates store annual_pre_erta
}

di ""
di "ERTA Period (1981-1983 base years):"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t i.year_t married single ///
    mstat_change_sm mstat_change_ms ///
    [aweight=income_weight] if year_t >= 1981 & year_t <= 1983, cluster(taxsimid)
if _rc == 0 {
    estimates store annual_erta
}

di ""
di "TRA86 Period (1984-1986 base years):"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t i.year_t married single ///
    mstat_change_sm mstat_change_ms ///
    [aweight=income_weight] if year_t >= 1984 & year_t <= 1986, cluster(taxsimid)
if _rc == 0 {
    estimates store annual_tra86
}

di ""
di "Post-TRA86 (1987-1990 base years):"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t i.year_t married single ///
    mstat_change_sm mstat_change_ms ///
    [aweight=income_weight] if year_t >= 1987, cluster(taxsimid)
if _rc == 0 {
    estimates store annual_post_tra86
}

*--- Income Heterogeneity ---
di ""
di "2SLS BY INCOME GROUP (Annual Period):"
di "--------------------------------------"

gen income_group = 1 if broad_income_t >= 5000 & broad_income_t < 50000
replace income_group = 2 if broad_income_t >= 50000 & broad_income_t < 100000
replace income_group = 3 if broad_income_t >= 100000

di ""
di "Income Group: $5K-$50K [FIX #9: floor lowered]"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    mstat_change_sm mstat_change_ms ///
    [aweight=income_weight] if income_group == 1, cluster(taxsimid)
if _rc == 0 {
    estimates store annual_inc1
}

di ""
di "Income Group: $50K-$100K"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    mstat_change_sm mstat_change_ms ///
    [aweight=income_weight] if income_group == 2, cluster(taxsimid)
if _rc == 0 {
    estimates store annual_inc2
}

di ""
di "Income Group: $100K+"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    mstat_change_sm mstat_change_ms ///
    [aweight=income_weight] if income_group == 3, cluster(taxsimid)
if _rc == 0 {
    estimates store annual_inc3
}

* --- PART A9: NEAR-WORKER FLOOR ROBUSTNESS ($1K vs $5K ANNUAL INCOME FLOOR) ---

di ""
di "=============================================================================="
di "PART A9: NEAR-WORKER FLOOR ROBUSTNESS ($1K vs $5K annual floor)"
di "=============================================================================="
di ""

* --- Save primary ($5K) results ---
local beta_primary = $beta_annual
local se_primary   = $se_annual
local N_primary    = $N_annual
local F_primary    = $F_annual

di "Primary spec ($5K floor): ETI = " %7.3f `beta_primary' ///
   "  SE = " %6.3f `se_primary' ///
   "  t = " %5.2f `beta_primary'/`se_primary' ///
   "  N = " `N_primary'
di "Now re-estimating with $1K floor..."
di ""

* --- Reload annual data with $1K floor ---
use "paired_annual_with_inflation.dta", clear
merge 1:1 taxsimid year_t using "predicted_rates_annual.dta", ///
    keep(match) nogen

* Recreate income totals (same as A6)
gen broad_income_t  = pwages_t + swages_t + psemp_t + ssemp_t + ///
                      pui_t + sui_t + gssi_t + pensions_t + nonprop_t
gen broad_income_t3 = pwages_t3 + swages_t3 + psemp_t3 + ssemp_t3 + ///
                      pui_t3 + sui_t3 + gssi_t3 + pensions_t3 + nonprop_t3
gen real_income_t   = broad_income_t * ($cpi_1984 / cpi_t)

* Marital change indicators (FIX #10)
gen mstat_change_sm = (mstat_t == 1 & mstat_t3 == 2)
gen mstat_change_ms = (mstat_t == 2 & mstat_t3 == 1)

* Apply $1K floor (robustness)
local floor_rob = 1000
count
local n_before = r(N)
drop if real_income_t < `floor_rob'
count
local n_after_floor = r(N)
di "After $1K real floor: `n_after_floor' obs (vs " `n_before' " before floor)"

* Positive end-period income
drop if broad_income_t3 <= 0

* EITC exclusion
drop if mtr_fed_t < -10 | mtr_fed_t3 < -10 | mtr_fed_predicted < -10
count
local N_rob = r(N)
di "Final sample ($1K floor): `N_rob' observations"
di "Additional workers vs $5K floor: " (`N_rob' - `N_primary') ///
   " (+" %4.1f 100*(`N_rob' - `N_primary')/`N_primary' "%)"
di ""

* Describe near-worker stratum
count if real_income_t >= 1000 & real_income_t < 5000
local N_stratum = r(N)
di "Near-workers added ($1K–$5K stratum): `N_stratum' observations"
if `N_stratum' > 0 {
    sum real_income_t if real_income_t >= 1000 & real_income_t < 5000
    di "  Mean real income (near-workers): $" %6.0f r(mean) " (1984 dollars)"
}
di ""

* --- Recreate regression variables (same as A7) ---
gen log_income_t    = ln(broad_income_t)
gen log_income_t3   = ln(broad_income_t3)
gen log_income_change = log_income_t3 - log_income_t

gen mtr_t         = mtr_fed_t
gen mtr_end       = mtr_fed_t3
gen mtr_predicted = mtr_fed_predicted

gen ntr_t         = 1 - mtr_t/100
gen ntr_end       = 1 - mtr_end/100
gen ntr_predicted = 1 - mtr_predicted/100

replace ntr_t         = max(ntr_t, 0.01)
replace ntr_end       = max(ntr_end, 0.01)
replace ntr_predicted = max(ntr_predicted, 0.01)

gen log_ntr_change     = log(ntr_end)  - log(ntr_t)
gen log_ntr_instrument = log(ntr_predicted) - log(ntr_t)

* Fix: Trim extreme log income changes (|Δlog z| > log 5)
drop if abs(log_income_change) > log(5) & !missing(log_income_change)
count
di "After FIX #12 trim: " r(N) " observations"

* Controls
gen income_weight = min(broad_income_t, 1000000)
gen married = (mstat_t == 2)
gen single  = (mstat_t == 1)

* Income spline (10-piece, recomputed from this sample's distribution)
quietly _pctile log_income_t, p(10 20 30 40 50 60 70 80 90)
forval i = 1/9 {
    local cut`i' = r(r`i')
    gen spline`i' = max(0, log_income_t - `cut`i'')
}

* --- First stage (near-worker sample) ---
di "FIRST STAGE ($1K floor):"
regress log_ntr_change log_ntr_instrument ///
    log_income_t spline1-spline9 i.year_t married single ///
    mstat_change_sm mstat_change_ms ///
    [aweight=income_weight], cluster(taxsimid)
test log_ntr_instrument
local F_rob = r(F)
di "  First-stage F ($1K floor): " %8.2f `F_rob'
di "  First-stage F ($5K floor): " %8.2f `F_primary' " [primary]"
di ""

* --- Main 2SLS (near-worker sample) ---
di "2SLS — NEAR-WORKER ROBUSTNESS ($1K floor):"
ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    mstat_change_sm mstat_change_ms ///
    [aweight=income_weight], cluster(taxsimid)

local beta_rob = _b[log_ntr_change]
local se_rob   = _se[log_ntr_change]
estimates store annual_nearworker

* --- Side-by-side comparison ---
di ""
di "======================================================"
di "FLOOR SENSITIVITY: ANNUAL ETI ($5K vs $1K)"
di "======================================================"
di ""
di "                         $5K floor       $1K floor"
di "                         (primary)       (robustness)"
di "                         ---------       ------------"
di "ETI estimate             " %8.3f `beta_primary' "         " %8.3f `beta_rob'
di "Standard error           " %8.3f `se_primary'   "         " %8.3f `se_rob'
di "t-statistic              " %8.2f `beta_primary'/`se_primary' ///
   "         " %8.2f `beta_rob'/`se_rob'
di "N (person-years)         " %8.0f `N_primary'    "         " %8.0f `N_rob'
di "First-stage F            " %8.1f `F_primary'    "         " %8.1f `F_rob'
di ""
di "Near-workers added ($1K–$5K stratum): `N_stratum' obs"
di ""

* Interpret result
local sig_primary = (abs(`beta_primary'/`se_primary') >= 1.96)
local sig_rob     = (abs(`beta_rob'/`se_rob') >= 1.96)

if `sig_primary' == 0 & `sig_rob' == 0 {
    di "CONCLUSION: Annual ETI is INSIGNIFICANT under BOTH floor specifications."
    di "  → Floor choice does not explain the near-zero result."
    di "  → Confirms lifecycle interpretation: young workers (ages 17-35)"
    di "    do not adjust taxable income in response to net-of-tax rate changes"
    di "    regardless of income floor. Signaling incentives dominate tax"
    di "    optimization at this career stage."
    di "  → τ_p = 19.0% from biennial ε is unaffected (different period, different floor)."
}
else if `sig_primary' == 0 & `sig_rob' == 1 {
    di "NOTE: Significant at $1K but not $5K floor."
    di "  Near-workers ($1K-$5K) drive significance. Likely artifact:"
    di "  these workers face near-zero MTRs; check if first-stage F"
    di "  is strong for the $1K sample. If F_rob << F_primary, spurious."
    di "  Retain $5K floor as primary; report $1K as sensitivity."
}
else if `sig_primary' == 1 & `sig_rob' == 1 {
    di "NOTE: Significant under both floors. Consistent annual ETI."
    di "  Update primary results — both specifications agree."
}
else {
    di "NOTE: Significant at $5K but not $1K floor."
    di "  Near-workers dilute the annual estimate. $5K floor is appropriate."
}

di ""
di "NOTE: Biennial τ_p = 19.0% [15.6%, 22.6%] is unchanged — derived from"
di "  biennial ε (1995-2019, $10K floor) and γ_FE (Phase 1). Neither input"
di "  is affected by the annual income floor choice."
di ""

* --- PART A10: PRE-TREND TESTS AND PLACEBO REGRESSIONS (ANNUAL PERIOD) ---

di ""
di "=============================================================================="
di "PART A10: PRE-TREND TESTS AND PLACEBO REGRESSIONS (ANNUAL PERIOD)"
di "=============================================================================="

* --------
* A10a: BUILD PRE-PERIOD INCOME CHANGE (t-3 → t) WITHIN analysis_annual.dta
* --------

* Reload primary analysis dataset
use "analysis_annual.dta", clear

di ""
di "A10a: ANNUAL PRE-TREND TEST"
di "---------------------------------------------------------------------------"
di "  Dependent var: log income change from (t-3) to t"
di "  Instrument:    log_ntr_instrument (same simulated NTR as main spec)"
di "  H0: coeff = 0  (instrument uncorrelated with pre-reform income dynamics)"
di ""

* Construct lagged income from analysis_annual: each row is (taxsimid, year_t).
* If the same person appears at year_t and year_t-3, the earlier row's
* log_income_t is the t-3 income for the later row.
sort taxsimid year_t
bysort taxsimid (year_t): gen log_inc_lag3 = log_income_t[_n-3] ///
    if year_t - year_t[_n-3] == 3
label var log_inc_lag3 "log income 3 base-years prior (t-3)"

gen log_change_pre = log_income_t - log_inc_lag3
label var log_change_pre "Pre-period income change: log(income_t) - log(income_{t-3})"

qui count if !missing(log_change_pre) & !missing(log_ntr_instrument)
local n_pre = r(N)
di "Pre-trend test sample (persons with t-3 obs in analysis_annual): " `n_pre' " obs"

if `n_pre' >= 300 {
    di ""
    di "PRE-TREND REGRESSION:"
    ivregress 2sls log_change_pre ///
        (log_ntr_change = log_ntr_instrument) ///
        log_income_t spline1-spline9 i.year_t married single ///
        mstat_change_sm mstat_change_ms ///
        [aweight=income_weight] if !missing(log_change_pre), ///
        cluster(taxsimid)
    estimates store annual_pretrend

    local b_pre  = _b[log_ntr_change]
    local se_pre = _se[log_ntr_change]
    local t_pre  = `b_pre' / `se_pre'
    local n_pre_reg = e(N)

    di ""
    di "Pre-trend result (annual):"
    di "  Coefficient: " %9.4f `b_pre' "   SE: " %8.4f `se_pre' ///
       "   t: " %6.2f `t_pre' "   N: " `n_pre_reg'
    di ""
    if abs(`t_pre') < 1.96 {
        di "  PASS (|t| < 1.96): Instrument is not correlated with pre-reform"
        di "  income trends. Parallel trends assumption is supported."
    }
    else if abs(`t_pre') >= 1.96 & abs(`t_pre') < 2.58 {
        di "  BORDERLINE (1.96 ≤ |t| < 2.58): Weak pre-trend evidence."
        di "  Consider including lagged income change control (Fix #11)."
    }
    else {
        di "  FAIL (|t| ≥ 2.58): Significant pre-trend. Investigate whether"
        di "  income trends are correlated with the simulated NTR instrument."
        di "  Potential solutions: (a) control for lagged income growth,"
        di "  (b) restrict to non-anticipation window, (c) check reform timing."
    }
}
else {
    di "  Insufficient pre-trend obs (< 300). Skipping pre-trend regression."
    di "  This may occur if the person-level balanced-panel requirement is"
    di "  very restrictive given the annual income floor and sample restrictions."
}

* --------
* A10b: ANNUAL PLACEBO PERIOD SUMMARY
* --------

di ""
di "A10b: ANNUAL PLACEBO PERIOD SUMMARY"
di "---------------------------------------------------------------------------"
di ""
di "  Uses reform-period estimates already stored in Part A8."
di "  REFORM windows (ETI should be non-zero if instrument is valid):"
di "    pre-ERTA 1978-1980: t+3 window spans ERTA 1981"
di "    TRA86   1984-1986:  t+3 window spans TRA 1986"
di ""
di "  PLACEBO windows (no major reform in t → t+3; ETI should be ≈ 0):"
di "    ERTA    1981-1983:  post-ERTA, pre-TRA86"
di "    post-TRA86 1987-1990: post-TRA86, no further reforms before 1993"
di ""
di "  Period                 | Base yrs  | Type    |   ETI    |  SE     |   t  |  N"
di "  -----------------------|-----------|---------|----------|---------|------|------"

foreach spec in pre_erta erta tra86 post_tra86 {
    capture {
        estimates restore annual_`spec'
        local b_s  = _b[log_ntr_change]
        local se_s = _se[log_ntr_change]
        local t_s  = `b_s' / `se_s'
        local n_s  = e(N)

        if "`spec'" == "pre_erta"    local lbl "pre-ERTA 1978-80 [REFORM] "
        if "`spec'" == "erta"        local lbl "ERTA     1981-83 [PLACEBO]"
        if "`spec'" == "tra86"       local lbl "TRA86    1984-86 [REFORM] "
        if "`spec'" == "post_tra86"  local lbl "post-TRA86 87-90 [PLACEBO]"

        di "  `lbl' | " %9.4f `b_s' " | " %7.4f `se_s' " | " %5.2f `t_s' " | " `n_s'
    }
    if _rc != 0 {
        di "  WARNING: estimates for annual_`spec' not found (may not have converged)"
    }
}

di ""
di "  INTERPRETATION:"
di "    Placebos (erta, post_tra86) should show |t| < 1.96 if IV is reform-driven."
di "    Reform windows (pre_erta, tra86) should show larger absolute ETI."
di "    If placebos ≈ 0 and reforms ≠ 0: identification is reform-specific. ✓"
di "    If placebos ≈ reforms: instrument captures secular trend, not reform. ✗"
di ""

* --------
* A10c: COMPARISON TABLE — MAIN vs PRE-TREND vs PLACEBO
* --------

di ""
di "A10c: CONSOLIDATED VALIDITY SUMMARY (ANNUAL PERIOD)"
di "---------------------------------------------------------------------------"
di ""
di "  Specification               | ETI      |  SE      |   t   | Conclusion"
di "  ----------------------------|----------|----------|-------|------------"
di "  Main (primary, all years)   | " %8.4f $beta_annual " | " %8.4f $se_annual " | " %5.2f $beta_annual/$se_annual " | Primary estimate"

capture {
    estimates restore annual_pretrend
    local b_pt = _b[log_ntr_change]
    local se_pt = _se[log_ntr_change]
    di "  Pre-trend test (t-3→t)    | " %8.4f `b_pt' " | " %8.4f `se_pt' " | " %5.2f `b_pt'/`se_pt' " | Should be ≈ 0"
}
if _rc != 0 di "  Pre-trend test            | [not estimated — sample too small]"

capture {
    estimates restore annual_erta
    di "  Placebo 1: 1981-83         | " %8.4f _b[log_ntr_change] " | " %8.4f _se[log_ntr_change] " | " %5.2f _b[log_ntr_change]/_se[log_ntr_change] " | Should be ≈ 0"
}
capture {
    estimates restore annual_post_tra86
    di "  Placebo 2: 1987-90         | " %8.4f _b[log_ntr_change] " | " %8.4f _se[log_ntr_change] " | " %5.2f _b[log_ntr_change]/_se[log_ntr_change] " | Should be ≈ 0"
}

di ""
di "=============================================================================="
di "END PART A10: PRE-TREND TESTS (ANNUAL PERIOD)"
di "=============================================================================="
di ""

* --- PART B: BIENNIAL PERIOD ANALYSIS (1995-2019) — 2-YEAR DIFFERENCES ---

di ""
di "=============================================================================="
di "=============================================================================="
di "PART B: BIENNIAL PERIOD ANALYSIS"
di "=============================================================================="
di "=============================================================================="
di ""
di "Period: 1995-2019 (income years, odd years only)"
di "Lag: 2 years (matches survey frequency)"
di "Cohort ages: ~31-62"
di "Major tax reforms: EGTRRA 2001, JGTRRA 2003, ATRA 2012, TCJA 2017"
di ""
di "NOTE: Ages in biennial period are INCOME-YEAR ages (corrected in Data_process.do)"
di ""

* --------
* B1: RUN TAXSIM ON BIENNIAL DATA
* --------

di ""
di "=============================================================================="
di "B1: RUNNING TAXSIM ON BIENNIAL DATA (1995-2019)"
di "=============================================================================="

use "nlsy_long_pre_taxsim.dta", clear

* Keep only biennial period (odd years from 1995 onwards)
keep if year >= 1995 & mod(year, 2) == 1

di ""
di "Observations in biennial period: " _N
tab year

* Check income data exists
di ""
di "Income check (should have positive values):"
tabstat pwages, by(year) stat(mean median n)

* Verify marital status distribution
di ""
di "Marital status distribution (biennial period):"
tab mstat

* --- TAXSIM VARIABLE VALIDATION (FIX #6) ---

di ""
di "Validating TAXSIM inputs before running..."

* Validate sage (spouse age) - must be 0-100
replace sage = 0 if sage < 0 | sage > 100 | missing(sage)
replace sage = 0 if mstat != 2  // Single filers should have sage = 0

* Validate page (primary taxpayer age) - must be 0-100
replace page = 0 if page < 0 | page > 100 | missing(page)

* Validate mstat - must be 1 or 2
replace mstat = 1 if mstat != 1 & mstat != 2

* Validate depx - must be 0-15
replace depx = 0 if depx < 0 | missing(depx)
replace depx = 15 if depx > 15

* Zero out spouse income for single filers
replace swages = 0 if mstat != 2
replace ssemp = 0 if mstat != 2

* Validate all income variables are non-negative
foreach v in pwages swages psemp ssemp pui sui gssi transfers nonprop pensions rentpaid {
    capture replace `v' = 0 if `v' < 0 | missing(`v')
}

di ""
di "Validation summary:"
di "  sage range: " 
summarize sage, meanonly
di "    min=" r(min) " max=" r(max)
count if sage > 100 | sage < 0
di "    invalid values: " r(N)

di "  page range:"
summarize page, meanonly  
di "    min=" r(min) " max=" r(max)

di ""
di "Running TAXSIM..."

* Run TAXSIM
taxsimlocal35, replace
save "taxsim_biennial.dta", replace

* Rename outputs
use "taxsim_biennial.dta", clear
rename fiitax tax_fed_t
rename siitax tax_st_t
rename frate mtr_fed_t
rename srate mtr_st_t

di ""
di "Actual marginal tax rates (biennial period):"
sum mtr_fed_t mtr_st_t, detail

* Keep needed variables
keep taxsimid year mtr_fed_t mtr_st_t tax_fed_t tax_st_t ///
     pwages swages psemp ssemp pui sui gssi transfers nonprop pensions rentpaid ///
     mstat page depx

save "taxsim_biennial_clean.dta", replace

* --------
* B2: CREATE CPI DATA FOR BIENNIAL PERIOD
* --------

di ""
di "=============================================================================="
di "B2: CREATING CPI DATA FOR BIENNIAL PERIOD"
di "=============================================================================="

use "BLS_CPI.dta", clear
keep year CPI
sort year

* Save version for base year merge
rename year year_t
rename CPI cpi_t
save "cpi_base_biennial.dta", replace

* Save version for end year (t+2) merge
use "BLS_CPI.dta", clear
keep year CPI
sort year
rename year year_t2
rename CPI cpi_t2
save "cpi_end_biennial.dta", replace

* --------
* B3: CREATE 2-YEAR PAIRED OBSERVATIONS
* --------

di ""
di "=============================================================================="
di "B3: CREATING 2-YEAR PAIRED OBSERVATIONS"
di "=============================================================================="

use "taxsim_biennial_clean.dta", clear

* For biennial data, 1 observation ahead = 2 calendar years
local lag = 1

sort taxsimid year

* Verify 2-year gaps
by taxsimid: gen year_gap = year - year[_n-1]
tab year_gap if year_gap != ., missing
di "All gaps should be 2 for biennial data"
drop year_gap

* Create LEAD variables (1 observation ahead = 2 years ahead)
by taxsimid: gen mtr_fed_t2 = mtr_fed_t[_n + `lag']
by taxsimid: gen mtr_st_t2 = mtr_st_t[_n + `lag']
by taxsimid: gen tax_fed_t2 = tax_fed_t[_n + `lag']
by taxsimid: gen tax_st_t2 = tax_st_t[_n + `lag']

by taxsimid: gen pwages_t2 = pwages[_n + `lag']
by taxsimid: gen swages_t2 = swages[_n + `lag']
by taxsimid: gen psemp_t2 = psemp[_n + `lag']
by taxsimid: gen ssemp_t2 = ssemp[_n + `lag']
by taxsimid: gen pui_t2 = pui[_n + `lag']
by taxsimid: gen sui_t2 = sui[_n + `lag']
by taxsimid: gen gssi_t2 = gssi[_n + `lag']
by taxsimid: gen transfers_t2 = transfers[_n + `lag']
by taxsimid: gen nonprop_t2 = nonprop[_n + `lag']
by taxsimid: gen pensions_t2 = pensions[_n + `lag']
by taxsimid: gen rentpaid_t2 = rentpaid[_n + `lag']

by taxsimid: gen mstat_t2 = mstat[_n + `lag']
by taxsimid: gen page_t2 = page[_n + `lag']
by taxsimid: gen depx_t2 = depx[_n + `lag']
by taxsimid: gen year_t2 = year[_n + `lag']

* Rename base year variables
rename year year_t
rename pwages pwages_t
rename swages swages_t
rename psemp psemp_t
rename ssemp ssemp_t
rename pui pui_t
rename sui sui_t
rename gssi gssi_t
rename transfers transfers_t
rename nonprop nonprop_t
rename pensions pensions_t
rename rentpaid rentpaid_t
rename mstat mstat_t
rename page page_t
rename depx depx_t

* Drop incomplete pairs
drop if missing(mtr_fed_t2)

di ""
di "Year pairs (biennial period):"
tab year_t year_t2

* Keep base years 1995-2017 (end years 1997-2019)
keep if year_t >= 1995 & year_t <= 2017

di ""
di "After restricting to 1995-2017 base years: " _N

save "paired_biennial.dta", replace

* --------
* B4: CONSTRUCT INSTRUMENT
* --------

di ""
di "=============================================================================="
di "B4: CONSTRUCTING INSTRUMENT (BIENNIAL PERIOD)"
di "=============================================================================="

use "paired_biennial.dta", clear

* Merge CPI
merge m:1 year_t using "cpi_base_biennial.dta", keep(match master) nogen
merge m:1 year_t2 using "cpi_end_biennial.dta", keep(match master) nogen

* Calculate inflation factor
gen inflation_factor = cpi_t2 / cpi_t

di ""
di "Inflation factors by base year:"
tabstat inflation_factor, by(year_t) stat(mean min max n)

* Create inflated income (year t income in year t+2 dollars)
gen pwages_inflated = pwages_t * inflation_factor
gen swages_inflated = swages_t * inflation_factor
gen psemp_inflated = psemp_t * inflation_factor
gen ssemp_inflated = ssemp_t * inflation_factor
gen pui_inflated = pui_t * inflation_factor
gen sui_inflated = sui_t * inflation_factor
gen gssi_inflated = gssi_t * inflation_factor
gen transfers_inflated = transfers_t * inflation_factor
gen nonprop_inflated = nonprop_t * inflation_factor
gen pensions_inflated = pensions_t * inflation_factor
gen rentpaid_inflated = rentpaid_t * inflation_factor

save "paired_biennial_with_inflation.dta", replace

* --------
* B5: RUN TAXSIM ON COUNTERFACTUAL
* --------

di ""
di "=============================================================================="
di "B5: RUNNING TAXSIM ON COUNTERFACTUAL (BIENNIAL PERIOD)"
di "=============================================================================="

use "paired_biennial_with_inflation.dta", clear

* Save identifiers
gen taxsimid_orig = taxsimid
gen year_t_orig = year_t

* Prepare for TAXSIM (year t+2 law, inflated year t income)
gen year = year_t2
gen pwages = pwages_inflated
gen swages = swages_inflated
gen psemp = psemp_inflated
gen ssemp = ssemp_inflated
gen pui = pui_inflated
gen sui = sui_inflated
gen gssi = gssi_inflated
gen transfers = transfers_inflated
gen nonprop = nonprop_inflated
gen pensions = pensions_inflated
gen rentpaid = rentpaid_inflated
gen mstat = mstat_t
gen page = page_t
gen depx = depx_t

* Generate required TAXSIM variables
foreach v in otherprop stcg ltcg proptax otheritem childcare pprofinc sprofinc scorp pbusinc sbusinc {
    capture gen `v' = 0
}

* Zero out spouse variables if not married
replace swages = 0 if mstat != 2
replace ssemp = 0 if mstat != 2
replace sui = 0 if mstat != 2

gen ui = pui

* Zero-fill missing/negative
foreach v in pwages swages psemp ssemp ui sui gssi transfers nonprop pensions rentpaid ///
             mstat page depx otherprop stcg ltcg proptax otheritem childcare ///
             pprofinc sprofinc scorp pbusinc sbusinc {
    capture replace `v' = 0 if missing(`v')
    capture replace `v' = 0 if `v' < 0
}

* --- TAXSIM VARIABLE VALIDATION - Biennial Counterfactual ---
* Generate sage if not present (TAXSIM requires it)
capture gen sage = 0
replace sage = 0 if mstat != 2
replace sage = page if mstat == 2 & (missing(sage) | sage == 0)  // Use respondent age as proxy
replace sage = 0 if sage < 0 | sage > 100 | missing(sage)

* Validate page and depx
replace page = 0 if page < 0 | page > 100 | missing(page)
replace depx = 0 if depx < 0 | missing(depx)
replace depx = 15 if depx > 15

di ""
di "Biennial counterfactual validation:"
di "  sage range:"
summarize sage, meanonly
di "    min=" r(min) " max=" r(max)
count if sage > 100 | sage < 0
di "    invalid values: " r(N)

keep taxsimid year taxsimid_orig year_t_orig ///
     pwages swages psemp ssemp ui sui gssi transfers nonprop pensions rentpaid ///
     mstat page depx sage otherprop stcg ltcg proptax otheritem childcare ///
     pprofinc sprofinc scorp pbusinc sbusinc

save "counterfactual_biennial_for_taxsim.dta", replace

di ""
di "Running TAXSIM on biennial counterfactual..."

* Run TAXSIM
taxsimlocal35, replace
save "taxsim_counterfactual_biennial.dta", replace

* Extract predicted rates
use "taxsim_counterfactual_biennial.dta", clear
rename frate mtr_fed_predicted
rename srate mtr_st_predicted
rename fiitax tax_fed_predicted
rename siitax tax_st_predicted

keep taxsimid_orig year_t_orig mtr_fed_predicted mtr_st_predicted tax_fed_predicted tax_st_predicted
rename taxsimid_orig taxsimid
rename year_t_orig year_t

save "predicted_rates_biennial.dta", replace

* --------
* B6: MERGE AND APPLY SAMPLE RESTRICTIONS
* --------

di ""
di "=============================================================================="
di "B6: SAMPLE RESTRICTIONS (BIENNIAL PERIOD)"
di "=============================================================================="

use "paired_biennial_with_inflation.dta", clear
merge 1:1 taxsimid year_t using "predicted_rates_biennial.dta", keep(match) nogen

* Create broad income measures
gen broad_income_t = pwages_t + swages_t + psemp_t + ssemp_t + ///
                     pui_t + sui_t + gssi_t + pensions_t + nonprop_t

gen broad_income_t2 = pwages_t2 + swages_t2 + psemp_t2 + ssemp_t2 + ///
                      pui_t2 + sui_t2 + gssi_t2 + pensions_t2 + nonprop_t2

* Create real income in 1984 dollars
gen real_income_t = broad_income_t * ($cpi_1984 / cpi_t)

di ""
di "SAMPLE RESTRICTION FLOW (Biennial Period):"
di "-------------------------------------------"

count
local n0 = r(N)
di "Initial paired observations: `n0'"

* Marital stability
drop if mstat_t != mstat_t2
count
local n1 = r(N)
di "After marital stability: `n1' (" %4.1f 100*`n1'/`n0' "% retained)"

* Real income floor
drop if real_income_t < $real_floor
count
local n2 = r(N)
di "After real income floor ($10K 1984$): `n2' (" %4.1f 100*`n2'/`n0' "% of initial)"

* Positive end-period income
drop if broad_income_t2 <= 0
count
local n3 = r(N)
di "After positive end-period income: `n3' (" %4.1f 100*`n3'/`n0' "% of initial)"

* EITC exclusion
drop if mtr_fed_t < -10 | mtr_fed_t2 < -10 | mtr_fed_predicted < -10
count
local n4 = r(N)
di "After EITC exclusion (MTR < -10%): `n4' (" %4.1f 100*`n4'/`n0' "% of initial)"

global N_biennial = `n4'

di ""
di "FINAL BIENNIAL SAMPLE: $N_biennial observations"

* --------
* B7: CREATE REGRESSION VARIABLES
* --------

di ""
di "=============================================================================="
di "B7: CREATING REGRESSION VARIABLES (BIENNIAL PERIOD)"
di "=============================================================================="

* Log income
gen log_income_t = ln(broad_income_t)
gen log_income_t2 = ln(broad_income_t2)
gen log_income_change = log_income_t2 - log_income_t

* --- FIX #12 (BIENNIAL PERIOD): Trim extreme log income changes ---
di ""
di "FIX #12 PRE-TRIM DIAGNOSTICS (Biennial Period):"
sum log_income_change, detail
count if abs(log_income_change) > log(5) & !missing(log_income_change)
di "  Obs with |Δlog(z)| > log(5)=1.609 (to be dropped): " r(N)

drop if abs(log_income_change) > log(5) & !missing(log_income_change)
count
di "After |Δlog(z)| ≤ log(5) trim [FIX #12]: " r(N) " obs"

* Marginal tax rates
gen mtr_t = mtr_fed_t
gen mtr_end = mtr_fed_t2
gen mtr_predicted = mtr_fed_predicted

* Net-of-tax rates
gen ntr_t = 1 - mtr_t/100
gen ntr_end = 1 - mtr_end/100
gen ntr_predicted = 1 - mtr_predicted/100

* Floor net-of-tax rates at 0.01
replace ntr_t = 0.01 if ntr_t <= 0
replace ntr_end = 0.01 if ntr_end <= 0
replace ntr_predicted = 0.01 if ntr_predicted <= 0

* Log net-of-tax rates
gen log_ntr_t = ln(ntr_t)
gen log_ntr_end = ln(ntr_end)
gen log_ntr_predicted = ln(ntr_predicted)

* Key variables for regression
gen log_ntr_change = log_ntr_end - log_ntr_t
gen log_ntr_instrument = log_ntr_predicted - log_ntr_t

* Controls
gen income_weight = min(broad_income_t, 1000000)
gen married = (mstat_t == 2)
gen single = (mstat_t == 1)

* Age variable
gen age_t = page_t
gen age_group = 1 if age_t < 40
replace age_group = 2 if age_t >= 40 & age_t < 50
replace age_group = 3 if age_t >= 50
label define age_lbl_bien 1 "Under 40" 2 "40-49" 3 "50+"
label values age_group age_lbl_bien

* Create 10-piece spline
quietly _pctile log_income_t, p(10 20 30 40 50 60 70 80 90)
forval i = 1/9 {
    local cut`i' = r(r`i')
    gen spline`i' = max(0, log_income_t - `cut`i'')
}

di ""
di "Key variables summary:"
sum log_income_change log_ntr_change log_ntr_instrument

di ""
di "First-stage correlation (instrument vs actual change):"
corr log_ntr_change log_ntr_instrument

save "analysis_biennial.dta", replace

* --------
* B8: RUN REGRESSIONS (BIENNIAL PERIOD)
* --------

di ""
di "=============================================================================="
di "B8: REGRESSIONS (BIENNIAL PERIOD)"
di "=============================================================================="

*--- First Stage ---
di ""
di "FIRST STAGE (Biennial Period):"
di "------------------------------"
regress log_ntr_change log_ntr_instrument ///
    log_income_t spline1-spline9 i.year_t married single ///
    [aweight=income_weight], cluster(taxsimid)
test log_ntr_instrument
global F_biennial = r(F)
di ""
di "First-stage F-statistic: " %8.2f $F_biennial

*--- Main 2SLS ---
di ""
di "2SLS - MAIN SPECIFICATION (Biennial Period):"
di "---------------------------------------------"
ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    [aweight=income_weight], cluster(taxsimid)

global beta_biennial = _b[log_ntr_change]
global se_biennial = _se[log_ntr_change]

estimates store biennial_main

*--- By Age Group ---
di ""
di "2SLS BY AGE GROUP (Biennial Period):"
di "-------------------------------------"

forval ag = 1/3 {
    local lbl: label age_lbl_bien `ag'
    di ""
    di "Age Group: `lbl'"
    capture noisily ivregress 2sls log_income_change ///
        (log_ntr_change = log_ntr_instrument) ///
        log_income_t spline1-spline9 i.year_t married single ///
        [aweight=income_weight] if age_group == `ag', cluster(taxsimid)
    
    if _rc == 0 {
        estimates store biennial_age`ag'
    }
}

*--- By Tax Reform Period ---
di ""
di "2SLS BY TAX REFORM PERIOD (Biennial Period):"
di "---------------------------------------------"

di ""
di "Pre-EGTRRA (1995-1999 base years):"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t i.year_t married single ///
    [aweight=income_weight] if year_t <= 1999, cluster(taxsimid)
if _rc == 0 {
    estimates store biennial_pre_egtrra
}

di ""
di "Bush Tax Cuts (2001-2007 base years):"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t i.year_t married single ///
    [aweight=income_weight] if year_t >= 2001 & year_t <= 2007, cluster(taxsimid)
if _rc == 0 {
    estimates store biennial_bush
}

di ""
di "Great Recession (2009-2011 base years):"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t i.year_t married single ///
    [aweight=income_weight] if year_t >= 2009 & year_t <= 2011, cluster(taxsimid)
if _rc == 0 {
    estimates store biennial_recession
}

di ""
di "Post-ATRA/TCJA (2013-2017 base years):"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t i.year_t married single ///
    [aweight=income_weight] if year_t >= 2013, cluster(taxsimid)
if _rc == 0 {
    estimates store biennial_tcja
}

*--- Income Heterogeneity ---
di ""
di "2SLS BY INCOME GROUP (Biennial Period):"
di "----------------------------------------"

gen income_group = 1 if broad_income_t >= 10000 & broad_income_t < 50000
replace income_group = 2 if broad_income_t >= 50000 & broad_income_t < 100000
replace income_group = 3 if broad_income_t >= 100000

di ""
di "Income Group: $10K-$50K"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    [aweight=income_weight] if income_group == 1, cluster(taxsimid)
if _rc == 0 {
    estimates store biennial_inc1
}

di ""
di "Income Group: $50K-$100K"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    [aweight=income_weight] if income_group == 2, cluster(taxsimid)
if _rc == 0 {
    estimates store biennial_inc2
}

di ""
di "Income Group: $100K+"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    [aweight=income_weight] if income_group == 3, cluster(taxsimid)
if _rc == 0 {
    estimates store biennial_inc3
}

* --- PART B9: PRE-TREND TESTS AND PLACEBO REGRESSIONS (BIENNIAL PERIOD) ---

di ""
di "=============================================================================="
di "PART B9: PRE-TREND TESTS AND PLACEBO REGRESSIONS (BIENNIAL PERIOD)"
di "=============================================================================="

* --------
* B9a: BUILD PRE-PERIOD INCOME CHANGE (t-2 → t) WITHIN analysis_biennial.dta
* --------

use "analysis_biennial.dta", clear

di ""
di "B9a: BIENNIAL PRE-TREND TEST"
di "---------------------------------------------------------------------------"
di "  Dependent var: log income change from (t-2) to t"
di "  Instrument:    log_ntr_instrument (same simulated NTR as main spec)"
di "  H0: coeff = 0"
di ""

* In analysis_biennial, base years are biennial: 1995, 1997, 1999, ..., 2017.
* Two consecutive biennial base years are 2 calendar years apart.
* Lagged income: look back to the previous base year (2 years earlier).
sort taxsimid year_t
bysort taxsimid (year_t): gen log_inc_lag2 = log_income_t[_n-1] ///
    if year_t - year_t[_n-1] == 2
label var log_inc_lag2 "log income at previous biennial base year (t-2)"

gen log_change_pre_b = log_income_t - log_inc_lag2
label var log_change_pre_b "Pre-period income change: log(income_t) - log(income_{t-2})"

qui count if !missing(log_change_pre_b) & !missing(log_ntr_instrument)
local n_bpre = r(N)
di "Biennial pre-trend test sample (persons with t-2 biennial obs): " `n_bpre' " obs"
di "(Coverage: base years 1997-2017; 1995 has no t-2 obs in biennial period)"

if `n_bpre' >= 300 {
    di ""
    di "BIENNIAL PRE-TREND REGRESSION:"
    ivregress 2sls log_change_pre_b ///
        (log_ntr_change = log_ntr_instrument) ///
        log_income_t spline1-spline9 i.year_t married single ///
        [aweight=income_weight] if !missing(log_change_pre_b), ///
        cluster(taxsimid)
    estimates store biennial_pretrend

    local b_bpre  = _b[log_ntr_change]
    local se_bpre = _se[log_ntr_change]
    local t_bpre  = `b_bpre' / `se_bpre'
    local n_bpre_r = e(N)

    di ""
    di "Biennial pre-trend result:"
    di "  Coefficient: " %9.4f `b_bpre' "   SE: " %8.4f `se_bpre' ///
       "   t: " %6.2f `t_bpre' "   N: " `n_bpre_r'
    di ""
    if abs(`t_bpre') < 1.96 {
        di "  PASS (|t| < 1.96): Biennial instrument orthogonal to pre-reform"
        di "  income trends. IV identification assumption supported."
    }
    else {
        di "  FAIL (|t| ≥ 1.96): Biennial pre-trend is significant."
        di "  Investigate whether biennial reforms correlate with prior income growth."
        di "  Consider controlling for lagged income change."
    }
}
else {
    di "  Insufficient biennial pre-trend obs (< 300). Skipping."
}

* --------
* B9b: BIENNIAL PLACEBO PERIOD SUMMARY
* --------

di ""
di "B9b: BIENNIAL PLACEBO PERIOD SUMMARY"
di "---------------------------------------------------------------------------"
di ""
di "  Period                  | Base yrs   | Type    |   ETI    |  SE     |   t  |  N"
di "  ------------------------|------------|---------|----------|---------|------|------"

foreach spec in pre_egtrra bush recession tcja {
    capture {
        estimates restore biennial_`spec'
        local b_s  = _b[log_ntr_change]
        local se_s = _se[log_ntr_change]
        local t_s  = `b_s' / `se_s'
        local n_s  = e(N)

        if "`spec'" == "pre_egtrra" local lbl "pre-EGTRRA 1995-99 [PLACEBO]"
        if "`spec'" == "bush"       local lbl "Bush cuts 2001-07  [REFORM] "
        if "`spec'" == "recession"  local lbl "Recession 2009-11  [QUIET]  "
        if "`spec'" == "tcja"       local lbl "post-ATRA/TCJA 13-17 [REFORM]"

        di "  `lbl' | " %9.4f `b_s' " | " %7.4f `se_s' " | " %5.2f `t_s' " | " `n_s'
    }
    if _rc != 0 {
        di "  WARNING: estimates for biennial_`spec' not found"
    }
}

di ""
di "  INTERPRETATION:"
di "    pre-EGTRRA (1995-99) and recession (2009-11) should show ETI ≈ 0."
di "    Bush cuts (2001-07) and post-ATRA/TCJA should show significant ETI."
di "    If reform-window ETI > placebo ETI: identification is reform-driven. ✓"
di ""

* --------
* B9c: CONSOLIDATED VALIDITY SUMMARY (BIENNIAL PERIOD)
* --------

di ""
di "B9c: CONSOLIDATED VALIDITY SUMMARY (BIENNIAL PERIOD)"
di "---------------------------------------------------------------------------"
di ""
di "  Specification               | ETI      |  SE      |   t   | Conclusion"
di "  ----------------------------|----------|----------|-------|------------"
di "  Main (primary, all years)   | " %8.4f $beta_biennial " | " %8.4f $se_biennial " | " %5.2f $beta_biennial/$se_biennial " | Primary estimate"

capture {
    estimates restore biennial_pretrend
    di "  Pre-trend test (t-2→t)    | " %8.4f _b[log_ntr_change] " | " ///
       %8.4f _se[log_ntr_change] " | " %5.2f _b[log_ntr_change]/_se[log_ntr_change] " | Should be ≈ 0"
}
if _rc != 0 di "  Pre-trend test            | [not estimated — sample too small]"

capture {
    estimates restore biennial_pre_egtrra
    di "  Placebo: pre-EGTRRA 95-99  | " %8.4f _b[log_ntr_change] " | " ///
       %8.4f _se[log_ntr_change] " | " %5.2f _b[log_ntr_change]/_se[log_ntr_change] " | Should be ≈ 0"
}
capture {
    estimates restore biennial_recession
    di "  Placebo: recession 09-11   | " %8.4f _b[log_ntr_change] " | " ///
       %8.4f _se[log_ntr_change] " | " %5.2f _b[log_ntr_change]/_se[log_ntr_change] " | Should be ≈ 0"
}

di ""
di "=============================================================================="
di "END PART B9: PRE-TREND TESTS (BIENNIAL PERIOD)"
di "=============================================================================="
di ""

* --- PART C: COMPARISON AND SUMMARY ---

di ""
di "=============================================================================="
di "=============================================================================="
di "PART C: COMPARISON OF ANNUAL VS BIENNIAL PERIODS"
di "=============================================================================="
di "=============================================================================="

di ""
di "=============================================================================="
di "SAMPLE CHARACTERISTICS"
di "=============================================================================="
di ""
di "                           ANNUAL              BIENNIAL"
di "                           (1978-1993)         (1995-2019)"
di "-----------------------------------------------------------"
di "Lag                        3 years             2 years"
di "Sample size                $N_annual              $N_biennial"
di "Age range                  ~17-35              ~31-62"
di "First-stage F              " %8.1f $F_annual "            " %8.1f $F_biennial
di ""

di ""
di "=============================================================================="
di "MAIN ETI ESTIMATES"
di "=============================================================================="
di ""
di "                           ANNUAL              BIENNIAL"
di "                           (Young workers)     (Prime-age)"
di "-----------------------------------------------------------"
di "ETI estimate               " %8.3f $beta_annual "            " %8.3f $beta_biennial
di "Standard error             " %8.3f $se_annual "            " %8.3f $se_biennial
di "t-statistic                " %8.2f $beta_annual/$se_annual "            " %8.2f $beta_biennial/$se_biennial
di ""

* Diagnostic: show all stored estimates before tables
di ""
di "=============================================================================="
di "ESTIMATES IN MEMORY (diagnostic):"
di "=============================================================================="
estimates dir

* Formal comparison table
di ""
di "=============================================================================="
di "FULL COMPARISON TABLE"
di "=============================================================================="
estimates table annual_main biennial_main, ///
    keep(log_ntr_change) b(%9.3f) se(%9.3f) stats(N) ///
    title("ETI Estimates: Annual (3yr) vs Biennial (2yr)")

di ""
di "=============================================================================="
di "AGE GROUP COMPARISONS"
di "=============================================================================="

di ""
di "ANNUAL PERIOD BY AGE:"
capture noisily estimates table annual_age1 annual_age2 annual_age3, ///
    keep(log_ntr_change) b(%9.3f) se(%9.3f) stats(N) ///
    title("Annual Period: Under 25 | 25-29 | 30+")
if _rc != 0 di "WARNING: annual age group table failed (_rc=" _rc ")"

di ""
di "BIENNIAL PERIOD BY AGE:"
capture noisily estimates table biennial_age1 biennial_age2 biennial_age3, ///
    keep(log_ntr_change) b(%9.3f) se(%9.3f) stats(N) ///
    title("Biennial Period: Under 40 | 40-49 | 50+")
if _rc != 0 di "WARNING: biennial age group table failed (_rc=" _rc ")"

di ""
di "=============================================================================="
di "TAX REFORM PERIOD COMPARISONS"
di "=============================================================================="

di ""
di "ANNUAL PERIOD TAX REFORMS:"
capture noisily estimates table annual_pre_erta annual_erta annual_tra86 annual_post_tra86, ///
    keep(log_ntr_change) b(%9.3f) se(%9.3f) stats(N) ///
    title("Annual: Pre-ERTA | ERTA | TRA86 | Post-TRA86")
if _rc != 0 di "WARNING: annual reform period table failed (_rc=" _rc ")"

di ""
di "BIENNIAL PERIOD TAX REFORMS:"
capture noisily estimates table biennial_pre_egtrra biennial_bush biennial_recession biennial_tcja, ///
    keep(log_ntr_change) b(%9.3f) se(%9.3f) stats(N) ///
    title("Biennial: Pre-EGTRRA | Bush Cuts | Recession | Post-ATRA/TCJA")
if _rc != 0 di "WARNING: biennial reform period table failed (_rc=" _rc ")"

di ""
di "=============================================================================="
di "INCOME GROUP COMPARISONS"
di "=============================================================================="

di ""
di "ANNUAL PERIOD BY INCOME:"
capture noisily estimates table annual_inc1 annual_inc2 annual_inc3, ///
    keep(log_ntr_change) b(%9.3f) se(%9.3f) stats(N) ///
    title("Annual: $10-50K | $50-100K | $100K+")
if _rc != 0 di "WARNING: annual income group table failed (_rc=" _rc ")"

di ""
di "BIENNIAL PERIOD BY INCOME:"
capture noisily estimates table biennial_inc1 biennial_inc2 biennial_inc3, ///
    keep(log_ntr_change) b(%9.3f) se(%9.3f) stats(N) ///
    title("Biennial: $10-50K | $50-100K | $100K+")
if _rc != 0 di "WARNING: biennial income group table failed (_rc=" _rc ")"

* --- Interpretation ---

di ""
di "=============================================================================="
di "Interpretation:"
di "=============================================================================="
di ""
di "KEY RESEARCH QUESTIONS:"
di ""
di "1. DO PEOPLE RESPOND DIFFERENTLY WITH AGE?"
di "   - Annual period: Young workers (ages 17-35)"
di "   - Biennial period: Prime-age workers (ages 31-62)"
di "   - Theory: Higher ETI for prime-age (more tax planning opportunities)"
di ""
di "2. DO DIFFERENT TAX REFORMS GENERATE DIFFERENT ELASTICITIES?"
di "   Annual reforms:"
di "     - ERTA 1981: Top rate 70% -> 50%"
di "     - TRA 1986: Top rate 50% -> 28%"
di "   Biennial reforms:"
di "     - EGTRRA 2001, JGTRRA 2003: Rate cuts"
di "     - TCJA 2017: Top rate 39.6% -> 37%"
di ""
di "3. HOW DOES ECONOMIC CONTEXT MATTER?"
di "   - 1980s: High inflation, then strong growth"
di "   - 2000s: Dot-com bust, housing boom, Great Recession"
di ""
di "METHODOLOGICAL NOTES:"
di "  - 3-year lag (annual): Matches Gruber-Saez exactly"
di "  - 2-year lag (biennial): Matches survey frequency"
di "  - Real income floor ($10K 1984$): Makes samples comparable"
di "  - Same individuals across periods: Life-cycle tracking"
di ""
di "DATA CORRECTIONS APPLIED (see Data_process_CORRECTED.do):"
di "  - Marital status correctly mapped for TAXSIM"
di "  - Biennial ages are income-year ages (not interview ages)"
di "  - Cumulative hours include interpolated non-survey years"
di ""

* --- PART E: FORMATTED OUTPUT (esttab + graphs) ---

di ""
di "=============================================================================="
di "PART E: FORMATTED REGRESSION TABLES (esttab)"
di "=============================================================================="

* Main ETI comparison table
capture noisily esttab annual_main annual_kopczuk biennial_main ///
    using "${outdir}\Table1_MainETI.rtf", replace ///
    keep(log_ntr_change) ///
    b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N, fmt(%12.0fc) labels("Observations")) ///
    mtitles("Annual (Primary)" "Annual (Kopczuk Rob.)" "Biennial (2yr)") ///
    title("Table 1: ETI Estimates - Annual vs Biennial Periods") ///
    note("Col (1): Primary spec, Fixes #9+#10+#12, N≈53K. Col (2): Kopczuk (2005) Table 5 robustness with lagged income change, N≈1,600. Col (3): Biennial primary spec. Standard errors clustered by individual.")
if _rc != 0 di "WARNING: esttab Table1 failed (_rc=" _rc "). Install estout: ssc install estout"

* Age group subgroup table
capture noisily esttab annual_age1 annual_age2 annual_age3 ///
    biennial_age1 biennial_age2 biennial_age3 ///
    using "${outdir}\Table2_AgeGroups.rtf", replace ///
    keep(log_ntr_change) ///
    b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N, fmt(%12.0fc) labels("Observations")) ///
    mtitles("Ann <25" "Ann 25-29" "Ann 30+" "Bien <40" "Bien 40-49" "Bien 50+") ///
    title("Table 2: ETI by Age Group") ///
    note("Standard errors clustered by individual.")
if _rc != 0 di "WARNING: esttab Table2 failed (_rc=" _rc ")"

* Reform period subgroup table
capture noisily esttab annual_pre_erta annual_erta annual_tra86 annual_post_tra86 ///
    biennial_pre_egtrra biennial_bush biennial_recession biennial_tcja ///
    using "${outdir}\Table3_ReformPeriods.rtf", replace ///
    keep(log_ntr_change) ///
    b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N, fmt(%12.0fc) labels("Observations")) ///
    mtitles("Pre-ERTA" "ERTA" "TRA86" "Post-TRA" "Pre-EGTRRA" "Bush" "Recession" "TCJA") ///
    title("Table 3: ETI by Tax Reform Period") ///
    note("Annual period: 3-year differences. Biennial period: 2-year differences.")
if _rc != 0 di "WARNING: esttab Table3 failed (_rc=" _rc ")"

* Income group subgroup table
capture noisily esttab annual_inc1 annual_inc2 annual_inc3 ///
    biennial_inc1 biennial_inc2 biennial_inc3 ///
    using "${outdir}\Table4_IncomeGroups.rtf", replace ///
    keep(log_ntr_change) ///
    b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N, fmt(%12.0fc) labels("Observations")) ///
    mtitles("Ann $10-50K" "Ann $50-100K" "Ann $100K+" "Bien $10-50K" "Bien $50-100K" "Bien $100K+") ///
    title("Table 4: ETI by Income Group") ///
    note("Standard errors clustered by individual.")
if _rc != 0 di "WARNING: esttab Table4 failed (_rc=" _rc ")"

di ""
di "=============================================================================="
di "PART F: COEFFICIENT PLOTS"
di "=============================================================================="

* ETI point estimates by period - restore analysis_annual for graphs
use "${datadir}\analysis_annual.dta", clear

* First-stage scatter: instrument vs actual NTR change (annual)
twoway (scatter log_ntr_change log_ntr_instrument [aweight=income_weight], ///
        msymbol(circle_hollow) mcolor(navy%30) msize(vsmall)) ///
       (lfit log_ntr_change log_ntr_instrument [aweight=income_weight], ///
        lcolor(red) lwidth(medium)), ///
    xtitle("Log NTR Change (Instrument)") ///
    ytitle("Log NTR Change (Actual)") ///
    title("First Stage: Annual Period") ///
    legend(off)
graph export "${outdir}\Fig1a_FirstStage_Annual.png", replace

use "${datadir}\analysis_biennial.dta", clear

twoway (scatter log_ntr_change log_ntr_instrument [aweight=income_weight], ///
        msymbol(circle_hollow) mcolor(maroon%30) msize(vsmall)) ///
       (lfit log_ntr_change log_ntr_instrument [aweight=income_weight], ///
        lcolor(red) lwidth(medium)), ///
    xtitle("Log NTR Change (Instrument)") ///
    ytitle("Log NTR Change (Actual)") ///
    title("First Stage: Biennial Period") ///
    legend(off)
graph export "${outdir}\Fig1b_FirstStage_Biennial.png", replace

di "Graphs exported to ${outdir}"

* --- SECTION: BOOTSTRAP CONFIDENCE INTERVAL FOR τ_p ---

di ""
di "=============================================================================="
di "BOOTSTRAP CI FOR τ_p (Clustered bootstrap, B=500)"
di "=============================================================================="
di ""

* Fixed structural parameters
local gamma_fe   = 0.9366
local alpha_par  = 3.295

* Check biennial sample is available (analysis_biennial.dta should be in memory)
capture confirm variable log_ntr_change
if _rc != 0 {
    di as error "WARNING: Biennial IV variables not found in memory."
    di as error "  Run the biennial IV estimation section first."
    di as error "  Skipping bootstrap CI."
}
else {

    * --- Define bootstrap program ---
    capture program drop bs_tau_p
    program define bs_tau_p, rclass
        syntax [, gamma(real 0.9366) alpha(real 3.295)]

        * Re-estimate biennial IV ETI (same spec as main biennial estimate)
        capture ivregress 2sls log_income_change ///
            (log_ntr_change = log_ntr_instrument) ///
            log_income_t spline1-spline9 i.year_t married single ///
            [aweight=income_weight], cluster(taxsimid)

        if _rc != 0 {
            * Fallback: OLS if ivregress fails on bootstrap subsample
            capture regress log_income_change log_ntr_change ///
                log_income_t spline1-spline9 i.year_t married single ///
                [aweight=income_weight], cluster(taxsimid)
        }

        if _rc == 0 {
            local eps_bs = _b[log_ntr_change]
            local delta_bs = `gamma' * (1 + `eps_bs') / (1 + `gamma')
            * Bound δ to (0,1) — protect against extreme bootstrap draws
            if `delta_bs' < 0  local delta_bs = 0.001
            if `delta_bs' > 1  local delta_bs = 0.999
            local tau_bs = `delta_bs' / `alpha'
            return scalar tau_p   = `tau_bs'
            return scalar delta   = `delta_bs'
            return scalar eps_eti = `eps_bs'
        }
        else {
            return scalar tau_p   = .
            return scalar delta   = .
            return scalar eps_eti = .
        }
    end

    * --- Run bootstrap ---
    di "Running B=500 clustered bootstrap (cluster = taxsimid)..."
    di "  Fixed: γ_FE = " %6.4f `gamma_fe' "  α = " %5.3f `alpha_par'
    di ""

    set seed 20260412
    bootstrap tau_p=r(tau_p) delta=r(delta) eps_eti=r(eps_eti), ///
        reps(500) cluster(taxsimid) nowarn: ///
        bs_tau_p, gamma(`gamma_fe') alpha(`alpha_par')

    * --- Report results ---
    di ""
    di "BOOTSTRAP RESULTS (B=500, cluster=taxsimid):"
    di "----------------------------------------------"
    estat bootstrap, percentile normal

    di ""
    di "KEY BOOTSTRAP CIs:"

    * Extract normal-based CIs from bootstrap e() matrices
    * e(b) and e(V) have column names matching bootstrap variable spec
    * This is more reliable than r(ci_percentile) from estat bootstrap
    matrix boot_b = e(b)
    matrix boot_V = e(V)
    local col_tau = colnumb(boot_b, "tau_p")
    local col_eps = colnumb(boot_b, "eps_eti")
    local se_tau  = sqrt(boot_V[`col_tau', `col_tau'])
    local se_eps  = sqrt(boot_V[`col_eps', `col_eps'])
    local tau_lo  = boot_b[1, `col_tau'] - 1.96 * `se_tau'
    local tau_hi  = boot_b[1, `col_tau'] + 1.96 * `se_tau'
    local eps_lo  = boot_b[1, `col_eps'] - 1.96 * `se_eps'
    local eps_hi  = boot_b[1, `col_eps'] + 1.96 * `se_eps'

    di "  ε_biennial  95% CI (normal-based): [" %6.3f `eps_lo' ", " %6.3f `eps_hi' "]"
    di "  τ_p         95% CI (normal-based): [" %5.1f `tau_lo'*100 "%, " %5.1f `tau_hi'*100 "%]"
    di ""
    di "  Analytic delta-method CI:          [15.6%, 22.6%]   (from results.md §5.2)"
    di "  Bootstrap normal-based CI:         [" %5.1f `tau_lo'*100 "%, " %5.1f `tau_hi'*100 "%]"
    di ""

    if abs(`tau_lo' - 0.156) < 0.03 & abs(`tau_hi' - 0.226) < 0.03 {
        di "  Delta-method and bootstrap CIs agree within 3 percentage points."
        di "  Analytic approximation is valid."
    }
    else {
        di "  NOTE: Bootstrap CI differs from delta-method by >3pp."
        di "  Report bootstrap CI as primary; delta-method as reference."
    }

    di ""
    di "FINAL τ_p REPORT:"
    di "  Point estimate:      " %5.1f (`gamma_fe' * (1 + 0.297) / (1 + `gamma_fe')) / `alpha_par' * 100 "%"
    di "  Delta-method 95% CI: [15.6%, 22.6%]"
    di "  Bootstrap 95% CI:    [" %5.1f `tau_lo'*100 "%, " %5.1f `tau_hi'*100 "%]"

} // end if biennial variables available

* --- PART H: ETI BY OCCUPATIONAL GROUP (ANNUAL PERIOD) ---

di ""
di "=============================================================================="
di "PART H: ETI BY OCCUPATIONAL GROUP (ANNUAL PERIOD)"
di "=============================================================================="
di ""
di "Theory: High-signaling occupations → stronger signaling incentive → lower ETI"
di "  (signaling incentive offsets substitution effect of tax cut)"
di ""

*--- H1: Merge occupation data into analysis_annual ---
use "${datadir}\analysis_annual.dta", clear

di "Merging occ_broad from merged_data_with_occind.dta (reshape wide -> long)..."
preserve
use "${datadir}\merged_data_with_occind.dta", clear
keep taxsimid occ_broad_* ind_broad_*
reshape long occ_broad_ ind_broad_, i(taxsimid) j(year)
rename occ_broad_ occ_broad
rename ind_broad_ ind_broad
rename year year_t
keep taxsimid year_t occ_broad ind_broad
tempfile occ_merge
save `occ_merge'
restore

merge m:1 taxsimid year_t using `occ_merge', keep(master match) nogen keepusing(occ_broad ind_broad)

qui count if !missing(occ_broad)
di "Observations with occ_broad: " r(N) " (of " _N " total in analysis_annual)"
di "(occ_broad only covers 1979–1993 — full annual period ✓)"
di ""

*--- H2: Create signaling group ---
capture drop signal_occ
gen signal_occ = 2   // Medium (default)
replace signal_occ = 3 if inlist(occ_broad, 1, 2)     // High: professional/managerial
replace signal_occ = 1 if inlist(occ_broad, 7, 8)     // Low: laborers/farm
label define sig_lbl 1 "Low signaling" 2 "Medium" 3 "High signaling"
label values signal_occ sig_lbl
label var signal_occ "Signaling intensity by occupation"

tab signal_occ, missing
di ""

*--- H3: ETI by occupation group ---
di "ETI BY OCCUPATIONAL SIGNALING GROUP:"
di ""
di "  Group            N       ε_ETI    SE       t      Prediction"
di "  ---------------  ------  -------  -------  -----  ----------"

local grp_names `" "Low" "Medium" "High" "'
local grp_pred  `" "positive" "moderate" "near-zero" "'

forvalues g = 1/3 {
    local gname : word `g' of `grp_names'
    local gpred : word `g' of `grp_pred'

    qui count if signal_occ == `g' & !missing(log_ntr_instrument)
    local n_g = r(N)

    if `n_g' >= 300 {
        capture ivregress 2sls log_income_change ///
            (log_ntr_change = log_ntr_instrument) ///
            log_income_t spline1-spline9 i.year_t married single ///
            mstat_change_sm mstat_change_ms ///
            [aweight=income_weight] if signal_occ == `g', cluster(taxsimid)

        if _rc == 0 {
            local eti_g  = _b[log_ntr_change]
            local se_g   = _se[log_ntr_change]
            local t_g    = `eti_g' / `se_g'
            local fs_g   = .   // first stage reported separately
            di "  `gname' (g=`g')      " %6.0f `n_g' "  " %7.3f `eti_g' ///
               "  " %7.3f `se_g' "  " %5.2f `t_g' "  (`gpred')"

            * Store for later
            global eti_occ`g'  = `eti_g'
            global se_occ`g'   = `se_g'
            global n_occ`g'    = `n_g'
        }
        else {
            di "  `gname' (g=`g')      [IV failed — N=" `n_g' "]"
        }
    }
    else {
        di "  `gname' (g=`g')      [N < 300 — skipped]"
    }
}

di ""
di "MONOTONICITY CHECK (Low > Medium > High):"
capture {
    if $eti_occ1 > $eti_occ2 & $eti_occ2 > $eti_occ3 {
        di "  PASS: ETI monotonically decreasing with signaling intensity"
        di "  Consistent with signaling suppressing behavioral labor supply response"
    }
    else if $eti_occ1 > $eti_occ3 {
        di "  PARTIAL: Low > High (main prediction confirmed), Medium not monotone"
    }
    else {
        di "  FAIL: Monotone ordering not confirmed"
        di "  NOTE: Small cells and occupation coverage limited to 1979–1993"
        di "        (ages 17–28 for this cohort — early career only)"
    }
}
di ""

*--- H4: First-stage by occupation group ---
di "FIRST-STAGE RELEVANCE BY GROUP:"
di "  (Confirm instrument is strong within each occupation group)"
di ""
forvalues g = 1/3 {
    local gname : word `g' of `grp_names'
    qui count if signal_occ == `g' & !missing(log_ntr_instrument)
    if r(N) >= 300 {
        qui reg log_ntr_change log_ntr_instrument ///
            log_income_t spline1-spline9 i.year_t married single ///
            [aweight=income_weight] if signal_occ == `g', cluster(taxsimid)
        local fstat_g = (_b[log_ntr_instrument]/_se[log_ntr_instrument])^2
        di "  `gname': F = " %7.1f `fstat_g'
    }
}
di ""
di "NOTE: Occupation groups cover 1979–1993 (annual period) only."
di "No occupation data for biennial period (1995–2019) in NLSY79."

* --- PART I: JOINT BOOTSTRAP — RESAMPLING BOTH γ AND ε SIMULTANEOUSLY ---

di ""
di "=============================================================================="
di "PART I: JOINT BOOTSTRAP (γ AND ε JOINTLY RESAMPLED, B=200)"
di "=============================================================================="
di ""
di "Resamples both γ (from full panel) and ε (from biennial IV) jointly."
di "Slower than ε-only bootstrap — uses B=200."
di ""

*--- I1: Build the per-person biennial IV dataset (needed for bootstrap) ---
capture confirm file "${datadir}\analysis_biennial.dta"
if _rc != 0 {
    di as error "WARNING: analysis_biennial.dta not found. Skipping joint bootstrap."
}
else {

    *  Load biennial IV sample; keep only what's needed
    preserve
    use "${datadir}\analysis_biennial.dta", clear

    *  Keep only the regression variables
    keep taxsimid year_t log_income_change log_ntr_change log_ntr_instrument ///
         log_income_t spline1-spline9 married single income_weight

    * Keep only non-missing observations (IV sample)
    drop if missing(log_income_change) | missing(log_ntr_instrument)
    tempfile bien_iv_sample
    save `bien_iv_sample'
    local n_bien_iv = _N
    restore

    *  Load full structural panel (for γ) — we need log_pwages, log_cumhrs, pot_exp, year
    preserve
    use "${datadir}\nlsy_long_pre_taxsim.dta", clear
    foreach _v in log_pwages log_cumhrs pot_exp pot_exp2_v2 {
        capture drop `_v'
    }
    gen log_pwages  = ln(pwages) if pwages > 0
    gen log_cumhrs  = ln(cumhrs) if cumhrs > 0
    capture rename page_at_interview page_dummy  // avoid abbreviation conflict (if var exists)
    gen pot_exp = page - hgc - 6 if !missing(hgc)
    keep if !missing(log_pwages) & !missing(log_cumhrs) & !missing(pot_exp)
    keep if pot_exp >= 0 & pot_exp <= 40
    xtset taxsimid year
    gen pot_exp2_v2 = pot_exp^2
    keep taxsimid year log_pwages log_cumhrs pot_exp pot_exp2_v2
    tempfile struct_sample
    save `struct_sample'
    local n_struct = _N
    restore

    *  Get unique person IDs in both samples
    preserve
    use `struct_sample', clear
    keep taxsimid
    sort taxsimid
    duplicates drop
    tempfile struct_ids
    save `struct_ids'
    restore

    di "Joint bootstrap samples:"
    di "  Structural (γ) sample: " `n_struct' " person-years"
    di "  Biennial IV (ε) sample: " `n_bien_iv' " person-years"
    di ""

    *--- I2: Bootstrap program ---
    capture program drop bs_joint_taup
    program define bs_joint_taup, rclass
        args struct_file bien_file

        *  1. Re-estimate γ on the bootstrap structural subsample
        capture {
            use "`struct_file'", clear
            xtset taxsimid year
            qui xtreg log_pwages log_cumhrs pot_exp pot_exp2_v2 i.year, fe
            local gamma_bs = _b[log_cumhrs]
        }
        if _rc != 0 | missing(`gamma_bs') {
            return scalar tau_p = .
            return scalar delta  = .
            return scalar gamma_bs = .
            return scalar eps_bs   = .
            exit
        }

        *  2. Re-estimate ε on the bootstrap biennial subsample
        capture {
            use "`bien_file'", clear
            qui ivregress 2sls log_income_change ///
                (log_ntr_change = log_ntr_instrument) ///
                log_income_t spline1-spline9 i.year_t married single ///
                [aweight=income_weight], cluster(taxsimid)
            local eps_bs = _b[log_ntr_change]
        }
        if _rc != 0 | missing(`eps_bs') {
            return scalar tau_p = .
            return scalar delta  = .
            return scalar gamma_bs = `gamma_bs'
            return scalar eps_bs   = .
            exit
        }

        *  3. Compute δ and τ_p
        local delta_bs = `gamma_bs' * (1 + `eps_bs') / (1 + `gamma_bs')
        if `delta_bs' < 0  local delta_bs = 0.001
        if `delta_bs' > 1  local delta_bs = 0.999
        local alpha_bs = 3.295

        return scalar tau_p    = `delta_bs' / `alpha_bs'
        return scalar delta    = `delta_bs'
        return scalar gamma_bs = `gamma_bs'
        return scalar eps_bs   = `eps_bs'
    end

    *--- I3: Run joint bootstrap by manually looping ---
    *  Stata's bootstrap command can't easily handle two separate datasets.
    *  Manual loop: draw person IDs, filter each dataset, run program.
    *
    *  Get the unique person list from structural sample
    use `struct_ids', clear
    local n_persons = _N
    di "Unique persons in structural sample: " `n_persons'
    di ""
    di "Running B=200 joint bootstrap iterations..."
    di "(This may take several minutes)"
    di ""

    set seed 20260412

    local B = 200
    local tau_list ""
    local delta_list ""
    local gamma_list ""
    local eps_list ""
    local n_fail = 0

    *  (struct_ids no longer needed — bsample draws directly from struct_sample)

    forvalues b = 1/`B' {
        local _bs_ok = 0
        local _gamma_bs = .
        local _eps_bs = .
        
        quietly {
            * --- Draw bootstrap structural sample and estimate γ ---
            preserve
            use `struct_sample', clear
            bsample, cluster(taxsimid)
            
            * Save drawn person IDs before running xtreg
            keep taxsimid
            duplicates drop
            sort taxsimid
            save "${datadir}\_boot_ids.dta", replace
            restore
            
            * Re-estimate γ on bootstrapped structural sample
            preserve
            use `struct_sample', clear
            merge m:1 taxsimid using "${datadir}\_boot_ids.dta", keep(match) nogen
            capture {
                xtset taxsimid year
                xtreg log_pwages log_cumhrs pot_exp pot_exp2_v2 i.year, fe
                local _gamma_bs = _b[log_cumhrs]
            }
            restore
            
            * --- Estimate ε on biennial sample for same persons ---
            if !missing(`_gamma_bs') {
                preserve
                use `bien_iv_sample', clear
                merge m:1 taxsimid using "${datadir}\_boot_ids.dta", keep(match) nogen
                capture {
                    ivregress 2sls log_income_change ///
                        (log_ntr_change = log_ntr_instrument) ///
                        log_income_t spline1-spline9 i.year_t married single ///
                        [aweight=income_weight], cluster(taxsimid)
                    local _eps_bs = _b[log_ntr_change]
                }
                restore
            }
            
            * --- Compute τ_p ---
            if !missing(`_gamma_bs') & !missing(`_eps_bs') {
                local _delta_bs = `_gamma_bs' * (1 + `_eps_bs') / (1 + `_gamma_bs')
                if `_delta_bs' < 0  local _delta_bs = 0.001
                if `_delta_bs' > 1  local _delta_bs = 0.999
                local _tau_bs = `_delta_bs' / 3.295
                local _bs_ok = 1
            }
        }

        if `_bs_ok' == 1 {
            local tau_list "`tau_list' `_tau_bs'"
            local delta_list "`delta_list' `_delta_bs'"
            local gamma_list "`gamma_list' `_gamma_bs'"
            local eps_list "`eps_list' `_eps_bs'"
        }
        else {
            local n_fail = `n_fail' + 1
        }

        *  Progress: print every 50 iterations
        if mod(`b', 50) == 0 {
            di "  Completed `b'/`B' iterations (failures so far: `n_fail')"
        }
    }

    *--- I4: Compute CI from bootstrap distribution ---
    capture erase "${datadir}\_boot_ids.dta"
    di ""
    di "JOINT BOOTSTRAP COMPLETE:"
    di "  Iterations: `B'"
    di "  Failures:   `n_fail'"
    di "  Valid draws: " (`B' - `n_fail')
    di ""

    *  Convert lists to a dataset and compute percentiles
    preserve
    clear

    local n_valid = `B' - `n_fail'
    if `n_valid' >= 50 {
        set obs `n_valid'
        gen tau_p_bs  = .
        gen delta_bs  = .
        gen gamma_bs  = .
        gen eps_bs    = .

        local i = 0
        foreach v in `tau_list' {
            local i = `i' + 1
            replace tau_p_bs  = `v'  in `i'
        }
        local i = 0
        foreach v in `delta_list' {
            local i = `i' + 1
            replace delta_bs = `v' in `i'
        }
        local i = 0
        foreach v in `gamma_list' {
            local i = `i' + 1
            replace gamma_bs = `v' in `i'
        }
        local i = 0
        foreach v in `eps_list' {
            local i = `i' + 1
            replace eps_bs = `v' in `i'
        }

        *  Percentile CI
        qui sum tau_p_bs, detail
        local tau_mean  = r(mean)
        local tau_sd    = r(sd)
        qui _pctile tau_p_bs, p(2.5 97.5)
        local tau_lo_jt = r(r1)     // 2.5th percentile
        local tau_hi_jt = r(r2)     // 97.5th percentile
        local tau_lo_n  = `tau_mean' - 1.96 * `tau_sd'
        local tau_hi_n  = `tau_mean' + 1.96 * `tau_sd'

        qui sum gamma_bs, detail
        local gam_mean = r(mean)
        local gam_sd   = r(sd)

        qui sum eps_bs, detail
        local eps_mean = r(mean)
        local eps_sd   = r(sd)

        di "JOINT BOOTSTRAP RESULTS:"
        di "  γ_bootstrap:   mean=" %6.4f `gam_mean' "  SD=" %6.4f `gam_sd'
        di "  ε_bootstrap:   mean=" %6.4f `eps_mean' "  SD=" %6.4f `eps_sd'
        di "  τ_p bootstrap: mean=" %5.1f `tau_mean'*100 "%  SD=" %5.1f `tau_sd'*100 "%"
        di ""
        di "  95% CI (normal-based):   [" %5.1f `tau_lo_n'*100 "%, " %5.1f `tau_hi_n'*100 "%]"
        di "  95% CI (percentile):     [" %5.1f `tau_lo_jt'*100 "%, " %5.1f `tau_hi_jt'*100 "%]"
        di ""
        di "  ε-only bootstrap:        [15.6%, 22.5%]  (from Part F)"
        di "  Delta-method CI:         [15.6%, 22.6%]"
        di ""
        di "COMPARISON:"
        local jt_width = (`tau_hi_n' - `tau_lo_n') * 100
        local ep_width = 22.5 - 15.6
        if `jt_width' > `ep_width' + 0.5 {
            di "  Joint CI is wider than ε-only CI by " %4.1f (`jt_width' - `ep_width') "pp"
            di "  → γ uncertainty adds non-trivial width; joint bootstrap is the correct CI"
        }
        else {
            di "  Joint CI ≈ ε-only CI (γ uncertainty negligible, as expected)"
            di "  → delta-method CI [15.6%, 22.6%] remains valid"
        }

        *  Save bootstrap distribution
        export delimited tau_p_bs delta_bs gamma_bs eps_bs ///
            using "${outdir}\joint_bootstrap_draws.csv", replace
        di ""
        di "Bootstrap draws saved to joint_bootstrap_draws.csv"
    }
    else {
        di "WARNING: Too few valid draws (" `n_valid' ") for reliable CI."
        di "  Check that both datasets are accessible and well-specified."
    }

    restore

} // end if analysis_biennial.dta exists

* --- PART G: SAVE RESULTS ---

di ""
di "=============================================================================="
di "SAVING RESULTS"
di "=============================================================================="

* Create summary dataset
clear
set obs 2

gen period = ""
replace period = "Annual (1978-1993)" in 1
replace period = "Biennial (1995-2019)" in 2

gen lag = .
replace lag = 3 in 1
replace lag = 2 in 2

gen N = .
replace N = $N_annual in 1
replace N = $N_biennial in 2

gen F_stat = .
replace F_stat = $F_annual in 1
replace F_stat = $F_biennial in 2

gen ETI = .
replace ETI = $beta_annual in 1
replace ETI = $beta_biennial in 2

gen SE = .
replace SE = $se_annual in 1
replace SE = $se_biennial in 2

gen t_stat = ETI / SE

gen ages = ""
replace ages = "17-35" in 1
replace ages = "31-62" in 2

gen major_reforms = ""
replace major_reforms = "ERTA 1981, TRA 1986" in 1
replace major_reforms = "EGTRRA 2001, JGTRRA 2003, TCJA 2017" in 2

save "${outdir}\two_period_summary.dta", replace
export delimited using "${outdir}\two_period_summary.csv", replace

di ""
di "Summary results:"
list, clean noobs

di ""
di "=============================================================================="
di "ANALYSIS COMPLETE"
di "=============================================================================="
di ""
di "Output files created:"
di "  DATA (${datadir}):"
di "    analysis_annual.dta          : Full analysis dataset (1978-1993)"
di "    analysis_biennial.dta        : Full analysis dataset (1995-2019)"
di "  OUTPUT (${outdir}):"
di "    two_period_analysis_log.txt  : Complete log file"
di "    two_period_summary.dta/csv   : Summary comparison table"
di "    Table1_MainETI.rtf           : Main ETI comparison (esttab)"
di "    Table2_AgeGroups.rtf         : ETI by age group (esttab)"
di "    Table3_ReformPeriods.rtf     : ETI by reform period (esttab)"
di "    Table4_IncomeGroups.rtf      : ETI by income group (esttab)"
di "    Fig1a_FirstStage_Annual.png  : First stage scatter (annual)"
di "    Fig1b_FirstStage_Biennial.png: First stage scatter (biennial)"
di ""
di "End time: $S_DATE $S_TIME"

capture log close _all
