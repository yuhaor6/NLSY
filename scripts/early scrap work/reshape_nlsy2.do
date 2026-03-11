* reshape_nlsy2.do
cd "/Users/yuhaoren/Downloads/nlsy79_94_00_small"
clear all
set more off

* 1) Import the CSV (one row per person)
import delimited "nlsy79_94_00_small.csv", varnames(1) clear

* 2) Rename the ID
rename r0000100 taxsimid

* 3) Rename wave‐specific vars into *_YYYY stubs
* — Unemployment insurance
rename g0119700 unemp_1994
rename g0135300 unemp_1996
rename g0150900 unemp_1998
rename g0166500 unemp_2000

* Marital status, filing status, dependents
rename r5081300 mstat_1994
rename r5166600 mstat_1996
rename r6479200 mstat_1998
rename r7006900 mstat_2000
* Page
rename r5081700 page_1994
rename r5167000 page_1996
rename r6479800 page_1998
rename r7007500 page_2000
* Depx
rename r5087500 depx_1994
rename r5172800 depx_1996
rename r6486400 depx_1998
rename r7014200 depx_2000

* Wages & salary
rename r4982801 pwages_1994
rename r5626201 pwages_1996
rename r6364601 pwages_1998
rename r6909701 pwages_2000

rename r4996001 swages_1994
rename r5650801 swages_1996
rename r6374901 swages_1998
rename r6917801 swages_2000

* Self‐employment income
rename r4983201 psemp_1994
rename r5626601 psemp_1996
rename r6365001 psemp_1998
rename r6911101 psemp_2000

rename r4996601 ssemp_1994
rename r5651401 ssemp_1996
rename r6375301 ssemp_1998
rename r6919201 ssemp_2000

* Spouse UI
rename g0122300 sui_1994
rename g0137900 sui_1996
rename g0153500 sui_1998
rename g0169100 sui_2000

* — Other property income (only available in '98 & '00 waves here)
rename r6423900 nonprop_1998
rename r6939500 nonprop_2000
gen nonprop_1994 = 0
gen nonprop_1996 = 0

* Gross Social Security
rename g0130100 gssi_1994
rename g0145700 gssi_1996
rename g0161300 gssi_1998
rename g0176900 gssi_2000

* Non-taxable transfers (AFDC + food stamps + vet ben)
gen transfers_1994 = g0124900 + g0127500 + r5044500
gen transfers_1996 = g0140500 + g0143100 + r5725900
gen transfers_1998 = g0156100 + g0158700 + r6424200
gen transfers_2000 = g0171700 + g0174300 + r6939900
drop ///
    g0124900 g0127500 r5044500  ///
    g0140500 g0143100 r5725900  ///
    g0156100 g0158700 r6424200  ///
    g0171700 g0174300 r6939900

*Mortgage interest deductions
rename r5047001 mortgage_1994
rename r5728401 mortgage_1996
rename r6426401 mortgage_1998
rename r6944601 mortgage_2000

* Pension/IRA distributions (taxable)
rename r5047401 pensions_1994
rename r5728801 pensions_1996
rename r6426801 pensions_1998
rename r6945301 pensions_2000

* Dividends (proxy at 3% of market‐value)
gen dividends_1994 = r2736201 * 0.03
gen dividends_1996 = r2983701 * 0.03
gen dividends_1998 = 0
gen dividends_2000 = 0
drop r2736201 r2983701

* Taxable interest (intrec) at 3% of savings‐balance
gen intrec_1994 = r5047201 * 0.03
gen intrec_1996 = r5728601 * 0.03
gen intrec_1998 = r6426601 * 0.03
gen intrec_2000 = r6944801 * 0.03
drop r5047201 r5728601 r6426601 r6944801

*Rent paid (assume zero)
gen rentpaid_1994 = 0
gen rentpaid_1996 = 0
gen rentpaid_1998 = 0
gen rentpaid_2000 = 0

*  Spouse & children DOB (month/year pairs)
rename r4506800 spomonth_1994
rename r4506801 spoyear_1994
rename r5206700 spomonth_1996
rename r5206701 spoyear_1996
rename r5805700 spomonth_1998
rename r5805701 spoyear_1998
rename r6538000 spomonth_2000
rename r6538001 spoyear_2000

rename r5083601 child1month_1994
rename r5083602 child1year_1994
rename r5168901 child1month_1996
rename r5168902 child1year_1996
rename r6481701 child1month_1998
rename r6481702 child1year_1998
rename r7009401 child1month_2000
rename r7009402 child1year_2000

rename r5084101 child2month_1994
rename r5084102 child2year_1994
rename r5169401 child2month_1996
rename r5169402 child2year_1996
rename r6482201 child2month_1998
rename r6482202 child2year_1998
rename r7009901 child2month_2000
rename r7009902 child2year_2000

rename r5084601 child3month_1994
rename r5084602 child3year_1994
rename r5169901 child3month_1996
rename r5169902 child3year_1996
rename r6482701 child3month_1998
rename r6482702 child3year_1998
rename r7010401 child3month_2000
rename r7010402 child3year_2000

* Reshape WIDE to LONG 
reshape long unemp_ mstat_ page_ depx_ pwages_ swages_ psemp_ ssemp_ ///
              sui_ gssi_ transfers_ nonprop_ mortgage_ pensions_ dividends_ ///
              intrec_ rentpaid_ spomonth_ spoyear_ ///
              child1month_ child1year_ child2month_ child2year_ child3month_ child3year_, ///
    i(taxsimid) j(year) string

* turn year into numeric
destring year, replace

* fix self‐employment stub names
rename psemp pbusinc
rename ssemp sbusinc

* Compute ages for spouse & kids
gen refdate    = mdy(7,1,year)
gen dob_spouse = mdy(spomonth,  1, spoyear)
gen dob_c1     = mdy(child1month, 1, child1year)
gen dob_c2     = mdy(child2month, 1, child2year)
gen dob_c3     = mdy(child3month, 1, child3year)

gen sage = floor((refdate - dob_spouse)/365.25)
gen age1 = floor((refdate - dob_c1    )/365.25)
gen age2 = floor((refdate - dob_c2    )/365.25)
gen age3 = floor((refdate - dob_c3    )/365.25)

* zero out any negative ages
replace sage = 0 if sage < 0
foreach a of varlist age1 age2 age3 {
    replace `a' = 0 if `a' < 0
}

* drop intermediate date vars
drop spomonth spoyear dob_spouse dob_c1 dob_c2 dob_c3 refdate ///
     child1month child1year child2month child2year child3month child3year

replace sage  = 0 if missing(sage)  | sage  < 0
replace age1  = 0 if missing(age1)  | age1  < 0
replace age2  = 0 if missing(age2)  | age2  < 0
replace age3  = 0 if missing(age3)  | age3  < 0

*  Rename to TAXSIM's exact input names
rename unemp_     pui
rename sui_       sui
rename pwages_    pwages
rename swages    swages
rename gssi_      gssi
rename transfers_ transfers
rename nonprop_   nonprop
rename mortgage_  mortgage
rename pensions_  pensions
rename dividends_ dividends
rename intrec_    intrec
rename rentpaid_  rentpaid
* mstat, page, depx named
rename mstat_    mstat
rename page_     page
rename depx_     depx

*  Build dependent‐age counts
gen dep6  = 0
gen dep13 = 0
gen dep17 = 0
gen dep18 = 0
gen dep19 = 0
foreach a in age1 age2 age3 {
    replace dep6  = dep6  + (`a' <  6)
    replace dep13 = dep13 + (`a' < 13)
    replace dep17 = dep17 + (`a' < 17)
    replace dep18 = dep18 + (`a' < 18)
    replace dep19 = dep19 + (`a' < 19)
}
replace depx = dep19 if dep19 > depx

* Mstat
gen byte mstat2 = .
replace mstat2 = 2 if mstat == 2
replace mstat2 = 1 if mstat < 1
replace mstat2 = 1 if missing(mstat2)
drop mstat
rename mstat2 mstat

replace sage    = 0 if mstat != 2
replace swages  = 0 if mstat != 2
replace sbusinc = 0 if mstat != 2

* Option‐flag defaults
foreach v in opt1 opt1v opt2 opt2v {
    gen `v' = 0
}

gen otherprop = 0
gen ui = 0
gen psemp = 0
gen ssemp = 0

* capital gains (short & long)
gen stcg      = 0
gen ltcg      = 0

* itemized‐deduction prefs
gen proptax   = 0
gen otheritem = 0

* childcare credit
gen childcare = 0

* business & professional income you don't have
gen pprofinc  = 0
gen sprofinc  = 0
gen scorp     = 0

*State dummy
gen state = 36

* Zero‐fill any remaining missing inputs
foreach v in pui sui pwages swages pbusinc sbusinc ///
              gssi transfers nonprop mortgage ///
              pensions dividends intrec rentpaid ///
              mstat page depx stcg ltcg proptax ///
              otheritem childcare pprofinc sprofinc scorp {
    replace `v' = 0 if missing(`v')
}

local survvars page depx pui pwages swages pbusinc sbusinc sui gssi ///
                transfers nonprop mortgage pensions dividends ///
                intrec rentpaid

foreach v of local survvars {
    replace `v' = 0 if `v' < 0
}

save "nlsy_long_pre_taxsim.dta", replace
* Run Taxsim
taxsimlocal35, replace
save "taxsim_out_nominal.dta", replace

* rename outputs
use "taxsim_out_nominal.dta", clear
rename fiitax  tax_fed        // federal income tax liability
rename siitax  tax_st         // state income tax liability
rename fica    tax_payroll    // FICA (OADSI and HI, sum of employee AND employer including Additional Medicare Tax)
rename frate   mtr_fed        // federal marginal rate
rename srate   mtr_st         // state marginal rate
rename ficar   fica_rt         //  FICA rate
rename tfica   fica_taxliab   // taxpayer liability for FICA
save "taxsim_out_nominal.dta", replace

*  Merge CPI data to obtain inflation factors (base year = 1994)
use "BLS_CPI.dta", clear
keep year CPI
quietly summarize CPI if year==1994
gen CPI94 = r(mean)
gen deflator = CPI94 / CPI
keep year deflator
tempfile cpidata
save `cpidata', replace

* bring back the Taxsim results and merge in CPI
use "nlsy_long_pre_taxsim.dta", clear
sort year
merge m:1 year using `cpidata'
drop if _merge==2
drop _merge

foreach v in pwages swages pbusinc sbusinc sui gssi transfers nonprop ///
             mortgage pensions dividends intrec rentpaid {
    replace `v' = `v' * deflator
}

bysort taxsimid: egen pwages94    = mean(cond(year==1994, pwages,     .))
bysort taxsimid: egen swages94    = mean(cond(year==1994, swages,     .))
bysort taxsimid: egen pbusinc94   = mean(cond(year==1994, pbusinc,    .))
bysort taxsimid: egen sbusinc94   = mean(cond(year==1994, sbusinc,    .))
bysort taxsimid: egen sui94       = mean(cond(year==1994, sui,        .))
bysort taxsimid: egen gssi94      = mean(cond(year==1994, gssi,       .))
bysort taxsimid: egen transfers94 = mean(cond(year==1994, transfers,  .))
bysort taxsimid: egen nonprop94   = mean(cond(year==1994, nonprop,    .))
bysort taxsimid: egen mortgage94  = mean(cond(year==1994, mortgage,   .))
bysort taxsimid: egen pensions94  = mean(cond(year==1994, pensions,   .))
bysort taxsimid: egen dividends94 = mean(cond(year==1994, dividends,  .))
bysort taxsimid: egen intrec94    = mean(cond(year==1994, intrec,     .))
bysort taxsimid: egen rentpaid94  = mean(cond(year==1994, rentpaid,   .))

replace pwages    = pwages94
replace swages    = swages94
replace pbusinc   = pbusinc94
replace sbusinc   = sbusinc94
replace sui       = sui94
replace gssi      = gssi94
replace transfers = transfers94
replace nonprop   = nonprop94
replace mortgage  = mortgage94
replace pensions  = pensions94
replace dividends = dividends94
replace intrec    = intrec94
replace rentpaid  = rentpaid94

drop pwages94 swages94 pbusinc94 sbusinc94 ///
     sui94 gssi94 transfers94 nonprop94 ///
     mortgage94 pensions94 dividends94 ///
     intrec94 rentpaid94 deflator

replace swages   = 0   if mstat != 2
replace sbusinc  = 0   if mstat != 2
replace sui      = 0   if mstat != 2

* save deflated‐inputs
save "nlsy_long_deflated.dta", replace

* Run Taxsim again
taxsimlocal35, replace
save "taxsim_out_fixedreal.dta", replace
