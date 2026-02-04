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

* 3) Merge the two datasets by respondent ID
use "base_data.dta", clear
merge 1:1 taxsimid using "left_out.dta"

tab _merge
drop _merge

save "merged_data.dta", replace

use "merged_data.dta", clear


* 4) Rename wave‐specific vars into *_YYYY stubs

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
rename r5626601 psemp_1994
rename r6365001 psemp_1995
rename r6911101 psemp_1996
rename r6911101 psemp_1997
rename r7609000 psemp_1998
rename r8318200 psemp_2000
rename t0913900 psemp_2002
rename t2078800 psemp_2004
rename t3047500 psemp_2006
rename t3979400 psemp_2008
rename t4917800 psemp_2010
rename t5621700 psemp_2012
rename t8116700 psemp_2014
rename t8646800 psemp_2016
rename t9199700 psemp_2018

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

* Reshape Wide to Long by year
* Note: Removed mortgage_, dividends_, intrec_ from list
reshape long ///
    unemp_ mstat_ page_ depx_ pwages_ swages_ ///
    psemp_ ssemp_ sui_ gssi_ transfers_ nonprop_ ///
    pensions_ rentpaid_ ///
    spomonth_ spoyear_ ///
    child1month_ child1year_ ///
    child2month_ child2year_ ///
    child3month_ child3year_, ///
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

* change pui to ui, because seems to read ui only
gen double ui = pui

save "nlsy_long_pre_taxsim.dta", replace

* Run Taxsim
taxsimlocal35, replace
save "taxsim_out_nominal.dta", replace

* rename outputs
use "taxsim_out_nominal.dta", clear
rename fiitax  tax_fed        // federal income tax liability
rename siitax  tax_st         // state income tax liability
rename fica    tax_payroll    // FICA
rename frate   mtr_fed        // federal marginal rate
rename srate   mtr_st         // state marginal rate
rename ficar   fica_rt         //  FICA rate
rename tfica   fica_taxliab   // taxpayer liability for FICA
save "taxsim_out_nominal.dta", replace


* Merge base-year CPI
use "BLS_CPI.dta", clear
keep year CPI
sort year
save "cpi_temp.dta", replace

* Merge CPI into the main taxsim output (Current Year)
use "taxsim_out_nominal.dta", clear
merge m:1 year using "cpi_temp.dta", keep(match master) nogen

* Create a LEAD CPI variable (4 years forward)
* We use 4 years to align with biennial survey waves (1994, 1998, etc.)
rename CPI cpi_current

gen year_lead4 = year + 4
rename year year_original
rename year_lead4 year

merge m:1 year using "cpi_temp.dta", keep(match master) keepusing(CPI)
rename CPI cpi_lead4
drop _merge

* Restore original variable names
rename year year_lead4  
rename year_original year

* Calculate CPI adjustment factor: cpi_current / cpi_lead4
gen cpi_adjustment = cpi_current / cpi_lead4

* For the last 4 years of the dataset, there is no t+4 data, so set to missing
replace cpi_adjustment = . if missing(cpi_lead4)

save "taxsim_with_cpi.dta", replace

* Create LEAD Income Variables (from 4 years future)
use "nlsy_long_pre_taxsim.dta", clear
sort taxsimid year

* List of dollar-value variables that need to be pulled from the future
local dollar_vars pwages swages psemp ssemp pui sui gssi transfers nonprop ///
                  pensions rentpaid otherprop stcg ltcg ///
                  proptax otheritem childcare pprofinc sprofinc pbusinc sbusinc

* Create LEAD versions (4 years forward)
foreach var of local dollar_vars {
    by taxsimid: gen `var'_lead4 = `var'[_n+4]
    replace `var'_lead4 = . if `var'_lead4 == .
}

save "nlsy_with_leads.dta", replace

* Create Counterfactual Dataset (Fixed Income from t+4)
use "nlsy_with_leads.dta", clear

* Merge in CPI data for current year
merge m:1 year using "cpi_temp.dta", keep(match master) nogen
rename CPI cpi_current

* Merge in CPI data for t+4
gen year_lead4 = year + 4
rename year year_original
rename year_lead4 year

merge m:1 year using "cpi_temp.dta", keep(match master) keepusing(CPI)
rename CPI cpi_lead4
drop _merge

rename year year_lead4
rename year_original year

* Calculate CPI adjustment factor
gen cpi_adjustment = cpi_current / cpi_lead4
replace cpi_adjustment = . if missing(cpi_lead4)

* Create counterfactual versions: use FUTURE income (t+4), adjusted to CURRENT prices
foreach var of local dollar_vars {
    gen `var'_cf = `var'_lead4 * cpi_adjustment
    replace `var'_cf = . if missing(`var'_lead4) | missing(cpi_adjustment)
}

* Save the counterfactual dataset
preserve

* Drop observations without t+4 data (The last 4 years of data)
drop if missing(cpi_adjustment)

* Replace actual values with counterfactual (future t+4) values
foreach var of local dollar_vars {
    replace `var' = `var'_cf
}

replace ui = pui
drop if missing(pwages)

* Zero out spouse variables when not married
replace sage = 0 if mstat != 2
replace swages = 0 if mstat != 2
replace ssemp = 0 if mstat != 2
replace sui = 0 if mstat != 2

* Save this counterfactual dataset for TAXSIM
save "nlsy_counterfactual_taxsim.dta", replace

* Run TAXSIM on counterfactual data
taxsimlocal35, replace
save "taxsim_out_counterfactual.dta", replace

restore

* Calculate Changes (Actual vs Future Counterfactual)

* Load actual TAXSIM output
use "taxsim_with_cpi.dta", clear

rename mtr_fed mtr_fed_actual
rename mtr_st mtr_st_actual
rename tax_fed tax_fed_actual
rename tax_st tax_st_actual
rename tax_payroll tax_payroll_actual

keep taxsimid year mtr_fed_actual mtr_st_actual tax_fed_actual tax_st_actual ///
     tax_payroll_actual cpi_current cpi_lead4 cpi_adjustment

* Merge with counterfactual TAXSIM output
merge 1:1 taxsimid year using "taxsim_out_counterfactual.dta"

keep if _merge == 3
drop _merge

rename fiitax tax_fed_cf
rename siitax tax_st_cf
rename fica tax_payroll_cf
rename frate mtr_fed_cf
rename srate mtr_st_cf

* Create change variables
gen change_mtr_fed = mtr_fed_actual - mtr_fed_cf
gen change_mtr_st = mtr_st_actual - mtr_st_cf
gen change_mtr_total = change_mtr_fed + change_mtr_st

gen change_tax_fed = tax_fed_actual - tax_fed_cf
gen change_tax_st = tax_st_actual - tax_st_cf
gen change_tax_payroll = tax_payroll_actual - tax_payroll_cf
gen change_tax_total = change_tax_fed + change_tax_st + change_tax_payroll

label variable change_mtr_fed "Change in federal marginal tax rate (pp)"
label variable change_mtr_st "Change in state marginal tax rate (pp)"
label variable change_mtr_total "Change in total marginal tax rate (pp)"
label variable change_tax_fed "Change in federal tax liability ($)"
label variable change_tax_st "Change in state tax liability ($)"
label variable change_tax_payroll "Change in payroll tax liability ($)"
label variable change_tax_total "Change in total tax burden ($)"

label variable mtr_fed_actual "Actual federal MTR"
label variable mtr_fed_cf "Counterfactual federal MTR (t+4 income)"
label variable tax_fed_actual "Actual federal tax"
label variable tax_fed_cf "Counterfactual federal tax (t+4 income)"

note: Last 4 years are dropped because t+4 data is not available (Forward Look)

save "taxsim_with_changes.dta", replace

* Summary statistics and data description

* Show year coverage
tab year
di "NOTE: Last 4 years are excluded due to lack of t+4 comparison data"

* Display summary statistics
di "SUMMARY STATISTICS FOR CHANGE VARIABLES"
summarize change_mtr_fed change_mtr_st change_mtr_total ///
          change_tax_fed change_tax_st change_tax_payroll change_tax_total, detail

* Show distribution by year
di " "
di "AVERAGE CHANGES BY YEAR (t+4 Horizon)"
tabstat change_mtr_total change_tax_total, by(year) format(%9.2f)

* Create histograms
histogram change_mtr_total, title("Change in Total MTR (t+4)") ///
          xtitle("Change in MTR (percentage points)") ///
          note("Change = Actual MTR - Counterfactual MTR (with t+4 income)")
graph export "change_mtr_histogram.png", replace

histogram change_tax_total, title("Change in Total Tax Burden (t+4)") ///
          xtitle("Change in Tax Burden (dollars)") ///
          note("Change = Actual Tax - Counterfactual Tax (with t+4 income)")
graph export "change_tax_histogram.png", replace
