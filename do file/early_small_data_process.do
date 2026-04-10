clear all
set more off

* 1) Import Base Data
import delimited "NLSY_All_Data.csv", varnames(1) clear
rename r0000100 taxsimid
save "base_data.dta", replace

* 2) Import Left-Out Variables
import delimited "left_out.csv", varnames(1) clear
rename r0000100 taxsimid
save "left_out.dta", replace

* 3) Merge
use "base_data.dta", clear
merge 1:1 taxsimid using "left_out.dta"
drop _merge

rename r2870900 mstat_1988
rename r3074600 mstat_1989
rename r3401300 mstat_1990
rename r3656700 mstat_1991
rename r4007200 mstat_1992
rename r4418300 mstat_1993
rename r5081300 mstat_1994

* Age (Page)
rename r2871300 page_1988
rename r3075000 page_1989
rename r3401700 page_1990
rename r3657100 page_1991
rename r4007600 page_1992
rename r4418700 page_1993
rename r5081700 page_1994

* Dependents (Depx)
rename r2877600 depx_1988
rename r3076842 depx_1989
rename r3407700 depx_1990
rename r3659047 depx_1991
rename r4009447 depx_1992
rename r4444700 depx_1993
rename r5087500 depx_1994

* Wages (Primary)
rename r2722501 pwages_1988
rename r2971401 pwages_1989
rename r3279401 pwages_1990
rename r3559001 pwages_1991
rename r3897101 pwages_1992
rename r4295101 pwages_1993
rename r4982801 pwages_1994

* Wages (Spouse)
rename r2724701 swages_1988
rename r2973601 swages_1989
rename r3281601 swages_1990
rename r3561201 swages_1991
rename r3899301 swages_1992
rename r4314401 swages_1993
rename r4996001 swages_1994

* Self-Employment (Primary)
rename r2722801 psemp_1988
rename r2971701 psemp_1989
rename r3279701 psemp_1990
rename r3559301 psemp_1991
rename r3897401 psemp_1992
rename r4295501 psemp_1993
rename r4983201 psemp_1994

* Self-Employment (Spouse)
rename r2725001 ssemp_1988
rename r2973901 ssemp_1989
rename r3281901 ssemp_1990
rename r3561501 ssemp_1991
rename r3899601 ssemp_1992
rename r4314901 ssemp_1993
rename r4996601 ssemp_1994

* Unemployment (UI)
rename g0079400 unemp_1988
rename g0087200 unemp_1989
rename g0095000 unemp_1990
rename g0102800 unemp_1991
rename g0110600 unemp_1992
rename g0118400 unemp_1993
rename g0119700 unemp_1994

rename g0080700 sui_1988
rename g0088500 sui_1989
rename g0096300 sui_1990
rename g0104100 sui_1991
rename g0111900 sui_1992
rename g0121000 sui_1993
rename g0122300 sui_1994

* Social Security (GSSI)
rename g0084600 gssi_1988
rename g0092400 gssi_1989
rename g0100200 gssi_1990
rename g0108000 gssi_1991
rename g0115800 gssi_1992
rename g0128800 gssi_1993
rename g0130100 gssi_1994

* ------------------------------------------------------------------------------
* RESTORED VARIABLES (1988-1994 Only)
* ------------------------------------------------------------------------------

* 1. Veteran Benefits (VetBen)
rename r2980900 vetben_1988 
rename r3290200 vetben_1989 
rename r3569800 vetben_1990 
rename r3907900 vetben_1991 
rename r4388300 vetben_1992 
rename r5044500 vetben_1993 
* 1994 missing, will zero-fill later

* 2. Mortgage Interest (Consistent in this period)
rename r2735801 mortgage_1988
rename r2983301 mortgage_1989
rename r3293701 mortgage_1990
* 1991 Missing in raw data
rename r3911401 mortgage_1992
rename r4392701 mortgage_1993
rename r5047001 mortgage_1994

* 3. AFDC & Food Stamps (For Transfers)
rename g0082000 afdc_1988
rename g0089800 afdc_1989
rename g0097600 afdc_1990
rename g0105400 afdc_1991
rename g0113200 afdc_1992
rename g0123600 afdc_1993
rename g0124900 afdc_1994

rename g0083300 foodstamp_1988
rename g0091100 foodstamp_1989
rename g0098900 foodstamp_1990
rename g0106700 foodstamp_1991
rename g0114500 foodstamp_1992
rename g0126200 foodstamp_1993
rename g0127500 foodstamp_1994

* Construct Transfers (Including VetBen where possible)
forvalues y = 1988/1993 {
    capture confirm variable vetben_`y'
    if _rc == 0 {
        gen transfers_`y' = afdc_`y' + foodstamp_`y' + vetben_`y'
    }
    else {
        gen transfers_`y' = afdc_`y' + foodstamp_`y'
    }
}
gen transfers_1994 = afdc_1994 + foodstamp_1994
drop afdc_* foodstamp_* vetben_*

* 4. Dividend & Interest Proxies
* These raw variables actually exist for this period!
gen dividends_1988 = r2722501 * 0.045
gen dividends_1989 = r2971401 * 0.045
gen dividends_1990 = r3279401 * 0.045
* 1991 Missing
gen dividends_1992 = r3897101 * 0.045
gen dividends_1993 = r4295101 * 0.045
gen dividends_1994 = r4982801 * 0.045

gen intrec_1988 = r2722501 * 0.03
gen intrec_1989 = r2971401 * 0.03
gen intrec_1990 = r3279401 * 0.03
* 1991 Missing
gen intrec_1992 = r3897101 * 0.03
gen intrec_1993 = r4295101 * 0.03
gen intrec_1994 = r4982801 * 0.03

* Drop source vars to clean up
capture drop r2722501 r2971401 r3279401 r3897101 r4295101 r4982801

* Birth Dates (Use 1994 base)
rename r4506800 spomonth_1994
rename r4506801 spoyear_1994
rename r5083601 child1month_1994
rename r5083602 child1year_1994
rename r5084101 child2month_1994
rename r5084102 child2year_1994
rename r5084601 child3month_1994
rename r5084602 child3year_1994

* ------------------------------------------------------------------------------
* RESHAPE & PANEL SETUP (1988-1994 ONLY)
* ------------------------------------------------------------------------------

keep taxsimid *_1988 *_1989 *_1990 *_1991 *_1992 *_1993 *_1994

reshape long mstat_ page_ depx_ pwages_ swages_ psemp_ ssemp_ unemp_ sui_ gssi_ transfers_ mortgage_ dividends_ intrec_ spomonth_ spoyear_ child1month_ child1year_ child2month_ child2year_ child3month_ child3year_, i(taxsimid) j(year)

keep if year >= 1988 & year <= 1994

* Construct Ages
gen refdate    = mdy(7,1,year)
gen dob_spouse = mdy(spomonth_,  1, spoyear_)
gen dob_c1     = mdy(child1month_, 1, child1year_)
gen dob_c2     = mdy(child2month_, 1, child2year_)
gen dob_c3     = mdy(child3month_, 1, child3year_)

gen sage = floor((refdate - dob_spouse)/365.25)
gen age1 = floor((refdate - dob_c1    )/365.25)
gen age2 = floor((refdate - dob_c2    )/365.25)
gen age3 = floor((refdate - dob_c3    )/365.25)

replace sage = 0 if sage < 0 | missing(sage)
foreach a of varlist age1 age2 age3 {
    replace `a' = 0 if `a' < 0 | missing(`a')
}

* Rename to TAXSIM Inputs
rename unemp_     pui
rename sui_       sui
rename pwages_    pwages
rename swages_    swages
rename psemp_     psemp
rename ssemp_     ssemp
rename gssi_      gssi
rename transfers_ transfers
rename mortgage_  mortgage
rename dividends_ dividends
rename intrec_    intrec
rename mstat_     mstat
rename page_      page
rename depx_      depx

* Fill Dependents Logic
gen dep13 = 0
gen dep17 = 0
gen dep18 = 0
foreach a in age1 age2 age3 {
    replace dep13 = dep13 + (`a' < 13)
    replace dep17 = dep17 + (`a' < 17)
    replace dep18 = dep18 + (`a' < 18)
}
replace depx = dep18 if dep18 > depx

* Zero-fill Missing Financials
foreach v in pui sui pwages swages psemp ssemp gssi transfers mortgage dividends intrec {
    replace `v' = 0 if missing(`v')
}

* Mstat Fix
replace mstat = 1 if missing(mstat) | mstat < 1
replace mstat = 2 if mstat == 2
replace sage = 0 if mstat != 2
replace swages = 0 if mstat != 2

* Placeholder Vars for TAXSIM
gen double ui = pui
gen stcg = 0
gen ltcg = 0
gen proptax = 0
gen otheritem = 0
gen childcare = 0

save "nlsy_short_pre_taxsim.dta", replace

* ------------------------------------------------------------------------------
* RUN TAXSIM (Short Panel)
* ------------------------------------------------------------------------------
taxsimlocal35, replace
save "taxsim_out_short_nominal.dta", replace

use "taxsim_out_short_nominal.dta", clear
rename fiitax tax_fed
rename siitax tax_st
rename fica   tax_payroll
rename frate  mtr_fed
rename srate  mtr_st

* ------------------------------------------------------------------------------
* FORWARD t+2 LOGIC (Annual Data)
* ------------------------------------------------------------------------------

* Merge CPI
use "BLS_CPI.dta", clear
keep year CPI
sort year
save "cpi_temp.dta", replace

use "taxsim_out_short_nominal.dta", clear
merge m:1 year using "cpi_temp.dta", keep(match master) nogen
rename CPI cpi_current

* Create Lead CPI (t+2)
gen year_lead2 = year + 2
rename year year_original
rename year_lead2 year
merge m:1 year using "cpi_temp.dta", keep(match master) keepusing(CPI)
rename CPI cpi_lead2
drop _merge
rename year year_lead2
rename year_original year

gen cpi_adjustment = cpi_current / cpi_lead2
replace cpi_adjustment = . if missing(cpi_lead2)

save "taxsim_short_cpi.dta", replace

* Create Lead Income (t+2)
use "nlsy_short_pre_taxsim.dta", clear
sort taxsimid year
local dollar_vars pwages swages psemp ssemp pui sui gssi transfers mortgage dividends intrec

foreach var of local dollar_vars {
    by taxsimid: gen `var'_lead2 = `var'[_n+2]
    replace `var'_lead2 = . if `var'_lead2 == .
}
save "nlsy_short_leads.dta", replace

* Counterfactual Construction
use "nlsy_short_leads.dta", clear
merge m:1 year using "cpi_temp.dta", keep(match master) nogen
rename CPI cpi_current
gen year_lead2 = year + 2
rename year year_original
rename year_lead2 year
merge m:1 year using "cpi_temp.dta", keep(match master) keepusing(CPI)
rename CPI cpi_lead2
drop _merge
rename year year_lead2
rename year_original year
gen cpi_adjustment = cpi_current / cpi_lead2

foreach var of local dollar_vars {
    gen `var'_cf = `var'_lead2 * cpi_adjustment
    replace `var'_cf = . if missing(`var'_lead2)
}

* Preserve/Run Counterfactual TAXSIM
preserve
drop if missing(cpi_adjustment)
foreach var of local dollar_vars {
    replace `var' = `var'_cf
}
replace ui = pui
save "nlsy_short_cf_taxsim.dta", replace
taxsimlocal35, replace
save "taxsim_out_short_cf.dta", replace
restore

* CALCULATE CHANGES & SUMMARY
use "taxsim_short_cpi.dta", clear
rename mtr_fed mtr_fed_actual
rename tax_fed tax_fed_actual
rename tax_st tax_st_actual
rename tax_payroll tax_payroll_actual

merge 1:1 taxsimid year using "taxsim_out_short_cf.dta"
keep if _merge == 3
drop _merge

rename fiitax tax_fed_cf
rename siitax tax_st_cf
rename fica tax_payroll_cf
rename frate mtr_fed_cf

gen change_tax_total = (tax_fed_actual + tax_st_actual + tax_payroll_actual) - ///
                       (tax_fed_cf + tax_st_cf + tax_payroll_cf)

label variable change_tax_total "Tax Shock (Actual - Future t+2)"

* Summary Stats
tabstat change_tax_total, by(year) format(%9.2f)
