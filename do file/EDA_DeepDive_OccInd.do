/*==============================================================================
EDA_DEEPDIVE_OCCIND.DO - COMPREHENSIVE OCCUPATION × INDUSTRY ANALYSIS
================================================================================
Purpose: Deep exploratory analysis for wage dynamics by occupation × industry

ANALYSES INCLUDED:
1. Occupation × Industry cell size analysis (histograms, heatmaps)
2. Distributional wage moments by cell (mean, median, SD, percentiles)
3. Nonparametric wage profiles by experience, split by occupation×industry
4. Wage vs cumulative hours heterogeneity by occupation×industry
5. Collinearity analysis (age, experience, cumulative hours)
6. Within-person vs between-person variation decomposition
7. Occupation/industry switching and wage changes
==============================================================================*/

clear all
set more off
capture log close _all

global projdir "D:\Stata Data\labor_signaling_project"
global datadir "${projdir}\data"
global outdir  "${projdir}\output"

* Set working directory to data folder so all relative paths work
cd "${datadir}"

* Start log
log using "${outdir}\EDA_DeepDive_log.txt", replace text

di ""
di "=============================================================================="
di "COMPREHENSIVE EDA: OCCUPATION × INDUSTRY DEEP DIVE"
di "=============================================================================="
di "Start time: $S_DATE $S_TIME"
di ""

/*==============================================================================
PART 0: LOAD DATA AND CREATE OCCUPATION/INDUSTRY IN LONG FORMAT
==============================================================================*/

di ""
di "=============================================================================="
di "PART 0: DATA PREPARATION - CREATING OCC/IND IN LONG FORMAT"
di "=============================================================================="

* Check if the wide data with occ/ind exists
capture confirm file "${datadir}\merged_data_with_occind.dta"
if _rc != 0 {
    di as error "ERROR: ${datadir}\merged_data_with_occind.dta not found!"
    di as error ""
    di as error "Re-run Data_process.do to generate this file."
    di as error ""
    exit 601
}

* Step 1: Load wide-format data with occ/ind variables
use "${datadir}\merged_data_with_occind.dta", clear

di "Loaded merged_data_with_occind.dta: " _N " observations"

* Verify occ_broad variables exist
capture confirm variable occ_broad_1990
if _rc != 0 {
    di as error "ERROR: occ_broad_1990 not found in the data!"
    di as error "Make sure you added the save command AFTER the occ_broad variables are created."
    exit 111
}

di "Verified: occ_broad and ind_broad variables exist"

* Keep only ID and occupation/industry broad variables
keep taxsimid occ_broad_* ind_broad_*

* Reshape to long format
reshape long occ_broad_ ind_broad_, i(taxsimid) j(year)

* Rename variables
rename occ_broad_ occ_broad
rename ind_broad_ ind_broad

* Label variables
label var occ_broad "Broad occupation (1-digit, 1970 Census)"
label var ind_broad "Broad industry (1-digit, 1970 Census)"

* Label values
label define occ_broad_lbl 1 "Professional/Technical" 2 "Managers/Admin" ///
    3 "Sales" 4 "Clerical" 5 "Craftsmen" 6 "Operatives" ///
    7 "Laborers" 8 "Farm Workers" 9 "Service Workers", replace
label values occ_broad occ_broad_lbl

label define ind_broad_lbl 1 "Agriculture" 2 "Mining" 3 "Construction" ///
    4 "Manufacturing" 5 "Transport/Utilities" 6 "Trade" ///
    7 "Finance/Insurance" 8 "Business Services" 9 "Personal Services" ///
    10 "Entertainment" 11 "Professional Services" 12 "Public Admin", replace
label values ind_broad ind_broad_lbl

* Save occupation/industry long data
tempfile occ_ind_long
save `occ_ind_long', replace

di "Reshaped occ/ind data: " _N " observations"

* Step 2: Load the long-format wage data and merge
use "nlsy_long_pre_taxsim.dta", clear
di "Loaded nlsy_long_pre_taxsim.dta: " _N " observations"

* Merge with occupation/industry data
merge 1:1 taxsimid year using `occ_ind_long', keep(master match) nogen

di ""
di "After merging occupation/industry:"
di "  Total observations: " _N
count if !missing(occ_broad)
di "  Observations with occupation data: " r(N)
count if !missing(ind_broad)
di "  Observations with industry data: " r(N)

di ""
di "NOTE: Occupation/industry data available for 1979-1993 (1970 Census codes)"

* Create occupation × industry cell identifier
gen occ_ind_cell = occ_broad * 100 + ind_broad if !missing(occ_broad) & !missing(ind_broad)
label var occ_ind_cell "Occupation × Industry cell (occ_broad*100 + ind_broad)"

* Create log wages
capture drop log_pwages
gen log_pwages = ln(pwages) if pwages > 0
label var log_pwages "Log primary wages"

* Create log cumulative hours
capture drop log_cumhrs
gen log_cumhrs = ln(cumhrs) if cumhrs > 0
label var log_cumhrs "Log cumulative hours"

* Create hours per age
capture drop hrs_per_age
gen hrs_per_age = cumhrs / page if page > 0 & cumhrs >= 0
label var hrs_per_age "Cumulative hours / Age"

capture drop log_hrs_per_age
gen log_hrs_per_age = ln(hrs_per_age) if hrs_per_age > 0
label var log_hrs_per_age "Log(cumulative hours / age)"

* Check if pot_exp exists, if not create it
capture confirm variable pot_exp
if _rc != 0 {
    * Create potential experience = age - education - 6
    gen pot_exp = page - hgc - 6 if !missing(page) & !missing(hgc)
    replace pot_exp = 0 if pot_exp < 0
    replace pot_exp = page - 18 if missing(pot_exp) & !missing(page)
    replace pot_exp = 0 if pot_exp < 0
    label var pot_exp "Potential experience (age - education - 6)"
}

* Create education years variable if needed
capture confirm variable educ_years
if _rc != 0 {
    gen educ_years = hgc
    label var educ_years "Years of education"
}

* Create wage sample indicator
gen wage_sample = (pwages > 0 & !missing(page) & page >= 16 & page <= 65)

di ""
di "Wage sample observations: "
count if wage_sample == 1
di "  Total: " r(N)
count if wage_sample == 1 & !missing(occ_ind_cell)
di "  With occupation × industry data: " r(N)

* Save prepared data
save "eda_deepdive_data.dta", replace

/*==============================================================================
PART 1: OCCUPATION × INDUSTRY CELL SIZE ANALYSIS
==============================================================================*/

di ""
di "=============================================================================="
di "PART 1: OCCUPATION × INDUSTRY CELL SIZE ANALYSIS"
di "=============================================================================="

*------------------------------------------------------------------------------
* 1.1: Basic cell counts
*------------------------------------------------------------------------------

di ""
di "1.1 BASIC CELL COUNTS"
di "---------------------"

preserve
keep if wage_sample == 1 & !missing(occ_ind_cell)

* Count observations per cell
bysort occ_ind_cell: gen n_obs = _N

* Get unique individuals per cell
bysort occ_ind_cell taxsimid: gen first_in_cell = (_n == 1)
bysort occ_ind_cell: egen n_individuals = total(first_in_cell)

* Get mean wage per cell
bysort occ_ind_cell: egen mean_wage = mean(pwages)

* Keep one row per cell
egen cell_tag = tag(occ_ind_cell)
keep if cell_tag == 1
keep occ_ind_cell occ_broad ind_broad n_obs n_individuals mean_wage

di ""
di "TOTAL UNIQUE OCCUPATION × INDUSTRY CELLS: " _N

* Summary of cell sizes
di ""
di "CELL SIZE DISTRIBUTION (Observations):"
summarize n_obs, detail

di ""
di "CELL SIZE DISTRIBUTION (Unique Individuals):"
summarize n_individuals, detail

* Count cells meeting thresholds
di ""
di "CELLS MEETING THRESHOLDS:"
count if n_obs >= 30
di "  Cells with >= 30 observations: " r(N)
count if n_obs >= 100
di "  Cells with >= 100 observations: " r(N)
count if n_obs >= 500
di "  Cells with >= 500 observations: " r(N)
count if n_individuals >= 30
di "  Cells with >= 30 individuals: " r(N)
count if n_individuals >= 100
di "  Cells with >= 100 individuals: " r(N)

* Top 20 cells by observation count
gsort -n_obs
di ""
di "TOP 20 OCCUPATION × INDUSTRY CELLS BY OBSERVATION COUNT:"
list occ_broad ind_broad n_obs n_individuals mean_wage in 1/20, clean noobs

restore

*------------------------------------------------------------------------------
* 1.2: Cross-tabulation (Heatmap data)
*------------------------------------------------------------------------------

di ""
di "1.2 OCCUPATION × INDUSTRY CROSS-TABULATION"
di "-------------------------------------------"

preserve
keep if wage_sample == 1 & !missing(occ_broad) & !missing(ind_broad)

di ""
di "OBSERVATION COUNTS BY OCCUPATION × INDUSTRY:"
tab occ_broad ind_broad

di ""
di "MEAN WAGES BY OCCUPATION × INDUSTRY:"
table occ_broad ind_broad, stat(mean pwages) nformat(%9.0fc)

restore

*------------------------------------------------------------------------------
* 1.3: Cell counts by year
*------------------------------------------------------------------------------

di ""
di "1.3 CELL REPRESENTATION OVER TIME"
di "----------------------------------"

preserve
keep if wage_sample == 1 & !missing(occ_ind_cell)

* Count years represented per cell
bysort occ_ind_cell year: gen year_tag = (_n == 1)
bysort occ_ind_cell: egen n_years = total(year_tag)
bysort occ_ind_cell: gen n_obs = _N

* Keep one row per cell
egen cell_tag = tag(occ_ind_cell)
keep if cell_tag == 1

di ""
di "YEARS REPRESENTED PER CELL:"
summarize n_years, detail

count if n_years >= 10
di "Cells with >= 10 years of data: " r(N)

restore

*------------------------------------------------------------------------------
* 1.4: Create histograms
*------------------------------------------------------------------------------

di ""
di "1.4 CREATING HISTOGRAMS"
di "-----------------------"

preserve
keep if wage_sample == 1 & !missing(occ_ind_cell)

bysort occ_ind_cell: gen n_obs = _N
bysort occ_ind_cell taxsimid: gen first_in_cell = (_n == 1)
bysort occ_ind_cell: egen n_individuals = total(first_in_cell)

egen cell_tag = tag(occ_ind_cell)
keep if cell_tag == 1

local ncells = _N

histogram n_obs, bin(30) ///
    title("Distribution of Observations per Occupation × Industry Cell") ///
    xtitle("Number of Observations") ytitle("Number of Cells") ///
    note("N = `ncells' cells")
graph export "${outdir}\hist_obs_per_cell.png", replace

histogram n_individuals, bin(30) ///
    title("Distribution of Unique Individuals per Occupation × Industry Cell") ///
    xtitle("Number of Unique Individuals") ytitle("Number of Cells") ///
    note("N = `ncells' cells")
graph export "${outdir}\hist_individuals_per_cell.png", replace

restore

/*==============================================================================
PART 2: DISTRIBUTIONAL WAGE MOMENTS BY OCCUPATION × INDUSTRY
==============================================================================*/

di ""
di "=============================================================================="
di "PART 2: DISTRIBUTIONAL WAGE MOMENTS BY OCCUPATION × INDUSTRY"
di "=============================================================================="

preserve
keep if wage_sample == 1 & !missing(occ_ind_cell) & !missing(log_pwages)

collapse (count) n_obs=pwages ///
         (mean) mean_wage=pwages mean_log_wage=log_pwages ///
         (median) median_wage=pwages median_log_wage=log_pwages ///
         (sd) sd_log_wage=log_pwages ///
         (p10) p10_log_wage=log_pwages ///
         (p25) p25_log_wage=log_pwages ///
         (p75) p75_log_wage=log_pwages ///
         (p90) p90_log_wage=log_pwages, ///
         by(occ_ind_cell occ_broad ind_broad)

* Calculate inequality measures
gen p90_p10 = p90_log_wage - p10_log_wage
gen p75_p25 = p75_log_wage - p25_log_wage
gen mean_median_gap = mean_log_wage - median_log_wage

label var p90_p10 "P90-P10 log wage gap"
label var p75_p25 "P75-P25 log wage gap"
label var mean_median_gap "Mean-Median log wage gap"

keep if n_obs >= 30

local ncells = _N
di ""
di "DISTRIBUTIONAL MOMENTS FOR CELLS WITH >= 30 OBS (N = `ncells' cells)"

di ""
di "SUMMARY OF WAGE INEQUALITY ACROSS CELLS:"
summarize mean_wage sd_log_wage p90_p10 p75_p25, detail

di ""
di "TOP 10 CELLS BY WAGE INEQUALITY (P90-P10):"
gsort -p90_p10
list occ_broad ind_broad n_obs mean_wage p90_p10 in 1/10, clean noobs

di ""
di "TOP 10 CELLS BY MEAN WAGE:"
gsort -mean_wage
list occ_broad ind_broad n_obs mean_wage p90_p10 in 1/10, clean noobs

save "occ_ind_wage_moments.dta", replace

restore

*------------------------------------------------------------------------------
* 2.2: Box plots of log wages for top cells
*------------------------------------------------------------------------------

di ""
di "2.2 CREATING BOX PLOTS"
di "----------------------"

preserve
keep if wage_sample == 1 & !missing(occ_ind_cell)

bysort occ_ind_cell: gen cell_obs = _N
egen cell_tag = tag(occ_ind_cell)
gsort -cell_obs occ_ind_cell
gen temp_rank = sum(cell_tag)
bysort occ_ind_cell: egen cell_rank = min(temp_rank)
keep if cell_rank <= 10

gen cell_str = "O" + string(occ_broad) + "×I" + string(ind_broad)

graph box log_pwages, over(cell_str, sort(1) descending label(angle(45) labsize(small))) ///
    title("Log Wage Distribution") ///
    subtitle("Top 10 Occupation × Industry Cells") ///
    ytitle("Log Wages")
graph export "${outdir}\boxplot_wages_top_cells.png", replace

restore

/*==============================================================================
PART 3: NONPARAMETRIC WAGE PROFILES BY EXPERIENCE
==============================================================================*/

di ""
di "=============================================================================="
di "PART 3: NONPARAMETRIC WAGE PROFILES BY EXPERIENCE"
di "=============================================================================="

*------------------------------------------------------------------------------
* 3.1: Overall wage-experience profile
*------------------------------------------------------------------------------

di ""
di "3.1 OVERALL WAGE-EXPERIENCE PROFILE"
di "------------------------------------"

preserve
keep if wage_sample == 1 & pot_exp >= 0 & pot_exp <= 40 & !missing(log_pwages)

gen exp_bin = floor(pot_exp / 2) * 2

collapse (count) n_obs=pwages ///
         (mean) mean_log_wage=log_pwages ///
         (median) median_log_wage=log_pwages ///
         (p10) p10_log_wage=log_pwages ///
         (p90) p90_log_wage=log_pwages, ///
         by(exp_bin)

di ""
di "WAGE-EXPERIENCE PROFILE (POOLED):"
list, clean noobs

twoway (line mean_log_wage exp_bin, lcolor(blue) lwidth(medthick)) ///
       (line median_log_wage exp_bin, lcolor(red) lpattern(dash)) ///
       (line p10_log_wage exp_bin, lcolor(gray) lpattern(dot)) ///
       (line p90_log_wage exp_bin, lcolor(gray) lpattern(dot)), ///
       title("Wage-Experience Profile (Pooled)") ///
       xtitle("Potential Experience (years)") ytitle("Log Wages") ///
       legend(order(1 "Mean" 2 "Median" 3 "P10" 4 "P90") rows(1))
graph export "${outdir}\wage_exp_profile_pooled.png", replace

restore

*------------------------------------------------------------------------------
* 3.2: Wage-experience profiles by broad occupation
*------------------------------------------------------------------------------

di ""
di "3.2 WAGE-EXPERIENCE PROFILES BY OCCUPATION"
di "-------------------------------------------"

preserve
keep if wage_sample == 1 & pot_exp >= 0 & pot_exp <= 40 & !missing(occ_broad) & !missing(log_pwages)

gen exp_bin = floor(pot_exp / 5) * 5

collapse (count) n_obs=pwages (mean) mean_log_wage=log_pwages, by(occ_broad exp_bin)

reshape wide mean_log_wage n_obs, i(exp_bin) j(occ_broad)

twoway (line mean_log_wage1 exp_bin, lcolor(blue)) ///
       (line mean_log_wage2 exp_bin, lcolor(red)) ///
       (line mean_log_wage4 exp_bin, lcolor(green)) ///
       (line mean_log_wage5 exp_bin, lcolor(orange)) ///
       (line mean_log_wage6 exp_bin, lcolor(purple)) ///
       (line mean_log_wage9 exp_bin, lcolor(gray)), ///
       title("Wage-Experience Profiles by Occupation") ///
       xtitle("Potential Experience (years)") ytitle("Mean Log Wages") ///
       legend(order(1 "Prof/Tech" 2 "Managers" 3 "Clerical" 4 "Craftsmen" 5 "Operatives" 6 "Service") rows(2))
graph export "${outdir}\wage_exp_by_occupation.png", replace

restore

*------------------------------------------------------------------------------
* 3.3: Wage-experience profiles by broad industry
*------------------------------------------------------------------------------

di ""
di "3.3 WAGE-EXPERIENCE PROFILES BY INDUSTRY"
di "-----------------------------------------"

preserve
keep if wage_sample == 1 & pot_exp >= 0 & pot_exp <= 40 & !missing(ind_broad) & !missing(log_pwages)

gen exp_bin = floor(pot_exp / 5) * 5

collapse (count) n_obs=pwages (mean) mean_log_wage=log_pwages, by(ind_broad exp_bin)

keep if inlist(ind_broad, 3, 4, 5, 6, 7, 11, 12)

reshape wide mean_log_wage n_obs, i(exp_bin) j(ind_broad)

twoway (line mean_log_wage4 exp_bin, lcolor(blue)) ///
       (line mean_log_wage6 exp_bin, lcolor(red)) ///
       (line mean_log_wage7 exp_bin, lcolor(green)) ///
       (line mean_log_wage11 exp_bin, lcolor(orange)) ///
       (line mean_log_wage12 exp_bin, lcolor(purple)), ///
       title("Wage-Experience Profiles by Industry") ///
       xtitle("Potential Experience (years)") ytitle("Mean Log Wages") ///
       legend(order(1 "Manufacturing" 2 "Trade" 3 "Finance" 4 "Prof Services" 5 "Public Admin") rows(2))
graph export "${outdir}\wage_exp_by_industry.png", replace

restore

/*==============================================================================
PART 4: CUMULATIVE HOURS RETURNS BY OCCUPATION × INDUSTRY
==============================================================================*/

di ""
di "=============================================================================="
di "PART 4: CUMULATIVE HOURS RETURNS BY OCCUPATION × INDUSTRY"
di "=============================================================================="

*------------------------------------------------------------------------------
* 4.1: Overall cumulative hours - wage relationship
*------------------------------------------------------------------------------

di ""
di "4.1 OVERALL CUMULATIVE HOURS - WAGE RELATIONSHIP"
di "-------------------------------------------------"

preserve
keep if wage_sample == 1 & cumhrs > 0 & !missing(log_pwages) & !missing(log_cumhrs)

di ""
di "POOLED REGRESSION: log(wage) on log(cumhrs)"
reg log_pwages log_cumhrs, robust

di ""
di "WITH CONTROLS (year FE, experience, education):"
reg log_pwages log_cumhrs pot_exp c.pot_exp#c.pot_exp educ_years i.year, robust

restore

*------------------------------------------------------------------------------
* 4.2: Cumulative hours returns by cell
*------------------------------------------------------------------------------

di ""
di "4.2 CUMULATIVE HOURS RETURNS BY CELL"
di "------------------------------------"

preserve
keep if wage_sample == 1 & cumhrs > 0 & !missing(occ_ind_cell) & !missing(log_pwages) & !missing(log_cumhrs)

bysort occ_ind_cell: gen cell_n = _N
keep if cell_n >= 50

di ""
di "Running cell-specific regressions..."

statsby _b[log_cumhrs] _se[log_cumhrs] e(r2) e(N), by(occ_ind_cell occ_broad ind_broad) clear: ///
    reg log_pwages log_cumhrs, robust

rename _stat_1 beta_cumhrs
rename _stat_2 se_cumhrs
rename _stat_3 r2
rename _stat_4 n_obs

gen ci_lo = beta_cumhrs - 1.96 * se_cumhrs
gen ci_hi = beta_cumhrs + 1.96 * se_cumhrs
gen significant = (ci_lo > 0 | ci_hi < 0)

di ""
di "NUMBER OF CELLS ANALYZED: " _N
di ""
di "DISTRIBUTION OF CUMULATIVE HOURS COEFFICIENTS:"
summarize beta_cumhrs, detail

di ""
di "CELLS WITH HIGHEST CUMULATIVE HOURS RETURNS:"
gsort -beta_cumhrs
list occ_broad ind_broad n_obs beta_cumhrs se_cumhrs r2 in 1/10, clean noobs

di ""
di "CELLS WITH LOWEST CUMULATIVE HOURS RETURNS:"
gsort beta_cumhrs
list occ_broad ind_broad n_obs beta_cumhrs se_cumhrs r2 in 1/10, clean noobs

count if significant == 1
di ""
di "Cells with significant coefficients: " r(N) " out of " _N

histogram beta_cumhrs, bin(20) ///
    title("Distribution of Cumulative Hours Returns") ///
    xtitle("Coefficient") ytitle("Number of Cells") ///
    xline(0, lcolor(red))
graph export "${outdir}\hist_cumhrs_coef.png", replace

gsort beta_cumhrs
gen rank = _n

twoway (rcap ci_lo ci_hi rank, horizontal lcolor(gray)) ///
       (scatter rank beta_cumhrs, mcolor(blue) msize(small)), ///
       title("Cumulative Hours Returns by Occupation × Industry") ///
       xtitle("Coefficient on log(cumhrs)") ytitle("Cell Rank") ///
       xline(0, lcolor(red) lpattern(dash)) ///
       legend(off)
graph export "${outdir}\forest_cumhrs_returns.png", replace

save "cumhrs_returns_by_cell.dta", replace

restore

/*==============================================================================
PART 5: COLLINEARITY ANALYSIS
==============================================================================*/

di ""
di "=============================================================================="
di "PART 5: COLLINEARITY ANALYSIS"
di "=============================================================================="

di ""
di "5.1 PAIRWISE CORRELATIONS"
di "-------------------------"

preserve
keep if wage_sample == 1 & !missing(log_pwages) & !missing(log_cumhrs) & !missing(pot_exp)

di ""
di "CORRELATION MATRIX:"
correlate page pot_exp cumhrs log_cumhrs

di ""
di "CORRELATION WITH WAGES:"
correlate log_pwages page pot_exp log_cumhrs educ_years

restore

di ""
di "5.2 BINNED SCATTER PLOTS"
di "------------------------"

preserve
keep if wage_sample == 1 & cumhrs > 0

gen page_bin = floor(page / 2) * 2
collapse (mean) mean_exp=pot_exp mean_cumhrs=cumhrs (count) n=page, by(page_bin)
keep if page_bin >= 18 & page_bin <= 60

twoway scatter mean_exp page_bin [w=n], ///
    title("Age vs Potential Experience") ///
    xtitle("Age") ytitle("Mean Experience")
graph export "${outdir}\scatter_age_exp.png", replace

twoway scatter mean_cumhrs page_bin [w=n], ///
    title("Age vs Cumulative Hours") ///
    xtitle("Age") ytitle("Mean Cumulative Hours")
graph export "${outdir}\scatter_age_cumhrs.png", replace

restore

di ""
di "5.3 VARIANCE INFLATION FACTORS"
di "------------------------------"

preserve
keep if wage_sample == 1 & cumhrs > 0 & !missing(educ_years) & !missing(log_pwages)

quietly reg log_pwages pot_exp c.pot_exp#c.pot_exp log_cumhrs educ_years page i.year
estat vif

restore

/*==============================================================================
PART 6: WITHIN-PERSON VS BETWEEN-PERSON VARIATION
==============================================================================*/

di ""
di "=============================================================================="
di "PART 6: WITHIN-PERSON VS BETWEEN-PERSON VARIATION"
di "=============================================================================="

di ""
di "6.1 VARIANCE DECOMPOSITION"
di "--------------------------"

preserve
keep if wage_sample == 1 & !missing(log_pwages) & !missing(log_cumhrs)

xtset taxsimid year

di ""
di "LOG WAGES - VARIANCE DECOMPOSITION:"
quietly xtreg log_pwages, mle
di "  Total variance: " %9.4f e(sigma_e)^2 + e(sigma_u)^2
di "  Between-person variance: " %9.4f e(sigma_u)^2
di "  Within-person variance: " %9.4f e(sigma_e)^2
di "  Intraclass correlation (rho): " %9.4f e(rho)
di "  " %4.1f e(rho)*100 "% of wage variance is between-person"

di ""
di "LOG CUMULATIVE HOURS - VARIANCE DECOMPOSITION:"
quietly xtreg log_cumhrs, mle
di "  Between-person variance: " %9.4f e(sigma_u)^2
di "  Within-person variance: " %9.4f e(sigma_e)^2
di "  Intraclass correlation (rho): " %9.4f e(rho)

restore

di ""
di "6.2 PERSON-LEVEL WAGE DISTRIBUTIONS"
di "------------------------------------"

preserve
keep if wage_sample == 1 & !missing(log_pwages)

bysort taxsimid (year): gen years_observed = _N
bysort taxsimid (year): gen first_year = year[1]
bysort taxsimid (year): gen last_year = year[_N]

bysort taxsimid: egen person_mean_wage = mean(log_pwages)

bysort taxsimid (year): gen first_wage = log_pwages[1]
bysort taxsimid (year): gen last_wage = log_pwages[_N]
gen wage_growth = (last_wage - first_wage) / (last_year - first_year) if last_year > first_year

bysort taxsimid: keep if _n == 1

di ""
di "PERSON-LEVEL MEAN WAGE DISTRIBUTION:"
summarize person_mean_wage, detail

di ""
di "PERSON-LEVEL WAGE GROWTH (workers with 5+ years):"
summarize wage_growth if years_observed >= 5, detail

histogram person_mean_wage, bin(30) ///
    title("Distribution of Person-Level Mean Log Wages") ///
    xtitle("Mean Log Wage") ytitle("Number of Individuals")
graph export "${outdir}\hist_person_mean_wage.png", replace

restore

di ""
di "6.3 AVERAGE WAGE-AGE PROFILE"
di "----------------------------"

preserve
keep if wage_sample == 1 & !missing(log_pwages)

collapse (mean) mean_log_wage=log_pwages (median) median_log_wage=log_pwages, by(page)
keep if page >= 18 & page <= 60

twoway (line mean_log_wage page, lcolor(blue) lwidth(thick)) ///
       (line median_log_wage page, lcolor(red) lpattern(dash)), ///
    title("Average Wage-Age Profile") ///
    xtitle("Age") ytitle("Log Wage") ///
    legend(order(1 "Mean" 2 "Median"))
graph export "${outdir}\avg_wage_age_profile.png", replace

restore

/*==============================================================================
PART 7: OCCUPATION/INDUSTRY SWITCHING ANALYSIS
==============================================================================*/

di ""
di "=============================================================================="
di "PART 7: OCCUPATION/INDUSTRY SWITCHING ANALYSIS"
di "=============================================================================="

di ""
di "7.1 SWITCHING FREQUENCY"
di "-----------------------"

preserve
keep if wage_sample == 1 & !missing(occ_broad) & !missing(ind_broad)

sort taxsimid year

by taxsimid: gen occ_switch = (occ_broad != occ_broad[_n-1] & _n > 1 & !missing(occ_broad[_n-1]))
by taxsimid: gen ind_switch = (ind_broad != ind_broad[_n-1] & _n > 1 & !missing(ind_broad[_n-1]))
by taxsimid: gen cell_switch = (occ_ind_cell != occ_ind_cell[_n-1] & _n > 1 & !missing(occ_ind_cell[_n-1]))

di ""
di "SWITCHING RATES:"
summarize occ_switch ind_switch cell_switch

bysort taxsimid: egen total_occ_switches = total(occ_switch)
bysort taxsimid: egen total_cell_switches = total(cell_switch)

bysort taxsimid: keep if _n == 1

di ""
di "PERSON-LEVEL SWITCHING SUMMARY:"
summarize total_occ_switches total_cell_switches, detail

di ""
di "DISTRIBUTION OF OCCUPATION SWITCHES:"
tab total_occ_switches if total_occ_switches <= 10

restore

di ""
di "7.2 WAGE CHANGES AROUND SWITCHES"
di "---------------------------------"

preserve
keep if wage_sample == 1 & !missing(occ_ind_cell) & !missing(log_pwages)

sort taxsimid year

by taxsimid: gen cell_switch = (occ_ind_cell != occ_ind_cell[_n-1] & _n > 1 & !missing(occ_ind_cell[_n-1]))

gen switch_year = year if cell_switch == 1
bysort taxsimid: egen first_switch_year = min(switch_year)
gen event_time = year - first_switch_year

keep if event_time >= -3 & event_time <= 3 & !missing(first_switch_year)

collapse (mean) mean_log_wage=log_pwages (count) n_obs=log_pwages, by(event_time)

di ""
di "WAGE EVOLUTION AROUND SWITCH:"
list, clean noobs

twoway connected mean_log_wage event_time, ///
       xline(0, lcolor(red) lpattern(dash)) ///
       title("Wages Around Occupation × Industry Switch") ///
       xtitle("Years Relative to Switch") ytitle("Mean Log Wage") ///
       xlabel(-3(1)3)
graph export "${outdir}\event_study_cell_switch.png", replace

restore

di ""
di "7.3 SWITCHERS VS STAYERS"
di "------------------------"

preserve
keep if wage_sample == 1 & !missing(occ_ind_cell) & !missing(log_pwages)

sort taxsimid year

by taxsimid: gen cell_switch = (occ_ind_cell != occ_ind_cell[_n-1] & _n > 1 & !missing(occ_ind_cell[_n-1]))
bysort taxsimid: egen ever_switched = max(cell_switch)

bysort taxsimid (year): gen wage_growth = log_pwages - log_pwages[_n-1] if _n > 1

di ""
di "WAGE GROWTH - SWITCHERS VS STAYERS:"
ttest wage_growth, by(ever_switched)

bysort taxsimid: egen mean_wage = mean(log_pwages)
bysort taxsimid: keep if _n == 1

di ""
di "PERSON-LEVEL MEAN WAGES - SWITCHERS VS STAYERS:"
ttest mean_wage, by(ever_switched)

restore

di ""
di "7.4 OCCUPATION TRANSITION MATRIX"
di "---------------------------------"

preserve
keep if wage_sample == 1 & !missing(occ_broad)

sort taxsimid year
by taxsimid: gen prev_occ = occ_broad[_n-1] if _n > 1 & !missing(occ_broad[_n-1])

di ""
di "OCCUPATION TRANSITION MATRIX (Row = From, Column = To):"
tab prev_occ occ_broad if !missing(prev_occ), row nofreq

restore

/*==============================================================================
PART 8: ADDITIONAL VISUALIZATIONS
==============================================================================*/

di ""
di "=============================================================================="
di "PART 8: ADDITIONAL VISUALIZATIONS"
di "=============================================================================="

di ""
di "8.1 WAGE HEATMAP DATA"
di "---------------------"

preserve
keep if wage_sample == 1 & !missing(occ_broad) & !missing(ind_broad)

collapse (mean) mean_wage=pwages (count) n_obs=pwages, by(occ_broad ind_broad)

di ""
di "MEAN WAGES BY OCCUPATION × INDUSTRY:"
reshape wide mean_wage n_obs, i(occ_broad) j(ind_broad)
list, clean noobs

restore

di ""
di "8.2 DENSITY OVERLAYS"
di "--------------------"

preserve
keep if wage_sample == 1 & !missing(occ_broad) & !missing(ind_broad) & !missing(log_pwages)

gen cell_group = .
replace cell_group = 1 if occ_broad == 6 & ind_broad == 4  // Operatives in Manufacturing
replace cell_group = 2 if occ_broad == 1 & ind_broad == 11 // Professionals in Prof Services
replace cell_group = 3 if occ_broad == 9 & ind_broad == 6  // Service in Trade
replace cell_group = 4 if occ_broad == 4 & ind_broad == 6  // Clerical in Trade

keep if !missing(cell_group)

tab cell_group

twoway (kdensity log_pwages if cell_group == 1, lcolor(blue) lwidth(medthick)) ///
       (kdensity log_pwages if cell_group == 2, lcolor(red) lwidth(medthick)) ///
       (kdensity log_pwages if cell_group == 3, lcolor(green) lwidth(medthick)) ///
       (kdensity log_pwages if cell_group == 4, lcolor(orange) lwidth(medthick)), ///
       title("Log Wage Distributions by Occupation × Industry") ///
       xtitle("Log Wages") ytitle("Density") ///
       legend(order(1 "Operatives × Mfg" 2 "Prof × ProfSvc" 3 "Service × Trade" 4 "Clerical × Trade") rows(2))
graph export "${outdir}\density_overlay_cells.png", replace

restore

/*==============================================================================
SUMMARY STATISTICS
==============================================================================*/

di ""
di "=============================================================================="
di "SUMMARY STATISTICS"
di "=============================================================================="

preserve
keep if wage_sample == 1

di ""
di "FULL SAMPLE SUMMARY:"
summarize pwages log_pwages pot_exp cumhrs page educ_years

di ""
di "SAMPLE WITH OCCUPATION/INDUSTRY DATA:"
keep if !missing(occ_ind_cell)
summarize pwages log_pwages pot_exp cumhrs page educ_years

di ""
di "BY BROAD OCCUPATION:"
table occ_broad, stat(mean pwages) stat(mean pot_exp) stat(count pwages) nformat(%9.2f)

di ""
di "BY BROAD INDUSTRY:"
table ind_broad, stat(mean pwages) stat(mean pot_exp) stat(count pwages) nformat(%9.2f)

restore

/*==============================================================================
CLEAN UP
==============================================================================*/

di ""
di "=============================================================================="
di "EDA DEEP DIVE COMPLETE"
di "=============================================================================="
di "End time: $S_DATE $S_TIME"
di ""
di "OUTPUT FILES:"
di "  - eda_deepdive_data.dta"
di "  - occ_ind_wage_moments.dta"
di "  - cumhrs_returns_by_cell.dta"
di "  - Multiple .png graph files"
di ""

log close
