clear all
set more off

* 1) Import the CSV (one row per person)
import delimited "NLSY_All_Data.csv", varnames(1) clear
rename r0000100 taxsimid
save "base_data.dta", replace

* 2) Import the left-out variables
import delimited "left_out.csv", varnames(1) clear
rename r0000100 taxsimid
save "left_out.dta", replace

* 3) Import the occupation/industry variables
import delimited "Occupation_Industry.csv", varnames(1) clear
rename r0000100 taxsimid

* Keep only the variables we need (ID + occupation + industry variables)
keep taxsimid ///
    r0046400 r0263400 r0446400 r0702100 r0945000 r1255400 r1650200 ///
    r1922800 r2317600 r2525400 r2924400 r3127100 r3522800 r3727800 r4182100 ///
    r0338300 r0546000 r0840500 r1087700 r1463400 r1810200 r2171900 ///
    r2376700 r2771500 r3013300 r3340700 r3605000 r3955200 r4587904 ///
    r5270600 r6472600 r6591800 r7209600 r7898000 t0138400 t1298000 ///
    t2326500 t3308700 t4282800 t5256900 t7818600 t8428300 t8982400 ///
    e5900100 e5910100 e5920100 e5930100 e5940100 e5950100 e5960100 ///
    e5970100 e5980100 e5990100 e6000100 e6010100 e6020100 e6030100 ///
    e6040100 e6050100 e6060100 e6070100 e6080100 e6090100 e6100100 ///
    e6110100 e6120100 e6130100 e8590100 x0177200 e8741100 e8939000 ///
    e9164500 e9452000

save "occupation_industry.dta", replace

* 4) NOW LOAD BASE DATA AND MERGE EVERYTHING
use "base_data.dta", clear 
merge 1:1 taxsimid using "left_out.dta"
tab _merge
drop _merge

merge 1:1 taxsimid using "occupation_industry.dta"
tab _merge
drop _merge

save "merged_data.dta", replace

import delimited "demo_x_hour.csv", varnames(1) clear
rename r0000100 taxsimid
save "demo_hour_data.dta", replace

* Merge with existing data
use "merged_data.dta", clear
merge 1:1 taxsimid using "demo_hour_data.dta"
tab _merge
drop _merge

save "merged_data.dta", replace

use "merged_data.dta", clear

* Race/Ethnicity (1=Hispanic, 2=Black, 3=Non-Black Non-Hispanic)
rename r0214700 race_ethnicity

* Sex (1=Male, 2=Female)
rename r0214800 sex

* Sample type
rename r0173600 sample_id

* AFQT scores (all measured in 1981)
rename r0618200 afqt_pct_1980    // Original 1980 percentile
rename r0618300 afqt_pct_1989    // 1989 revised percentile
rename r0618301 afqt_pct_2006    // 2006 revised percentile

* 4) Rename wave‐specific vars into *_YYYY stubs

* RENAME HIGHEST GRADE COMPLETED VARIABLES
rename r0017300 hgc_1979
rename r0229200 hgc_1980
rename r0417400 hgc_1981
rename r0664500 hgc_1982
rename r0905900 hgc_1983
rename r1205800 hgc_1984
rename r1605100 hgc_1985
rename r1905600 hgc_1986
rename r2306500 hgc_1987
rename r2509000 hgc_1988
rename r2908100 hgc_1989
rename r3110200 hgc_1990
rename r3510200 hgc_1991
rename r3710200 hgc_1992
rename r4137900 hgc_1993
rename r4526500 hgc_1994
rename r5221800 hgc_1996
rename r5821800 hgc_1998
rename r6540400 hgc_2000
rename r7103600 hgc_2002
rename r7810500 hgc_2004
rename t0014400 hgc_2006
rename t1214300 hgc_2008
rename t2272800 hgc_2010
rename t3212900 hgc_2012
rename t4201100 hgc_2014
rename t5176100 hgc_2016
rename t7743900 hgc_2018
rename t8355300 hgc_2020

* RENAME HOURS WORKED VARIABLES
rename r0215710 hrs_1978
rename r0407300 hrs_1979
rename r0646600 hrs_1980
rename r0896800 hrs_1981
rename r1145200 hrs_1982
rename r1520400 hrs_1983
rename r1891100 hrs_1984
rename r2258200 hrs_1985
rename r2445600 hrs_1986
rename r2871400 hrs_1987
rename r3075100 hrs_1988
rename r3401800 hrs_1989
rename r3657200 hrs_1990
rename r4007700 hrs_1991
rename r4418800 hrs_1992
rename r5081800 hrs_1993
rename r5167100 hrs_1995
rename r6479900 hrs_1997
rename r7007600 hrs_1999
rename r7704900 hrs_2001
rename r8497300 hrs_2003
rename t0989100 hrs_2005
rename t2210900 hrs_2007
rename t3108800 hrs_2009
rename t4113300 hrs_2011
rename t5024700 hrs_2013
rename t5772700 hrs_2015
rename t8219900 hrs_2017
rename t8789100 hrs_2019
rename t9300900 hrs_2021

* Replace NLSY missing codes with Stata missing
* -1 = Refused, -2 = Don't know, -3 = Invalid skip, -4 = Valid skip, -5 = Non-interview

foreach var of varlist hrs_* {
    capture replace `var' = . if `var' < 0
}

foreach var of varlist hgc_* {
    capture replace `var' = . if `var' < 0
}

foreach var of varlist afqt_* {
    capture replace `var' = . if `var' < 0
}

replace race_ethnicity = . if race_ethnicity < 0
replace sex = . if sex < 0

* Create a female indicator
gen female = (sex == 2) if sex != .

* Create race dummies
gen black = (race_ethnicity == 2) if race_ethnicity != .
gen hispanic = (race_ethnicity == 1) if race_ethnicity != .

* Create education categories (using most recent non-missing HGC)
egen max_education = rowmax(hgc_*)
gen college_grad = (max_education >= 16) if max_education != .
gen some_college = (max_education >= 13 & max_education < 16) if max_education != .
gen hs_grad = (max_education == 12) if max_education != .

* Apply value labels
label define race_lbl 1 "Hispanic" 2 "Black" 3 "Non-Black, Non-Hispanic"
label values race_ethnicity race_lbl

label define sex_lbl 1 "Male" 2 "Female"
label values sex sex_lbl

label var female "Female indicator"
label var black "Black indicator"
label var hispanic "Hispanic indicator"
label var max_education "Maximum education attained"
label var college_grad "College graduate (16+ years)"
label var some_college "Some college (13-15 years)"
label var hs_grad "High school graduate only"

* CREATE CUMULATIVE HOURS WORKED
foreach yr in 1978 1979 1980 1981 1982 1983 1984 1985 1986 1987 1988 1989 1990 1991 1992 1993 1995 1997 1999 2001 2003 2005 2007 2009 2011 2013 2015 2017 2019 2021 {
    gen hrs_temp_`yr' = hrs_`yr'
    replace hrs_temp_`yr' = 0 if missing(hrs_temp_`yr')
}

gen cumhrs_1978 = hrs_temp_1978
gen cumhrs_1979 = cumhrs_1978 + hrs_temp_1979
gen cumhrs_1980 = cumhrs_1979 + hrs_temp_1980
gen cumhrs_1981 = cumhrs_1980 + hrs_temp_1981
gen cumhrs_1982 = cumhrs_1981 + hrs_temp_1982
gen cumhrs_1983 = cumhrs_1982 + hrs_temp_1983
gen cumhrs_1984 = cumhrs_1983 + hrs_temp_1984
gen cumhrs_1985 = cumhrs_1984 + hrs_temp_1985
gen cumhrs_1986 = cumhrs_1985 + hrs_temp_1986
gen cumhrs_1987 = cumhrs_1986 + hrs_temp_1987
gen cumhrs_1988 = cumhrs_1987 + hrs_temp_1988
gen cumhrs_1989 = cumhrs_1988 + hrs_temp_1989
gen cumhrs_1990 = cumhrs_1989 + hrs_temp_1990
gen cumhrs_1991 = cumhrs_1990 + hrs_temp_1991
gen cumhrs_1992 = cumhrs_1991 + hrs_temp_1992
gen cumhrs_1993 = cumhrs_1992 + hrs_temp_1993
gen cumhrs_1995 = cumhrs_1993 + hrs_temp_1995
gen cumhrs_1997 = cumhrs_1995 + hrs_temp_1997
gen cumhrs_1999 = cumhrs_1997 + hrs_temp_1999
gen cumhrs_2001 = cumhrs_1999 + hrs_temp_2001
gen cumhrs_2003 = cumhrs_2001 + hrs_temp_2003
gen cumhrs_2005 = cumhrs_2003 + hrs_temp_2005
gen cumhrs_2007 = cumhrs_2005 + hrs_temp_2007
gen cumhrs_2009 = cumhrs_2007 + hrs_temp_2009
gen cumhrs_2011 = cumhrs_2009 + hrs_temp_2011
gen cumhrs_2013 = cumhrs_2011 + hrs_temp_2013
gen cumhrs_2015 = cumhrs_2013 + hrs_temp_2015
gen cumhrs_2017 = cumhrs_2015 + hrs_temp_2017
gen cumhrs_2019 = cumhrs_2017 + hrs_temp_2019
gen cumhrs_2021 = cumhrs_2019 + hrs_temp_2021

* Drop temporary variables
drop hrs_temp_*

* Label cumulative hours
foreach yr in 1978 1979 1980 1981 1982 1983 1984 1985 1986 1987 1988 1989 1990 1991 1992 1993 1995 1997 1999 2001 2003 2005 2007 2009 2011 2013 2015 2017 2019 2021 {
    label var cumhrs_`yr' "Cumulative hours worked through `yr'"
}

/*==============================================================================
PART 2: RENAME CPSOCC70 - CPS JOB OCCUPATION (1970 Census 3-digit codes)
==============================================================================
Reference numbers from codebook:
- These represent the occupation of the respondent's current/most recent job
- Available 1979-1993 (annual survey period)
==============================================================================*/
* 1979: R00464.00
rename r0046400 cpsocc70_1979

* 1980: R02634.00
rename r0263400 cpsocc70_1980

* 1981: R04464.00
rename r0446400 cpsocc70_1981

* 1982: R07021.00
rename r0702100 cpsocc70_1982

* 1983: R09450.00
rename r0945000 cpsocc70_1983

* 1984: R12554.00
rename r1255400 cpsocc70_1984

* 1985: R16502.00
rename r1650200 cpsocc70_1985

* 1986: R19228.00
rename r1922800 cpsocc70_1986

* 1987: R23176.00
rename r2317600 cpsocc70_1987

* 1988: R25254.00
rename r2525400 cpsocc70_1988

* 1989: R29244.00
rename r2924400 cpsocc70_1989

* 1990: R31271.00
rename r3127100 cpsocc70_1990

* 1991: R35228.00
rename r3522800 cpsocc70_1991

* 1992: R37278.00
rename r3727800 cpsocc70_1992

* 1993: R41821.00
rename r4182100 cpsocc70_1993


/*==============================================================================
PART 3: RENAME OCCALL-EMP.01 - JOB #1 OCCUPATION (All Jobs)
==============================================================================
Reference numbers from codebook:
- Occupation of Employer #1 (typically the main/primary job)
- Available 1980-2022
==============================================================================*/

* 1980: R03383.00
rename r0338300 occall01_1980

* 1981: R05460.00
rename r0546000 occall01_1981

* 1982: R08405.00
rename r0840500 occall01_1982

* 1983: R10877.00
rename r1087700 occall01_1983

* 1984: R14634.00
rename r1463400 occall01_1984

* 1985: R18102.00
rename r1810200 occall01_1985

* 1986: R21719.00
rename r2171900 occall01_1986

* 1987: R23767.00
rename r2376700 occall01_1987

* 1988: R27715.00
rename r2771500 occall01_1988

* 1989: R30133.00
rename r3013300 occall01_1989

* 1990: R33407.00
rename r3340700 occall01_1990

* 1991: R36050.00
rename r3605000 occall01_1991

* 1992: R39552.00
rename r3955200 occall01_1992

* 1994: R45879.04
rename r4587904 occall01_1994

* 1996: R52706.00
rename r5270600 occall01_1996

* 1998: R64726.00
rename r6472600 occall01_1998

* 2000: R65918.00
rename r6591800 occall01_2000

* 2002: R72096.00
rename r7209600 occall01_2002

* 2004: R78980.00
rename r7898000 occall01_2004

* 2006: T01384.00
rename t0138400 occall01_2006

* 2008: T12980.00
rename t1298000 occall01_2008

* 2010: T23265.00
rename t2326500 occall01_2010

* 2012: T33087.00
rename t3308700 occall01_2012

* 2014: T42828.00
rename t4282800 occall01_2014

* 2016: T52569.00
rename t5256900 occall01_2016

* 2018: T78186.00
rename t7818600 occall01_2018

* 2020: T84283.00
rename t8428300 occall01_2020

* 2022: T89824.00
rename t8982400 occall01_2022

/*==============================================================================
PART 4: RENAME EMPLOYERS_ALL_IND - JOB #1 INDUSTRY (1970 Census codes)
==============================================================================
Reference numbers from codebook:
- Industry of Employer #1
- 1970 Census codes for 1979-2000
- 2000 Census codes for 2002+
==============================================================================*/

* 1979: E59001.00
rename e5900100 ind01_1979

* 1980: E59101.00
rename e5910100 ind01_1980

* 1981: E59201.00
rename e5920100 ind01_1981

* 1982: E59301.00
rename e5930100 ind01_1982

* 1983: E59401.00
rename e5940100 ind01_1983

* 1984: E59501.00
rename e5950100 ind01_1984

* 1985: E59601.00
rename e5960100 ind01_1985

* 1986: E59701.00
rename e5970100 ind01_1986

* 1987: E59801.00
rename e5980100 ind01_1987

* 1988: E59901.00
rename e5990100 ind01_1988

* 1989: E60001.00
rename e6000100 ind01_1989

* 1990: E60101.00
rename e6010100 ind01_1990

* 1991: E60201.00
rename e6020100 ind01_1991

* 1992: E60301.00
rename e6030100 ind01_1992

* 1993: E60401.00
rename e6040100 ind01_1993

* 1994: E60501.00
rename e6050100 ind01_1994

* 1996: E60601.00
rename e6060100 ind01_1996

* 1998: E60701.00
rename e6070100 ind01_1998

* 2000: E60801.00
rename e6080100 ind01_2000

* 2002: E60901.00
rename e6090100 ind01_2002

* 2004: E61001.00
rename e6100100 ind01_2004

* 2006: E61101.00
rename e6110100 ind01_2006

* 2008: E61201.00
rename e6120100 ind01_2008

* 2010: E61301.00
rename e6130100 ind01_2010

* 2012: E85901.00
rename e8590100 ind01_2012

* 2014: X01772.00
rename x0177200 ind01_2014

* 2016: E87411.00
rename e8741100 ind01_2016

* 2018: E89390.00
rename e8939000 ind01_2018

* 2020: E91645.00
rename e9164500 ind01_2020

* 2022: E94520.00
rename e9452000 ind01_2022

di "EMPLOYERS_ALL_IND variables renamed: 1979-2022"

/*==============================================================================
PART 5: CLEAN MISSING VALUES
==============================================================================
NLSY missing codes:
-1 = Refused
-2 = Don't know
-3 = Invalid skip
-4 = Valid skip
-5 = Non-interview
==============================================================================*/

di ""
di "Cleaning missing values..."

* CPSOCC70 variables
replace cpsocc70_1979 = . if cpsocc70_1979 < 0
replace cpsocc70_1980 = . if cpsocc70_1980 < 0
replace cpsocc70_1981 = . if cpsocc70_1981 < 0
replace cpsocc70_1982 = . if cpsocc70_1982 < 0
replace cpsocc70_1983 = . if cpsocc70_1983 < 0
replace cpsocc70_1984 = . if cpsocc70_1984 < 0
replace cpsocc70_1985 = . if cpsocc70_1985 < 0
replace cpsocc70_1986 = . if cpsocc70_1986 < 0
replace cpsocc70_1987 = . if cpsocc70_1987 < 0
replace cpsocc70_1988 = . if cpsocc70_1988 < 0
replace cpsocc70_1989 = . if cpsocc70_1989 < 0
replace cpsocc70_1990 = . if cpsocc70_1990 < 0
replace cpsocc70_1991 = . if cpsocc70_1991 < 0
replace cpsocc70_1992 = . if cpsocc70_1992 < 0
replace cpsocc70_1993 = . if cpsocc70_1993 < 0

* OCCALL01 variables
replace occall01_1980 = . if occall01_1980 < 0
replace occall01_1981 = . if occall01_1981 < 0
replace occall01_1982 = . if occall01_1982 < 0
replace occall01_1983 = . if occall01_1983 < 0
replace occall01_1984 = . if occall01_1984 < 0
replace occall01_1985 = . if occall01_1985 < 0
replace occall01_1986 = . if occall01_1986 < 0
replace occall01_1987 = . if occall01_1987 < 0
replace occall01_1988 = . if occall01_1988 < 0
replace occall01_1989 = . if occall01_1989 < 0
replace occall01_1990 = . if occall01_1990 < 0
replace occall01_1991 = . if occall01_1991 < 0
replace occall01_1992 = . if occall01_1992 < 0
replace occall01_1994 = . if occall01_1994 < 0
replace occall01_1996 = . if occall01_1996 < 0
replace occall01_1998 = . if occall01_1998 < 0
replace occall01_2000 = . if occall01_2000 < 0
replace occall01_2002 = . if occall01_2002 < 0
replace occall01_2004 = . if occall01_2004 < 0
replace occall01_2006 = . if occall01_2006 < 0
replace occall01_2008 = . if occall01_2008 < 0
replace occall01_2010 = . if occall01_2010 < 0
replace occall01_2012 = . if occall01_2012 < 0
replace occall01_2014 = . if occall01_2014 < 0
replace occall01_2016 = . if occall01_2016 < 0
replace occall01_2018 = . if occall01_2018 < 0
replace occall01_2020 = . if occall01_2020 < 0
replace occall01_2022 = . if occall01_2022 < 0

* IND01 variables
replace ind01_1979 = . if ind01_1979 < 0
replace ind01_1980 = . if ind01_1980 < 0
replace ind01_1981 = . if ind01_1981 < 0
replace ind01_1982 = . if ind01_1982 < 0
replace ind01_1983 = . if ind01_1983 < 0
replace ind01_1984 = . if ind01_1984 < 0
replace ind01_1985 = . if ind01_1985 < 0
replace ind01_1986 = . if ind01_1986 < 0
replace ind01_1987 = . if ind01_1987 < 0
replace ind01_1988 = . if ind01_1988 < 0
replace ind01_1989 = . if ind01_1989 < 0
replace ind01_1990 = . if ind01_1990 < 0
replace ind01_1991 = . if ind01_1991 < 0
replace ind01_1992 = . if ind01_1992 < 0
replace ind01_1993 = . if ind01_1993 < 0
replace ind01_1994 = . if ind01_1994 < 0
replace ind01_1996 = . if ind01_1996 < 0
replace ind01_1998 = . if ind01_1998 < 0
replace ind01_2000 = . if ind01_2000 < 0
replace ind01_2002 = . if ind01_2002 < 0
replace ind01_2004 = . if ind01_2004 < 0
replace ind01_2006 = . if ind01_2006 < 0
replace ind01_2008 = . if ind01_2008 < 0
replace ind01_2010 = . if ind01_2010 < 0
replace ind01_2012 = . if ind01_2012 < 0
replace ind01_2014 = . if ind01_2014 < 0
replace ind01_2016 = . if ind01_2016 < 0
replace ind01_2018 = . if ind01_2018 < 0
replace ind01_2020 = . if ind01_2020 < 0
replace ind01_2022 = . if ind01_2022 < 0

/*==============================================================================
PART 6: CREATE UNIFIED OCCUPATION VARIABLE (occ_YYYY)
==============================================================================
Strategy:
- For 1979-1993: Use CPSOCC70 (CPS job occupation)
- For 1994+: Use OCCALL01 (Job #1 occupation)
==============================================================================*/

* Annual period: Use CPSOCC70
gen occ_1979 = cpsocc70_1979
gen occ_1980 = cpsocc70_1980
gen occ_1981 = cpsocc70_1981
gen occ_1982 = cpsocc70_1982
gen occ_1983 = cpsocc70_1983
gen occ_1984 = cpsocc70_1984
gen occ_1985 = cpsocc70_1985
gen occ_1986 = cpsocc70_1986
gen occ_1987 = cpsocc70_1987
gen occ_1988 = cpsocc70_1988
gen occ_1989 = cpsocc70_1989
gen occ_1990 = cpsocc70_1990
gen occ_1991 = cpsocc70_1991
gen occ_1992 = cpsocc70_1992
gen occ_1993 = cpsocc70_1993

* Biennial period: Use OCCALL01
gen occ_1994 = occall01_1994
gen occ_1996 = occall01_1996
gen occ_1998 = occall01_1998
gen occ_2000 = occall01_2000
gen occ_2002 = occall01_2002
gen occ_2004 = occall01_2004
gen occ_2006 = occall01_2006
gen occ_2008 = occall01_2008
gen occ_2010 = occall01_2010
gen occ_2012 = occall01_2012
gen occ_2014 = occall01_2014
gen occ_2016 = occall01_2016
gen occ_2018 = occall01_2018
gen occ_2020 = occall01_2020
gen occ_2022 = occall01_2022

di "Unified occ_YYYY variables created"

/*==============================================================================
PART 7: CREATE UNIFIED INDUSTRY VARIABLE (ind_YYYY)
==============================================================================*/

gen ind_1979 = ind01_1979
gen ind_1980 = ind01_1980
gen ind_1981 = ind01_1981
gen ind_1982 = ind01_1982
gen ind_1983 = ind01_1983
gen ind_1984 = ind01_1984
gen ind_1985 = ind01_1985
gen ind_1986 = ind01_1986
gen ind_1987 = ind01_1987
gen ind_1988 = ind01_1988
gen ind_1989 = ind01_1989
gen ind_1990 = ind01_1990
gen ind_1991 = ind01_1991
gen ind_1992 = ind01_1992
gen ind_1993 = ind01_1993
gen ind_1994 = ind01_1994
gen ind_1996 = ind01_1996
gen ind_1998 = ind01_1998
gen ind_2000 = ind01_2000
gen ind_2002 = ind01_2002
gen ind_2004 = ind01_2004
gen ind_2006 = ind01_2006
gen ind_2008 = ind01_2008
gen ind_2010 = ind01_2010
gen ind_2012 = ind01_2012
gen ind_2014 = ind01_2014
gen ind_2016 = ind01_2016
gen ind_2018 = ind01_2018
gen ind_2020 = ind01_2020
gen ind_2022 = ind01_2022


/*==============================================================================
PART 8: CREATE BROAD OCCUPATION CATEGORIES (1-digit from 3-digit codes)
==============================================================================
1970 Census Occupation Codes → Broad Categories:
001-195: Professional, Technical (1)
201-245: Managers, Administrators (2)
260-285: Sales Workers (3)
301-395: Clerical Workers (4)
401-575: Craftsmen (5)
601-695: Operatives except transport (6)
701-715: Transport Equipment Operatives (6)
740-785: Laborers (7)
801-824: Farm Workers (8)
901-984: Service Workers (9)
==============================================================================*/

* 1979
gen occ_broad_1979 = .
replace occ_broad_1979 = 1 if occ_1979 >= 1 & occ_1979 <= 195
replace occ_broad_1979 = 2 if occ_1979 >= 201 & occ_1979 <= 245
replace occ_broad_1979 = 3 if occ_1979 >= 260 & occ_1979 <= 285
replace occ_broad_1979 = 4 if occ_1979 >= 301 & occ_1979 <= 395
replace occ_broad_1979 = 5 if occ_1979 >= 401 & occ_1979 <= 575
replace occ_broad_1979 = 6 if occ_1979 >= 601 & occ_1979 <= 715
replace occ_broad_1979 = 7 if occ_1979 >= 740 & occ_1979 <= 785
replace occ_broad_1979 = 8 if occ_1979 >= 801 & occ_1979 <= 824
replace occ_broad_1979 = 9 if occ_1979 >= 901 & occ_1979 <= 984

* 1980
gen occ_broad_1980 = .
replace occ_broad_1980 = 1 if occ_1980 >= 1 & occ_1980 <= 195
replace occ_broad_1980 = 2 if occ_1980 >= 201 & occ_1980 <= 245
replace occ_broad_1980 = 3 if occ_1980 >= 260 & occ_1980 <= 285
replace occ_broad_1980 = 4 if occ_1980 >= 301 & occ_1980 <= 395
replace occ_broad_1980 = 5 if occ_1980 >= 401 & occ_1980 <= 575
replace occ_broad_1980 = 6 if occ_1980 >= 601 & occ_1980 <= 715
replace occ_broad_1980 = 7 if occ_1980 >= 740 & occ_1980 <= 785
replace occ_broad_1980 = 8 if occ_1980 >= 801 & occ_1980 <= 824
replace occ_broad_1980 = 9 if occ_1980 >= 901 & occ_1980 <= 984

* 1981
gen occ_broad_1981 = .
replace occ_broad_1981 = 1 if occ_1981 >= 1 & occ_1981 <= 195
replace occ_broad_1981 = 2 if occ_1981 >= 201 & occ_1981 <= 245
replace occ_broad_1981 = 3 if occ_1981 >= 260 & occ_1981 <= 285
replace occ_broad_1981 = 4 if occ_1981 >= 301 & occ_1981 <= 395
replace occ_broad_1981 = 5 if occ_1981 >= 401 & occ_1981 <= 575
replace occ_broad_1981 = 6 if occ_1981 >= 601 & occ_1981 <= 715
replace occ_broad_1981 = 7 if occ_1981 >= 740 & occ_1981 <= 785
replace occ_broad_1981 = 8 if occ_1981 >= 801 & occ_1981 <= 824
replace occ_broad_1981 = 9 if occ_1981 >= 901 & occ_1981 <= 984

* 1982
gen occ_broad_1982 = .
replace occ_broad_1982 = 1 if occ_1982 >= 1 & occ_1982 <= 195
replace occ_broad_1982 = 2 if occ_1982 >= 201 & occ_1982 <= 245
replace occ_broad_1982 = 3 if occ_1982 >= 260 & occ_1982 <= 285
replace occ_broad_1982 = 4 if occ_1982 >= 301 & occ_1982 <= 395
replace occ_broad_1982 = 5 if occ_1982 >= 401 & occ_1982 <= 575
replace occ_broad_1982 = 6 if occ_1982 >= 601 & occ_1982 <= 715
replace occ_broad_1982 = 7 if occ_1982 >= 740 & occ_1982 <= 785
replace occ_broad_1982 = 8 if occ_1982 >= 801 & occ_1982 <= 824
replace occ_broad_1982 = 9 if occ_1982 >= 901 & occ_1982 <= 984

* 1983
gen occ_broad_1983 = .
replace occ_broad_1983 = 1 if occ_1983 >= 1 & occ_1983 <= 195
replace occ_broad_1983 = 2 if occ_1983 >= 201 & occ_1983 <= 245
replace occ_broad_1983 = 3 if occ_1983 >= 260 & occ_1983 <= 285
replace occ_broad_1983 = 4 if occ_1983 >= 301 & occ_1983 <= 395
replace occ_broad_1983 = 5 if occ_1983 >= 401 & occ_1983 <= 575
replace occ_broad_1983 = 6 if occ_1983 >= 601 & occ_1983 <= 715
replace occ_broad_1983 = 7 if occ_1983 >= 740 & occ_1983 <= 785
replace occ_broad_1983 = 8 if occ_1983 >= 801 & occ_1983 <= 824
replace occ_broad_1983 = 9 if occ_1983 >= 901 & occ_1983 <= 984

* 1984
gen occ_broad_1984 = .
replace occ_broad_1984 = 1 if occ_1984 >= 1 & occ_1984 <= 195
replace occ_broad_1984 = 2 if occ_1984 >= 201 & occ_1984 <= 245
replace occ_broad_1984 = 3 if occ_1984 >= 260 & occ_1984 <= 285
replace occ_broad_1984 = 4 if occ_1984 >= 301 & occ_1984 <= 395
replace occ_broad_1984 = 5 if occ_1984 >= 401 & occ_1984 <= 575
replace occ_broad_1984 = 6 if occ_1984 >= 601 & occ_1984 <= 715
replace occ_broad_1984 = 7 if occ_1984 >= 740 & occ_1984 <= 785
replace occ_broad_1984 = 8 if occ_1984 >= 801 & occ_1984 <= 824
replace occ_broad_1984 = 9 if occ_1984 >= 901 & occ_1984 <= 984

* 1985
gen occ_broad_1985 = .
replace occ_broad_1985 = 1 if occ_1985 >= 1 & occ_1985 <= 195
replace occ_broad_1985 = 2 if occ_1985 >= 201 & occ_1985 <= 245
replace occ_broad_1985 = 3 if occ_1985 >= 260 & occ_1985 <= 285
replace occ_broad_1985 = 4 if occ_1985 >= 301 & occ_1985 <= 395
replace occ_broad_1985 = 5 if occ_1985 >= 401 & occ_1985 <= 575
replace occ_broad_1985 = 6 if occ_1985 >= 601 & occ_1985 <= 715
replace occ_broad_1985 = 7 if occ_1985 >= 740 & occ_1985 <= 785
replace occ_broad_1985 = 8 if occ_1985 >= 801 & occ_1985 <= 824
replace occ_broad_1985 = 9 if occ_1985 >= 901 & occ_1985 <= 984

* 1986
gen occ_broad_1986 = .
replace occ_broad_1986 = 1 if occ_1986 >= 1 & occ_1986 <= 195
replace occ_broad_1986 = 2 if occ_1986 >= 201 & occ_1986 <= 245
replace occ_broad_1986 = 3 if occ_1986 >= 260 & occ_1986 <= 285
replace occ_broad_1986 = 4 if occ_1986 >= 301 & occ_1986 <= 395
replace occ_broad_1986 = 5 if occ_1986 >= 401 & occ_1986 <= 575
replace occ_broad_1986 = 6 if occ_1986 >= 601 & occ_1986 <= 715
replace occ_broad_1986 = 7 if occ_1986 >= 740 & occ_1986 <= 785
replace occ_broad_1986 = 8 if occ_1986 >= 801 & occ_1986 <= 824
replace occ_broad_1986 = 9 if occ_1986 >= 901 & occ_1986 <= 984

* 1987
gen occ_broad_1987 = .
replace occ_broad_1987 = 1 if occ_1987 >= 1 & occ_1987 <= 195
replace occ_broad_1987 = 2 if occ_1987 >= 201 & occ_1987 <= 245
replace occ_broad_1987 = 3 if occ_1987 >= 260 & occ_1987 <= 285
replace occ_broad_1987 = 4 if occ_1987 >= 301 & occ_1987 <= 395
replace occ_broad_1987 = 5 if occ_1987 >= 401 & occ_1987 <= 575
replace occ_broad_1987 = 6 if occ_1987 >= 601 & occ_1987 <= 715
replace occ_broad_1987 = 7 if occ_1987 >= 740 & occ_1987 <= 785
replace occ_broad_1987 = 8 if occ_1987 >= 801 & occ_1987 <= 824
replace occ_broad_1987 = 9 if occ_1987 >= 901 & occ_1987 <= 984

* 1988
gen occ_broad_1988 = .
replace occ_broad_1988 = 1 if occ_1988 >= 1 & occ_1988 <= 195
replace occ_broad_1988 = 2 if occ_1988 >= 201 & occ_1988 <= 245
replace occ_broad_1988 = 3 if occ_1988 >= 260 & occ_1988 <= 285
replace occ_broad_1988 = 4 if occ_1988 >= 301 & occ_1988 <= 395
replace occ_broad_1988 = 5 if occ_1988 >= 401 & occ_1988 <= 575
replace occ_broad_1988 = 6 if occ_1988 >= 601 & occ_1988 <= 715
replace occ_broad_1988 = 7 if occ_1988 >= 740 & occ_1988 <= 785
replace occ_broad_1988 = 8 if occ_1988 >= 801 & occ_1988 <= 824
replace occ_broad_1988 = 9 if occ_1988 >= 901 & occ_1988 <= 984

* 1989
gen occ_broad_1989 = .
replace occ_broad_1989 = 1 if occ_1989 >= 1 & occ_1989 <= 195
replace occ_broad_1989 = 2 if occ_1989 >= 201 & occ_1989 <= 245
replace occ_broad_1989 = 3 if occ_1989 >= 260 & occ_1989 <= 285
replace occ_broad_1989 = 4 if occ_1989 >= 301 & occ_1989 <= 395
replace occ_broad_1989 = 5 if occ_1989 >= 401 & occ_1989 <= 575
replace occ_broad_1989 = 6 if occ_1989 >= 601 & occ_1989 <= 715
replace occ_broad_1989 = 7 if occ_1989 >= 740 & occ_1989 <= 785
replace occ_broad_1989 = 8 if occ_1989 >= 801 & occ_1989 <= 824
replace occ_broad_1989 = 9 if occ_1989 >= 901 & occ_1989 <= 984

* 1990
gen occ_broad_1990 = .
replace occ_broad_1990 = 1 if occ_1990 >= 1 & occ_1990 <= 195
replace occ_broad_1990 = 2 if occ_1990 >= 201 & occ_1990 <= 245
replace occ_broad_1990 = 3 if occ_1990 >= 260 & occ_1990 <= 285
replace occ_broad_1990 = 4 if occ_1990 >= 301 & occ_1990 <= 395
replace occ_broad_1990 = 5 if occ_1990 >= 401 & occ_1990 <= 575
replace occ_broad_1990 = 6 if occ_1990 >= 601 & occ_1990 <= 715
replace occ_broad_1990 = 7 if occ_1990 >= 740 & occ_1990 <= 785
replace occ_broad_1990 = 8 if occ_1990 >= 801 & occ_1990 <= 824
replace occ_broad_1990 = 9 if occ_1990 >= 901 & occ_1990 <= 984

* 1991
gen occ_broad_1991 = .
replace occ_broad_1991 = 1 if occ_1991 >= 1 & occ_1991 <= 195
replace occ_broad_1991 = 2 if occ_1991 >= 201 & occ_1991 <= 245
replace occ_broad_1991 = 3 if occ_1991 >= 260 & occ_1991 <= 285
replace occ_broad_1991 = 4 if occ_1991 >= 301 & occ_1991 <= 395
replace occ_broad_1991 = 5 if occ_1991 >= 401 & occ_1991 <= 575
replace occ_broad_1991 = 6 if occ_1991 >= 601 & occ_1991 <= 715
replace occ_broad_1991 = 7 if occ_1991 >= 740 & occ_1991 <= 785
replace occ_broad_1991 = 8 if occ_1991 >= 801 & occ_1991 <= 824
replace occ_broad_1991 = 9 if occ_1991 >= 901 & occ_1991 <= 984

* 1992
gen occ_broad_1992 = .
replace occ_broad_1992 = 1 if occ_1992 >= 1 & occ_1992 <= 195
replace occ_broad_1992 = 2 if occ_1992 >= 201 & occ_1992 <= 245
replace occ_broad_1992 = 3 if occ_1992 >= 260 & occ_1992 <= 285
replace occ_broad_1992 = 4 if occ_1992 >= 301 & occ_1992 <= 395
replace occ_broad_1992 = 5 if occ_1992 >= 401 & occ_1992 <= 575
replace occ_broad_1992 = 6 if occ_1992 >= 601 & occ_1992 <= 715
replace occ_broad_1992 = 7 if occ_1992 >= 740 & occ_1992 <= 785
replace occ_broad_1992 = 8 if occ_1992 >= 801 & occ_1992 <= 824
replace occ_broad_1992 = 9 if occ_1992 >= 901 & occ_1992 <= 984

* 1993
gen occ_broad_1993 = .
replace occ_broad_1993 = 1 if occ_1993 >= 1 & occ_1993 <= 195
replace occ_broad_1993 = 2 if occ_1993 >= 201 & occ_1993 <= 245
replace occ_broad_1993 = 3 if occ_1993 >= 260 & occ_1993 <= 285
replace occ_broad_1993 = 4 if occ_1993 >= 301 & occ_1993 <= 395
replace occ_broad_1993 = 5 if occ_1993 >= 401 & occ_1993 <= 575
replace occ_broad_1993 = 6 if occ_1993 >= 601 & occ_1993 <= 715
replace occ_broad_1993 = 7 if occ_1993 >= 740 & occ_1993 <= 785
replace occ_broad_1993 = 8 if occ_1993 >= 801 & occ_1993 <= 824
replace occ_broad_1993 = 9 if occ_1993 >= 901 & occ_1993 <= 984

* Apply labels
label define occ_broad_lbl ///
    1 "Professional/Technical" ///
    2 "Managers/Administrators" ///
    3 "Sales Workers" ///
    4 "Clerical Workers" ///
    5 "Craftsmen" ///
    6 "Operatives" ///
    7 "Laborers" ///
    8 "Farm Workers" ///
    9 "Service Workers"

label values occ_broad_1979 occ_broad_lbl
label values occ_broad_1980 occ_broad_lbl
label values occ_broad_1981 occ_broad_lbl
label values occ_broad_1982 occ_broad_lbl
label values occ_broad_1983 occ_broad_lbl
label values occ_broad_1984 occ_broad_lbl
label values occ_broad_1985 occ_broad_lbl
label values occ_broad_1986 occ_broad_lbl
label values occ_broad_1987 occ_broad_lbl
label values occ_broad_1988 occ_broad_lbl
label values occ_broad_1989 occ_broad_lbl
label values occ_broad_1990 occ_broad_lbl
label values occ_broad_1991 occ_broad_lbl
label values occ_broad_1992 occ_broad_lbl
label values occ_broad_1993 occ_broad_lbl

di "Broad occupation categories created"

/*==============================================================================
PART 9: CREATE BROAD INDUSTRY CATEGORIES (1-digit from 3-digit codes)
1970 Census Industry Codes → Broad Categories:
017-029: Agriculture, Forestry, Fisheries (1)
047-058: Mining (2)
067-078: Construction (3)
107-398: Manufacturing (4)
407-499: Transportation, Communication, Utilities (5)
507-699: Wholesale and Retail Trade (6)
707-719: Finance, Insurance, Real Estate (7)
727-767: Business and Repair Services (8)
769-799: Personal Services (9)
807-817: Entertainment and Recreation (10)
828-899: Professional Services (11)
907-947: Public Administration (12)
==============================================================================*/

* 1979
gen ind_broad_1979 = .
replace ind_broad_1979 = 1 if ind_1979 >= 17 & ind_1979 <= 29
replace ind_broad_1979 = 2 if ind_1979 >= 47 & ind_1979 <= 58
replace ind_broad_1979 = 3 if ind_1979 >= 67 & ind_1979 <= 78
replace ind_broad_1979 = 4 if ind_1979 >= 107 & ind_1979 <= 398
replace ind_broad_1979 = 5 if ind_1979 >= 407 & ind_1979 <= 499
replace ind_broad_1979 = 6 if ind_1979 >= 507 & ind_1979 <= 699
replace ind_broad_1979 = 7 if ind_1979 >= 707 & ind_1979 <= 719
replace ind_broad_1979 = 8 if ind_1979 >= 727 & ind_1979 <= 767
replace ind_broad_1979 = 9 if ind_1979 >= 769 & ind_1979 <= 799
replace ind_broad_1979 = 10 if ind_1979 >= 807 & ind_1979 <= 817
replace ind_broad_1979 = 11 if ind_1979 >= 828 & ind_1979 <= 899
replace ind_broad_1979 = 12 if ind_1979 >= 907 & ind_1979 <= 947

* 1980
gen ind_broad_1980 = .
replace ind_broad_1980 = 1 if ind_1980 >= 17 & ind_1980 <= 29
replace ind_broad_1980 = 2 if ind_1980 >= 47 & ind_1980 <= 58
replace ind_broad_1980 = 3 if ind_1980 >= 67 & ind_1980 <= 78
replace ind_broad_1980 = 4 if ind_1980 >= 107 & ind_1980 <= 398
replace ind_broad_1980 = 5 if ind_1980 >= 407 & ind_1980 <= 499
replace ind_broad_1980 = 6 if ind_1980 >= 507 & ind_1980 <= 699
replace ind_broad_1980 = 7 if ind_1980 >= 707 & ind_1980 <= 719
replace ind_broad_1980 = 8 if ind_1980 >= 727 & ind_1980 <= 767
replace ind_broad_1980 = 9 if ind_1980 >= 769 & ind_1980 <= 799
replace ind_broad_1980 = 10 if ind_1980 >= 807 & ind_1980 <= 817
replace ind_broad_1980 = 11 if ind_1980 >= 828 & ind_1980 <= 899
replace ind_broad_1980 = 12 if ind_1980 >= 907 & ind_1980 <= 947

* 1981
gen ind_broad_1981 = .
replace ind_broad_1981 = 1 if ind_1981 >= 17 & ind_1981 <= 29
replace ind_broad_1981 = 2 if ind_1981 >= 47 & ind_1981 <= 58
replace ind_broad_1981 = 3 if ind_1981 >= 67 & ind_1981 <= 78
replace ind_broad_1981 = 4 if ind_1981 >= 107 & ind_1981 <= 398
replace ind_broad_1981 = 5 if ind_1981 >= 407 & ind_1981 <= 499
replace ind_broad_1981 = 6 if ind_1981 >= 507 & ind_1981 <= 699
replace ind_broad_1981 = 7 if ind_1981 >= 707 & ind_1981 <= 719
replace ind_broad_1981 = 8 if ind_1981 >= 727 & ind_1981 <= 767
replace ind_broad_1981 = 9 if ind_1981 >= 769 & ind_1981 <= 799
replace ind_broad_1981 = 10 if ind_1981 >= 807 & ind_1981 <= 817
replace ind_broad_1981 = 11 if ind_1981 >= 828 & ind_1981 <= 899
replace ind_broad_1981 = 12 if ind_1981 >= 907 & ind_1981 <= 947

* 1982
gen ind_broad_1982 = .
replace ind_broad_1982 = 1 if ind_1982 >= 17 & ind_1982 <= 29
replace ind_broad_1982 = 2 if ind_1982 >= 47 & ind_1982 <= 58
replace ind_broad_1982 = 3 if ind_1982 >= 67 & ind_1982 <= 78
replace ind_broad_1982 = 4 if ind_1982 >= 107 & ind_1982 <= 398
replace ind_broad_1982 = 5 if ind_1982 >= 407 & ind_1982 <= 499
replace ind_broad_1982 = 6 if ind_1982 >= 507 & ind_1982 <= 699
replace ind_broad_1982 = 7 if ind_1982 >= 707 & ind_1982 <= 719
replace ind_broad_1982 = 8 if ind_1982 >= 727 & ind_1982 <= 767
replace ind_broad_1982 = 9 if ind_1982 >= 769 & ind_1982 <= 799
replace ind_broad_1982 = 10 if ind_1982 >= 807 & ind_1982 <= 817
replace ind_broad_1982 = 11 if ind_1982 >= 828 & ind_1982 <= 899
replace ind_broad_1982 = 12 if ind_1982 >= 907 & ind_1982 <= 947

* 1983
gen ind_broad_1983 = .
replace ind_broad_1983 = 1 if ind_1983 >= 17 & ind_1983 <= 29
replace ind_broad_1983 = 2 if ind_1983 >= 47 & ind_1983 <= 58
replace ind_broad_1983 = 3 if ind_1983 >= 67 & ind_1983 <= 78
replace ind_broad_1983 = 4 if ind_1983 >= 107 & ind_1983 <= 398
replace ind_broad_1983 = 5 if ind_1983 >= 407 & ind_1983 <= 499
replace ind_broad_1983 = 6 if ind_1983 >= 507 & ind_1983 <= 699
replace ind_broad_1983 = 7 if ind_1983 >= 707 & ind_1983 <= 719
replace ind_broad_1983 = 8 if ind_1983 >= 727 & ind_1983 <= 767
replace ind_broad_1983 = 9 if ind_1983 >= 769 & ind_1983 <= 799
replace ind_broad_1983 = 10 if ind_1983 >= 807 & ind_1983 <= 817
replace ind_broad_1983 = 11 if ind_1983 >= 828 & ind_1983 <= 899
replace ind_broad_1983 = 12 if ind_1983 >= 907 & ind_1983 <= 947

* 1984
gen ind_broad_1984 = .
replace ind_broad_1984 = 1 if ind_1984 >= 17 & ind_1984 <= 29
replace ind_broad_1984 = 2 if ind_1984 >= 47 & ind_1984 <= 58
replace ind_broad_1984 = 3 if ind_1984 >= 67 & ind_1984 <= 78
replace ind_broad_1984 = 4 if ind_1984 >= 107 & ind_1984 <= 398
replace ind_broad_1984 = 5 if ind_1984 >= 407 & ind_1984 <= 499
replace ind_broad_1984 = 6 if ind_1984 >= 507 & ind_1984 <= 699
replace ind_broad_1984 = 7 if ind_1984 >= 707 & ind_1984 <= 719
replace ind_broad_1984 = 8 if ind_1984 >= 727 & ind_1984 <= 767
replace ind_broad_1984 = 9 if ind_1984 >= 769 & ind_1984 <= 799
replace ind_broad_1984 = 10 if ind_1984 >= 807 & ind_1984 <= 817
replace ind_broad_1984 = 11 if ind_1984 >= 828 & ind_1984 <= 899
replace ind_broad_1984 = 12 if ind_1984 >= 907 & ind_1984 <= 947

* 1985
gen ind_broad_1985 = .
replace ind_broad_1985 = 1 if ind_1985 >= 17 & ind_1985 <= 29
replace ind_broad_1985 = 2 if ind_1985 >= 47 & ind_1985 <= 58
replace ind_broad_1985 = 3 if ind_1985 >= 67 & ind_1985 <= 78
replace ind_broad_1985 = 4 if ind_1985 >= 107 & ind_1985 <= 398
replace ind_broad_1985 = 5 if ind_1985 >= 407 & ind_1985 <= 499
replace ind_broad_1985 = 6 if ind_1985 >= 507 & ind_1985 <= 699
replace ind_broad_1985 = 7 if ind_1985 >= 707 & ind_1985 <= 719
replace ind_broad_1985 = 8 if ind_1985 >= 727 & ind_1985 <= 767
replace ind_broad_1985 = 9 if ind_1985 >= 769 & ind_1985 <= 799
replace ind_broad_1985 = 10 if ind_1985 >= 807 & ind_1985 <= 817
replace ind_broad_1985 = 11 if ind_1985 >= 828 & ind_1985 <= 899
replace ind_broad_1985 = 12 if ind_1985 >= 907 & ind_1985 <= 947

* 1986
gen ind_broad_1986 = .
replace ind_broad_1986 = 1 if ind_1986 >= 17 & ind_1986 <= 29
replace ind_broad_1986 = 2 if ind_1986 >= 47 & ind_1986 <= 58
replace ind_broad_1986 = 3 if ind_1986 >= 67 & ind_1986 <= 78
replace ind_broad_1986 = 4 if ind_1986 >= 107 & ind_1986 <= 398
replace ind_broad_1986 = 5 if ind_1986 >= 407 & ind_1986 <= 499
replace ind_broad_1986 = 6 if ind_1986 >= 507 & ind_1986 <= 699
replace ind_broad_1986 = 7 if ind_1986 >= 707 & ind_1986 <= 719
replace ind_broad_1986 = 8 if ind_1986 >= 727 & ind_1986 <= 767
replace ind_broad_1986 = 9 if ind_1986 >= 769 & ind_1986 <= 799
replace ind_broad_1986 = 10 if ind_1986 >= 807 & ind_1986 <= 817
replace ind_broad_1986 = 11 if ind_1986 >= 828 & ind_1986 <= 899
replace ind_broad_1986 = 12 if ind_1986 >= 907 & ind_1986 <= 947

* 1987
gen ind_broad_1987 = .
replace ind_broad_1987 = 1 if ind_1987 >= 17 & ind_1987 <= 29
replace ind_broad_1987 = 2 if ind_1987 >= 47 & ind_1987 <= 58
replace ind_broad_1987 = 3 if ind_1987 >= 67 & ind_1987 <= 78
replace ind_broad_1987 = 4 if ind_1987 >= 107 & ind_1987 <= 398
replace ind_broad_1987 = 5 if ind_1987 >= 407 & ind_1987 <= 499
replace ind_broad_1987 = 6 if ind_1987 >= 507 & ind_1987 <= 699
replace ind_broad_1987 = 7 if ind_1987 >= 707 & ind_1987 <= 719
replace ind_broad_1987 = 8 if ind_1987 >= 727 & ind_1987 <= 767
replace ind_broad_1987 = 9 if ind_1987 >= 769 & ind_1987 <= 799
replace ind_broad_1987 = 10 if ind_1987 >= 807 & ind_1987 <= 817
replace ind_broad_1987 = 11 if ind_1987 >= 828 & ind_1987 <= 899
replace ind_broad_1987 = 12 if ind_1987 >= 907 & ind_1987 <= 947

* 1988
gen ind_broad_1988 = .
replace ind_broad_1988 = 1 if ind_1988 >= 17 & ind_1988 <= 29
replace ind_broad_1988 = 2 if ind_1988 >= 47 & ind_1988 <= 58
replace ind_broad_1988 = 3 if ind_1988 >= 67 & ind_1988 <= 78
replace ind_broad_1988 = 4 if ind_1988 >= 107 & ind_1988 <= 398
replace ind_broad_1988 = 5 if ind_1988 >= 407 & ind_1988 <= 499
replace ind_broad_1988 = 6 if ind_1988 >= 507 & ind_1988 <= 699
replace ind_broad_1988 = 7 if ind_1988 >= 707 & ind_1988 <= 719
replace ind_broad_1988 = 8 if ind_1988 >= 727 & ind_1988 <= 767
replace ind_broad_1988 = 9 if ind_1988 >= 769 & ind_1988 <= 799
replace ind_broad_1988 = 10 if ind_1988 >= 807 & ind_1988 <= 817
replace ind_broad_1988 = 11 if ind_1988 >= 828 & ind_1988 <= 899
replace ind_broad_1988 = 12 if ind_1988 >= 907 & ind_1988 <= 947

* 1989
gen ind_broad_1989 = .
replace ind_broad_1989 = 1 if ind_1989 >= 17 & ind_1989 <= 29
replace ind_broad_1989 = 2 if ind_1989 >= 47 & ind_1989 <= 58
replace ind_broad_1989 = 3 if ind_1989 >= 67 & ind_1989 <= 78
replace ind_broad_1989 = 4 if ind_1989 >= 107 & ind_1989 <= 398
replace ind_broad_1989 = 5 if ind_1989 >= 407 & ind_1989 <= 499
replace ind_broad_1989 = 6 if ind_1989 >= 507 & ind_1989 <= 699
replace ind_broad_1989 = 7 if ind_1989 >= 707 & ind_1989 <= 719
replace ind_broad_1989 = 8 if ind_1989 >= 727 & ind_1989 <= 767
replace ind_broad_1989 = 9 if ind_1989 >= 769 & ind_1989 <= 799
replace ind_broad_1989 = 10 if ind_1989 >= 807 & ind_1989 <= 817
replace ind_broad_1989 = 11 if ind_1989 >= 828 & ind_1989 <= 899
replace ind_broad_1989 = 12 if ind_1989 >= 907 & ind_1989 <= 947

* 1990
gen ind_broad_1990 = .
replace ind_broad_1990 = 1 if ind_1990 >= 17 & ind_1990 <= 29
replace ind_broad_1990 = 2 if ind_1990 >= 47 & ind_1990 <= 58
replace ind_broad_1990 = 3 if ind_1990 >= 67 & ind_1990 <= 78
replace ind_broad_1990 = 4 if ind_1990 >= 107 & ind_1990 <= 398
replace ind_broad_1990 = 5 if ind_1990 >= 407 & ind_1990 <= 499
replace ind_broad_1990 = 6 if ind_1990 >= 507 & ind_1990 <= 699
replace ind_broad_1990 = 7 if ind_1990 >= 707 & ind_1990 <= 719
replace ind_broad_1990 = 8 if ind_1990 >= 727 & ind_1990 <= 767
replace ind_broad_1990 = 9 if ind_1990 >= 769 & ind_1990 <= 799
replace ind_broad_1990 = 10 if ind_1990 >= 807 & ind_1990 <= 817
replace ind_broad_1990 = 11 if ind_1990 >= 828 & ind_1990 <= 899
replace ind_broad_1990 = 12 if ind_1990 >= 907 & ind_1990 <= 947

* 1991
gen ind_broad_1991 = .
replace ind_broad_1991 = 1 if ind_1991 >= 17 & ind_1991 <= 29
replace ind_broad_1991 = 2 if ind_1991 >= 47 & ind_1991 <= 58
replace ind_broad_1991 = 3 if ind_1991 >= 67 & ind_1991 <= 78
replace ind_broad_1991 = 4 if ind_1991 >= 107 & ind_1991 <= 398
replace ind_broad_1991 = 5 if ind_1991 >= 407 & ind_1991 <= 499
replace ind_broad_1991 = 6 if ind_1991 >= 507 & ind_1991 <= 699
replace ind_broad_1991 = 7 if ind_1991 >= 707 & ind_1991 <= 719
replace ind_broad_1991 = 8 if ind_1991 >= 727 & ind_1991 <= 767
replace ind_broad_1991 = 9 if ind_1991 >= 769 & ind_1991 <= 799
replace ind_broad_1991 = 10 if ind_1991 >= 807 & ind_1991 <= 817
replace ind_broad_1991 = 11 if ind_1991 >= 828 & ind_1991 <= 899
replace ind_broad_1991 = 12 if ind_1991 >= 907 & ind_1991 <= 947

* 1992
gen ind_broad_1992 = .
replace ind_broad_1992 = 1 if ind_1992 >= 17 & ind_1992 <= 29
replace ind_broad_1992 = 2 if ind_1992 >= 47 & ind_1992 <= 58
replace ind_broad_1992 = 3 if ind_1992 >= 67 & ind_1992 <= 78
replace ind_broad_1992 = 4 if ind_1992 >= 107 & ind_1992 <= 398
replace ind_broad_1992 = 5 if ind_1992 >= 407 & ind_1992 <= 499
replace ind_broad_1992 = 6 if ind_1992 >= 507 & ind_1992 <= 699
replace ind_broad_1992 = 7 if ind_1992 >= 707 & ind_1992 <= 719
replace ind_broad_1992 = 8 if ind_1992 >= 727 & ind_1992 <= 767
replace ind_broad_1992 = 9 if ind_1992 >= 769 & ind_1992 <= 799
replace ind_broad_1992 = 10 if ind_1992 >= 807 & ind_1992 <= 817
replace ind_broad_1992 = 11 if ind_1992 >= 828 & ind_1992 <= 899
replace ind_broad_1992 = 12 if ind_1992 >= 907 & ind_1992 <= 947

* 1993
gen ind_broad_1993 = .
replace ind_broad_1993 = 1 if ind_1993 >= 17 & ind_1993 <= 29
replace ind_broad_1993 = 2 if ind_1993 >= 47 & ind_1993 <= 58
replace ind_broad_1993 = 3 if ind_1993 >= 67 & ind_1993 <= 78
replace ind_broad_1993 = 4 if ind_1993 >= 107 & ind_1993 <= 398
replace ind_broad_1993 = 5 if ind_1993 >= 407 & ind_1993 <= 499
replace ind_broad_1993 = 6 if ind_1993 >= 507 & ind_1993 <= 699
replace ind_broad_1993 = 7 if ind_1993 >= 707 & ind_1993 <= 719
replace ind_broad_1993 = 8 if ind_1993 >= 727 & ind_1993 <= 767
replace ind_broad_1993 = 9 if ind_1993 >= 769 & ind_1993 <= 799
replace ind_broad_1993 = 10 if ind_1993 >= 807 & ind_1993 <= 817
replace ind_broad_1993 = 11 if ind_1993 >= 828 & ind_1993 <= 899
replace ind_broad_1993 = 12 if ind_1993 >= 907 & ind_1993 <= 947

* Apply labels
label define ind_broad_lbl ///
    1 "Agriculture/Forestry/Fisheries" ///
    2 "Mining" ///
    3 "Construction" ///
    4 "Manufacturing" ///
    5 "Transport/Communication/Utilities" ///
    6 "Wholesale/Retail Trade" ///
    7 "Finance/Insurance/Real Estate" ///
    8 "Business/Repair Services" ///
    9 "Personal Services" ///
    10 "Entertainment/Recreation" ///
    11 "Professional Services" ///
    12 "Public Administration"

label values ind_broad_1979 ind_broad_lbl
label values ind_broad_1980 ind_broad_lbl
label values ind_broad_1981 ind_broad_lbl
label values ind_broad_1982 ind_broad_lbl
label values ind_broad_1983 ind_broad_lbl
label values ind_broad_1984 ind_broad_lbl
label values ind_broad_1985 ind_broad_lbl
label values ind_broad_1986 ind_broad_lbl
label values ind_broad_1987 ind_broad_lbl
label values ind_broad_1988 ind_broad_lbl
label values ind_broad_1989 ind_broad_lbl
label values ind_broad_1990 ind_broad_lbl
label values ind_broad_1991 ind_broad_lbl
label values ind_broad_1992 ind_broad_lbl
label values ind_broad_1993 ind_broad_lbl

di ""
di "Broad occupation distribution (1990):"
tab occ_broad_1990

di ""
di "Broad industry distribution (1990):"
tab ind_broad_1990

* Marital status
rename r0217500 mstat_1979
rename r0405600 mstat_1980
rename r0618600 mstat_1981
rename r0898400 mstat_1982
rename r1144900 mstat_1983
rename r1520100 mstat_1984
rename r1890800 mstat_1985
rename r2257900 mstat_1986
rename r2445300 mstat_1987
rename r2870900 mstat_1988
rename r3074600 mstat_1989
rename r3401300 mstat_1990
rename r3656700 mstat_1991
rename r4007200 mstat_1992
rename r4418300 mstat_1993
rename r5081300 mstat_1994
rename r5166600 mstat_1996
rename r6479200 mstat_1998
rename r7006900 mstat_2000
rename r7704200 mstat_2002
rename r8496600 mstat_2004
rename t0988400 mstat_2006
rename t2210400 mstat_2008
rename t3108300 mstat_2010
rename t4112800 mstat_2012
rename t5023200 mstat_2014
rename t5771100 mstat_2016
rename t8219200 mstat_2018
rename t8788400 mstat_2020
rename t9300200 mstat_2022

* Page
rename r0216500 page_1979
rename r0406510 page_1980
rename r0619010 page_1981
rename r0898310 page_1982
rename r1145110 page_1983
rename r1520310 page_1984
rename r1891010 page_1985
rename r2258110 page_1986
rename r2445510 page_1987
rename r2871300 page_1988
rename r3075000 page_1989
rename r3401700 page_1990
rename r3657100 page_1991
rename r4007600 page_1992
rename r4418700 page_1993
rename r5081700 page_1994
rename r5167000 page_1996
rename r6479800 page_1998
rename r7007500 page_2000
rename r7704800 page_2002
rename r8497200 page_2004
rename t0989000 page_2006
rename t2210800 page_2008
rename t3108700 page_2010
rename t4113200 page_2012
rename t5023600 page_2014
rename t5771500 page_2016
rename t8219400 page_2018
rename t8788600 page_2020
rename t9300400 page_2022

* Depx
rename r0218001 depx_1979
rename r0407601 depx_1980
rename r0647101 depx_1981
rename r0898838 depx_1982
rename r1146830 depx_1983
rename r1522037 depx_1984
rename r1892737 depx_1985
rename r2259837 depx_1986
rename r2448037 depx_1987
rename r2877600 depx_1988
rename r3076842 depx_1989
rename r3407700 depx_1990
rename r3659047 depx_1991
rename r4009447 depx_1992
rename r4444700 depx_1993
rename r5087500 depx_1994
rename r5172800 depx_1996
rename r6486400 depx_1998
rename r7014200 depx_2000
rename r7711800 depx_2002
rename r8504300 depx_2004
rename t0996000 depx_2006
rename t2217800 depx_2008
rename t3115800 depx_2010
rename t4120300 depx_2012
rename t5031500 depx_2014
rename t5779700 depx_2016
rename t8226800 depx_2018
rename t8796100 depx_2020
rename t9307900 depx_2022

* Wages & salary (IN PAST CALENDAR YEAR)
rename r0155400 pwages_1978
rename r0312300 pwages_1979
rename r0482600 pwages_1980
rename r0782101 pwages_1981
rename r1024001 pwages_1982
rename r1410701 pwages_1983
rename r1778501 pwages_1984
rename r2141601 pwages_1985
rename r2350301 pwages_1986
rename r2722501 pwages_1987
rename r2971401 pwages_1988
rename r3279401 pwages_1989
rename r3559001 pwages_1990
rename r3897101 pwages_1991
rename r4295101 pwages_1992
rename r4982801 pwages_1993
rename r5626201 pwages_1995
rename r6364601 pwages_1997
rename r6909701 pwages_1999
rename r7607800 pwages_2001
rename r8316300 pwages_2003
rename t0912400 pwages_2005
rename t2076700 pwages_2007
rename t3045300 pwages_2009
rename t3977400 pwages_2011
rename t4915800 pwages_2013
rename t5619500 pwages_2015
rename t8115400 pwages_2017
rename t8645700 pwages_2019
rename t9198400 pwages_2021

rename r0155500 swages_1978
rename r0312710 swages_1979
rename r0482910 swages_1980
rename r0784301 swages_1981
rename r1026201 swages_1982
rename r1412901 swages_1983
rename r1780701 swages_1984
rename r2143801 swages_1985
rename r2352501 swages_1986
rename r2724701 swages_1987
rename r2973601 swages_1988
rename r3281601 swages_1989
rename r3561201 swages_1990
rename r3899301 swages_1991
rename r4314401 swages_1992
rename r4996001 swages_1993
rename r5650801 swages_1995
rename r6374901 swages_1997
rename r6917801 swages_1999
rename r7617300 swages_2001
rename r8325800 swages_2003
rename t0920800 swages_2005
rename t2085500 swages_2007
rename t3056000 swages_2009
rename t3987600 swages_2011
rename t4924900 swages_2013
rename t5630100 swages_2015
rename t8135900 swages_2017
rename t8671700 swages_2019
rename t9223100 swages_2021

* Self‐employment income
rename r0156000 psemp_1978
rename r0312600 psemp_1979
rename r0483200 psemp_1980
rename r0782401 psemp_1981
rename r1024301 psemp_1982
rename r1411001 psemp_1983
rename r1778801 psemp_1984
rename r2141901 psemp_1985
rename r2350601 psemp_1986
rename r2722801 psemp_1987
rename r2971701 psemp_1988
rename r3279701 psemp_1989
rename r3559301 psemp_1990
rename r3897401 psemp_1991
rename r4295501 psemp_1992
rename r4983201 psemp_1993
rename r5626601 psemp_1995
rename r6365001 psemp_1997
rename r6911101 psemp_1999
rename r7609000 psemp_2001
rename r8318200 psemp_2003
rename t0913900 psemp_2005
rename t2078800 psemp_2007
rename t3047500 psemp_2009
rename t3979400 psemp_2011
rename t4917800 psemp_2013
rename t5621700 psemp_2015
rename t8116700 psemp_2017
rename t8646800 psemp_2019
rename t9199700 psemp_2021

rename r0156100 ssemp_1978
rename r0313000 ssemp_1979
rename r0483500 ssemp_1980
rename r0784601 ssemp_1981
rename r1026501 ssemp_1982
rename r1413201 ssemp_1983
rename r1781001 ssemp_1984
rename r2144101 ssemp_1985
rename r2352801 ssemp_1986
rename r2725001 ssemp_1987
rename r2973901 ssemp_1988
rename r3281901 ssemp_1989
rename r3561501 ssemp_1990
rename r3899601 ssemp_1991
rename r4314901 ssemp_1992
rename r4996601 ssemp_1993
rename r5651401 ssemp_1995
rename r6375301 ssemp_1997
rename r6919201 ssemp_1999
rename r7618500 ssemp_2001
rename r8328000 ssemp_2003
rename t0922200 ssemp_2005
rename t2087700 ssemp_2007
rename t3058300 ssemp_2009
rename t3989900 ssemp_2011
rename t4927200 ssemp_2013
rename t5632400 ssemp_2015
rename t8137300 ssemp_2017
rename t8673100 ssemp_2019
rename t9224500 ssemp_2021

* UI
rename g0001400 unemp_1978
rename g0009200 unemp_1979
rename g0017000 unemp_1980
rename g0024800 unemp_1981
rename g0032600 unemp_1982
rename g0040400 unemp_1983
rename g0048200 unemp_1984
rename g0056000 unemp_1985
rename g0063800 unemp_1986
rename g0071600 unemp_1987
rename g0079400 unemp_1988
rename g0087200 unemp_1989
rename g0095000 unemp_1990
rename g0102800 unemp_1991
rename g0110600 unemp_1992
rename g0118400 unemp_1993
rename g0119700 unemp_1994
rename g0135200 unemp_1995
rename g0135300 unemp_1996
rename g0150800 unemp_1997
rename g0150900 unemp_1998
rename g0166400 unemp_1999
rename g0166500 unemp_2000
rename g0182000 unemp_2001
rename g0182100 unemp_2002
rename g0197600 unemp_2003
rename g0197700 unemp_2004
rename g0213300 unemp_2005
rename g0213400 unemp_2006
rename g0226700 unemp_2007
rename g0236600 unemp_2008
rename g0241700 unemp_2009
rename g0253800 unemp_2010
rename g0262100 unemp_2011
rename g0269500 unemp_2012
rename g0277000 unemp_2013
rename g0286200 unemp_2014
rename g0293800 unemp_2015
rename g0300700 unemp_2016
rename g0301900 unemp_2017
rename g0317700 unemp_2018
rename g0318800 unemp_2019
rename g0336300 unemp_2020
rename g0337500 unemp_2021
rename g0355400 unemp_2022
rename g0356400 unemp_2023

rename g0002700 sui_1978
rename g0010500 sui_1979
rename g0018300 sui_1980
rename g0026100 sui_1981
rename g0033900 sui_1982
rename g0041700 sui_1983
rename g0049500 sui_1984
rename g0057300 sui_1985
rename g0065100 sui_1986
rename g0072900 sui_1987
rename g0080700 sui_1988
rename g0088500 sui_1989
rename g0096300 sui_1990
rename g0104100 sui_1991
rename g0111900 sui_1992
rename g0121000 sui_1993
rename g0122300 sui_1994
rename g0137900 sui_1996
rename g0153400 sui_1997
rename g0153500 sui_1998
rename g0169100 sui_2000
rename g0184600 sui_2001
rename g0184700 sui_2002
rename g0200200 sui_2003
rename g0200300 sui_2004
rename g0215900 sui_2005
rename g0216000 sui_2006
rename g0226900 sui_2007
rename g0237600 sui_2008
rename g0241800 sui_2009
rename g0255100 sui_2010
rename g0263400 sui_2011
rename g0270800 sui_2012
rename g0278000 sui_2013
rename g0287500 sui_2014
rename g0294900 sui_2015
rename g0303200 sui_2016
rename g0304400 sui_2017
rename g0320100 sui_2018
rename g0321200 sui_2019
rename g0338800 sui_2020
rename g0340000 sui_2021
rename g0357700 sui_2022
rename g0358700 sui_2023

* Other non‐property income

* Gross Social Security
rename g0006600 gssi_1978
rename g0014400 gssi_1979
rename g0022200 gssi_1980
rename g0030000 gssi_1981
rename g0037800 gssi_1982
rename g0045600 gssi_1983
rename g0053400 gssi_1984
rename g0061200 gssi_1985
rename g0069000 gssi_1986
rename g0076800 gssi_1987
rename g0084600 gssi_1988
rename g0092400 gssi_1989
rename g0100200 gssi_1990
rename g0108000 gssi_1991
rename g0115800 gssi_1992
rename g0128800 gssi_1993
rename g0130100 gssi_1994
rename g0145600 gssi_1995
rename g0145700 gssi_1996
rename g0161200 gssi_1997
rename g0161300 gssi_1998
rename g0176800 gssi_1999
rename g0176900 gssi_2000
rename g0192400 gssi_2001
rename g0192500 gssi_2002
rename g0208000 gssi_2003
rename g0208100 gssi_2004
rename g0223700 gssi_2005
rename g0223800 gssi_2006
rename g0227700 gssi_2007
rename g0240600 gssi_2008
rename g0242000 gssi_2009
rename g0259000 gssi_2010
rename g0267100 gssi_2011
rename g0274700 gssi_2012
rename g0280900 gssi_2013
rename g0291400 gssi_2014
rename g0298200 gssi_2015
rename g0310600 gssi_2016
rename g0311800 gssi_2017
rename g0327300 gssi_2018
rename g0328400 gssi_2019
rename g0346400 gssi_2020
rename g0347700 gssi_2021
rename g0364500 gssi_2022
rename g0365500 gssi_2023

* Non-taxable transfers (AFDC + food stamps)
* Veteran benefits REMOVED due to missing data

* AFDC
rename g0004000 afdc_1978
rename g0011800 afdc_1979
rename g0019600 afdc_1980
rename g0027400 afdc_1981
rename g0035200 afdc_1982
rename g0043000 afdc_1983
rename g0050800 afdc_1984
rename g0058600 afdc_1985
rename g0066400 afdc_1986
rename g0074200 afdc_1987
rename g0082000 afdc_1988
rename g0089800 afdc_1989
rename g0097600 afdc_1990
rename g0105400 afdc_1991
rename g0113200 afdc_1992
rename g0123600 afdc_1993
rename g0124900 afdc_1994
rename g0140400 afdc_1995
rename g0140500 afdc_1996
rename g0156000 afdc_1997
rename g0156100 afdc_1998
rename g0171600 afdc_1999
rename g0171700 afdc_2000
rename g0187200 afdc_2001
rename g0187300 afdc_2002
rename g0202800 afdc_2003
rename g0202900 afdc_2004
rename g0218500 afdc_2005
rename g0218600 afdc_2006
rename g0227100 afdc_2007
rename g0238600 afdc_2008
rename g0248900 afdc_2009
rename g0256400 afdc_2010
rename g0264700 afdc_2011
rename g0272100 afdc_2012
rename g0278900 afdc_2013
rename g0288800 afdc_2014
rename g0296000 afdc_2015
rename g0305700 afdc_2016
rename g0306800 afdc_2017
rename g0322500 afdc_2018
rename g0323600 afdc_2019
rename g0341300 afdc_2020
rename g0342500 afdc_2021
rename g0360000 afdc_2022
rename g0360900 afdc_2023

* FOOD STAMPS
rename g0005300 foodstamp_1978
rename g0013100 foodstamp_1979
rename g0020900 foodstamp_1980
rename g0028700 foodstamp_1981
rename g0036500 foodstamp_1982
rename g0044300 foodstamp_1983
rename g0052100 foodstamp_1984
rename g0059900 foodstamp_1985
rename g0067700 foodstamp_1986
rename g0075500 foodstamp_1987
rename g0083300 foodstamp_1988
rename g0091100 foodstamp_1989
rename g0098900 foodstamp_1990
rename g0106700 foodstamp_1991
rename g0114500 foodstamp_1992
rename g0126200 foodstamp_1993
rename g0127500 foodstamp_1994
rename g0143000 foodstamp_1995
rename g0143100 foodstamp_1996
rename g0158600 foodstamp_1997
rename g0158700 foodstamp_1998
rename g0174200 foodstamp_1999
rename g0174300 foodstamp_2000
rename g0189800 foodstamp_2001
rename g0189900 foodstamp_2002
rename g0205400 foodstamp_2003
rename g0205500 foodstamp_2004
rename g0221100 foodstamp_2005
rename g0221200 foodstamp_2006
rename g0227400 foodstamp_2007
rename g0239600 foodstamp_2008
rename g0241900 foodstamp_2009
rename g0257700 foodstamp_2010
rename g0260500 foodstamp_2011
rename g0273400 foodstamp_2012
rename g0279900 foodstamp_2013
rename g0290100 foodstamp_2014
rename g0297100 foodstamp_2015
rename g0308100 foodstamp_2016
rename g0309300 foodstamp_2017
rename g0324900 foodstamp_2018
rename g0326000 foodstamp_2019
rename g0343800 foodstamp_2020
rename g0345100 foodstamp_2021
rename g0362200 foodstamp_2022
rename g0363200 foodstamp_2023

* CALCULATE TRANSFERS (Excluding Vetben)
gen transfers_1978 = afdc_1978 + foodstamp_1978 
gen transfers_1979 = afdc_1979 + foodstamp_1979 
gen transfers_1980 = afdc_1980 + foodstamp_1980 
gen transfers_1981 = afdc_1981 + foodstamp_1981 
gen transfers_1982 = afdc_1982 + foodstamp_1982 
gen transfers_1983 = afdc_1983 + foodstamp_1983 
gen transfers_1984 = afdc_1984 + foodstamp_1984 
gen transfers_1985 = afdc_1985 + foodstamp_1985
gen transfers_1986 = afdc_1986 + foodstamp_1986
gen transfers_1987 = afdc_1987 + foodstamp_1987
gen transfers_1988 = afdc_1988 + foodstamp_1988
gen transfers_1989 = afdc_1989 + foodstamp_1989
gen transfers_1990 = afdc_1990 + foodstamp_1990
gen transfers_1991 = afdc_1991 + foodstamp_1991
gen transfers_1992 = afdc_1992 + foodstamp_1992
gen transfers_1993 = afdc_1993 + foodstamp_1993
gen transfers_1994 = afdc_1994 + foodstamp_1994 
gen transfers_1995 = afdc_1995 + foodstamp_1995
gen transfers_1996 = afdc_1996 + foodstamp_1996 
gen transfers_1997 = afdc_1997 + foodstamp_1997
gen transfers_1998 = afdc_1998 + foodstamp_1998 
gen transfers_1999 = afdc_1999 + foodstamp_1999
gen transfers_2000 = afdc_2000 + foodstamp_2000 
gen transfers_2001 = afdc_2001 + foodstamp_2001
gen transfers_2002 = afdc_2002 + foodstamp_2002
gen transfers_2003 = afdc_2003 + foodstamp_2003
gen transfers_2004 = afdc_2004 + foodstamp_2004
gen transfers_2005 = afdc_2005 + foodstamp_2005
gen transfers_2006 = afdc_2006 + foodstamp_2006
gen transfers_2007 = afdc_2007 + foodstamp_2007
gen transfers_2008 = afdc_2008 + foodstamp_2008
gen transfers_2009 = afdc_2009 + foodstamp_2009
gen transfers_2010 = afdc_2010 + foodstamp_2010
gen transfers_2011 = afdc_2011 + foodstamp_2011
gen transfers_2012 = afdc_2012 + foodstamp_2012
gen transfers_2013 = afdc_2013 + foodstamp_2013
gen transfers_2014 = afdc_2014 + foodstamp_2014
gen transfers_2015 = afdc_2015 + foodstamp_2015
gen transfers_2016 = afdc_2016 + foodstamp_2016 
gen transfers_2017 = afdc_2017 + foodstamp_2017
gen transfers_2018 = afdc_2018 + foodstamp_2018 
gen transfers_2019 = afdc_2019 + foodstamp_2019
gen transfers_2020 = afdc_2020 + foodstamp_2020 
gen transfers_2021 = afdc_2021 + foodstamp_2021
gen transfers_2022 = afdc_2022 + foodstamp_2022 
gen transfers_2023 = afdc_2023 + foodstamp_2023

drop afdc_* foodstamp_* 
* REMOVED: Mortgage Interest Deductions
* REMOVED: Dividend Income
* REMOVED: Taxable Interest Income

* Spouse & children DOB (month/year pairs)
rename r4506800 spomonth_1994
rename r4506801 spoyear_1994
rename r5206700 spomonth_1996
rename r5206701 spoyear_1996
rename r5805700 spomonth_1998
rename r5805701 spoyear_1998
rename r6538000 spomonth_2000
rename r6538001 spoyear_2000
rename r7101200 spomonth_2002
rename r7101201 spoyear_2002
rename r7808100 spomonth_2004
rename r7808101 spoyear_2004
rename t0012000 spomonth_2006
rename t0012001 spoyear_2006
rename t1210500 spomonth_2008
rename t1210501 spoyear_2008
rename t2270400 spomonth_2010
rename t2270401 spoyear_2010
rename t3206900 spomonth_2012
rename t3206901 spoyear_2012
rename t4194900 spomonth_2014
rename t4194901 spoyear_2014
rename t5173500 spomonth_2016
rename t5173501 spoyear_2016
rename t7741300 spomonth_2018
rename t7741301 spoyear_2018
rename t8352600 spomonth_2020
rename t8352601 spoyear_2020
rename t8904500 spomonth_2022
rename t8904501 spoyear_2022

rename r5083601 child1month_1994
rename r5083602 child1year_1994
rename r5168901 child1month_1996
rename r5168902 child1year_1996
rename r6481701 child1month_1998
rename r6481702 child1year_1998
rename r7009401 child1month_2000
rename r7009402 child1year_2000
rename r7706701 child1month_2002
rename r7706702 child1year_2002
rename r8499101 child1month_2004
rename r8499102 child1year_2004
rename r9900001 child1month_2006
rename r9900002 child1year_2006
rename t0990801 child1month_2008
rename t0990802 child1year_2008
rename t2212601 child1month_2010
rename t2212602 child1year_2010
rename t3110501 child1month_2012
rename t3110502 child1year_2012
rename t4115001 child1month_2014
rename t4115002 child1year_2014
rename t5026301 child1month_2016
rename t5026302 child1year_2016
rename t5774401 child1month_2018
rename t5774402 child1year_2018
rename t8790801 child1month_2020
rename t8790802 child1year_2020
rename t9302601 child1month_2022
rename t9302602 child1year_2022

rename r5084101 child2month_1994
rename r5084102 child2year_1994
rename r5169401 child2month_1996
rename r5169402 child2year_1996
rename r6482201 child2month_1998
rename r6482202 child2year_1998
rename r7009901 child2month_2000
rename r7009902 child2year_2000
rename r7707201 child2month_2002
rename r7707202 child2year_2002
rename r8499601 child2month_2004
rename r8499602 child2year_2004
rename r9900801 child2month_2006
rename r9900802 child2year_2006
rename t0991301 child2month_2008
rename t0991302 child2year_2008
rename t2213101 child2month_2010
rename t2213102 child2year_2010
rename t3111001 child2month_2012
rename t3111002 child2year_2012
rename t4115501 child2month_2014
rename t4115502 child2year_2014
rename t5026801 child2month_2016
rename t5026802 child2year_2016
rename t5774901 child2month_2018
rename t5774902 child2year_2018
rename t8791301 child2month_2020
rename t8791302 child2year_2020
rename t9303101 child2month_2022
rename t9303102 child2year_2022

rename r5084601 child3month_1994
rename r5084602 child3year_1994
rename r5169901 child3month_1996
rename r5169902 child3year_1996
rename r6482701 child3month_1998
rename r6482702 child3year_1998
rename r7010401 child3month_2000
rename r7010402 child3year_2000
rename r7707701 child3month_2002
rename r7707702 child3year_2002
rename r8500101 child3month_2004
rename r8500102 child3year_2004
rename r9901601 child3month_2006
rename r9901602 child3year_2006
rename t0991801 child3month_2008
rename t0991802 child3year_2008
rename t2213601 child3month_2010
rename t2213602 child3year_2010
rename t3111501 child3month_2012
rename t3111502 child3year_2012
rename t4116001 child3month_2014
rename t4116002 child3year_2014
rename t5027301 child3month_2016
rename t5027302 child3year_2016
rename t5775401 child3month_2018
rename t5775402 child3year_2018
rename t8791801 child3month_2020
rename t8791802 child3year_2020
rename t9303601 child3month_2022
rename t9303602 child3year_2022

* Note: For 1994, spouse/child DOB variables are only available for the survey year (1994), not the income year (1993)
*Critical to align demographic variables with income variables for biennial years, since we use spouse/child DOB to calculate dependent ages, which are used in tax unit definitions
di "=============================================================================="
di "REALIGNING DEMOGRAPHIC VARIABLES FOR BIENNIAL YEARS"
di "=============================================================================="

* Rename biennial demographic variables: SURVEY YEAR → INCOME YEAR
* page: Survey year → Income year (survey_year - 1)
rename page_1996 page_1995
rename page_1998 page_1997
rename page_2000 page_1999
rename page_2002 page_2001
rename page_2004 page_2003
rename page_2006 page_2005
rename page_2008 page_2007
rename page_2010 page_2009
rename page_2012 page_2011
rename page_2014 page_2013
rename page_2016 page_2015
rename page_2018 page_2017
rename page_2020 page_2019
rename page_2022 page_2021

* mstat: Survey year → Income year
rename mstat_1996 mstat_1995
rename mstat_1998 mstat_1997
rename mstat_2000 mstat_1999
rename mstat_2002 mstat_2001
rename mstat_2004 mstat_2003
rename mstat_2006 mstat_2005
rename mstat_2008 mstat_2007
rename mstat_2010 mstat_2009
rename mstat_2012 mstat_2011
rename mstat_2014 mstat_2013
rename mstat_2016 mstat_2015
rename mstat_2018 mstat_2017
rename mstat_2020 mstat_2019
rename mstat_2022 mstat_2021

* depx: Survey year → Income year
rename depx_1996 depx_1995
rename depx_1998 depx_1997
rename depx_2000 depx_1999
rename depx_2002 depx_2001
rename depx_2004 depx_2003
rename depx_2006 depx_2005
rename depx_2008 depx_2007
rename depx_2010 depx_2009
rename depx_2012 depx_2011
rename depx_2014 depx_2013
rename depx_2016 depx_2015
rename depx_2018 depx_2017
rename depx_2020 depx_2019
rename depx_2022 depx_2021

* Also need to align spouse/child DOB variables for biennial years
* These are used to calculate dependent ages

* spomonth/spoyear
rename spomonth_1996 spomonth_1995
rename spoyear_1996 spoyear_1995
rename spomonth_1998 spomonth_1997
rename spoyear_1998 spoyear_1997
rename spomonth_2000 spomonth_1999
rename spoyear_2000 spoyear_1999
rename spomonth_2002 spomonth_2001
rename spoyear_2002 spoyear_2001
rename spomonth_2004 spomonth_2003
rename spoyear_2004 spoyear_2003
rename spomonth_2006 spomonth_2005
rename spoyear_2006 spoyear_2005
rename spomonth_2008 spomonth_2007
rename spoyear_2008 spoyear_2007
rename spomonth_2010 spomonth_2009
rename spoyear_2010 spoyear_2009
rename spomonth_2012 spomonth_2011
rename spoyear_2012 spoyear_2011
rename spomonth_2014 spomonth_2013
rename spoyear_2014 spoyear_2013
rename spomonth_2016 spomonth_2015
rename spoyear_2016 spoyear_2015
rename spomonth_2018 spomonth_2017
rename spoyear_2018 spoyear_2017
rename spomonth_2020 spomonth_2019
rename spoyear_2020 spoyear_2019
rename spomonth_2022 spomonth_2021
rename spoyear_2022 spoyear_2021

* child1month/child1year
rename child1month_1996 child1month_1995
rename child1year_1996 child1year_1995
rename child1month_1998 child1month_1997
rename child1year_1998 child1year_1997
rename child1month_2000 child1month_1999
rename child1year_2000 child1year_1999
rename child1month_2002 child1month_2001
rename child1year_2002 child1year_2001
rename child1month_2004 child1month_2003
rename child1year_2004 child1year_2003
rename child1month_2006 child1month_2005
rename child1year_2006 child1year_2005
rename child1month_2008 child1month_2007
rename child1year_2008 child1year_2007
rename child1month_2010 child1month_2009
rename child1year_2010 child1year_2009
rename child1month_2012 child1month_2011
rename child1year_2012 child1year_2011
rename child1month_2014 child1month_2013
rename child1year_2014 child1year_2013
rename child1month_2016 child1month_2015
rename child1year_2016 child1year_2015
rename child1month_2018 child1month_2017
rename child1year_2018 child1year_2017
rename child1month_2020 child1month_2019
rename child1year_2020 child1year_2019
rename child1month_2022 child1month_2021
rename child1year_2022 child1year_2021

* child2month/child2year
rename child2month_1996 child2month_1995
rename child2year_1996 child2year_1995
rename child2month_1998 child2month_1997
rename child2year_1998 child2year_1997
rename child2month_2000 child2month_1999
rename child2year_2000 child2year_1999
rename child2month_2002 child2month_2001
rename child2year_2002 child2year_2001
rename child2month_2004 child2month_2003
rename child2year_2004 child2year_2003
rename child2month_2006 child2month_2005
rename child2year_2006 child2year_2005
rename child2month_2008 child2month_2007
rename child2year_2008 child2year_2007
rename child2month_2010 child2month_2009
rename child2year_2010 child2year_2009
rename child2month_2012 child2month_2011
rename child2year_2012 child2year_2011
rename child2month_2014 child2month_2013
rename child2year_2014 child2year_2013
rename child2month_2016 child2month_2015
rename child2year_2016 child2year_2015
rename child2month_2018 child2month_2017
rename child2year_2018 child2year_2017
rename child2month_2020 child2month_2019
rename child2year_2020 child2year_2019
rename child2month_2022 child2month_2021
rename child2year_2022 child2year_2021

* child3month/child3year
rename child3month_1996 child3month_1995
rename child3year_1996 child3year_1995
rename child3month_1998 child3month_1997
rename child3year_1998 child3year_1997
rename child3month_2000 child3month_1999
rename child3year_2000 child3year_1999
rename child3month_2002 child3month_2001
rename child3year_2002 child3year_2001
rename child3month_2004 child3month_2003
rename child3year_2004 child3year_2003
rename child3month_2006 child3month_2005
rename child3year_2006 child3year_2005
rename child3month_2008 child3month_2007
rename child3year_2008 child3year_2007
rename child3month_2010 child3month_2009
rename child3year_2010 child3year_2009
rename child3month_2012 child3month_2011
rename child3year_2012 child3year_2011
rename child3month_2014 child3month_2013
rename child3year_2014 child3year_2013
rename child3month_2016 child3month_2015
rename child3year_2016 child3year_2015
rename child3month_2018 child3month_2017
rename child3year_2018 child3year_2017
rename child3month_2020 child3month_2019
rename child3year_2020 child3year_2019
rename child3month_2022 child3month_2021
rename child3year_2022 child3year_2021

di ""
di "Demographic variables realigned to income years."
di "Now the reshape will correctly match demographics to income data."
di ""


* Reshape Wide to Long by year
* Note: Removed mortgage_, dividends_, intrec_ from list
reshape long ///
    unemp_ mstat_ page_ depx_ pwages_ swages_ ///
    psemp_ ssemp_ sui_ gssi_ transfers_ nonprop_ ///
    pensions_ rentpaid_ ///
    spomonth_ spoyear_ ///
    child1month_ child1year_ ///
    child2month_ child2year_ ///
    child3month_ child3year_ ///
    hrs_ cumhrs_, ///
    i(taxsimid) j(year)

* turn year into numeric
destring year, replace

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

* Rename to TAXSIM's exact input names
rename unemp_     pui
rename sui_       sui
rename pwages_    pwages
rename swages_    swages
rename psemp_     psemp
rename ssemp_     ssemp
rename gssi_      gssi
rename transfers_ transfers
rename nonprop_   nonprop
rename pensions_  pensions
rename rentpaid_  rentpaid
rename mstat_     mstat
rename page_      page
rename depx_      depx
rename hrs_       hrs
rename cumhrs_    cumhrs

* Removed: mortgage, dividends, intrec

* Build dependent‐age counts
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
replace ssemp = 0 if mstat != 2


foreach v in opt1 opt1v opt2 opt2v {
    gen `v' = 0
}

gen otherprop = 0
gen stcg      = 0
gen ltcg      = 0
gen proptax   = 0
gen otheritem = 0
gen childcare = 0
gen pprofinc  = 0
gen sprofinc  = 0
gen scorp     = 0
gen pbusinc   = 0
gen sbusinc   = 0

* Zero‐fill any remaining missing inputs
* Removed: mortgage, dividends, intrec from list
foreach v in pui sui pwages swages psemp ssemp ///
             gssi transfers nonprop ///
             pensions rentpaid ///
             mstat page depx stcg ltcg proptax ///
             otheritem childcare pprofinc sprofinc scorp {
    replace `v' = 0 if missing(`v')
}

local survvars page depx pui pwages swages pbusinc sbusinc sui gssi ///
                transfers nonprop pensions ///
                rentpaid

foreach v of local survvars {
    replace `v' = 0 if `v' < 0
}

* SKILL VS SIGNALING: Variable Construction
*The code creates these new variables:
*- pot_exp          : Potential experience (age - education - 6)
*- pot_exp2, pot_exp3: Experience squared and cubed
*- early_career     : Indicator for first 10 years of experience
*- afqt             : Best available AFQT score
*- afqt_std         : Standardized AFQT (mean=0, sd=1)
*- afqt_quartile    : AFQT quartile (1-4)
*- educ_years       : Years of education
*- hs_diploma, ba_degree, grad_degree: Degree completion dummies
*- recent_hrs       : Hours worked in most recent period
*- log_recent_hrs   : Log of recent hours
*- exp_bin          : Experience bins (5-year intervals)

* 1) Create proper potential experience using education
*    Experience = Age - Years of Education - 6
*    (6 is the typical school starting age)

gen pot_exp = page - max_education - 6 if !missing(page) & !missing(max_education)
replace pot_exp = 0 if pot_exp < 0 & !missing(pot_exp)
replace pot_exp = . if page < 16 | page > 65
label var pot_exp "Potential experience (age - education - 6)"

* 2) Create experience squared and cubed for Mincer regressions
gen pot_exp2 = pot_exp^2
gen pot_exp3 = pot_exp^3
label var pot_exp2 "Potential experience squared"
label var pot_exp3 "Potential experience cubed"

* 3) Create early career indicator (first 10 years of potential experience)
gen early_career = (pot_exp <= 10) if !missing(pot_exp)
label var early_career "Early career (0-10 years potential experience)"

* 4) Create AFQT variable (use 2006 revised percentile, most recent revision)
*    Fall back to 1989 or 1980 if missing
gen afqt = afqt_pct_2006
replace afqt = afqt_pct_1989 if missing(afqt)
replace afqt = afqt_pct_1980 if missing(afqt)
label var afqt "AFQT percentile (best available revision)"

* 5) Create AFQT quartiles for heterogeneity analysis
*    Note: AFQT is time-invariant, so we calculate quartiles on unique individuals
preserve
keep taxsimid afqt
duplicates drop taxsimid, force
xtile afqt_quartile = afqt, nq(4)
tempfile afqt_q
save `afqt_q', replace
restore

merge m:1 taxsimid using `afqt_q', keep(master match) nogen

label define afqt_q_lbl 1 "Q1 (Lowest)" 2 "Q2" 3 "Q3" 4 "Q4 (Highest)"
label values afqt_quartile afqt_q_lbl
label var afqt_quartile "AFQT quartile"

* 6) Standardize AFQT for regression (mean=0, sd=1)
*    Again, calculate on unique individuals then merge back
preserve
keep taxsimid afqt
duplicates drop taxsimid, force
summarize afqt
gen afqt_std = (afqt - r(mean)) / r(sd) if !missing(afqt)
keep taxsimid afqt_std
tempfile afqt_s
save `afqt_s', replace
restore

merge m:1 taxsimid using `afqt_s', keep(master match) nogen
label var afqt_std "AFQT standardized (mean=0, sd=1)"

* 7) Create education categories for sheepskin analysis
gen educ_years = max_education
label var educ_years "Years of education"

* Degree completion dummies (sheepskin effects)
gen hs_diploma = (max_education == 12) if !missing(max_education)
gen some_coll = (max_education >= 13 & max_education <= 15) if !missing(max_education)
gen ba_degree = (max_education == 16) if !missing(max_education)
gen grad_degree = (max_education >= 17) if !missing(max_education)

label var hs_diploma "Completed exactly 12 years (HS diploma)"
label var some_coll "13-15 years (some college, no BA)"
label var ba_degree "Completed exactly 16 years (BA degree)"
label var grad_degree "17+ years (graduate degree)"

* 8) Create lagged hours for signaling analysis
*    We need hours from previous period to separate "recent signaling" from cumulative learning
*    Sort by person and year first
sort taxsimid year

* Create lagged cumulative hours (previous observation's cumhrs)
by taxsimid: gen cumhrs_lag = cumhrs[_n-1]
label var cumhrs_lag "Cumulative hours (lagged one survey period)"

* Recent hours = current cumhrs - lagged cumhrs
* This captures hours worked in the most recent period
gen recent_hrs = cumhrs - cumhrs_lag if !missing(cumhrs) & !missing(cumhrs_lag)
replace recent_hrs = hrs if missing(recent_hrs) & !missing(hrs)
label var recent_hrs "Hours worked in most recent period"

* 9) Create log versions for elasticity analysis
gen log_recent_hrs = ln(recent_hrs) if recent_hrs > 0
label var log_recent_hrs "Log of recent hours"

* 10) Create experience bins for variance analysis
gen exp_bin = .
replace exp_bin = 1 if pot_exp >= 0 & pot_exp <= 5
replace exp_bin = 2 if pot_exp > 5 & pot_exp <= 10
replace exp_bin = 3 if pot_exp > 10 & pot_exp <= 15
replace exp_bin = 4 if pot_exp > 15 & pot_exp <= 20
replace exp_bin = 5 if pot_exp > 20 & pot_exp <= 25
replace exp_bin = 6 if pot_exp > 25 & pot_exp <= 30
replace exp_bin = 7 if pot_exp > 30 & !missing(pot_exp)

label define exp_bin_lbl 1 "0-5 yrs" 2 "6-10 yrs" 3 "11-15 yrs" 4 "16-20 yrs" ///
                         5 "21-25 yrs" 6 "26-30 yrs" 7 "30+ yrs"
label values exp_bin exp_bin_lbl
label var exp_bin "Experience bin (5-year intervals)"

di ""
di "=============================================================================="
di "SKILL VS SIGNALING VARIABLES CREATED"
di "=============================================================================="
di ""
di "Key variables for analysis:"
di "  pot_exp        - Potential experience (age - education - 6)"
di "  afqt_std       - Standardized AFQT score"
di "  afqt_quartile  - AFQT quartile (1-4)"
di "  early_career   - Indicator for first 10 years of experience"
di "  recent_hrs     - Hours worked in most recent period"
di "  exp_bin        - Experience bins for variance analysis"
di ""

* change pui to ui, because seems to read ui only
gen double ui = pui

save "nlsy_long_pre_taxsim.dta", replace

do Two_Period_Analysis.do

do EDA_Wage_Analysis.do

do Skill_vs_Signal_Analysis.do

