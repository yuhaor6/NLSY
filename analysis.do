*------------------------------------------------------------------------------
* analysis.do  
*------------------------------------------------------------------------------

capture log close
log using analysis.log, text replace

clear all
set more off

*-----------------------------------------
* 0) build a long‐panel of demo + hours
*-----------------------------------------
import delimited "nlsy79_small_demographic.csv", varnames(1) clear
rename r0000100 taxsimid
rename r0017300 grade
rename r061830  AFQT
rename r5081800 hrs_1994
rename r5167100 hrs_1996
rename r6479900 hrs_1998
rename r7007600 hrs_2000

reshape long hrs_, i(taxsimid) j(year)
keep if inlist(year,1994,1996,1998,2000)

bysort taxsimid: assert grade == grade[1]
bysort taxsimid: assert AFQT  == AFQT[1]

save "nlsy79_demo_hours.dta", replace


*-----------------------------------------
* 1) load deflated panel
*-----------------------------------------
use "nlsy_long_deflated.dta", clear


*-----------------------------------------
* 2) merge in demo + hours
*-----------------------------------------
merge 1:1 taxsimid year using "nlsy79_demo_hours.dta"
assert _merge==3
drop _merge


*-----------------------------------------
* 3) merge in nominal‐run TaxSim results
*-----------------------------------------
merge 1:1 taxsimid year using "taxsim_out_nominal.dta"
assert _merge==3
drop _merge


*-----------------------------------------
* 4) merge in fixed‐real TaxSim rates("hidden" instrument)
*-----------------------------------------
merge 1:1 taxsimid year using "taxsim_out_fixedreal.dta", ///
    keepusing(mtr_fed_fix mtr_st_fix fica_rt_fix)
assert _merge==3
drop _merge


*-----------------------------------------
* 5) label & build demographics
*-----------------------------------------
rename r021470 race
rename r021480 sex

label define race 1 "Hispanic" 2 "Black" 3 "Non‐Black, Non‐Hispanic"
label values race race

label define sex 1 "Male" 2 "Female"
label values sex sex

gen byte female     = (sex==2)
label variable female "female = 1 if respondent is female"

gen byte highschool = (grade >= 12)
gen byte college    = (grade >= 16)


*-----------------------------------------
* 6) set panel & create log‐hours
*-----------------------------------------
xtset taxsimid year
gen lnH = ln(hrs_ + 1)    // ln(1+hrs), so zero‐hours → 0


*-----------------------------------------
* 7) build net‐of‐tax shares & instrument
*-----------------------------------------
gen nsh   = 1 - (mtr_fed   + mtr_st   + fica_rt)
gen nsh_h = 1 - (mtr_fed_fix + mtr_st_fix + fica_rt_fix)

gen ln_nsh   = ln(nsh)
gen ln_nsh_h = ln(nsh_h)


*-----------------------------------------
* 8) Model 1: intensive‐margin FE–IV
*     outcome: lnH
*     endogenous: ln_nsh
*     instrument: ln_nsh_h
*     controls: calendar‐year FEs, grade, AFQT, race, female
*-----------------------------------------
xtivreg lnH ///
    (ln_nsh = ln_nsh_h) ///
    i.year       /// calendar‐year fixed effects
    c.grade c.AFQT ///
    i.race  i.female,  ///
    fe vce(cluster taxsimid)
