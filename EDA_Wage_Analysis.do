/*==============================================================================
EDA_WAGE_ANALYSIS.DO
================================================================================
Purpose: Exploratory Data Analysis for Wage Dynamics
         Examining how wages change with experience, hours, age, and occupation

Author: Generated for Yuhao
Date: February 2026

ANALYSES INCLUDED:
1. Occupation × Industry granularity assessment
2. Wages vs. Experience (Mincer-style)
3. Wages vs. Cumulative Hours Worked
4. Wages vs. Age
5. Wages vs. Cumulative Hours / Age (work intensity)

PREREQUISITES:
- Run Data_process.do first to create nlsy_long_pre_taxsim.dta
- Or use the long-format analysis dataset

NOTE: All analyses use both parametric (regression) and non-parametric approaches
==============================================================================*/

clear all
set more off
capture log close

* Start log
log using "EDA_wage_analysis_log.txt", replace text

di ""
di "=============================================================================="
di "EXPLORATORY DATA ANALYSIS: WAGE DYNAMICS"
di "=============================================================================="
di "Start time: $S_DATE $S_TIME"
di ""

/*==============================================================================
PART 0: LOAD AND PREPARE DATA
==============================================================================*/

di ""
di "=============================================================================="
di "PART 0: DATA PREPARATION"
di "=============================================================================="

* Load the long-format data
* Adjust this path to your actual file
use "nlsy_long_pre_taxsim.dta", clear

di ""
di "Loaded dataset with " _N " observations"

* Check which variables are available
describe pwages page cumhrs hrs year taxsimid

/*------------------------------------------------------------------------------
0.1: Create key analytic variables
------------------------------------------------------------------------------*/

* Generate log wages (for workers with positive wages)
* Use capture drop to avoid "already defined" errors if re-running
capture drop log_pwages
gen log_pwages = ln(pwages) if pwages > 0

* Generate potential experience = Age - Years of Education - 6
* First, we need education. Merge from wide data if needed.
* If hgc is available:
capture drop experience
capture gen experience = page - 6  // Simple version: age - 6 (assumes work starts at 6)

* Better version if you have highest grade completed in long format:
* gen experience = page - hgc - 6 if !missing(hgc) & !missing(page)
* replace experience = 0 if experience < 0

* For now, use age-based proxy
capture drop exp_proxy
gen exp_proxy = page - 18
replace exp_proxy = 0 if exp_proxy < 0
replace exp_proxy = . if page < 14 | page > 70

* Create hours per year of age (work intensity measure)
capture drop hrs_per_age
gen hrs_per_age = cumhrs / page if page > 0 & cumhrs >= 0

* Create log versions for elasticity analysis
capture drop log_cumhrs
gen log_cumhrs = ln(cumhrs) if cumhrs > 0

capture drop log_hrs_per_age
gen log_hrs_per_age = ln(hrs_per_age) if hrs_per_age > 0

* Label variables
label var log_pwages "Log of primary wages"
label var exp_proxy "Potential experience (age - 18)"
label var hrs_per_age "Cumulative hours / Age"
label var log_cumhrs "Log cumulative hours"
label var log_hrs_per_age "Log(cumulative hours / age)"

/*------------------------------------------------------------------------------
0.2: Sample restrictions for wage analysis
------------------------------------------------------------------------------*/

* Create sample indicator for valid wage observations
capture drop wage_sample
gen wage_sample = (pwages > 0 & !missing(page) & page >= 16 & page <= 65)

di ""
di "Sample summary:"
tab year if wage_sample == 1, sum(pwages)

* Count by year
preserve
keep if wage_sample == 1
collapse (count) n_obs=pwages (mean) mean_wage=pwages, by(year)
list, clean noobs
restore

save "eda_analysis_temp.dta", replace

/*==============================================================================
PART 1: OCCUPATION × INDUSTRY GRANULARITY ANALYSIS
==============================================================================*/

di ""
di "=============================================================================="
di "PART 1: OCCUPATION × INDUSTRY GRANULARITY"
di "=============================================================================="
di ""

* NOTE: If occupation/industry are not yet merged, this section will be skipped
* You need to run Merge_OccInd.do first and include occ/ind in the reshape

* Check if occupation variables exist
capture confirm variable occ
if _rc != 0 {
    di "WARNING: Occupation variable not found in dataset."
    di "Run Merge_OccInd.do and include occ in your reshape to enable this analysis."
    di ""
    
    * Try to load separate occupation data if available
    capture {
        preserve
        use "occ_ind_data.dta", clear
        
        * Quick summary of occupation data (wide format)
        di "Occupation data summary (from separate file):"
        foreach yr in 1980 1985 1990 {
            quietly count if !missing(occ_`yr')
            di "Year `yr': " r(N) " observations with occupation data"
        }
        
        * Count by broad occupation for 1990
        di ""
        di "Broad occupation distribution (1990):"
        tab occ_broad_1990
        
        * Count cells for occupation × industry
        di ""
        di "Occupation × Industry cell counts (1990):"
        gen occ_ind_cell = occ_broad_1990 * 100 + ind_broad_1990 if !missing(occ_broad_1990) & !missing(ind_broad_1990)
        tab occ_broad_1990 ind_broad_1990, cell
        
        restore
    }
}
else {
    * Occupation variable exists - run full analysis
    di "1.1 OCCUPATION DISTRIBUTION (3-digit codes)"
    di "--------------------------------------------"
    
    preserve
    keep if wage_sample == 1 & !missing(occ)
    
    collapse (count) n_obs=pwages (mean) mean_wage=pwages, by(occ)
    gsort -n_obs
    
    di ""
    di "TOP 20 OCCUPATIONS BY OBSERVATION COUNT:"
    list in 1/20, clean noobs
    
    * Summary statistics on cell sizes
    summarize n_obs, detail
    di ""
    di "Occupation cell size summary:"
    di "  Total unique occupations: " _N
    di "  Mean observations per occupation: " %8.1f r(mean)
    di "  Median observations: " %8.0f r(p50)
    di "  Min: " r(min) ", Max: " r(max)
    di "  Cells with 30+ obs: " 
    count if n_obs >= 30
    
    restore
    
    * Industry distribution
    di ""
    di "1.2 INDUSTRY DISTRIBUTION (3-digit codes)"
    di "-----------------------------------------"
    
    preserve
    keep if wage_sample == 1 & !missing(ind)
    
    collapse (count) n_obs=pwages (mean) mean_wage=pwages, by(ind)
    gsort -n_obs
    
    di ""
    di "TOP 20 INDUSTRIES BY OBSERVATION COUNT:"
    list in 1/20, clean noobs
    
    summarize n_obs, detail
    di ""
    di "Industry cell size summary:"
    di "  Total unique industries: " _N
    di "  Cells with 30+ obs: " 
    count if n_obs >= 30
    
    restore
    
    * Occupation × Industry cross-tabulation
    di ""
    di "1.3 OCCUPATION × INDUSTRY CELL ANALYSIS"
    di "---------------------------------------"
    
    preserve
    keep if wage_sample == 1 & !missing(occ) & !missing(ind)
    
    * Create cell identifier
    egen occ_ind_cell = group(occ ind)
    
    collapse (count) n_obs=pwages (mean) mean_wage=pwages, by(occ_ind_cell occ ind)
    gsort -n_obs
    
    di ""
    di "TOP 20 OCCUPATION × INDUSTRY CELLS:"
    list in 1/20, clean noobs
    
    summarize n_obs, detail
    di ""
    di "Occ × Ind cell size summary:"
    di "  Total unique cells: " _N
    di "  Mean obs per cell: " %8.1f r(mean)
    di "  Median obs: " %8.0f r(p50)
    di "  Cells with 30+ obs (good for regression): "
    count if n_obs >= 30
    di "  Cells with 100+ obs: "
    count if n_obs >= 100
    
    restore
}

/*==============================================================================
PART 2: WAGES VS EXPERIENCE
==============================================================================*/

di ""
di "=============================================================================="
di "PART 2: WAGES VS EXPERIENCE"
di "=============================================================================="
di ""

use "eda_analysis_temp.dta", clear
keep if wage_sample == 1

/*------------------------------------------------------------------------------
2.1: Non-parametric analysis - Mean wages by experience level
------------------------------------------------------------------------------*/

di "2.1 NON-PARAMETRIC: MEAN WAGES BY EXPERIENCE"
di "---------------------------------------------"

preserve

* Collapse by experience level
collapse (mean) mean_wage=pwages mean_log_wage=log_pwages ///
         (median) med_wage=pwages ///
         (p25) p25_wage=pwages (p75) p75_wage=pwages ///
         (count) n_obs=pwages, by(exp_proxy)

* Keep reasonable experience range
keep if exp_proxy >= 0 & exp_proxy <= 45

di ""
di "Mean Wages by Years of Experience:"
di "Exp   | Mean Wage | Median   | N"
di "------|-----------|----------|--------"
forval e = 0(5)40 {
    local e_end = `e' + 4
    quietly sum mean_wage if exp_proxy >= `e' & exp_proxy <= `e_end'
    if r(N) > 0 {
        local mw = r(mean)
        quietly sum med_wage if exp_proxy >= `e' & exp_proxy <= `e_end'
        local med = r(mean)
        quietly sum n_obs if exp_proxy >= `e' & exp_proxy <= `e_end'
        local nn = r(sum)
        di "`e'-`e_end' | " %9.0f `mw' " | " %8.0f `med' " | " %8.0f `nn'
    }
}

* Create graph
twoway (line mean_wage exp_proxy, lcolor(navy) lwidth(thick)) ///
       (line med_wage exp_proxy, lcolor(maroon) lpattern(dash)), ///
    title("Wage-Experience Profile (Non-Parametric)") ///
    xtitle("Years of Potential Experience") ///
    ytitle("Wages ($)") ///
    legend(order(1 "Mean" 2 "Median") pos(5) ring(0)) ///
    note("Experience = Age - 18")
graph export "wages_by_experience.png", replace width(1200)

restore

/*------------------------------------------------------------------------------
2.2: Parametric analysis - Mincer-style regression
------------------------------------------------------------------------------*/

di ""
di "2.2 PARAMETRIC: MINCER EARNINGS REGRESSION"
di "------------------------------------------"

* Create squared and cubed experience - use capture drop to avoid errors
capture drop exp2
gen exp2 = exp_proxy^2

capture drop exp3
gen exp3 = exp_proxy^3

* Basic Mincer regression
di ""
di "Model 1: Log wages = β₀ + β₁*Exp + β₂*Exp² + year FE"
regress log_pwages exp_proxy exp2 i.year, cluster(taxsimid)
estimates store mincer1

* Store key results
local b1 = _b[exp_proxy]
local b2 = _b[exp2]
local peak_exp = -`b1' / (2 * `b2')

di ""
di "INTERPRETATION:"
di "  Coefficient on experience: " %7.4f `b1'
di "  Coefficient on experience²: " %9.6f `b2'
di "  Initial return to experience: " %5.1f `b1'*100 "% per year"
di "  Peak earnings at experience = " %4.1f `peak_exp' " years"
di "  (Peak age ≈ " %4.0f `peak_exp' + 18 ")"

* Model with cubic term
di ""
di "Model 2: Log wages = β₀ + β₁*Exp + β₂*Exp² + β₃*Exp³ + year FE"
regress log_pwages exp_proxy exp2 exp3 i.year, cluster(taxsimid)
estimates store mincer2

* Compare models
di ""
di "MODEL COMPARISON:"
estimates table mincer1 mincer2, b(%9.4f) se(%9.4f) stats(N r2)

/*==============================================================================
PART 3: WAGES VS CUMULATIVE HOURS WORKED
==============================================================================*/

di ""
di "=============================================================================="
di "PART 3: WAGES VS CUMULATIVE HOURS WORKED"
di "=============================================================================="
di ""

/*------------------------------------------------------------------------------
3.1: Non-parametric analysis
------------------------------------------------------------------------------*/

di "3.1 NON-PARAMETRIC: WAGES BY CUMULATIVE HOURS"
di "---------------------------------------------"

* Create hours bins - use capture drop to avoid errors
capture drop cumhrs_bin
gen cumhrs_bin = 1 if cumhrs >= 0 & cumhrs < 5000
replace cumhrs_bin = 2 if cumhrs >= 5000 & cumhrs < 10000
replace cumhrs_bin = 3 if cumhrs >= 10000 & cumhrs < 20000
replace cumhrs_bin = 4 if cumhrs >= 20000 & cumhrs < 40000
replace cumhrs_bin = 5 if cumhrs >= 40000 & cumhrs < 60000
replace cumhrs_bin = 6 if cumhrs >= 60000 & cumhrs < 80000
replace cumhrs_bin = 7 if cumhrs >= 80000 & !missing(cumhrs)

capture label drop hrs_bin_lbl
label define hrs_bin_lbl 1 "0-5K" 2 "5-10K" 3 "10-20K" 4 "20-40K" 5 "40-60K" 6 "60-80K" 7 "80K+"
label values cumhrs_bin hrs_bin_lbl

preserve
keep if !missing(cumhrs_bin) & wage_sample == 1

collapse (mean) mean_wage=pwages mean_log_wage=log_pwages ///
         (median) med_wage=pwages ///
         (count) n_obs=pwages, by(cumhrs_bin)

di ""
di "Mean Wages by Cumulative Hours Worked:"
list, clean noobs

* Bar chart
graph bar mean_wage, over(cumhrs_bin) ///
    title("Mean Wages by Cumulative Hours Worked") ///
    ytitle("Mean Wages ($)") ///
    note("Hours bins in thousands")
graph export "wages_by_cumhrs_bars.png", replace width(1200)

restore

/*------------------------------------------------------------------------------
3.2: Scatter with LOWESS
------------------------------------------------------------------------------*/

di ""
di "3.2 SCATTER PLOT WITH LOWESS SMOOTHER"
di "-------------------------------------"

preserve
keep if cumhrs > 0 & cumhrs < 150000 & wage_sample == 1

* Sample for plotting (full data too dense)
set seed 12345
sample 10

gen cumhrs_thousands = cumhrs / 1000

twoway (scatter log_pwages cumhrs_thousands, msize(tiny) mcolor(gs12%30)) ///
       (lowess log_pwages cumhrs_thousands, bwidth(0.3) lcolor(red) lwidth(thick)), ///
    title("Log Wages vs Cumulative Hours") ///
    xtitle("Cumulative Hours (000s)") ///
    ytitle("Log Wages") ///
    legend(off) ///
    note("LOWESS bandwidth = 0.3; 10% random sample shown")
graph export "wages_cumhrs_scatter.png", replace width(1200)

restore

/*------------------------------------------------------------------------------
3.3: Regression analysis
------------------------------------------------------------------------------*/

di ""
di "3.3 PARAMETRIC: CUMULATIVE HOURS REGRESSION"
di "-------------------------------------------"

* Regression with log cumulative hours
di ""
di "Model: Log wages = β₀ + β₁*Log(CumHrs) + year FE"
regress log_pwages log_cumhrs i.year if cumhrs > 0, cluster(taxsimid)
estimates store cumhrs_reg

local elasticity = _b[log_cumhrs]
di ""
di "INTERPRETATION:"
di "  Elasticity of wages w.r.t. cumulative hours: " %6.3f `elasticity'
di "  A 10% increase in cumulative hours → " %4.2f `elasticity'*10 "% wage increase"
di "  Doubling cumulative hours → " %4.1f `elasticity'*100 * ln(2) "% wage increase"

/*==============================================================================
PART 4: WAGES VS AGE
==============================================================================*/

di ""
di "=============================================================================="
di "PART 4: WAGES VS AGE"
di "=============================================================================="
di ""

/*------------------------------------------------------------------------------
4.1: Non-parametric analysis
------------------------------------------------------------------------------*/

di "4.1 NON-PARAMETRIC: WAGE-AGE PROFILE"
di "------------------------------------"

preserve
keep if wage_sample == 1 & page >= 16 & page <= 65

collapse (mean) mean_wage=pwages mean_log_wage=log_pwages ///
         (median) med_wage=pwages ///
         (p10) p10_wage=pwages (p90) p90_wage=pwages ///
         (count) n_obs=pwages, by(page)

* Display wages for selected ages
di ""
di "Wages by Age (selected ages):"
list if inlist(page, 20, 25, 30, 35, 40, 45, 50, 55, 60), clean noobs

* List all ages
list if page >= 20 & page <= 60, clean noobs

* Create graph with confidence band
twoway (rarea p10_wage p90_wage page, color(gs14)) ///
       (line mean_wage page, lcolor(navy) lwidth(thick)) ///
       (line med_wage page, lcolor(maroon) lpattern(dash)), ///
    title("Wage-Age Profile") ///
    xtitle("Age") ///
    ytitle("Wages ($)") ///
    legend(order(2 "Mean" 3 "Median" 1 "10th-90th %ile") pos(11) ring(0) col(1)) ///
    xlabel(20(5)65)
graph export "wages_by_age.png", replace width(1200)

restore

/*------------------------------------------------------------------------------
4.2: Parametric analysis
------------------------------------------------------------------------------*/

di ""
di "4.2 PARAMETRIC: AGE-EARNINGS REGRESSION"
di "---------------------------------------"

* Create age terms - MUST use capture drop to avoid "already defined" errors
capture drop age2
gen age2 = page^2

capture drop age3
gen age3 = page^3

capture drop age4
gen age4 = page^4

* Quadratic model
di ""
di "Model 1: Log wages = β₀ + β₁*Age + β₂*Age² + year FE"
regress log_pwages page age2 i.year, cluster(taxsimid)
estimates store age_quad

local b1 = _b[page]
local b2 = _b[age2]
local peak_age = -`b1' / (2 * `b2')

di ""
di "QUADRATIC MODEL INTERPRETATION:"
di "  Peak earnings at age = " %4.1f `peak_age'

* Cubic model
di ""
di "Model 2: Log wages = β₀ + β₁*Age + β₂*Age² + β₃*Age³ + year FE"
regress log_pwages page age2 age3 i.year, cluster(taxsimid)
estimates store age_cubic

* Quartic model
di ""
di "Model 3: Log wages = β₀ + β₁*Age + β₂*Age² + β₃*Age³ + β₄*Age⁴ + year FE"
regress log_pwages page age2 age3 age4 i.year, cluster(taxsimid)
estimates store age_quartic

* Compare models
di ""
di "MODEL COMPARISON (Age Specifications):"
estimates table age_quad age_cubic age_quartic, b(%9.5f) se(%9.5f) stats(N r2)

/*==============================================================================
PART 5: WAGES VS CUMULATIVE HOURS / AGE (WORK INTENSITY)
==============================================================================*/

di ""
di "=============================================================================="
di "PART 5: WAGES VS WORK INTENSITY (CUM HOURS / AGE)"
di "=============================================================================="
di ""

di "This ratio captures 'work intensity' over the life course:"
di "  High ratio = Started working young and/or worked many hours"
di "  Low ratio = Limited work history relative to age"
di ""

/*------------------------------------------------------------------------------
5.1: Summary statistics
------------------------------------------------------------------------------*/

di "5.1 SUMMARY STATISTICS"
di "----------------------"

summarize hrs_per_age if wage_sample == 1, detail

di ""
di "INTERPRETATION:"
di "  Mean hours/age = " %8.0f r(mean) " hours per year of age"
di "  This is equivalent to about " %4.0f r(mean)/52 " hours per week on average"
di "  (assuming continuous work from birth, which overstates intensity)"
di ""
di "  More realistic interpretation for a 40-year-old:"
di "  If hrs_per_age = 2000, that's 80,000 total hours"
di "  Over 22 working years (age 18-40), that's ~3,600 hrs/year = ~70 hrs/week"
di ""

/*------------------------------------------------------------------------------
5.2: Non-parametric by quintiles
------------------------------------------------------------------------------*/

di "5.2 NON-PARAMETRIC: WAGES BY WORK INTENSITY QUINTILE"
di "----------------------------------------------------"

* Create quintiles - use capture drop to avoid errors
capture drop hrs_age_q
xtile hrs_age_q = hrs_per_age if wage_sample == 1, nq(5)

capture label drop haq_lbl
label define haq_lbl 1 "Q1 (Lowest)" 2 "Q2" 3 "Q3" 4 "Q4" 5 "Q5 (Highest)"
label values hrs_age_q haq_lbl

preserve
keep if !missing(hrs_age_q)

collapse (mean) mean_wage=pwages mean_hrs_age=hrs_per_age ///
         (median) med_wage=pwages ///
         (count) n_obs=pwages, by(hrs_age_q)

di ""
di "Wages by Work Intensity Quintile:"
list, clean noobs

* Bar chart
graph bar mean_wage, over(hrs_age_q) ///
    title("Mean Wages by Work Intensity Quintile") ///
    ytitle("Mean Wages ($)") ///
    note("Work Intensity = Cumulative Hours / Age" ///
         "Higher quintile = more intensive work history")
graph export "wages_by_work_intensity.png", replace width(1200)

restore

/*------------------------------------------------------------------------------
5.3: Regression analysis
------------------------------------------------------------------------------*/

di ""
di "5.3 PARAMETRIC: WORK INTENSITY REGRESSION"
di "-----------------------------------------"

* Regression with log hrs/age ratio
di ""
di "Model: Log wages = β₀ + β₁*Log(CumHrs/Age) + year FE"
regress log_pwages log_hrs_per_age i.year if hrs_per_age > 0, cluster(taxsimid)
estimates store hrs_age_reg

local elasticity = _b[log_hrs_per_age]
di ""
di "INTERPRETATION:"
di "  Elasticity of wages w.r.t. hours/age ratio: " %6.3f `elasticity'
di "  10% increase in work intensity → " %4.2f `elasticity'*10 "% wage increase"

/*------------------------------------------------------------------------------
5.4: Comparing specifications
------------------------------------------------------------------------------*/

di ""
di "5.4 COMPARING CUMULATIVE HOURS VS HOURS/AGE"
di "------------------------------------------"

* Model with both
di ""
di "Model with both cumulative hours and hours/age:"
regress log_pwages log_cumhrs log_hrs_per_age i.year if cumhrs > 0 & hrs_per_age > 0, cluster(taxsimid)
estimates store combined

* Model comparison table
di ""
di "COMPARISON OF SPECIFICATIONS:"
estimates table cumhrs_reg hrs_age_reg combined, ///
    keep(log_cumhrs log_hrs_per_age) ///
    b(%9.4f) se(%9.4f) stats(N r2)

di ""
di "NOTE: In the combined model:"
di "  - If log_cumhrs dominates: Total accumulated hours matter most"
di "  - If log_hrs_per_age dominates: Intensity matters most"
di "  - If both significant: Both channels affect wages"

/*==============================================================================
PART 6: COMPREHENSIVE SUMMARY TABLE
==============================================================================*/

di ""
di "=============================================================================="
di "PART 6: SUMMARY OF ALL WAGE DETERMINANTS"
di "=============================================================================="
di ""

* Run combined model with all variables
di "COMPREHENSIVE MODEL:"
di "Log wages = f(Experience, CumHrs, Age, Year)"
di ""

regress log_pwages exp_proxy exp2 log_cumhrs i.year if cumhrs > 0, cluster(taxsimid)
estimates store comprehensive

* Create summary table
di ""
di "SUMMARY TABLE: Wage Determinants"
di "================================"
estimates table mincer1 cumhrs_reg age_quad hrs_age_reg comprehensive, ///
    keep(exp_proxy exp2 log_cumhrs page age2 log_hrs_per_age) ///
    b(%9.4f) se(%9.4f) stats(N r2) ///
    title("Wage Determinants: Alternative Specifications")

/*==============================================================================
PART 7: SAVE RESULTS AND CLOSE
==============================================================================*/

di ""
di "=============================================================================="
di "OUTPUT FILES CREATED"
di "=============================================================================="
di ""
di "Graphs:"
di "  - wages_by_experience.png"
di "  - wages_by_cumhrs_bars.png"
di "  - wages_cumhrs_scatter.png"
di "  - wages_by_age.png"
di "  - wages_by_work_intensity.png"
di ""
di "Data:"
di "  - eda_analysis_temp.dta (working dataset)"
di ""
di "Log:"
di "  - EDA_wage_analysis_log.txt"
di ""

* Clean up
capture erase "eda_analysis_temp.dta"

di ""
di "=============================================================================="
di "ANALYSIS COMPLETE"
di "=============================================================================="
di "End time: $S_DATE $S_TIME"
di ""

* Run Skill vs Signal Analysis


log close
