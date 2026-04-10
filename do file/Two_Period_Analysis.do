/*==============================================================================
TWO_PERIOD_ANALYSIS.DO
==============================================================================

This do file continues from Data_process_CORRECTED.do after:
    save "nlsy_long_pre_taxsim.dta", replace

CORRECTIONS APPLIED IN DATA_PROCESS.DO:
1. MARITAL STATUS: Correctly maps married (NLSY=1) to MFJ (TAXSIM=2)
2. CUMULATIVE HOURS: Includes interpolated estimates for non-survey years
3. HGC IN LONG FORMAT: Year-specific education available
4. AGE ALIGNMENT: Biennial ages are income-year ages (survey age - 1)
5. POTENTIAL EXPERIENCE: Uses current-year education, not lifetime max
6. SPOUSE AGE VALIDATION: Bounds checking (0-100) prevents TAXSIM crash
   - Added validation before ALL taxsimlocal35 calls
   - sage validated to 0-100 range
   - sage set to 0 for single filers
   - sage set to respondent age as proxy for married filers with missing spouse age

RESEARCH DESIGN:
================
PERIOD 1: ANNUAL SURVEYS (1978-1993)
  - 3-year differences (matches Gruber-Saez)
  - Ages ~17-35 (young workers)
  - Tax reforms: ERTA 1981, TRA 1986

PERIOD 2: BIENNIAL SURVEYS (1995-2019)
  - 2-year differences (matches survey frequency)
  - Ages ~31-62 (prime-age workers)
  - Tax reforms: EGTRRA 2001, JGTRRA 2003, TCJA 2017

SAMPLE RESTRICTIONS:
  - Real income floor: $10,000 in 1984 dollars
  - Marital status stability required
  - EITC exclusion: MTR < -10%

==============================================================================*/

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

/*==============================================================================
PART 0: SETUP AND CONSTANTS
==============================================================================*/

* Get 1984 CPI for real income calculations
use "BLS_CPI.dta", clear
sum CPI if year == 1984
global cpi_1984 = r(mean)
di "1984 CPI for real income calculations: $cpi_1984"

* Real income floor in 1984 dollars
global real_floor = 10000
di "Real income floor: $" $real_floor " (1984 dollars)"

/*==============================================================================
PART 0b: DATA QUALITY VERIFICATION
==============================================================================*/

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

/*==============================================================================
                    PART A: ANNUAL PERIOD ANALYSIS (1978-1993)
                           3-YEAR DIFFERENCES
==============================================================================*/

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

*------------------------------------------------------------------------------
* A1: RUN TAXSIM ON ANNUAL DATA
*------------------------------------------------------------------------------

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

/*------------------------------------------------------------------------------
TAXSIM VARIABLE VALIDATION
------------------------------------------------------------------------------*/
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

*------------------------------------------------------------------------------
* A2: CREATE CPI DATA
*------------------------------------------------------------------------------

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

*------------------------------------------------------------------------------
* A3: CREATE 3-YEAR PAIRED OBSERVATIONS
*------------------------------------------------------------------------------

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

*------------------------------------------------------------------------------
* A4: CONSTRUCT INSTRUMENT
*------------------------------------------------------------------------------

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

*------------------------------------------------------------------------------
* A5: RUN TAXSIM ON COUNTERFACTUAL
*------------------------------------------------------------------------------

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

/*------------------------------------------------------------------------------
TAXSIM VARIABLE VALIDATION - Counterfactual
------------------------------------------------------------------------------*/
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

*------------------------------------------------------------------------------
* A6: MERGE AND APPLY SAMPLE RESTRICTIONS
*------------------------------------------------------------------------------

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

* Marital stability
drop if mstat_t != mstat_t3
count
local n1 = r(N)
di "After marital stability: `n1' (" %4.1f 100*`n1'/`n0' "% retained)"

* Real income floor
drop if real_income_t < $real_floor
count
local n2 = r(N)
di "After real income floor ($10K 1984$): `n2' (" %4.1f 100*`n2'/`n0' "% of initial)"

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

*------------------------------------------------------------------------------
* A7: CREATE REGRESSION VARIABLES
*------------------------------------------------------------------------------

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

*------------------------------------------------------------------------------
* A8: RUN REGRESSIONS (ANNUAL PERIOD)
*------------------------------------------------------------------------------

di ""
di "=============================================================================="
di "A8: REGRESSIONS (ANNUAL PERIOD)"
di "=============================================================================="

*--- First Stage ---
di ""
di "FIRST STAGE (Annual Period):"
di "----------------------------"
regress log_ntr_change log_ntr_instrument ///
    log_income_t spline1-spline9 i.year_t married single ///
    [aweight=income_weight], cluster(taxsimid)
test log_ntr_instrument
global F_annual = r(F)
di ""
di "First-stage F-statistic: " %8.2f $F_annual

*--- Main 2SLS ---
di ""
di "2SLS - MAIN SPECIFICATION (Annual Period):"
di "-------------------------------------------"
ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    [aweight=income_weight], cluster(taxsimid)

global beta_annual = _b[log_ntr_change]
global se_annual = _se[log_ntr_change]

estimates store annual_main

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
    [aweight=income_weight] if year_t <= 1980, cluster(taxsimid)
if _rc == 0 {
    estimates store annual_pre_erta
}

di ""
di "ERTA Period (1981-1983 base years):"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t i.year_t married single ///
    [aweight=income_weight] if year_t >= 1981 & year_t <= 1983, cluster(taxsimid)
if _rc == 0 {
    estimates store annual_erta
}

di ""
di "TRA86 Period (1984-1986 base years):"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t i.year_t married single ///
    [aweight=income_weight] if year_t >= 1984 & year_t <= 1986, cluster(taxsimid)
if _rc == 0 {
    estimates store annual_tra86
}

di ""
di "Post-TRA86 (1987-1990 base years):"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t i.year_t married single ///
    [aweight=income_weight] if year_t >= 1987, cluster(taxsimid)
if _rc == 0 {
    estimates store annual_post_tra86
}

*--- Income Heterogeneity ---
di ""
di "2SLS BY INCOME GROUP (Annual Period):"
di "--------------------------------------"

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
    estimates store annual_inc1
}

di ""
di "Income Group: $50K-$100K"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    [aweight=income_weight] if income_group == 2, cluster(taxsimid)
if _rc == 0 {
    estimates store annual_inc2
}

di ""
di "Income Group: $100K+"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    [aweight=income_weight] if income_group == 3, cluster(taxsimid)
if _rc == 0 {
    estimates store annual_inc3
}

/*==============================================================================
                    PART B: BIENNIAL PERIOD ANALYSIS (1995-2019)
                           2-YEAR DIFFERENCES
==============================================================================*/

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

*------------------------------------------------------------------------------
* B1: RUN TAXSIM ON BIENNIAL DATA
*------------------------------------------------------------------------------

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

/*------------------------------------------------------------------------------
TAXSIM VARIABLE VALIDATION (FIX #6)
------------------------------------------------------------------------------
Ensure all variables are within valid ranges before calling TAXSIM.
This prevents crashes like "Unbelievable spouse age: 118"
------------------------------------------------------------------------------*/

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

*------------------------------------------------------------------------------
* B2: CREATE CPI DATA FOR BIENNIAL PERIOD
*------------------------------------------------------------------------------

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

*------------------------------------------------------------------------------
* B3: CREATE 2-YEAR PAIRED OBSERVATIONS
*------------------------------------------------------------------------------

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

*------------------------------------------------------------------------------
* B4: CONSTRUCT INSTRUMENT
*------------------------------------------------------------------------------

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

*------------------------------------------------------------------------------
* B5: RUN TAXSIM ON COUNTERFACTUAL
*------------------------------------------------------------------------------

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

/*------------------------------------------------------------------------------
TAXSIM VARIABLE VALIDATION - Biennial Counterfactual
------------------------------------------------------------------------------
This is critical: the original crash "Unbelievable spouse age: 118" occurred
in the biennial period. Ensure sage is valid before calling TAXSIM.
------------------------------------------------------------------------------*/
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

*------------------------------------------------------------------------------
* B6: MERGE AND APPLY SAMPLE RESTRICTIONS
*------------------------------------------------------------------------------

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

*------------------------------------------------------------------------------
* B7: CREATE REGRESSION VARIABLES
*------------------------------------------------------------------------------

di ""
di "=============================================================================="
di "B7: CREATING REGRESSION VARIABLES (BIENNIAL PERIOD)"
di "=============================================================================="

* Log income
gen log_income_t = ln(broad_income_t)
gen log_income_t2 = ln(broad_income_t2)
gen log_income_change = log_income_t2 - log_income_t

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

*------------------------------------------------------------------------------
* B8: RUN REGRESSIONS (BIENNIAL PERIOD)
*------------------------------------------------------------------------------

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

/*==============================================================================
                    PART C: COMPARISON AND SUMMARY
==============================================================================*/

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

/*==============================================================================
                    PART D: INTERPRETATION GUIDE
==============================================================================*/

di ""
di "=============================================================================="
di "INTERPRETATION GUIDE"
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

/*==============================================================================
                    PART E: FORMATTED OUTPUT (esttab + graphs)
==============================================================================*/

di ""
di "=============================================================================="
di "PART E: FORMATTED REGRESSION TABLES (esttab)"
di "=============================================================================="

* Main ETI comparison table
capture noisily esttab annual_main biennial_main ///
    using "${outdir}\Table1_MainETI.rtf", replace ///
    keep(log_ntr_change) ///
    b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N, fmt(%12.0fc) labels("Observations")) ///
    mtitles("Annual (3yr)" "Biennial (2yr)") ///
    title("Table 1: ETI Estimates - Annual vs Biennial Periods") ///
    note("Standard errors clustered by individual. Instrument: predicted log NTR change.")
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

/*==============================================================================
                    PART G: SAVE RESULTS
==============================================================================*/

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
