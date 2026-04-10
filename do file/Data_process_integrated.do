clear all
set more off

*==============================================================================
* INTEGRATED DATA PROCESSING DO FILE
* Includes: Original NLSY data + Demographics + Hours Worked + Cumulative Hours
*==============================================================================

* 1) Import the CSV (one row per person)
import delimited "NLSY_All_Data.csv", varnames(1) clear
rename r0000100 taxsimid
save "base_data.dta", replace

* 2) Import the left-out variables
import delimited "left_out.csv", varnames(1) clear
rename r0000100 taxsimid
save "left_out.dta", replace

* 3) Merge the two datasets by respondent ID
use "base_data.dta", clear
merge 1:1 taxsimid using "left_out.dta"

tab _merge
drop _merge

save "merged_data.dta", replace

*==============================================================================
* NEW SECTION: IMPORT AND MERGE DEMOGRAPHIC & HOURS DATA
*==============================================================================

* Import the demographic/hours CSV
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

*==============================================================================
* RENAME TIME-INVARIANT DEMOGRAPHIC VARIABLES
*==============================================================================

* Race/Ethnicity (1=Hispanic, 2=Black, 3=Non-Black Non-Hispanic)
rename r0214700 race_ethnicity

* Sex (1=Male, 2=Female)
rename r0214800 sex

* Sample type
rename r0173600 sample_id

* AFQT scores (all measured in 1981)
rename r0618200 afqt_pct_1980    // Original 1980 percentile
rename r0618300 afqt_pct_1989    // 1989 revised percentile
rename r0618301 afqt_pct_2006    // 2006 revised percentile (RECOMMENDED)

*==============================================================================
* RENAME HIGHEST GRADE COMPLETED VARIABLES
*==============================================================================

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

*==============================================================================
* RENAME HOURS WORKED VARIABLES
* CRITICAL: NLSY asks about PREVIOUS calendar year, so we shift naming
* hrs_YYYY survey asks about year YYYY-1 work, rename to match income timing
*==============================================================================

* Hours from 1979 survey (about 1978 work) -> hrs_1978
rename r0215710 hrs_1978
* Hours from 1980 survey (about 1979 work) -> hrs_1979
rename r0407300 hrs_1979
* Hours from 1981 survey (about 1980 work) -> hrs_1980
rename r0646600 hrs_1980
* Hours from 1982 survey (about 1981 work) -> hrs_1981
rename r0896800 hrs_1981
* Hours from 1983 survey (about 1982 work) -> hrs_1982
rename r1145200 hrs_1982
* Hours from 1984 survey (about 1983 work) -> hrs_1983
rename r1520400 hrs_1983
* Hours from 1985 survey (about 1984 work) -> hrs_1984
rename r1891100 hrs_1984
* Hours from 1986 survey (about 1985 work) -> hrs_1985
rename r2258200 hrs_1985
* Hours from 1987 survey (about 1986 work) -> hrs_1986
rename r2445600 hrs_1986
* Hours from 1988 survey (about 1987 work) -> hrs_1987
rename r2871400 hrs_1987
* Hours from 1989 survey (about 1988 work) -> hrs_1988
rename r3075100 hrs_1988
* Hours from 1990 survey (about 1989 work) -> hrs_1989
rename r3401800 hrs_1989
* Hours from 1991 survey (about 1990 work) -> hrs_1990
rename r3657200 hrs_1990
* Hours from 1992 survey (about 1991 work) -> hrs_1991
rename r4007700 hrs_1991
* Hours from 1993 survey (about 1992 work) -> hrs_1992
rename r4418800 hrs_1992
* Hours from 1994 survey (about 1993 work) -> hrs_1993
rename r5081800 hrs_1993
* Hours from 1996 survey (about 1995 work) -> hrs_1995
rename r5167100 hrs_1995
* Hours from 1998 survey (about 1997 work) -> hrs_1997
rename r6479900 hrs_1997
* Hours from 2000 survey (about 1999 work) -> hrs_1999
rename r7007600 hrs_1999
* Hours from 2002 survey (about 2001 work) -> hrs_2001
rename r7704900 hrs_2001
* Hours from 2004 survey (about 2003 work) -> hrs_2003
rename r8497300 hrs_2003
* Hours from 2006 survey (about 2005 work) -> hrs_2005
rename t0989100 hrs_2005
* Hours from 2008 survey (about 2007 work) -> hrs_2007
rename t2210900 hrs_2007
* Hours from 2010 survey (about 2009 work) -> hrs_2009
rename t3108800 hrs_2009
* Hours from 2012 survey (about 2011 work) -> hrs_2011
rename t4113300 hrs_2011
* Hours from 2014 survey (about 2013 work) -> hrs_2013
rename t5024700 hrs_2013
* Hours from 2016 survey (about 2015 work) -> hrs_2015
rename t5772700 hrs_2015
* Hours from 2018 survey (about 2017 work) -> hrs_2017
rename t8219900 hrs_2017
* Hours from 2020 survey (about 2019 work) -> hrs_2019
rename t8789100 hrs_2019
* Hours from 2022 survey (about 2021 work) -> hrs_2021
rename t9300900 hrs_2021

*==============================================================================
* CLEAN MISSING VALUES FOR NEW VARIABLES (NLSY uses negative codes)
*==============================================================================

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

*==============================================================================
* CREATE DEMOGRAPHIC INDICATORS
*==============================================================================

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

*==============================================================================
* CREATE CUMULATIVE HOURS WORKED (in wide format before reshape)
*==============================================================================

* First, replace missing hours with 0 for cumulative calculation
* We'll create temp variables to avoid changing original hrs_*

foreach yr in 1978 1979 1980 1981 1982 1983 1984 1985 1986 1987 1988 1989 1990 1991 1992 1993 {
    gen hrs_temp_`yr' = hrs_`yr'
    replace hrs_temp_`yr' = 0 if missing(hrs_temp_`yr')
}

* Create cumulative hours for each year (sum of all hours up to and including that year)
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

* Drop temporary variables
drop hrs_temp_*

* Label cumulative hours
foreach yr in 1978 1979 1980 1981 1982 1983 1984 1985 1986 1987 1988 1989 1990 1991 1992 1993 {
    label var cumhrs_`yr' "Cumulative hours worked through `yr'"
}

*==============================================================================
* 4) Rename wave-specific vars into *_YYYY stubs (ORIGINAL CODE)
*==============================================================================

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

* Self-employment income
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

* Other non-property income

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

*==============================================================================
* RESHAPE WIDE TO LONG - NOW INCLUDING HOURS AND CUMULATIVE HOURS
*==============================================================================

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

* Build dependent-age counts
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

* Zero-fill any remaining missing inputs
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

* change pui to ui, because seems to read ui only
gen double ui = pui

* Label hours and cumulative hours
label var hrs "Annual hours worked"
label var cumhrs "Cumulative hours worked through this year"

save "nlsy_long_pre_taxsim.dta", replace

*==============================================================================
* PART 0: VERIFY DATA QUALITY BEFORE STARTING
*==============================================================================

clear all
set more off

use "nlsy_long_pre_taxsim.dta", clear

di "=============================================================================="
di "PART 0: DATA QUALITY VERIFICATION"
di "=============================================================================="

* Check which years actually have income data
di ""
di "Checking income data availability by year:"
di "(Non-survey years after 1993 should have zero/missing income)"

tabstat pwages, by(year) stat(mean median count)

* Check hours data availability
di ""
di "Checking hours data availability by year:"
tabstat hrs, by(year) stat(mean median count)

* Check cumulative hours
di ""
di "Checking cumulative hours by year:"
tabstat cumhrs, by(year) stat(mean median count)

* Create indicator for valid income years
gen valid_income_year = 0

* Annual period: 1978-1993 income years (from 1979-1994 surveys)
replace valid_income_year = 1 if year >= 1978 & year <= 1993

* Biennial period: odd years only after 1993
replace valid_income_year = 1 if year >= 1995 & mod(year, 2) == 1

* Also include even years for recent surveys if they exist
replace valid_income_year = 1 if inlist(year, 2019, 2021)

di ""
di "Valid income years in data:"
tab year valid_income_year

* Check how much data we lose by keeping only valid years
count if valid_income_year == 1
local valid_n = r(N)
count
local total_n = r(N)
di ""
di "Observations with valid income years: `valid_n' out of `total_n' (" %4.1f 100*`valid_n'/`total_n' "%)"

*------------------------------------------------------------------------------
* PART 1: RUN TAXSIM ON ACTUAL DATA (Only valid income years)
*------------------------------------------------------------------------------

di ""
di "=============================================================================="
di "PART 1: RUNNING TAXSIM ON ACTUAL DATA"
di "=============================================================================="

use "nlsy_long_pre_taxsim.dta", clear

* CRITICAL: Keep only valid income years
keep if year >= 1978 & year <= 1993

di "Keeping only annual period (1978-1993 income years):"
tab year
count

* Additional data cleaning before TAXSIM
di ""
di "Income distribution before cleaning:"
sum pwages, detail

* Run TAXSIM to get actual marginal tax rates
taxsimlocal35, replace
save "taxsim_actual.dta", replace

* Rename the key outputs we need
use "taxsim_actual.dta", clear
rename fiitax  tax_fed_t
rename siitax  tax_st_t
rename frate   mtr_fed_t
rename srate   mtr_st_t

di ""
di "Actual marginal tax rates from TAXSIM:"
sum mtr_fed_t mtr_st_t, detail

* Keep only the variables we need for merging - NOW INCLUDING DEMOGRAPHICS AND HOURS
keep taxsimid year mtr_fed_t mtr_st_t tax_fed_t tax_st_t ///
     pwages swages psemp ssemp pui sui gssi transfers nonprop pensions rentpaid ///
     mstat page depx ///
     female black hispanic max_education college_grad some_college hs_grad ///
     afqt_pct_2006 race_ethnicity sex ///
     hrs cumhrs

save "taxsim_actual_clean.dta", replace

*------------------------------------------------------------------------------
* PART 2: CREATE CPI DATA FOR INFLATION ADJUSTMENT
*------------------------------------------------------------------------------

di ""
di "=============================================================================="
di "PART 2: CREATING CPI DATA"
di "=============================================================================="

* Load your CPI data and prepare two versions for merging
use "BLS_CPI.dta", clear
keep year CPI
sort year

* Check CPI data
di "CPI data:"
list if year >= 1978 & year <= 1996

* Save version for base year (year t) merge
rename year year_t
rename CPI cpi_t
save "cpi_base.dta", replace

* Save version for end year (year t+3) merge
use "BLS_CPI.dta", clear
keep year CPI
sort year
rename year year_t3
rename CPI cpi_t3
save "cpi_end.dta", replace

*------------------------------------------------------------------------------
* PART 3: CREATE 3-YEAR PAIRED OBSERVATIONS
*------------------------------------------------------------------------------

di ""
di "=============================================================================="
di "PART 3: CREATING 3-YEAR PAIRED OBSERVATIONS"
di "=============================================================================="

use "taxsim_actual_clean.dta", clear

* For Gruber-Saez, we use 3-year differences
local lag = 3

* Sort by person and year
sort taxsimid year

* CRITICAL CHECK: Verify years are consecutive for each person
by taxsimid: gen year_gap = year - year[_n-1]
tab year_gap if year_gap != .
di "Year gaps should all be 1 for annual data"

* Create LEAD variables for year t+3 (the END year)
by taxsimid: gen mtr_fed_t3 = mtr_fed_t[_n + `lag']
by taxsimid: gen mtr_st_t3 = mtr_st_t[_n + `lag']
by taxsimid: gen tax_fed_t3 = tax_fed_t[_n + `lag']
by taxsimid: gen tax_st_t3 = tax_st_t[_n + `lag']

* Create LEAD income variables (for measuring income change)
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

* Create LEAD marital status (for checking if it changed)
by taxsimid: gen mstat_t3 = mstat[_n + `lag']

* Create LEAD page and depx for potential use
by taxsimid: gen page_t3 = page[_n + `lag']
by taxsimid: gen depx_t3 = depx[_n + `lag']

* Create LEAD hours and cumulative hours
by taxsimid: gen hrs_t3 = hrs[_n + `lag']
by taxsimid: gen cumhrs_t3 = cumhrs[_n + `lag']

* Create the end year variable
by taxsimid: gen year_t3 = year[_n + `lag']

* Rename base year variables for clarity
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
rename hrs hrs_t
rename cumhrs cumhrs_t

drop year_gap

* Drop observations where we can't form pairs (last 3 years)
drop if missing(mtr_fed_t3)

* CRITICAL: Verify year pairs are correct
di ""
di "Year pairs in data:"
tab year_t year_t3

* Keep only base years 1978-1990 (so end years are 1981-1993)
keep if year_t >= 1978 & year_t <= 1990

di ""
di "After restricting to 1978-1990 base years:"
tab year_t
count

save "paired_observations.dta", replace

*------------------------------------------------------------------------------
* PART 4: CONSTRUCT THE INSTRUMENT (CORRECTED DIRECTION!)
*------------------------------------------------------------------------------

di ""
di "=============================================================================="
di "PART 4: CONSTRUCTING THE INSTRUMENT"
di "=============================================================================="

use "paired_observations.dta", clear

* Merge CPI for base year (year t)
merge m:1 year_t using "cpi_base.dta", keep(match master) nogen

* Merge CPI for end year (year t+3)
merge m:1 year_t3 using "cpi_end.dta", keep(match master) nogen

* Check CPI merge results
di ""
di "CPI merge check:"
sum cpi_t cpi_t3

* Calculate inflation factor: CPI_t+3 / CPI_t
gen inflation_factor = cpi_t3 / cpi_t

* Display inflation factors by year
di ""
di "Inflation factors by base year (should be > 1 for all years):"
tabstat inflation_factor, by(year_t) stat(mean min max n)

* Create INFLATED year t income (in year t+3 dollars)
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

save "paired_with_inflation.dta", replace

*------------------------------------------------------------------------------
* PART 4b: RUN TAXSIM ON COUNTERFACTUAL (inflated year t income, year t+3 law)
*------------------------------------------------------------------------------

di ""
di "=============================================================================="
di "PART 4b: RUNNING TAXSIM ON COUNTERFACTUAL DATA"
di "=============================================================================="

use "paired_with_inflation.dta", clear

* Save original identifiers for later merge back
gen taxsimid_orig = taxsimid
gen year_t_orig = year_t

* Prepare variables for TAXSIM
* Set year to t+3 so TAXSIM uses t+3 tax law
gen year = year_t3

* Use inflated year t income
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

* Use base year demographics
gen mstat = mstat_t
gen page = page_t
gen depx = depx_t

* Generate required TAXSIM variables that might be missing
capture gen otherprop = 0
capture gen stcg = 0
capture gen ltcg = 0
capture gen proptax = 0
capture gen otheritem = 0
capture gen childcare = 0
capture gen pprofinc = 0
capture gen sprofinc = 0
capture gen scorp = 0
capture gen pbusinc = 0
capture gen sbusinc = 0

* Zero out spouse variables if not married
replace swages = 0 if mstat != 2
replace ssemp = 0 if mstat != 2
replace sui = 0 if mstat != 2

* Generate ui variable for TAXSIM
gen ui = pui

* Zero-fill missing values
foreach v in pwages swages psemp ssemp ui sui gssi transfers nonprop pensions rentpaid ///
             mstat page depx otherprop stcg ltcg proptax otheritem childcare ///
             pprofinc sprofinc scorp pbusinc sbusinc {
    capture replace `v' = 0 if missing(`v')
    capture replace `v' = 0 if `v' < 0
}

* Keep only variables needed for TAXSIM plus our identifiers
keep taxsimid year taxsimid_orig year_t_orig ///
     pwages swages psemp ssemp ui sui gssi transfers nonprop pensions rentpaid ///
     mstat page depx otherprop stcg ltcg proptax otheritem childcare ///
     pprofinc sprofinc scorp pbusinc sbusinc

drop if missing(year)

di "Observations for counterfactual TAXSIM:"
count

save "counterfactual_for_taxsim.dta", replace

* Run TAXSIM on counterfactual data
taxsimlocal35, replace
save "taxsim_counterfactual_raw.dta", replace

* Extract the predicted marginal rates
use "taxsim_counterfactual_raw.dta", clear
rename frate mtr_fed_predicted
rename srate mtr_st_predicted
rename fiitax tax_fed_predicted
rename siitax tax_st_predicted

keep taxsimid_orig year_t_orig mtr_fed_predicted mtr_st_predicted tax_fed_predicted tax_st_predicted

rename taxsimid_orig taxsimid
rename year_t_orig year_t

di ""
di "Predicted marginal rates summary:"
sum mtr_fed_predicted mtr_st_predicted, detail

save "predicted_rates.dta", replace

*------------------------------------------------------------------------------
* PART 5: MERGE EVERYTHING AND CREATE REGRESSION VARIABLES
*------------------------------------------------------------------------------

di ""
di "=============================================================================="
di "PART 5: MERGING DATA AND CREATING VARIABLES"
di "=============================================================================="

use "paired_with_inflation.dta", clear

merge 1:1 taxsimid year_t using "predicted_rates.dta"

tab _merge
keep if _merge == 3
drop _merge

di "After merging predicted rates:"
count

*------------------------------------------------------------------------------
* PART 6: SAMPLE RESTRICTIONS (Gruber-Saez style)
*------------------------------------------------------------------------------

di ""
di "=============================================================================="
di "PART 6: APPLYING SAMPLE RESTRICTIONS"
di "=============================================================================="

count
local initial_n = r(N)
di "Initial observations: `initial_n'"

* Restriction 1: Drop if marital status changed between t and t+3
gen mstat_changed = (mstat_t != mstat_t3)
tab mstat_changed
drop if mstat_changed == 1
count
di "After dropping marital status changes: " r(N)

* Restriction 2: Create broad income measure
gen broad_income_t = pwages_t + swages_t + psemp_t + ssemp_t + ///
                     pui_t + sui_t + gssi_t + pensions_t + nonprop_t
gen broad_income_t3 = pwages_t3 + swages_t3 + psemp_t3 + ssemp_t3 + ///
                      pui_t3 + sui_t3 + gssi_t3 + pensions_t3 + nonprop_t3

di ""
di "Broad income summary (before restrictions):"
sum broad_income_t broad_income_t3, detail

* Drop if base year broad income < $10,000
drop if broad_income_t < 10000
count
di "After dropping income < $10,000: " r(N)

* Restriction 3: Drop if end-year income is zero or negative (can't take logs)
drop if broad_income_t3 <= 0
count
di "After dropping zero/negative income at t+3: " r(N)

* NEW RESTRICTION: Exclude observations with extreme negative marginal rates
di ""
di "Checking marginal tax rate distribution:"
sum mtr_fed_t mtr_fed_t3 mtr_fed_predicted, detail

* Drop observations where ANY marginal rate is highly negative (< -10%)
gen extreme_eitc = (mtr_fed_t < -10 | mtr_fed_t3 < -10 | mtr_fed_predicted < -10)
tab extreme_eitc
drop if extreme_eitc == 1
count
di "After dropping extreme EITC observations (MTR < -10%): " r(N)

*------------------------------------------------------------------------------
* PART 7: CREATE REGRESSION VARIABLES
*------------------------------------------------------------------------------

di ""
di "=============================================================================="
di "PART 7: CREATING REGRESSION VARIABLES"
di "=============================================================================="

* Dependent variable: log change in income
gen log_income_t = ln(broad_income_t)
gen log_income_t3 = ln(broad_income_t3)
gen log_income_change = log_income_t3 - log_income_t

di ""
di "Log income change before censoring:"
sum log_income_change, detail

* Censor extreme income changes at +/- 7 (Gruber-Saez restriction)
replace log_income_change = 7 if log_income_change > 7 & !missing(log_income_change)
replace log_income_change = -7 if log_income_change < -7 & !missing(log_income_change)

di ""
di "Log income change after censoring:"
sum log_income_change, detail

* Create combined marginal tax rates (federal only since no state variation)
gen mtr_t = mtr_fed_t
gen mtr_t3 = mtr_fed_t3
gen mtr_predicted = mtr_fed_predicted

di ""
di "Marginal tax rates summary:"
sum mtr_t mtr_t3 mtr_predicted, detail

* Endogenous variable: log change in net-of-tax rate
gen ntr_t = 1 - mtr_t/100
gen ntr_t3 = 1 - mtr_t3/100
gen ntr_predicted = 1 - mtr_predicted/100

* Handle edge cases where NTR might be <= 0
replace ntr_t = 0.01 if ntr_t <= 0
replace ntr_t3 = 0.01 if ntr_t3 <= 0
replace ntr_predicted = 0.01 if ntr_predicted <= 0

gen log_ntr_t = ln(ntr_t)
gen log_ntr_t3 = ln(ntr_t3)
gen log_ntr_predicted = ln(ntr_predicted)

* ENDOGENOUS VARIABLE: Actual log change in net-of-tax rate
gen log_ntr_change = log_ntr_t3 - log_ntr_t

* INSTRUMENT: Predicted log change in net-of-tax rate
gen log_ntr_instrument = log_ntr_predicted - log_ntr_t

di ""
di "Endogenous variable and instrument summary:"
sum log_ntr_change log_ntr_instrument, detail

* CRITICAL CHECK: Correlation between instrument and endogenous variable
di ""
di "CRITICAL: First-stage correlation (should be positive and ideally > 0.3):"
corr log_ntr_change log_ntr_instrument

* Income weights (capped at $1 million)
gen income_weight = min(broad_income_t, 1000000)

* Marital status dummies
gen married = (mstat_t == 2)
gen single = (mstat_t == 1)
gen other_marital = (married == 0 & single == 0)

di ""
di "Marital status distribution:"
tab mstat_t

*------------------------------------------------------------------------------
* PART 7b: CREATE HOURS-RELATED VARIABLES
*------------------------------------------------------------------------------

di ""
di "=============================================================================="
di "PART 7b: CREATING HOURS-RELATED VARIABLES"
di "=============================================================================="

* Log hours (for those with positive hours)
gen log_hrs_t = ln(hrs_t) if hrs_t > 0
gen log_hrs_t3 = ln(hrs_t3) if hrs_t3 > 0

* Hours change
gen log_hrs_change = log_hrs_t3 - log_hrs_t

* Cumulative hours change
gen cumhrs_change = cumhrs_t3 - cumhrs_t

* Log cumulative hours
gen log_cumhrs_t = ln(cumhrs_t) if cumhrs_t > 0
gen log_cumhrs_t3 = ln(cumhrs_t3) if cumhrs_t3 > 0

di ""
di "Hours variables summary:"
sum hrs_t hrs_t3 cumhrs_t cumhrs_t3 log_hrs_change cumhrs_change, detail

* Label hours variables
label var hrs_t "Hours worked in base year"
label var hrs_t3 "Hours worked in end year"
label var cumhrs_t "Cumulative hours through base year"
label var cumhrs_t3 "Cumulative hours through end year"
label var log_hrs_t "Log hours worked in base year"
label var log_hrs_t3 "Log hours worked in end year"
label var log_hrs_change "Log change in hours worked"
label var cumhrs_change "Change in cumulative hours"
label var log_cumhrs_t "Log cumulative hours through base year"
label var log_cumhrs_t3 "Log cumulative hours through end year"

*------------------------------------------------------------------------------
* PART 8: CREATE 10-PIECE INCOME SPLINE
*------------------------------------------------------------------------------

di ""
di "=============================================================================="
di "PART 8: CREATING INCOME SPLINES"
di "=============================================================================="

* Calculate decile cutpoints of log base-year income
quietly _pctile log_income_t, p(10 20 30 40 50 60 70 80 90)

local cut1 = r(r1)
local cut2 = r(r2)
local cut3 = r(r3)
local cut4 = r(r4)
local cut5 = r(r5)
local cut6 = r(r6)
local cut7 = r(r7)
local cut8 = r(r8)
local cut9 = r(r9)

di "Income spline cutpoints (log scale and dollar equivalents):"
di "10th pctile: `cut1' = $" %12.0fc exp(`cut1')
di "20th pctile: `cut2' = $" %12.0fc exp(`cut2')
di "30th pctile: `cut3' = $" %12.0fc exp(`cut3')
di "40th pctile: `cut4' = $" %12.0fc exp(`cut4')
di "50th pctile: `cut5' = $" %12.0fc exp(`cut5')
di "60th pctile: `cut6' = $" %12.0fc exp(`cut6')
di "70th pctile: `cut7' = $" %12.0fc exp(`cut7')
di "80th pctile: `cut8' = $" %12.0fc exp(`cut8')
di "90th pctile: `cut9' = $" %12.0fc exp(`cut9')

* Create spline variables
gen spline1 = max(0, log_income_t - `cut1')
gen spline2 = max(0, log_income_t - `cut2')
gen spline3 = max(0, log_income_t - `cut3')
gen spline4 = max(0, log_income_t - `cut4')
gen spline5 = max(0, log_income_t - `cut5')
gen spline6 = max(0, log_income_t - `cut6')
gen spline7 = max(0, log_income_t - `cut7')
gen spline8 = max(0, log_income_t - `cut8')
gen spline9 = max(0, log_income_t - `cut9')

*------------------------------------------------------------------------------
* PART 9: FINAL DATA CHECKS AND DIAGNOSTICS
*------------------------------------------------------------------------------

di ""
di "=============================================================================="
di "PART 9: FINAL DATA CHECKS"
di "=============================================================================="

* Check for missing values
di "Missing value check:"
misstable summarize log_income_change log_ntr_change log_ntr_instrument log_income_t

* Final summary statistics
di ""
di "Final sample summary statistics:"
sum log_income_change log_ntr_change log_ntr_instrument log_income_t broad_income_t ///
    mtr_t mtr_t3 mtr_predicted

* Check demographics distribution
di ""
di "Demographic variables summary:"
tab female
tab black
tab hispanic
tab college_grad

* Check hours distribution
di ""
di "Hours variables summary:"
sum hrs_t hrs_t3 cumhrs_t cumhrs_t3

* Check instrument variation by year
di ""
di "Instrument variation by base year:"
tabstat log_ntr_instrument, by(year_t) stat(mean sd min max n)

* Final sample size
count
di ""
di "Final sample size for regression: " r(N)

save "gruber_saez_regression_data.dta", replace

*------------------------------------------------------------------------------
* PART 10: RUN THE GRUBER-SAEZ REGRESSIONS
*------------------------------------------------------------------------------

di ""
di "=============================================================================="
di "PART 10: GRUBER-SAEZ REGRESSIONS"
di "=============================================================================="

use "gruber_saez_regression_data.dta", clear

di ""
di "Sample size: " _N
di ""
di "Base years in sample:"
tab year_t

*--- First Stage Regression (Diagnostic) ---
di ""
di "FIRST STAGE REGRESSION (Instrument → Endogenous Variable):"
di "============================================================"

regress log_ntr_change log_ntr_instrument ///
    log_income_t spline1-spline9 i.year_t married single ///
    [aweight=income_weight], cluster(taxsimid)

* Test instrument strength
di ""
di "F-test for instrument (should be > 10, preferably > 20):"
test log_ntr_instrument

* Store F-statistic
local first_stage_F = r(F)
di ""
di "First-stage F-statistic: " %6.2f `first_stage_F'

if `first_stage_F' < 10 {
    di ""
    di "WARNING: Weak instrument (F < 10)!"
    di "2SLS estimates may be biased and unreliable."
    di "Consider using LIML or other weak-instrument robust methods."
}

*--- Model 1: No income controls ---
di ""
di "MODEL 1: No income controls"
di "----------------------------"

ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    i.year_t married single ///
    [aweight=income_weight], ///
    cluster(taxsimid)

estimates store model1
estat firststage

*--- Model 2: With log income control ---
di ""
di "MODEL 2: With log income control"
di "---------------------------------"

ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t i.year_t married single ///
    [aweight=income_weight], ///
    cluster(taxsimid)

estimates store model2
estat firststage

*--- Model 3: With 10-piece income spline (PREFERRED) ---
di ""
di "MODEL 3: With 10-piece income spline (PREFERRED SPECIFICATION)"
di "--------------------------------------------------------------"

ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    [aweight=income_weight], ///
    cluster(taxsimid)

estimates store model3
estat firststage

*--- Model 4: OLS for comparison ---
di ""
di "MODEL 4: OLS (biased - for comparison only)"
di "--------------------------------------------"

regress log_income_change log_ntr_change ///
    log_income_t spline1-spline9 i.year_t married single ///
    [aweight=income_weight], ///
    cluster(taxsimid)

estimates store model4_ols

*------------------------------------------------------------------------------
* PART 11: RESULTS SUMMARY
*------------------------------------------------------------------------------

di ""
di "=============================================================================="
di "SUMMARY OF RESULTS"
di "=============================================================================="

estimates table model1 model2 model3 model4_ols, ///
    keep(log_ntr_change) ///
    b(%9.3f) se(%9.3f) ///
    stats(N) ///
    title("Elasticity of Taxable Income Estimates")

di ""
di "INTERPRETATION:"
di "  - Model 1 (no controls): Likely biased by mean reversion"
di "  - Model 2 (log income): Partially controls for mean reversion"
di "  - Model 3 (splines): PREFERRED - best controls for mean reversion"
di "  - Model 4 (OLS): Biased benchmark (endogeneity not addressed)"
di ""
di "Gruber-Saez (2000) found:"
di "  - Broad Income elasticity: 0.12 (with splines)"
di "  - Taxable Income elasticity: 0.40 (with splines)"

*------------------------------------------------------------------------------
* PART 12: HETEROGENEITY BY INCOME GROUP
*------------------------------------------------------------------------------

di ""
di "=============================================================================="
di "HETEROGENEITY BY INCOME GROUP"
di "=============================================================================="

* Create income groups
gen income_group = 1 if broad_income_t >= 10000 & broad_income_t < 50000
replace income_group = 2 if broad_income_t >= 50000 & broad_income_t < 100000
replace income_group = 3 if broad_income_t >= 100000

label define inc_grp 1 "$10K-$50K" 2 "$50K-$100K" 3 "$100K+"
label values income_group inc_grp

di "Income group distribution:"
tab income_group

* Run separate regressions by income group
di ""
di "Income Group: $10,000 - $50,000"
di "--------------------------------"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    [aweight=income_weight] if income_group == 1, ///
    cluster(taxsimid)

di ""
di "Income Group: $50,000 - $100,000"
di "---------------------------------"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    [aweight=income_weight] if income_group == 2, ///
    cluster(taxsimid)

di ""
di "Income Group: $100,000+"
di "------------------------"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    [aweight=income_weight] if income_group == 3, ///
    cluster(taxsimid)

*------------------------------------------------------------------------------
* PART 12b: HETEROGENEITY BY DEMOGRAPHICS (NEW)
*------------------------------------------------------------------------------

di ""
di "=============================================================================="
di "HETEROGENEITY BY DEMOGRAPHICS"
di "=============================================================================="

* By Gender
di ""
di "ELASTICITY BY GENDER"
di "===================="

di ""
di "Males:"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    [aweight=income_weight] if female == 0, ///
    cluster(taxsimid)

di ""
di "Females:"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    [aweight=income_weight] if female == 1, ///
    cluster(taxsimid)

* By Education
di ""
di "ELASTICITY BY EDUCATION"
di "======================="

di ""
di "College graduates:"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    [aweight=income_weight] if college_grad == 1, ///
    cluster(taxsimid)

di ""
di "Non-college:"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    [aweight=income_weight] if college_grad == 0, ///
    cluster(taxsimid)

*------------------------------------------------------------------------------
* PART 12c: MODELS WITH DEMOGRAPHIC CONTROLS (NEW)
*------------------------------------------------------------------------------

di ""
di "=============================================================================="
di "MODELS WITH DEMOGRAPHIC CONTROLS"
di "=============================================================================="

di ""
di "Model with gender, race controls:"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    female black hispanic ///
    [aweight=income_weight], ///
    cluster(taxsimid)

di ""
di "Model with gender, race, education controls:"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    female black hispanic college_grad some_college ///
    [aweight=income_weight], ///
    cluster(taxsimid)

di ""
di "Model with cumulative hours control:"
capture noisily ivregress 2sls log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    female black hispanic college_grad some_college ///
    log_cumhrs_t ///
    [aweight=income_weight], ///
    cluster(taxsimid)

*------------------------------------------------------------------------------
* PART 12d: HOURS ELASTICITY ANALYSIS (NEW)
*------------------------------------------------------------------------------

di ""
di "=============================================================================="
di "HOURS ELASTICITY ANALYSIS (INTENSIVE MARGIN)"
di "=============================================================================="

* Keep only observations with positive hours in both periods
preserve
keep if hrs_t > 0 & hrs_t3 > 0

di ""
di "Sample with positive hours in both periods:"
count

di ""
di "Hours elasticity with respect to net-of-tax rate:"
capture noisily ivregress 2sls log_hrs_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    [aweight=income_weight], ///
    cluster(taxsimid)

restore

*------------------------------------------------------------------------------
* PART 13: DIAGNOSTIC PLOTS
*------------------------------------------------------------------------------

di ""
di "=============================================================================="
di "CREATING DIAGNOSTIC PLOTS"
di "=============================================================================="

* Histogram of the instrument
histogram log_ntr_instrument, ///
    title("Distribution of Instrument") ///
    xtitle("Predicted Log Change in Net-of-Tax Rate") ///
    note("Instrument = log(1-τ_predicted) - log(1-τ_t)") ///
    color(blue%50)
graph export "instrument_histogram.png", replace

* First stage scatter
twoway (scatter log_ntr_change log_ntr_instrument, msize(tiny) mcolor(blue%30)) ///
       (lfit log_ntr_change log_ntr_instrument, lcolor(red) lwidth(medium)), ///
    title("First Stage: Instrument vs Actual Tax Change") ///
    xtitle("Instrument: Predicted Log NTR Change") ///
    ytitle("Actual Log NTR Change") ///
    legend(off) ///
    note("Slope represents first-stage relationship")
graph export "first_stage_scatter.png", replace

* Instrument by year
graph bar (mean) log_ntr_instrument, over(year_t) ///
    title("Average Instrument Value by Base Year") ///
    ytitle("Mean Predicted Log NTR Change") ///
    note("Positive = predicted tax cut; Negative = predicted tax increase")
graph export "instrument_by_year.png", replace

* Reduced form: Income change vs Instrument
twoway (scatter log_income_change log_ntr_instrument, msize(tiny) mcolor(green%30)) ///
       (lfit log_income_change log_ntr_instrument, lcolor(red) lwidth(medium)), ///
    title("Reduced Form: Income Change vs Instrument") ///
    xtitle("Instrument: Predicted Log NTR Change") ///
    ytitle("Log Income Change") ///
    legend(off)
graph export "reduced_form_scatter.png", replace

* NEW: Cumulative hours distribution
histogram cumhrs_t if cumhrs_t > 0, ///
    title("Distribution of Cumulative Hours Worked") ///
    xtitle("Cumulative Hours through Base Year") ///
    color(green%50)
graph export "cumhrs_histogram.png", replace

*------------------------------------------------------------------------------
* PART 14: WEAK INSTRUMENT ROBUST INFERENCE (IF NEEDED)
*------------------------------------------------------------------------------

di ""
di "=============================================================================="
di "WEAK INSTRUMENT ROBUST INFERENCE"
di "=============================================================================="

* If first-stage F < 10, use LIML (more robust to weak instruments)
di ""
di "LIML Estimation (robust to weak instruments):"

ivregress liml log_income_change ///
    (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single ///
    [aweight=income_weight], ///
    cluster(taxsimid)

estimates store model_liml

* Compare 2SLS and LIML
di ""
di "Comparison: 2SLS vs LIML"
di "(If estimates differ substantially, weak instrument bias is likely)"
estimates table model3 model_liml, ///
    keep(log_ntr_change) ///
    b(%9.3f) se(%9.3f) ///
    title("2SLS vs LIML Comparison")

*------------------------------------------------------------------------------
* FINAL SUMMARY
*------------------------------------------------------------------------------

di ""
di "=============================================================================="
di "ANALYSIS COMPLETE"
di "=============================================================================="
di ""
di "Key output files:"
di "  - gruber_saez_regression_data.dta : Final analysis dataset"
di "  - instrument_histogram.png"
di "  - first_stage_scatter.png"
di "  - instrument_by_year.png"
di "  - reduced_form_scatter.png"
di "  - cumhrs_histogram.png"
di ""
di "NEW VARIABLES AVAILABLE:"
di "  - female, black, hispanic : Demographic indicators"
di "  - college_grad, some_college, hs_grad : Education indicators"
di "  - afqt_pct_2006 : AFQT score (ability measure)"
di "  - hrs_t, hrs_t3 : Hours worked in base/end years"
di "  - cumhrs_t, cumhrs_t3 : Cumulative hours through base/end years"
di "  - log_hrs_change : Log change in hours"
di "  - cumhrs_change : Change in cumulative hours"
di ""
di "IMPORTANT NOTES FOR INTERPRETATION:"
di ""
di "1. Your NLSY sample differs from Gruber-Saez's tax return data:"
di "   - NLSY is one birth cohort (born 1957-1964)"
di "   - Tax returns cover all ages and income levels"
di "   - Expect smaller sample and potentially different results"
di ""
di "2. If first-stage F < 10:"
di "   - Your 2SLS estimates are unreliable"
di "   - LIML estimates are more robust but may have wide confidence intervals"
di "   - Consider whether NLSY has sufficient tax variation for this analysis"
di ""
di "3. Gruber-Saez's key findings (for reference):"
di "   - Broad income elasticity: 0.12"
di "   - Taxable income elasticity: 0.40"
di "   - Higher elasticity for incomes > $100K (0.57)"
di "   - First-stage F always > 20"


