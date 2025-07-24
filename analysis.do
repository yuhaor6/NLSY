********************************************************************************
* analysis.do
********************************************************************************

* 0) set up
capture log close
log using analysis.log, text replace
clear all
set more off

* adjust this path to wherever you keep your data
cd "/Users/yuhaoren/Downloads/Signling_Research_Project_Data/nlsy79_94_00_small"

**************************************************
* 1) build long panel of demographics + hours
**************************************************
import delimited "nlsy79_small_demographic.csv", ///
    varnames(1) clear

* rename for clarity
rename r0000100 taxsimid
rename r0017300 grade
rename r061830  AFQT
rename r5081800 hrs_1994
rename r5167100 hrs_1996
rename r6479900 hrs_1998
rename r7007600 hrs_2000

* reshape to long
reshape long hrs_, i(taxsimid) j(year)
keep if inlist(year,1994,1996,1998,2000)

replace hrs_ = 0 if hrs_ < 0

bysort taxsimid: assert grade == grade[1]
bysort taxsimid: assert AFQT  == AFQT[1]

* save for merge
save "nlsy79_demo_hours.dta", replace

**************************************************
* 2) load deflated inputs + merge in demo & hours
**************************************************
use "nlsy_long_deflated.dta", clear

merge 1:1 taxsimid year using "nlsy79_demo_hours.dta"
assert _merge==3
drop _merge

**************************************************
* 3) merge in nominal‐rate TaxSim results
**************************************************
merge 1:1 taxsimid year using "taxsim_out_nominal.dta"
assert _merge==3
drop _merge

* after this we have:
*  mtr_fed   = federal marginal rate
*  mtr_st    = state marginal rate
*  fica_rt   = total payroll marginal rate

**************************************************
* 4) merge in fixed‑real ("hidden") TaxSim rates
**************************************************

merge 1:1 taxsimid year using "taxsim_out_fixedreal.dta", ///
    keepusing(mtr_fed_fix mtr_st_fix fica_rt_fix)
assert _merge==3
drop _merge

**************************************************
* 5) label & build demographics
**************************************************
rename r021470 race
rename r021480 sex

label define race 1 "Hispanic"   ///
              2 "Black"        ///
              3 "Non‐Black, Non‐Hispanic"
label values race race

label define sex 1 "Male" 2 "Female"
label values sex sex

gen byte female     = (sex==2)
label variable female "female = 1 if respondent is female"

gen byte highschool = (grade >= 12)
gen byte college    = (grade >= 16)

**************************************************
* 6) set panel & create log‐hours outcome
**************************************************
xtset taxsimid year
gen lnH = ln( hrs_ + 1 )   // ln(1 + hours): zero‐hours → 0

**************************************************
* 7) build net‑of‑tax shares & instrument
**************************************************
* actual net‑of‑tax share
gen nsh     = 1 - (mtr_fed + mtr_st + fica_rt)

* hidden (fixed‑real) net‑of‑tax share
gen nsh_h   = 1 - (mtr_fed_fix + mtr_st_fix + fica_rt_fix)

* logs
gen ln_nsh     = ln(nsh)
gen ln_nsh_h   = ln(nsh_h)

* simulated IV = Δ ln(1–τ_it) from policy change alone
gen Dln_nsh_sim = ln_nsh_h - ln_nsh

**************************************************
* 8) diagnostic: first‐stage F
**************************************************
xtreg ln_nsh ln_nsh_h i.year, fe cluster(taxsimid)
test ln_nsh_h

**************************************************
* 9) Model 1: intensive‐margin FE–IV
**************************************************
xtivreg lnH ///
    (ln_nsh = Dln_nsh_sim) ///
    i.year             /// calendar‑year FEs only
  , fe vce(cluster taxsimid)

* tidy up
estimates store iv_model1

**************************************************
* 10) compare to OLS FE
**************************************************
* OLS: ΔlnH on Δln(1–τ)
xtreg lnH ln_nsh i.year, fe vce(cluster taxsimid)
estimates store ols

* IV: instrument Δln(1–τ) with Δln(1–τ)_sim
xtivreg lnH (ln_nsh = Dln_nsh_sim) i.year, fe vce(cluster taxsimid)
estimates store iv

esttab ols iv using ols_vs_iv.rtf, ///
    b(3) se(2) ///
    title("OLS vs. IV: Intensive‐Margin Elasticity") replace


capture log close

// ——————————————
// Diagnostics by gender & age bins
// ——————————————

// 1) setup age
rename page age
label variable age "Age in survey year"

// 2) set up age bins
gen byte age25_34 = inrange(age,25,34)
gen byte age35_44 = inrange(age,35,44)
gen byte age45_64 = inrange(age,45,64)

gen byte agebin = .
replace agebin = 1 if age25_34
replace agebin = 2 if age35_44
replace agebin = 3 if age45_64
label define agelab 1 "25–34" 2 "35–44" 3 "45–64"
label values agebin agelab

// 3) Loop over gender
display as text _newline "======================================"
display as text " FIRST‐STAGE by gender (FE) "
display as text "======================================"
foreach g in 0 1 {
    local lab = cond(`g'==1, "Female", "Male")
    display as text _newline "---- `lab' sample ----"
    quietly xtreg ln_nsh ln_nsh_h i.year if female==`g', fe cluster(taxsimid)
    test ln_nsh_h
    display as text "--------------------------------------"
}

// 4) Loop over age bins
display as text _newline "======================================"
display as text " FIRST‐STAGE by age bin (FE) "
display as text "======================================"
levelsof agebin if !missing(agebin), local(bins)
foreach b of local bins {
    local desc : label agelab `b'
    display as text _newline "---- Age bin: `desc' ----"
    quietly xtreg ln_nsh ln_nsh_h i.year if agebin==`b', fe cluster(taxsimid)
    test ln_nsh_h
    display as text "--------------------------------------"
}

