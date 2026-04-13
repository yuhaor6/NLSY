* Sector_Heterogeneity_Analysis.do
* Estimates gamma and Altonji-Pierret employer-learning coefficients
* separately by occupation and industry groups.
* Tests whether signaling intensity varies by sector (e.g. finance vs mfg).
* Restricted to 1979-1993 (when occ/ind codes are available).
* Input:  data/nlsy_long_pre_taxsim.dta, data/merged_data_with_occind.dta
* Output: Phase4 tables/figures

clear all
set more off
capture log close _all

global projdir "D:\Stata Data\labor_signaling_project"
global datadir "${projdir}\data"
global outdir  "${projdir}\output"

log using "${outdir}\Sector_Heterogeneity_log.txt", replace text

di ""
di "=============================================================================="
di "SECTOR HETEROGENEITY IN SIGNALING (PHASE 4)"
di "=============================================================================="
di "Test: Do returns to cumhrs and employer-learning vary by occupation/industry?"
di "Framework: Cross-sector extension of Sztutman (2024)"
di "Start time: $S_DATE $S_TIME"
di ""

* --- Part 0: LOAD DATA AND DEFINE SAMPLE ---

di "=============================================================================="
di "PART 0: DATA SETUP"
di "=============================================================================="

capture confirm file "${datadir}\eda_deepdive_data.dta"
if _rc != 0 {
    di as error "ERROR: eda_deepdive_data.dta not found."
    di as error "  Run EDA_DeepDive_OccInd.do first."
    log close
    error 601
}

use "${datadir}\eda_deepdive_data.dta", clear
di "Loaded eda_deepdive_data.dta: " _N " observations"

*--- Restrict to occupation/industry analysis window (1979-1993) ---
keep if year >= 1979 & year <= 1993
di "After restricting to 1979-1993: " _N " observations"

*--- Variable checks ---
foreach v in pwages cumhrs pot_exp occ_broad ind_broad afqt_std log_pwages log_cumhrs {
    capture confirm variable `v'
    if _rc != 0 {
        di as error "ERROR: `v' not found in eda_deepdive_data.dta"
        log close
        error 111
    }
}
di "Required variables confirmed."
di ""

*--- Create pot_exp2 if not present ---
capture confirm variable pot_exp2
if _rc != 0 {
    gen pot_exp2 = pot_exp^2
    label var pot_exp2 "Potential experience squared"
}

*--- Analysis sample ---
capture drop phase4_sample
gen phase4_sample = (wage_sample == 1       ///
                   & !missing(occ_broad)    ///
                   & !missing(ind_broad)    ///
                   & !missing(afqt_std)     ///
                   & cumhrs > 0             ///
                   & !missing(pot_exp)      ///
                   & pot_exp >= 0           ///
                   & pot_exp <= 40)
label var phase4_sample "Phase 4 analysis sample (occ/ind window)"

di "Sample summary:"
tab phase4_sample
di ""
count if phase4_sample == 1 & !missing(occ_broad)
di "Phase 4 sample with occ/ind: " r(N) " person-years"
di ""

*--- Set panel structure ---
xtset taxsimid year

*--- Signaling intensity classification (a priori based on theory) ---
* High signaling: Professional, Managerial, Finance, Business Svcs, Prof Svcs
* Low signaling: Operatives, Laborers, Farm, Manufacturing, Agriculture

capture drop signal_occ
gen signal_occ = "Medium"
replace signal_occ = "High"  if inlist(occ_broad, 1, 2)   // Professional, Managers
replace signal_occ = "Low"   if inlist(occ_broad, 7, 8)   // Laborers, Farm Workers
label var signal_occ "A priori signaling intensity by occupation"

capture drop signal_ind
gen signal_ind = "Medium"
replace signal_ind = "High" if inlist(ind_broad, 7, 8, 11)   // Finance, BusSvcs, ProfSvcs
replace signal_ind = "Low"  if inlist(ind_broad, 1, 4)        // Agriculture, Manufacturing
label var signal_ind "A priori signaling intensity by industry"

di "A priori signaling classification:"
di "  Occupation — High: Professional (1), Managers (2)"
di "                Low: Laborers (7), Farm Workers (8)"
di "  Industry   — High: Finance (7), Business Svcs (8), Prof Svcs (11)"
di "                Low: Agriculture (1), Manufacturing (4)"
di ""

* --- Part 1: γ BY OCCUPATION — γ = ∂log(w) / ∂log(cumhrs)  [FE within-person] ---

di "=============================================================================="
di "PART 1: γ BY OCCUPATION (RETURN TO CUMULATIVE HOURS)"
di "=============================================================================="
di ""
di "Specification: xtreg log_pwages log_cumhrs pot_exp pot_exp2 i.year, fe"
di "               Estimated separately for each broad occupation"
di ""

* Occupation labels
local occ_lbl_1 "Professional/Tech"
local occ_lbl_2 "Managers/Admin"
local occ_lbl_3 "Sales"
local occ_lbl_4 "Clerical"
local occ_lbl_5 "Craftsmen"
local occ_lbl_6 "Operatives"
local occ_lbl_7 "Laborers"
local occ_lbl_8 "Farm Workers"
local occ_lbl_9 "Service Workers"

di "Occ  Label               N_obs  γ_FE     SE       t     Signal"
di "---- ------------------- ------ -------- -------- ----- ------"

forvalues o = 1/9 {
    qui count if phase4_sample == 1 & occ_broad == `o'
    local n_o = r(N)

    if `n_o' >= 200 {
        xtreg log_pwages log_cumhrs pot_exp pot_exp2 i.year ///
            if phase4_sample == 1 & occ_broad == `o', fe cluster(taxsimid)
        est store fe_occ`o'

        scalar gamma_occ`o' = _b[log_cumhrs]
        scalar se_occ`o'    = _se[log_cumhrs]

        * Determine signal category
        local sig = "Medium"
        if inlist(`o', 1, 2) local sig = "High"
        if inlist(`o', 7, 8) local sig = "Low"

        di "  `o'   " %-19s "`occ_lbl_`o''" " `n_o'  " ///
           %8.4f gamma_occ`o' "  " %6.4f se_occ`o' ///
           "  " %5.2f gamma_occ`o'/se_occ`o' "  `sig'"
    }
    else {
        di "  `o'   " %-19s "`occ_lbl_`o''" " `n_o'  [< 200 obs, skipped]"
        scalar gamma_occ`o' = .
        scalar se_occ`o'    = .
    }
}

di ""
di "Check: High-signaling occ γ > Low-signaling occ γ?"
local high_sig_g = max(gamma_occ1, gamma_occ2)
local low_sig_g  = min(gamma_occ7, gamma_occ8)
if !missing(`high_sig_g') & !missing(`low_sig_g') {
    if `high_sig_g' > `low_sig_g' {
        di "  CONSISTENT: γ_High (" %5.3f `high_sig_g' ") > γ_Low (" %5.3f `low_sig_g' ")"
    }
    else {
        di "  INCONSISTENT: γ_High (" %5.3f `high_sig_g' ") ≤ γ_Low (" %5.3f `low_sig_g' ")"
        di "  This would challenge the sector-specific signaling interpretation"
        di "  Possible explanation: physical skill accumulation in manual work"
    }
}

* --- Part 2: γ BY INDUSTRY ---

di ""
di "=============================================================================="
di "PART 2: γ BY INDUSTRY (RETURN TO CUMULATIVE HOURS)"
di "=============================================================================="
di ""

* Industry labels
local ind_lbl_1  "Agriculture"
local ind_lbl_2  "Mining"
local ind_lbl_3  "Construction"
local ind_lbl_4  "Manufacturing"
local ind_lbl_5  "Transport/Util"
local ind_lbl_6  "Trade"
local ind_lbl_7  "Finance/Ins"
local ind_lbl_8  "Business Svcs"
local ind_lbl_9  "Personal Svcs"
local ind_lbl_10 "Entertainment"
local ind_lbl_11 "Prof Services"
local ind_lbl_12 "Public Admin"

di "Ind  Label               N_obs  γ_FE     SE       t     Signal"
di "---- ------------------- ------ -------- -------- ----- ------"

forvalues i = 1/12 {
    qui count if phase4_sample == 1 & ind_broad == `i'
    local n_i = r(N)

    if `n_i' >= 200 {
        xtreg log_pwages log_cumhrs pot_exp pot_exp2 i.year ///
            if phase4_sample == 1 & ind_broad == `i', fe cluster(taxsimid)
        est store fe_ind`i'

        scalar gamma_ind`i' = _b[log_cumhrs]
        scalar se_ind`i'    = _se[log_cumhrs]

        local sig = "Medium"
        if inlist(`i', 7, 8, 11) local sig = "High"
        if inlist(`i', 1, 4)     local sig = "Low"

        di "  `i'   " %-19s "`ind_lbl_`i''" " `n_i'  " ///
           %8.4f gamma_ind`i' "  " %6.4f se_ind`i' ///
           "  " %5.2f gamma_ind`i'/se_ind`i' "  `sig'"
    }
    else {
        di "  `i'   " %-19s "`ind_lbl_`i''" " `n_i'  [< 200 obs, skipped]"
        scalar gamma_ind`i' = .
        scalar se_ind`i'    = .
    }
}

di ""
di "KEY COMPARISON: Finance vs Manufacturing"
if !missing(gamma_ind7) & !missing(gamma_ind4) {
    di "  Finance (ind 7):       γ = " %7.4f gamma_ind7
    di "  Manufacturing (ind 4): γ = " %7.4f gamma_ind4
    di "  Difference:              " %7.4f gamma_ind7 - gamma_ind4
    if gamma_ind7 > gamma_ind4 {
        di "  CONSISTENT with high signaling in Finance vs. low in Manufacturing"
    }
    else {
        di "  NOTE: γ_Finance ≤ γ_Manufacturing — investigate further"
    }
}

* --- Part 3: ALTONJI-PIERRET TEST BY SECTOR ---

di ""
di "=============================================================================="
di "PART 3: ALTONJI-PIERRET EMPLOYER LEARNING TEST BY SECTOR"
di "=============================================================================="
di ""
di "Specification: OLS (not FE) with AFQT × experience interaction"
di "Note: OLS required because AFQT is time-invariant (absorbed by FE)"
di ""

capture drop afqt_x_exp
gen afqt_x_exp = afqt_std * pot_exp
label var afqt_x_exp "AFQT std × Potential experience"

*--- By occupation ---
di "Altonji-Pierret (AP) slope β(AFQT × exp) by occupation:"
di ""
di "Occ  Label               AP slope  SE        t     Signal"
di "---- ------------------- --------- --------- ----- ------"

forvalues o = 1/9 {
    qui count if phase4_sample == 1 & occ_broad == `o' & !missing(afqt_std)
    local n_o = r(N)

    if `n_o' >= 200 {
        capture confirm variable educ_years
        if _rc == 0 {
            reg log_pwages afqt_std afqt_x_exp pot_exp pot_exp2 educ_years i.year ///
                if phase4_sample == 1 & occ_broad == `o', cluster(taxsimid)
        }
        else {
            reg log_pwages afqt_std afqt_x_exp pot_exp pot_exp2 i.year ///
                if phase4_sample == 1 & occ_broad == `o', cluster(taxsimid)
        }
        est store ap_occ`o'

        scalar ap_occ`o'   = _b[afqt_x_exp]
        scalar apse_occ`o' = _se[afqt_x_exp]

        local sig = "Medium"
        if inlist(`o', 1, 2) local sig = "High"
        if inlist(`o', 7, 8) local sig = "Low"

        di "  `o'   " %-19s "`occ_lbl_`o''" ///
           %9.5f ap_occ`o' "  " %8.5f apse_occ`o' ///
           "  " %5.2f ap_occ`o'/apse_occ`o' "  `sig'"
    }
    else {
        scalar ap_occ`o'   = .
        scalar apse_occ`o' = .
    }
}

di ""
di "Check: High-signaling occ AP slope > Low-signaling?"
if !missing(ap_occ1) & !missing(ap_occ7) {
    if ap_occ1 > ap_occ7 | ap_occ1 > ap_occ8 {
        di "  CONSISTENT: Professional AP slope > Manual workers"
        di "  Evidence for stronger employer learning in professional occupations"
    }
    else {
        di "  INCONSISTENT: AP slopes do not follow signaling prediction"
    }
}

*--- By industry ---
di ""
di "Altonji-Pierret (AP) slope β(AFQT × exp) by industry:"
di ""
di "Ind  Label               AP slope  SE        t     Signal"
di "---- ------------------- --------- --------- ----- ------"

forvalues i = 1/12 {
    qui count if phase4_sample == 1 & ind_broad == `i' & !missing(afqt_std)
    local n_i = r(N)

    if `n_i' >= 200 {
        capture confirm variable educ_years
        if _rc == 0 {
            reg log_pwages afqt_std afqt_x_exp pot_exp pot_exp2 educ_years i.year ///
                if phase4_sample == 1 & ind_broad == `i', cluster(taxsimid)
        }
        else {
            reg log_pwages afqt_std afqt_x_exp pot_exp pot_exp2 i.year ///
                if phase4_sample == 1 & ind_broad == `i', cluster(taxsimid)
        }
        est store ap_ind`i'

        scalar ap_ind`i'   = _b[afqt_x_exp]
        scalar apse_ind`i' = _se[afqt_x_exp]

        local sig = "Medium"
        if inlist(`i', 7, 8, 11) local sig = "High"
        if inlist(`i', 1, 4)     local sig = "Low"

        di "  `i'   " %-19s "`ind_lbl_`i''" ///
           %9.5f ap_ind`i' "  " %8.5f apse_ind`i' ///
           "  " %5.2f ap_ind`i'/apse_ind`i' "  `sig'"
    }
    else {
        scalar ap_ind`i'   = .
        scalar apse_ind`i' = .
    }
}

di ""
di "KEY COMPARISON: Finance vs Manufacturing (employer learning)"
if !missing(ap_ind7) & !missing(ap_ind4) {
    di "  Finance (ind 7):       AP slope = " %8.5f ap_ind7
    di "  Manufacturing (ind 4): AP slope = " %8.5f ap_ind4
    di "  Difference (Finance - Mfg): " %8.5f ap_ind7 - ap_ind4
}

* --- Part 3b: AP ROBUSTNESS — RESTRICT TO 5+ YEARS OCCUPATION TENURE ---

di ""
di "=============================================================================="
di "PART 3b: ALTONJI-PIERRET ROBUSTNESS — 5+ YEAR OCCUPATION TENURE"
di "=============================================================================="
di ""
di "Motivation: Professional/Tech AP slope may be attenuated by short tenure"
di "This spec restricts to workers with >= 5 years in same occupation"
di ""

*--- Create occupation tenure variable ---
* Count total years each person is observed in each occupation (full spell length)
sort taxsimid year
capture drop occ_tenure
bysort taxsimid occ_broad (year): gen occ_tenure = _N
label var occ_tenure "Total years observed in this occupation (per person)"

di "Occupation tenure distribution (phase4_sample):"
sum occ_tenure if phase4_sample == 1, detail
di "Obs with occ_tenure >= 5: "
count if phase4_sample == 1 & occ_tenure >= 5
di ""

*--- AP regression restricted to 5+ year tenure ---
di "AP slope b(AFQT x exp) by occupation -- RESTRICTED to 5+ year tenure:"
di ""
di "Occ  Label               N(>=5yr)  AP slope  SE        t     Signal"
di "---- ------------------- --------- --------- --------- ----- ------"

forvalues o = 1/9 {
    qui count if phase4_sample == 1 & occ_broad == `o' ///
                 & occ_tenure >= 5 & !missing(afqt_std)
    local n_o = r(N)

    if `n_o' >= 200 {
        capture confirm variable educ_years
        if _rc == 0 {
            reg log_pwages afqt_std afqt_x_exp pot_exp pot_exp2 educ_years i.year ///
                if phase4_sample == 1 & occ_broad == `o' & occ_tenure >= 5, ///
                cluster(taxsimid)
        }
        else {
            reg log_pwages afqt_std afqt_x_exp pot_exp pot_exp2 i.year ///
                if phase4_sample == 1 & occ_broad == `o' & occ_tenure >= 5, ///
                cluster(taxsimid)
        }

        scalar ap_occ5yr`o'   = _b[afqt_x_exp]
        scalar apse_occ5yr`o' = _se[afqt_x_exp]

        local sig = "Medium"
        if inlist(`o', 1, 2) local sig = "High"
        if inlist(`o', 7, 8) local sig = "Low"

        di "  `o'   " %-19s "`occ_lbl_`o''" " `n_o'  " ///
           %9.5f ap_occ5yr`o' "  " %8.5f apse_occ5yr`o' ///
           "  " %5.2f ap_occ5yr`o'/apse_occ5yr`o' "  `sig'"
    }
    else {
        di "  `o'   " %-19s "`occ_lbl_`o''" " `n_o'  [< 200 obs with 5+ yr tenure]"
        scalar ap_occ5yr`o'   = .
        scalar apse_occ5yr`o' = .
    }
}

di ""
di "COMPARISON: Full sample vs 5+ year tenure restriction:"
di "  Professional/Tech (theory: High signaling, occ=1)"
if !missing(ap_occ1) & !missing(ap_occ5yr1) {
    di "    Full sample AP slope:     " %8.5f ap_occ1   "  (t = " %5.2f ap_occ1/apse_occ1 ")"
    di "    5+ yr tenure AP slope:    " %8.5f ap_occ5yr1 "  (t = " %5.2f ap_occ5yr1/apse_occ5yr1 ")"
    if ap_occ5yr1 > ap_occ1 {
        di "    EXPECTED: AP slope rises with tenure restriction (more experience variation)"
    }
    else {
        di "    UNEXPECTED: AP slope does NOT rise -- inconsistency may be genuine finding"
    }
}
di "  Laborers (theory: Low signaling, occ=7)"
if !missing(ap_occ7) & !missing(ap_occ5yr7) {
    di "    Full sample AP slope:     " %8.5f ap_occ7   "  (t = " %5.2f ap_occ7/apse_occ7 ")"
    di "    5+ yr tenure AP slope:    " %8.5f ap_occ5yr7 "  (t = " %5.2f ap_occ5yr7/apse_occ5yr7 ")"
}

* --- Part 4: COMBINED SIGNALING RANKING ---

di ""
di "=============================================================================="
di "PART 4: COMBINED SIGNALING RANKING"
di "=============================================================================="
di ""
di "Sectors with HIGH γ AND HIGH AP slope → strongest signaling externality"
di "Sectors with LOW γ AND LOW AP slope  → weakest signaling (human capital)"
di ""

*--- Occupation ranking ---
di "OCCUPATION RANKING (by γ_FE, then AP slope):"
di ""
di "Rank Occ  Label               γ_FE     AP slope  Signal (Theory)"
di "---- ---- ------------------- -------- --------- ---------------"

* Create temporary dataset for ranking
preserve
clear
set obs 9
gen occ_n = _n
gen gamma_v = .
gen ap_v = .
gen occ_label = ""

forvalues o = 1/9 {
    replace gamma_v   = gamma_occ`o'  in `o'
    replace ap_v      = ap_occ`o'     in `o'
    replace occ_label = "`occ_lbl_`o''" in `o'
}

gsort -gamma_v  // Sort by γ descending
gen rank = _n

gen signal_theory = "Medium"
replace signal_theory = "High (pred)" if inlist(occ_n, 1, 2)
replace signal_theory = "Low  (pred)" if inlist(occ_n, 7, 8)

list rank occ_n occ_label gamma_v ap_v signal_theory, clean noobs

export delimited using "${outdir}\Phase4_Table4_SignalingRanking.csv", replace
restore

* --- Part 5: AGGREGATED HIGH vs LOW SIGNALING COMPARISON ---

di ""
di "=============================================================================="
di "PART 5: AGGREGATED HIGH vs LOW SIGNALING COMPARISON"
di "=============================================================================="
di ""

*--- Create aggregated signal group ---
capture drop signal_group
gen signal_group = "Medium"
replace signal_group = "High" if inlist(occ_broad, 1, 2) | inlist(ind_broad, 7, 8, 11)
replace signal_group = "Low"  if inlist(occ_broad, 7, 8) | inlist(ind_broad, 1, 4)
* Prioritize "High" classification
replace signal_group = "High" if (inlist(occ_broad, 1, 2) | inlist(ind_broad, 7, 8, 11)) ///
                                & !(inlist(occ_broad, 7, 8) | inlist(ind_broad, 1, 4))

* Numeric version
capture drop signal_num
gen signal_num = 2 if signal_group == "Medium"
replace signal_num = 3 if signal_group == "High"
replace signal_num = 1 if signal_group == "Low"
label define sig_lbl 1 "Low" 2 "Medium" 3 "High"
label values signal_num sig_lbl

di "Signal group distribution:"
tab signal_num if phase4_sample == 1, missing
di ""

*--- FE γ by signal group ---
di "γ_FE by signaling intensity group:"

foreach g in 1 2 3 {
    local gname "Low"
    if `g' == 2 local gname "Medium"
    if `g' == 3 local gname "High"

    qui count if phase4_sample == 1 & signal_num == `g'
    if r(N) >= 200 {
        xtreg log_pwages log_cumhrs pot_exp pot_exp2 i.year ///
            if phase4_sample == 1 & signal_num == `g', fe cluster(taxsimid)
        est store fe_sig`g'

        di "  `gname' signaling: γ = " %7.4f _b[log_cumhrs] ///
           "  SE = " %6.4f _se[log_cumhrs] ///
           "  t = " %5.2f _b[log_cumhrs]/_se[log_cumhrs]
    }
}

*--- AP slope by signal group ---
di ""
di "Altonji-Pierret slope by signaling group:"

foreach g in 1 2 3 {
    local gname "Low"
    if `g' == 2 local gname "Medium"
    if `g' == 3 local gname "High"

    qui count if phase4_sample == 1 & signal_num == `g' & !missing(afqt_std)
    if r(N) >= 200 {
        capture confirm variable educ_years
        if _rc == 0 {
            reg log_pwages afqt_std afqt_x_exp pot_exp pot_exp2 educ_years i.year ///
                if phase4_sample == 1 & signal_num == `g', cluster(taxsimid)
        }
        else {
            reg log_pwages afqt_std afqt_x_exp pot_exp pot_exp2 i.year ///
                if phase4_sample == 1 & signal_num == `g', cluster(taxsimid)
        }
        est store ap_sig`g'

        di "  `gname' signaling: AP slope = " %9.5f _b[afqt_x_exp] ///
           "  SE = " %8.5f _se[afqt_x_exp]
    }
}

* --- Part 6: OUTPUT — TABLES AND FIGURES ---

di ""
di "=============================================================================="
di "PART 6: OUTPUT"
di "=============================================================================="

*--- Table 1: γ by occupation ---
capture noisily {
    * Collect estimates that exist
    local estlist ""
    forvalues o = 1/9 {
        capture est restore fe_occ`o'
        if _rc == 0 local estlist "`estlist' fe_occ`o'"
    }
    if "`estlist'" != "" {
        esttab `estlist' ///
            using "${outdir}\Phase4_Table1_GammaByOcc.rtf", replace ///
            keep(log_cumhrs pot_exp pot_exp2) ///
            b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
            stats(N r2_w, fmt(%12.0fc %9.3f) labels("Observations" "Within R²")) ///
            title("Table 1: Return to Cumulative Hours γ by Occupation") ///
            note("FE estimator. Clustered SE. 1979-1993 annual period only." ///
                 "Prediction: γ higher in Professional/Managerial (high signaling).")
    }
}
if _rc != 0 di "WARNING: esttab Table1 failed"

*--- Table 2: γ by industry ---
capture noisily {
    local estlist ""
    forvalues i = 1/12 {
        capture est restore fe_ind`i'
        if _rc == 0 local estlist "`estlist' fe_ind`i'"
    }
    if "`estlist'" != "" {
        esttab `estlist' ///
            using "${outdir}\Phase4_Table2_GammaByInd.rtf", replace ///
            keep(log_cumhrs pot_exp pot_exp2) ///
            b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
            stats(N r2_w, fmt(%12.0fc %9.3f) labels("Observations" "Within R²")) ///
            title("Table 2: Return to Cumulative Hours γ by Industry") ///
            note("FE estimator. Key comparison: Finance (high signal) vs Manufacturing (low).")
    }
}
if _rc != 0 di "WARNING: esttab Table2 failed"

*--- Table 3: AP slopes by signal group ---
capture noisily esttab ap_sig1 ap_sig2 ap_sig3 ///
    using "${outdir}\Phase4_Table3_AltonjiPierretBySector.rtf", replace ///
    keep(afqt_std afqt_x_exp pot_exp pot_exp2) ///
    b(%9.5f) se(%9.5f) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observations" "R²")) ///
    mtitles("Low Signal" "Medium Signal" "High Signal") ///
    title("Table 3: Altonji-Pierret Test by Signaling Intensity Group") ///
    note("OLS (not FE — AFQT is time-invariant, absorbed by FE)." ///
         "AFQT × Experience slope = employer learning rate." ///
         "Prediction: High signaling sectors show stronger employer learning.")
if _rc != 0 di "WARNING: esttab Table3 failed"

*--- Figure 1: γ ranking by occupation ---
preserve
clear
set obs 9
gen occ_n = _n
gen gamma_v = .
gen se_v = .
forvalues o = 1/9 {
    replace gamma_v = gamma_occ`o' in `o'
    replace se_v    = se_occ`o'    in `o'
}
gen gamma_lo = gamma_v - 1.96*se_v
gen gamma_hi = gamma_v + 1.96*se_v
gen signal_level = "Medium"
replace signal_level = "High" if inlist(occ_n, 1, 2)
replace signal_level = "Low"  if inlist(occ_n, 7, 8)
gen bar_color = 1
replace bar_color = 2 if signal_level == "High"
replace bar_color = 0 if signal_level == "Low"

gsort -gamma_v
gen rank = _n

twoway ///
    (bar gamma_v rank if signal_level == "High", ///
        barwidth(0.7) fcolor(navy) lcolor(navy)) ///
    (bar gamma_v rank if signal_level == "Medium", ///
        barwidth(0.7) fcolor(gs8) lcolor(gs8)) ///
    (bar gamma_v rank if signal_level == "Low", ///
        barwidth(0.7) fcolor(maroon) lcolor(maroon)) ///
    (rcap gamma_hi gamma_lo rank, lcolor(black) lwidth(medium)), ///
    title("Return to Cumulative Hours γ by Occupation" ///
          "Ranked from Highest to Lowest", size(medium)) ///
    subtitle("High signaling sectors predicted to have higher γ (blue)") ///
    xtitle("Rank (1 = highest return to cumhrs)") ///
    ytitle("{it:γ} = ∂log(wage)/∂log(cumhrs)") ///
    legend(order(1 "High signal (pred)" 2 "Medium signal" 3 "Low signal (pred)") ///
           pos(1) ring(0) rows(3)) ///
    note("FE estimator. 95% CIs shown. 1979-1993 annual sample.")
graph export "${outdir}\Phase4_Fig1_GammaRanking.png", replace width(1400)
restore

*--- Figure 2: AP slope ranking by occupation ---
preserve
clear
set obs 9
gen occ_n = _n
gen ap_v = .
gen apse_v = .
forvalues o = 1/9 {
    replace ap_v   = ap_occ`o'   in `o'
    replace apse_v = apse_occ`o' in `o'
}
gen ap_lo = ap_v - 1.96*apse_v
gen ap_hi = ap_v + 1.96*apse_v
gen signal_level = "Medium"
replace signal_level = "High" if inlist(occ_n, 1, 2)
replace signal_level = "Low"  if inlist(occ_n, 7, 8)

gsort -ap_v
gen rank = _n

twoway ///
    (bar ap_v rank if signal_level == "High", ///
        barwidth(0.7) fcolor(navy) lcolor(navy)) ///
    (bar ap_v rank if signal_level == "Medium", ///
        barwidth(0.7) fcolor(gs8) lcolor(gs8)) ///
    (bar ap_v rank if signal_level == "Low", ///
        barwidth(0.7) fcolor(maroon) lcolor(maroon)) ///
    (rcap ap_hi ap_lo rank, lcolor(black) lwidth(thin)), ///
    yline(0, lcolor(gs10) lpattern(dash)) ///
    title("Employer Learning Rate (AFQT x Experience) by Occupation" ///
          "Ranked from Strongest to Weakest Employer Learning", size(medium)) ///
    subtitle("High signaling sectors predicted to show stronger employer learning") ///
    xtitle("Rank (1 = strongest employer learning)") ///
    ytitle("AP slope = d[AFQT effect]/d[experience]") ///
    legend(order(1 "High signal (pred)" 2 "Medium signal" 3 "Low signal (pred)") ///
           pos(1) ring(0) rows(3)) ///
    note("OLS (AFQT time-invariant). 95% CIs shown. 1979-1993.")
graph export "${outdir}\Phase4_Fig2_APRanking.png", replace width(1400)
restore

* --- Summary ---

di ""
di "=============================================================================="
di "Summary"
di "=============================================================================="
di ""

di "KEY QUESTIONS:"
di ""
di "1. Does γ rank by occupation follow the signaling prediction?"
di "   Professional/Managerial > Clerical > Manual/Farm"
di "   → Check from Part 1 output above"
di ""
di "2. Does AP slope rank follow the signaling prediction?"
di "   Professional > Clerical > Manual (employer learning rate decreasing)"
di "   → Check from Part 3 output above"
di ""
di "3. Is the Finance-Manufacturing gap large in BOTH γ and AP slope?"
di "   Most interpretable sector comparison; both measures should agree"
di ""
di "COMMON FAILURE MODES AND THEIR INTERPRETATIONS:"
di ""
di "  FAILURE: γ_Professional < γ_Manual"
di "   → Human capital accumulation may be faster in manual work (learning-by-doing)"
di "   → Signal: Model may need sector-specific δ that doesn't map 1:1 to occupation"
di ""
di "  FAILURE: AP slope flat across sectors"
di "   → Employer learning may be equally fast everywhere"
di "   → OR: AFQT doesn't capture the relevant ability dimension"
di "   → Check: AP slope in full sample (Skill_vs_Signal_Analysis.do) — if zero there too,"
di "            AFQT is simply not a good proxy for v(θ) in this cohort"
di ""
di "Next steps:"
di ""
di "  IF both γ and AP slope are higher in high-signaling sectors:"
di "  → Strong evidence for sector-heterogeneous signaling externalities"
di "  → Key contribution: optimal Pigouvian tax should vary by sector"
di ""
di "  IF only γ varies (not AP):"
di "  → Returns to experience are sector-specific but may not be signaling"
di "  → Could be human capital accumulation varying by sector"
di "  → Need additional identification to distinguish"
di ""
di "  IF neither varies:"
di "  → Signaling externality is UNIFORM across sectors"
di "  → Simplifies Pigouvian tax: single τ_p across all income types"

di ""
di "=============================================================================="
di "OUTPUT FILES CREATED"
di "=============================================================================="
di ""
di "Tables (${outdir}):"
di "  Phase4_Table1_GammaByOcc.rtf           : γ by occupation"
di "  Phase4_Table2_GammaByInd.rtf           : γ by industry"
di "  Phase4_Table3_AltonjiPierretBySector.rtf: AP slopes by signal group"
di "  Phase4_Table4_SignalingRanking.csv      : Full ranking table"
di ""
di "Figures (${outdir}):"
di "  Phase4_Fig1_GammaRanking.png           : γ ranking by occupation"
di "  Phase4_Fig2_APRanking.png              : AP slope ranking by occupation"
di ""
di "Log (${outdir}):"
di "  Sector_Heterogeneity_log.txt"
di ""
di "=============================================================================="
di "PHASE 4 COMPLETE"
di "=============================================================================="
di "End time: $S_DATE $S_TIME"

* Clean up
capture drop afqt_x_exp phase4_sample signal_occ signal_ind signal_group signal_num

log close
