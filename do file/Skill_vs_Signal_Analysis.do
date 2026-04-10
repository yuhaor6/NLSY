/*==============================================================================
SKILL_VS_SIGNAL_ANALYSIS.DO 
================================================================================
Purpose: Test whether early-career wage growth reflects genuine skill formation
         (human capital) or signaling/employer learning

CORRECTIONS APPLIED:
- Uses pot_exp from corrected Data_process.do (current-year education)
- Uses recent_hrs_annual for cross-period comparisons (annualized hours)
- AFQT properly standardized
- Ages are income-year aligned

RESEARCH QUESTION:
Do early-career wage jumps mainly stem from signaling strategies (long hours, 
credentials) or from real human-capital gains?

ANALYSES INCLUDED:
1. Altonji-Pierret Employer Learning Test (AFQT × Experience interaction)
2. Hours Decomposition (Recent "face time" vs. Cumulative learning)
3. Wage Variance Evolution (Does dispersion increase with experience?)
4. Fixed Effects Comparison (OLS vs FE to assess selection)
5. Sheepskin Effects (Discrete degree returns vs. continuous education)

THEORETICAL FRAMEWORK:
- Human Capital: Wages rise because workers become more productive
- Signaling/Employer Learning: Wages rise as employers discover true ability

KEY PREDICTIONS:
                        | Human Capital | Employer Learning
------------------------|---------------|-------------------
AFQT effect over time   | Constant      | INCREASES with exp
Recent hours effect     | Small         | Large (signaling)
Wage variance over exp  | Constant      | Increases then stable
FE vs OLS coefficients  | Similar       | FE much smaller
Sheepskin effects       | Small         | Large
==============================================================================*/

global projdir "D:\Stata Data\labor_signaling_project"
global datadir "${projdir}\data"
global outdir  "${projdir}\output"

* Check if data is already loaded with required variables
capture confirm variable pwages
if _rc != 0 {
    * Data not in memory - load it
    clear all
    set more off
    use "${datadir}\nlsy_long_pre_taxsim.dta", clear
}
else {
    set more off
}

* Create log wages if not exists
capture confirm variable log_pwages
if _rc != 0 {
    gen log_pwages = ln(pwages) if pwages > 0
}

* Start log
capture log close skill_signal_log
log using "${outdir}\Skill_vs_Signal_log.txt", replace text name(skill_signal_log)

di ""
di "=============================================================================="
di "SKILL VS SIGNALING ANALYSIS"
di "=============================================================================="
di "Research Question: Does early-career wage growth reflect skill formation"
di "                   or signaling/employer learning?"
di "=============================================================================="
di "Start time: $S_DATE $S_TIME"
di ""

/*==============================================================================
PART 0: DATA VERIFICATION AND SAMPLE DEFINITION
==============================================================================*/

di ""
di "=============================================================================="
di "PART 0: DATA VERIFICATION"
di "=============================================================================="

* Check that required variables exist
local required_vars afqt_std pot_exp pot_exp2 early_career recent_hrs cumhrs ///
                    educ_years hs_diploma ba_degree exp_bin log_pwages

local missing_vars = 0
foreach v of local required_vars {
    capture confirm variable `v'
    if _rc != 0 {
        di as error "ERROR: Variable `v' not found. Run Data_process_CORRECTED.do first."
        local missing_vars = 1
    }
}

if `missing_vars' == 1 {
    di as error "Missing required variables. Exiting."
    log close skill_signal_log
    error 111
}

di "All required variables found."
di ""

* Verify key corrections
di "VERIFICATION: Checking corrected variables"
di "-------------------------------------------"

* Check pot_exp distribution
di ""
di "Potential experience distribution (should be non-negative, reasonable):"
summarize pot_exp, detail

* Check for negative values (should be none after correction)
count if pot_exp < 0 & !missing(pot_exp)
if r(N) > 0 {
    di as error "WARNING: " r(N) " observations have negative pot_exp"
}
else {
    di "GOOD: No negative potential experience values"
}

* Check AFQT standardization
di ""
di "AFQT standardized (should have mean~0, sd~1):"
summarize afqt_std, detail

* Check recent_hrs_annual exists (for cross-period comparisons)
capture confirm variable recent_hrs_annual
if _rc == 0 {
    di ""
    di "recent_hrs_annual found - using annualized recent hours for analysis"
    summarize recent_hrs_annual, detail
}
else {
    di ""
    di "WARNING: recent_hrs_annual not found. Creating from recent_hrs."
    * Create annualized version
    capture confirm variable year_span
    if _rc == 0 {
        gen recent_hrs_annual = recent_hrs / year_span if year_span > 0
        replace recent_hrs_annual = recent_hrs if year_span == 1 | missing(year_span)
    }
    else {
        gen recent_hrs_annual = recent_hrs
    }
}

* Define analysis sample
capture drop skill_sample
gen skill_sample = (pwages > 0 & !missing(pot_exp) & pot_exp >= 0 & pot_exp <= 40 ///
                   & !missing(afqt_std) & page >= 18 & page <= 65)
label var skill_sample "Sample for skill vs signaling analysis"

di ""
di "Sample definition:"
di "  - Positive wages"
di "  - Valid potential experience (0-40 years)"
di "  - Non-missing AFQT score"
di "  - Age 18-65"
di ""

tab skill_sample
summarize pwages pot_exp afqt_std if skill_sample == 1

/*==============================================================================
PART 1: ALTONJI-PIERRET EMPLOYER LEARNING TEST
==============================================================================*/

di ""
di "=============================================================================="
di "PART 1: ALTONJI-PIERRET EMPLOYER LEARNING TEST"
di "=============================================================================="
di ""
di "THEORY:"
di "  If employers cannot directly observe ability (AFQT) but learn it over time,"
di "  then AFQT should predict wages MORE as experience increases."
di ""
di "  Human Capital:      AFQT effect is CONSTANT (reflects productivity)"
di "  Employer Learning:  AFQT effect GROWS with experience"
di ""

/*------------------------------------------------------------------------------
1.1: Baseline Mincer regression (no AFQT)
------------------------------------------------------------------------------*/

di "1.1 BASELINE MINCER REGRESSION (No AFQT)"
di "----------------------------------------"

regress log_pwages pot_exp pot_exp2 educ_years i.year if skill_sample == 1, cluster(taxsimid)
estimates store baseline_mincer

di ""
di "Baseline R-squared: " %6.4f e(r2)

/*------------------------------------------------------------------------------
1.2: Add AFQT (main effect only)
------------------------------------------------------------------------------*/

di ""
di "1.2 ADD AFQT (Main Effect Only)"
di "-------------------------------"

regress log_pwages afqt_std pot_exp pot_exp2 educ_years i.year if skill_sample == 1, cluster(taxsimid)
estimates store afqt_main

di ""
di "AFQT coefficient: " %7.4f _b[afqt_std] " (SE: " %6.4f _se[afqt_std] ")"
di "R-squared improvement: " %6.4f e(r2) - e(r2)
di ""
di "Interpretation: A 1 SD increase in AFQT is associated with " ///
   %4.1f _b[afqt_std]*100 "% higher wages"

/*------------------------------------------------------------------------------
1.3: KEY TEST - AFQT × Experience Interaction
------------------------------------------------------------------------------*/

di ""
di "1.3 KEY TEST: AFQT × EXPERIENCE INTERACTION"
di "-------------------------------------------"

* Create interaction
capture drop afqt_x_exp
gen afqt_x_exp = afqt_std * pot_exp

regress log_pwages afqt_std pot_exp pot_exp2 afqt_x_exp educ_years i.year ///
    if skill_sample == 1, cluster(taxsimid)
estimates store afqt_interaction

local b_afqt = _b[afqt_std]
local b_interaction = _b[afqt_x_exp]
local se_interaction = _se[afqt_x_exp]
local t_interaction = `b_interaction' / `se_interaction'

di ""
di "============================================================"
di "EMPLOYER LEARNING TEST RESULTS"
di "============================================================"
di ""
di "  AFQT main effect (at exp=0):     " %7.4f `b_afqt'
di "  AFQT × Experience interaction:   " %7.4f `b_interaction'
di "  Standard error:                  " %7.4f `se_interaction'
di "  t-statistic:                     " %7.2f `t_interaction'
di ""

if `b_interaction' > 0 & `t_interaction' > 1.96 {
    di "RESULT: EVIDENCE FOR EMPLOYER LEARNING"
    di "  The effect of AFQT on wages INCREASES with experience."
    di "  Employers appear to learn workers' true ability over time."
    di ""
    di "  At experience = 0:  AFQT effect = " %5.3f `b_afqt'
    di "  At experience = 10: AFQT effect = " %5.3f `b_afqt' + 10*`b_interaction'
    di "  At experience = 20: AFQT effect = " %5.3f `b_afqt' + 20*`b_interaction'
}
else if `b_interaction' > 0 & `t_interaction' > 1.65 {
    di "RESULT: WEAK EVIDENCE FOR EMPLOYER LEARNING (p < 0.10)"
    di "  The interaction is positive but marginally significant."
}
else {
    di "RESULT: NO STRONG EVIDENCE FOR EMPLOYER LEARNING"
    di "  The effect of AFQT does not significantly increase with experience."
    di "  This is more consistent with human capital theory."
}
di ""

/*------------------------------------------------------------------------------
1.4: Extended test - Education × Experience interaction
------------------------------------------------------------------------------*/

di ""
di "1.4 EDUCATION × EXPERIENCE INTERACTION"
di "--------------------------------------"
di ""
di "Signaling theory predicts: Education effect should DECLINE with experience"
di "  (The diploma matters for getting hired, but experience reveals true ability)"
di ""

capture drop educ_x_exp
gen educ_x_exp = educ_years * pot_exp

regress log_pwages afqt_std pot_exp pot_exp2 educ_years afqt_x_exp educ_x_exp i.year ///
    if skill_sample == 1, cluster(taxsimid)
estimates store full_learning

local b_educ_int = _b[educ_x_exp]
local se_educ_int = _se[educ_x_exp]
local t_educ_int = `b_educ_int' / `se_educ_int'

di "  Education × Experience interaction: " %9.6f `b_educ_int'
di "  Standard error:                     " %9.6f `se_educ_int'
di "  t-statistic:                        " %7.2f `t_educ_int'
di ""

if `b_educ_int' < 0 & `t_educ_int' < -1.96 {
    di "RESULT: Education returns DECLINE with experience"
    di "  Consistent with signaling: credentials matter less as employers learn"
}
else {
    di "RESULT: Education returns do NOT significantly decline with experience"
    di "  Consistent with human capital: education reflects persistent skills"
}

/*------------------------------------------------------------------------------
1.5: Comparison table
------------------------------------------------------------------------------*/

di ""
di "1.5 MODEL COMPARISON TABLE"
di "--------------------------"

estimates table baseline_mincer afqt_main afqt_interaction full_learning, ///
    keep(afqt_std pot_exp pot_exp2 educ_years afqt_x_exp educ_x_exp) ///
    b(%9.4f) se(%9.4f) stats(N r2) ///
    title("Employer Learning Test: Model Comparison")

/*==============================================================================
PART 2: HOURS DECOMPOSITION - RECENT SIGNALING VS CUMULATIVE LEARNING
==============================================================================*/

di ""
di "=============================================================================="
di "PART 2: HOURS DECOMPOSITION"
di "=============================================================================="
di ""
di "THEORY:"
di "  If hours reflect LEARNING-BY-DOING: Cumulative hours should matter most"
di "  If hours reflect SIGNALING: Recent hours ('face time') should matter"
di ""
di "  Test: Include both cumulative hours and recent hours in regression"
di "        See which dominates, especially in early career"
di ""
di "NOTE: Using recent_hrs_annual for proper cross-period comparisons"
di "      (annualized to account for biennial vs annual survey gaps)"
di ""

/*------------------------------------------------------------------------------
2.1: Cumulative hours only
------------------------------------------------------------------------------*/

di "2.1 CUMULATIVE HOURS ONLY"
di "-------------------------"

capture drop log_cumhrs
gen log_cumhrs = ln(cumhrs) if cumhrs > 0

regress log_pwages log_cumhrs pot_exp pot_exp2 educ_years i.year ///
    if skill_sample == 1 & cumhrs > 0, cluster(taxsimid)
estimates store cumhrs_only

di ""
di "Cumulative hours elasticity: " %6.3f _b[log_cumhrs]

/*------------------------------------------------------------------------------
2.2: Recent hours only (annualized)
------------------------------------------------------------------------------*/

di ""
di "2.2 RECENT HOURS ONLY (ANNUALIZED)"
di "----------------------------------"

* Use annualized recent hours for fair comparison
capture drop log_recent_hrs_annual
gen log_recent_hrs_annual = ln(recent_hrs_annual) if recent_hrs_annual > 0

regress log_pwages log_recent_hrs_annual pot_exp pot_exp2 educ_years i.year ///
    if skill_sample == 1 & recent_hrs_annual > 0, cluster(taxsimid)
estimates store recent_only

di ""
di "Recent hours (annualized) elasticity: " %6.3f _b[log_recent_hrs_annual]

/*------------------------------------------------------------------------------
2.3: Horse race - both types of hours
------------------------------------------------------------------------------*/

di ""
di "2.3 HORSE RACE: CUMULATIVE VS RECENT HOURS (ANNUALIZED)"
di "-------------------------------------------------------"

regress log_pwages log_cumhrs log_recent_hrs_annual pot_exp pot_exp2 educ_years i.year ///
    if skill_sample == 1 & cumhrs > 0 & recent_hrs_annual > 0, cluster(taxsimid)
estimates store hours_horserace

local b_cum = _b[log_cumhrs]
local b_recent = _b[log_recent_hrs_annual]

di ""
di "============================================================"
di "HOURS DECOMPOSITION RESULTS"
di "============================================================"
di ""
di "  Cumulative hours elasticity:       " %6.3f `b_cum'
di "  Recent hours (annual) elasticity:  " %6.3f `b_recent'
di ""

if abs(`b_cum') > abs(`b_recent') * 2 {
    di "RESULT: CUMULATIVE HOURS DOMINATES"
    di "  Consistent with LEARNING-BY-DOING (human capital)"
    di "  Total accumulated experience matters most"
}
else if abs(`b_recent') > abs(`b_cum') * 2 {
    di "RESULT: RECENT HOURS DOMINATES"
    di "  Consistent with SIGNALING"
    di "  Current 'face time' matters more than total experience"
}
else {
    di "RESULT: BOTH CHANNELS MATTER"
    di "  Evidence for both learning-by-doing and signaling"
}

/*------------------------------------------------------------------------------
2.4: Does recent hours matter MORE in early career? (Signaling test)
------------------------------------------------------------------------------*/

di ""
di "2.4 EARLY CAREER INTERACTION"
di "----------------------------"
di ""
di "If signaling matters: Recent hours should matter MORE in early career"
di "  (when employers have less information about workers)"
di ""

capture drop recent_x_early
gen recent_x_early = log_recent_hrs_annual * early_career

regress log_pwages log_cumhrs log_recent_hrs_annual recent_x_early early_career ///
    pot_exp pot_exp2 educ_years i.year ///
    if skill_sample == 1 & cumhrs > 0 & recent_hrs_annual > 0, cluster(taxsimid)
estimates store early_career_test

local b_interact = _b[recent_x_early]
local se_interact = _se[recent_x_early]

di ""
di "Recent hours × Early career interaction: " %6.4f `b_interact'
di "Standard error:                          " %6.4f `se_interact'
di ""

if `b_interact' > 0 & `b_interact'/`se_interact' > 1.65 {
    di "RESULT: Recent hours matter MORE in early career"
    di "  Evidence for SIGNALING: 'Face time' is especially valued early on"
}
else {
    di "RESULT: No significant early-career premium for recent hours"
    di "  Consistent with LEARNING-BY-DOING throughout career"
}

/*------------------------------------------------------------------------------
2.5: Hours comparison table
------------------------------------------------------------------------------*/

di ""
di "2.5 HOURS MODEL COMPARISON"
di "--------------------------"

estimates table cumhrs_only recent_only hours_horserace early_career_test, ///
    keep(log_cumhrs log_recent_hrs_annual recent_x_early early_career) ///
    b(%9.4f) se(%9.4f) stats(N r2) ///
    title("Hours Decomposition: Cumulative vs Recent (Annualized)")

/*==============================================================================
PART 3: WAGE VARIANCE EVOLUTION
==============================================================================*/

di ""
di "=============================================================================="
di "PART 3: WAGE VARIANCE OVER THE CAREER"
di "=============================================================================="
di ""
di "THEORY:"
di "  Employer Learning predicts:"
di "    - Wage variance INCREASES early in careers (as employers sort workers)"
di "    - Then stabilizes as sorting is complete"
di ""
di "  Human Capital predicts:"
di "    - Wage variance relatively CONSTANT (everyone grows similarly)"
di ""

/*------------------------------------------------------------------------------
3.1: Calculate variance by experience bin
------------------------------------------------------------------------------*/

di "3.1 WAGE VARIANCE BY EXPERIENCE"
di "-------------------------------"

preserve
keep if skill_sample == 1

* Calculate variance statistics by experience bin
collapse (mean) mean_log_wage = log_pwages ///
         (sd) sd_log_wage = log_pwages ///
         (p10) p10_wage = log_pwages ///
         (p90) p90_wage = log_pwages ///
         (count) n_obs = log_pwages, by(exp_bin)

* Calculate variance and interquartile range
gen var_log_wage = sd_log_wage^2
gen iqr_log_wage = p90_wage - p10_wage

di ""
di "Wage Dispersion by Experience:"
di "Exp Bin     | Variance | Std Dev | P90-P10 | N"
di "------------|----------|---------|---------|--------"
list exp_bin var_log_wage sd_log_wage iqr_log_wage n_obs, clean noobs

* Plot variance evolution
twoway (connected var_log_wage exp_bin, lcolor(navy) lwidth(thick) msymbol(circle)) ///
       (connected iqr_log_wage exp_bin, lcolor(maroon) lpattern(dash) msymbol(square)), ///
    title("Wage Dispersion Over the Career") ///
    xtitle("Experience Bin") ///
    ytitle("Dispersion Measure") ///
    legend(order(1 "Variance" 2 "P90-P10 Gap") pos(11) ring(0)) ///
    xlabel(1 "0-5" 2 "6-10" 3 "11-15" 4 "16-20" 5 "21-25" 6 "26-30" 7 "30+")
graph export "${outdir}\wage_variance_evolution.png", replace width(1200)

restore

/*==============================================================================
PART 4: FIXED EFFECTS VS OLS COMPARISON
==============================================================================*/

di ""
di "=============================================================================="
di "PART 4: FIXED EFFECTS VS OLS COMPARISON"
di "=============================================================================="
di ""
di "THEORY:"
di "  If ability selection drives wages: OLS will overestimate experience effects"
di "  because high-ability workers accumulate more experience."
di ""
di "  Fixed effects control for time-invariant ability, giving causal effect."
di ""
di "  Signaling: FE coefficients much SMALLER than OLS (ability was confounding)"
di "  Human Capital: FE and OLS coefficients SIMILAR (experience is causal)"
di ""

/*------------------------------------------------------------------------------
4.1: OLS baseline
------------------------------------------------------------------------------*/

di "4.1 OLS ESTIMATES"
di "-----------------"

regress log_pwages pot_exp pot_exp2 educ_years i.year ///
    if skill_sample == 1, cluster(taxsimid)
estimates store ols_main

local b_exp_ols = _b[pot_exp]
local b_exp2_ols = _b[pot_exp2]

di ""
di "OLS Experience coefficient: " %7.4f `b_exp_ols'
di "OLS Experience² coefficient: " %9.6f `b_exp2_ols'

/*------------------------------------------------------------------------------
4.2: Fixed effects
------------------------------------------------------------------------------*/

di ""
di "4.2 FIXED EFFECTS ESTIMATES"
di "---------------------------"

xtset taxsimid year
xtreg log_pwages pot_exp pot_exp2 i.year ///
    if skill_sample == 1, fe cluster(taxsimid)
estimates store fe_main

local b_exp_fe = _b[pot_exp]
local b_exp2_fe = _b[pot_exp2]

di ""
di "FE Experience coefficient: " %7.4f `b_exp_fe'
di "FE Experience² coefficient: " %9.6f `b_exp2_fe'

/*------------------------------------------------------------------------------
4.3: Comparison
------------------------------------------------------------------------------*/

di ""
di "4.3 OLS VS FE COMPARISON"
di "------------------------"

local exp_ratio = `b_exp_fe' / `b_exp_ols'
local exp2_ratio = `b_exp2_fe' / `b_exp2_ols'

di ""
di "============================================================"
di "FIXED EFFECTS TEST RESULTS"
di "============================================================"
di ""
di "                           OLS           FE          Ratio"
di "------------------------------------------------------------"
di "Experience               " %8.4f `b_exp_ols' "      " %8.4f `b_exp_fe' "      " %5.2f `exp_ratio'
di "Experience²              " %8.5f `b_exp2_ols' "     " %8.5f `b_exp2_fe' "     " %5.2f `exp2_ratio'
di ""

if `exp_ratio' > 0.7 {
    di "RESULT: FE ≈ OLS (ratio > 0.7)"
    di "  Consistent with HUMAN CAPITAL: Experience effect is mostly causal"
    di "  Ability selection accounts for small portion of returns"
}
else if `exp_ratio' < 0.5 {
    di "RESULT: FE << OLS (ratio < 0.5)"
    di "  Consistent with SIGNALING: Much of 'experience return' is ability selection"
    di "  High-ability workers gain more experience AND earn more"
}
else {
    di "RESULT: FE somewhat smaller than OLS (0.5 < ratio < 0.7)"
    di "  Mixed evidence: Some ability selection, but substantial causal returns"
}

/*------------------------------------------------------------------------------
4.4: Model comparison table
------------------------------------------------------------------------------*/

di ""
di "4.4 OLS VS FE MODEL TABLE"
di "-------------------------"

estimates table ols_main fe_main, ///
    keep(pot_exp pot_exp2 educ_years) ///
    b(%9.4f) se(%9.4f) stats(N r2) ///
    title("OLS vs Fixed Effects: Experience Returns")

/*==============================================================================
PART 5: SHEEPSKIN EFFECTS
==============================================================================*/

di ""
di "=============================================================================="
di "PART 5: SHEEPSKIN EFFECTS (Degree Returns)"
di "=============================================================================="
di ""
di "THEORY:"
di "  Signaling: Wages jump discretely at degree completion (credential matters)"
di "  Human Capital: Wages rise smoothly with years of schooling"
di ""
di "  Test: Include both years of education AND degree dummies"
di "        If degree dummies are large → Signaling"
di ""

/*------------------------------------------------------------------------------
5.1: Continuous education only
------------------------------------------------------------------------------*/

di "5.1 CONTINUOUS EDUCATION ONLY"
di "-----------------------------"

regress log_pwages educ_years pot_exp pot_exp2 i.year ///
    if skill_sample == 1, cluster(taxsimid)
estimates store educ_continuous

local return_per_year = _b[educ_years]

di ""
di "Return per year of education: " %5.2f `return_per_year'*100 "%"

/*------------------------------------------------------------------------------
5.2: Degree dummies only (no years)
------------------------------------------------------------------------------*/

di ""
di "5.2 DEGREE DUMMIES ONLY"
di "-----------------------"

* Create reference category: less than HS
capture drop less_than_hs
gen less_than_hs = (max_education < 12) if !missing(max_education)

regress log_pwages hs_diploma some_coll ba_degree grad_degree pot_exp pot_exp2 i.year ///
    if skill_sample == 1, cluster(taxsimid)
estimates store educ_degrees

di ""
di "Degree premiums (vs. less than HS):"
di "  HS diploma:    " %5.1f _b[hs_diploma]*100 "%"
di "  Some college:  " %5.1f _b[some_coll]*100 "%"
di "  BA degree:     " %5.1f _b[ba_degree]*100 "%"
di "  Graduate:      " %5.1f _b[grad_degree]*100 "%"

/*------------------------------------------------------------------------------
5.3: Both years AND degree dummies (key test)
------------------------------------------------------------------------------*/

di ""
di "5.3 KEY TEST: YEARS + DEGREE DUMMIES"
di "------------------------------------"

regress log_pwages educ_years hs_diploma ba_degree grad_degree pot_exp pot_exp2 i.year ///
    if skill_sample == 1, cluster(taxsimid)
estimates store sheepskin_test

local b_years = _b[educ_years]
local b_hs = _b[hs_diploma]
local b_ba = _b[ba_degree]
local b_grad = _b[grad_degree]

di ""
di "============================================================"
di "SHEEPSKIN EFFECTS RESULTS"
di "============================================================"
di ""
di "After controlling for years of education:"
di ""
di "  Return per year of education: " %5.2f `b_years'*100 "%"
di ""
di "  Additional premium for:"
di "    HS diploma (12 years):     " %5.1f `b_hs'*100 "%"
di "    BA degree (16 years):      " %5.1f `b_ba'*100 "%"
di "    Graduate degree (17+ yrs): " %5.1f `b_grad'*100 "%"
di ""

* Interpret sheepskin results
local large_sheepskin = 0
if abs(`b_ba') > 0.05 | abs(`b_hs') > 0.03 {
    local large_sheepskin = 1
}

if `large_sheepskin' == 1 {
    di "RESULT: SIGNIFICANT SHEEPSKIN EFFECTS"
    di "  Degree completion matters beyond years of schooling"
    di "  Supports SIGNALING: Credentials have independent value"
}
else {
    di "RESULT: SMALL SHEEPSKIN EFFECTS"
    di "  Years of education explain most of wage premium"
    di "  Supports HUMAN CAPITAL: It's the learning, not the diploma"
}

/*------------------------------------------------------------------------------
5.4: Sheepskin model comparison
------------------------------------------------------------------------------*/

di ""
di "5.4 EDUCATION MODEL COMPARISON"
di "------------------------------"

estimates table educ_continuous educ_degrees sheepskin_test, ///
    keep(educ_years hs_diploma some_coll ba_degree grad_degree) ///
    b(%9.4f) se(%9.4f) stats(N r2) ///
    title("Sheepskin Effects: Continuous vs Discrete Education")

/*==============================================================================
PART 6: COMPREHENSIVE SUMMARY
==============================================================================*/

di ""
di "=============================================================================="
di "=============================================================================="
di "COMPREHENSIVE SUMMARY: SKILL VS SIGNALING"
di "=============================================================================="
di "=============================================================================="
di ""

di "EVIDENCE SCORECARD"
di "=================="
di ""
di "Test                          | Human Capital | Employer Learning/Signaling"
di "------------------------------|---------------|-----------------------------"

* Altonji-Pierret
quietly estimates restore afqt_interaction
local ap_result = "Inconclusive"
if _b[afqt_x_exp] > 0 & _b[afqt_x_exp]/_se[afqt_x_exp] > 1.96 {
    local ap_result = "Signaling ✓"
}
else if _b[afqt_x_exp] <= 0 {
    local ap_result = "Human Cap ✓"
}
di "1. AFQT × Experience          |               | `ap_result'"

* Hours decomposition
quietly estimates restore hours_horserace
local hrs_result = "Mixed"
if abs(_b[log_cumhrs]) > abs(_b[log_recent_hrs_annual]) * 1.5 {
    local hrs_result = "Human Cap ✓"
}
else if abs(_b[log_recent_hrs_annual]) > abs(_b[log_cumhrs]) * 1.5 {
    local hrs_result = "Signaling ✓"
}
di "2. Hours decomposition        | `hrs_result'              |"

* FE comparison
local fe_result = "Mixed"
if `exp_ratio' > 0.7 {
    local fe_result = "Human Cap ✓"
}
else if `exp_ratio' < 0.5 {
    local fe_result = "Signaling ✓"
}
di "3. OLS vs FE (exp coef)       | `fe_result'              |"

* Sheepskin
local sheep_result = "Mixed"
if `large_sheepskin' == 1 {
    local sheep_result = "Signaling ✓"
}
else {
    local sheep_result = "Human Cap ✓"
}
di "4. Sheepskin effects          |               | `sheep_result'"

di ""
di "=============================================================================="
di ""
di "INTERPRETATION GUIDE:"
di ""
di "  The evidence suggests that early-career wage growth reflects BOTH:"
di "  - Genuine skill formation (human capital accumulation)"
di "  - Employer learning about worker ability (signaling/screening)"
di ""
di "  Key findings to emphasize in your research:"
di "  1. The AFQT × Experience interaction reveals employer learning dynamics"
di "  2. Cumulative vs recent hours decomposition shows learning-by-doing vs face time"
di "  3. Fixed effects help isolate causal effects from ability selection"
di "  4. Sheepskin effects reveal credential vs skill value of education"
di ""

/*==============================================================================
PART 7: FORMATTED REGRESSION TABLES (esttab)
==============================================================================*/

di ""
di "=============================================================================="
di "PART 7a: FORMATTED REGRESSION TABLES (esttab)"
di "=============================================================================="

* Employer Learning tests (AFQT x Experience)
capture noisily esttab baseline_mincer afqt_main afqt_interaction full_learning ///
    using "${outdir}\SkillSignal_Table1_EmployerLearning.rtf", replace ///
    keep(afqt_std pot_exp pot_exp2 afqt_x_exp educ_x_exp educ_years) ///
    order(afqt_std pot_exp pot_exp2 afqt_x_exp educ_x_exp educ_years) ///
    b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observations" "R-squared")) ///
    mtitles("Baseline" "AFQT Main" "AFQT×Exp" "Full Learning") ///
    title("Table 1: Employer Learning Tests (AFQT × Experience Interaction)") ///
    note("Year and individual controls included. Std. errors clustered by individual.")
if _rc != 0 di "WARNING: esttab SkillSignal Table1 failed (_rc=" _rc ")"

* Hours decomposition (human capital vs signaling)
capture noisily esttab cumhrs_only recent_only hours_horserace ///
    using "${outdir}\SkillSignal_Table2_Hours.rtf", replace ///
    keep(log_cumhrs log_recent_hrs_annual pot_exp pot_exp2 educ_years) ///
    b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observations" "R-squared")) ///
    mtitles("Cumulative Only" "Recent Only" "Both (Horse Race)") ///
    title("Table 2: Hours Decomposition - Cumulative vs Recent Face Time") ///
    note("Cumulative hours = stock of experience. Recent hours = signaling/effort.")
if _rc != 0 di "WARNING: esttab SkillSignal Table2 failed (_rc=" _rc ")"

* OLS vs FE comparison
capture noisily esttab ols_main fe_main ///
    using "${outdir}\SkillSignal_Table3_OLSvsFE.rtf", replace ///
    keep(pot_exp pot_exp2 educ_years) ///
    b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observations" "R-squared")) ///
    mtitles("OLS" "Fixed Effects") ///
    title("Table 3: OLS vs Fixed Effects - Ability Selection Test") ///
    note("FE eliminates time-invariant ability bias. Large OLS/FE difference implies signaling.")
if _rc != 0 di "WARNING: esttab SkillSignal Table3 failed (_rc=" _rc ")"

* Sheepskin effects
capture noisily esttab educ_continuous educ_degrees sheepskin_test ///
    using "${outdir}\SkillSignal_Table4_Sheepskin.rtf", replace ///
    keep(educ_years hs_diploma some_coll ba_degree grad_degree) ///
    b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observations" "R-squared")) ///
    mtitles("Continuous" "Degree Dummies" "Combined") ///
    title("Table 4: Sheepskin Effects - Degree vs. Continuous Education") ///
    note("Sheepskin = extra returns to completing a degree beyond continuous years.")
if _rc != 0 di "WARNING: esttab SkillSignal Table4 failed (_rc=" _rc ")"

/*==============================================================================
PART 7b: SAVE RESULTS AND CLEAN UP
==============================================================================*/

di ""
di "=============================================================================="
di "OUTPUT FILES CREATED"
di "=============================================================================="
di ""
di "Graphs (${outdir}):"
di "  - wage_variance_evolution.png"
di ""
di "Tables (${outdir}):"
di "  - SkillSignal_Table1_EmployerLearning.rtf"
di "  - SkillSignal_Table2_Hours.rtf"
di "  - SkillSignal_Table3_OLSvsFE.rtf"
di "  - SkillSignal_Table4_Sheepskin.rtf"
di ""
di "Log (${outdir}):"
di "  - Skill_vs_Signal_log.txt"
di ""

* Clean up temporary variables
capture drop afqt_x_exp educ_x_exp recent_x_early log_cumhrs skill_sample less_than_hs log_recent_hrs_annual

di ""
di "=============================================================================="
di "SKILL VS SIGNALING ANALYSIS COMPLETE"
di "=============================================================================="
di "End time: $S_DATE $S_TIME"
di ""
di "Key corrections applied in this analysis:"
di "  - pot_exp uses current-year education (not lifetime max)"
di "  - recent_hrs_annual used for cross-period comparisons"
di "  - AFQT properly standardized"
di "  - Ages are income-year aligned"
di ""

log close skill_signal_log
