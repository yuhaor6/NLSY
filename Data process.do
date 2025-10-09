* Data process.do
clear all
set more off

* 1) Import the CSV (one row per person)
import delimited "NLSY_All_Data.csv", varnames(1) clear

* 2) Rename the ID
rename r0000100 taxsimid

* 3) Rename wave‐specific vars into *_YYYY stubs
* — Unemployment insurance
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
rename g0160400 unemp_1999
rename g0166500 unemp_2000
rename g0182100 unemp_2001
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

* Marital status, filing status, dependents
rename r0217500 mstat_1979
rename r0450600 mstat_1980
rename r0618600 mstat_1981
rename r0898400 mstat_1982
rename r1144900 mstat_1983
rename r1520100 mstat_1984
rename r1898000 mstat_1985
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
rename r0450610 page_1980
rename r0619100 page_1981
rename r0898310 page_1982
rename r1145110 page_1983
rename r1520130 page_1984
rename r1899100 page_1985
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
rename r0476010 depx_1980
rename r0647100 depx_1981
rename r0898310 depx_1982
rename r1146830 depx_1983
rename r1520230 depx_1984
rename r1898370 depx_1985
rename r2259830 depx_1986
rename r2448030 depx_1987
rename r2877060 depx_1988
rename r3077000 depx_1989
rename r3407700 depx_1990
rename r3659040 depx_1991
rename r4007400 depx_1992
rename r4444700 depx_1993
rename r5087500 depx_1994
rename r5172800 depx_1996
rename r6486400 depx_1998
rename r7014200 depx_2000
rename r7711800 depx_2002
rename r8504300 depx_2004
rename t0996000 depx_2006
rename t2217900 depx_2008
rename t3115800 depx_2010
rename t4120300 depx_2012
rename t5031500 depx_2014
rename t5779000 depx_2016
rename t8226800 depx_2018
rename t8796100 depx_2020
rename t9307900 depx_2022

* Wages & salary
rename r0155400 pwages_1979
rename r0313200 pwages_1980
rename r0482600 pwages_1981
rename r0782101 pwages_1982
rename r1020401 pwages_1983
rename r1410701 pwages_1984
rename r1778501 pwages_1985
rename r2141601 pwages_1986
rename r2330501 pwages_1987
rename r2722501 pwages_1988
rename r2971401 pwages_1989
rename r3279401 pwages_1990
rename r3559901 pwages_1991
rename r3897101 pwages_1992
rename r4295101 pwages_1993
rename r4982801 pwages_1994
rename r5626201 pwages_1996
rename r6364601 pwages_1998
rename r6909701 pwages_2000
rename r7607800 pwages_2002
rename r8316300 pwages_2004
rename t0912400 pwages_2006
rename t2076700 pwages_2008
rename t3045300 pwages_2010
rename t3977400 pwages_2012
rename t4915800 pwages_2014
rename t5619500 pwages_2016
rename t8115400 pwages_2018
rename t8645700 pwages_2020
rename t9184800 pwages_2022

rename r0155500 swages_1979
rename r0312710 swages_1980
rename r0482910 swages_1981
rename r0784301 swages_1982
rename r1026201 swages_1983
rename r1412901 swages_1984
rename r1780701 swages_1985
rename r2143801 swages_1986
rename r2352501 swages_1987
rename r2724701 swages_1988
rename r2973601 swages_1989
rename r3281601 swages_1990
rename r3561201 swages_1991
rename r3899301 swages_1992
rename r4314401 swages_1993
rename r4996001 swages_1994
rename r5650801 swages_1996
rename r6374901 swages_1998
rename r6917801 swages_2000
rename r7617300 swages_2002
rename r8325800 swages_2004
rename t0920800 swages_2006
rename t2085500 swages_2008
rename t3056000 swages_2010
rename t3987600 swages_2012
rename t4924900 swages_2014
rename t5630100 swages_2016
rename t8153900 swages_2018
rename t8671700 swages_2020
rename t9223100 swages_2022

* Self‐employment income
rename r0156000 psemp_1979
rename r0312600 psemp_1980
rename r0483200 psemp_1981
rename r0782401 psemp_1982
rename r1024301 psemp_1983
rename r1411101 psemp_1984
rename r1778801 psemp_1985
rename r2141901 psemp_1986
rename r2350601 psemp_1987
rename r2722801 psemp_1988
rename r2977101 psemp_1989
rename r3279701 psemp_1990
rename r3559301 psemp_1991
rename r3897401 psemp_1992
rename r4295501 psemp_1993
rename r4983201 psemp_1994
rename r5626601 psemp_1996
rename r6365001 psemp_1998
rename r6911101 psemp_2000
rename r7600900 psemp_2002
rename r8318200 psemp_2004
rename t0913900 psemp_2006
rename t2078800 psemp_2008
rename t3047500 psemp_2010
rename t3979400 psemp_2012
rename t4917800 psemp_2014
rename t5621700 psemp_2016
rename t8161700 psemp_2018
rename t8646800 psemp_2020
rename t9199700 psemp_2022

rename r0156100 ssemp_1979
rename r0313000 ssemp_1980
rename r0483500 ssemp_1981
rename r0784601 ssemp_1982
rename r1026501 ssemp_1983
rename r1413201 ssemp_1984
rename r1781001 ssemp_1985
rename r2144101 ssemp_1986
rename r2352801 ssemp_1987
rename r2725001 ssemp_1988
rename r2979301 ssemp_1989
rename r3281901 ssemp_1990
rename r3561501 ssemp_1991
rename r3899601 ssemp_1992
rename r4314901 ssemp_1993
rename r4996601 ssemp_1994
rename r5651401 ssemp_1996
rename r6375301 ssemp_1998
rename r6919201 ssemp_2000
rename r7618500 ssemp_2002
rename r8328000 ssemp_2004
rename t0922200 ssemp_2006
rename t2087700 ssemp_2008
rename t3058300 ssemp_2010
rename t3989900 ssemp_2012
rename t4927200 ssemp_2014
rename t5632400 ssemp_2016
rename t8173700 ssemp_2018
rename t8673100 ssemp_2020
rename t9224500 ssemp_2022

* UI
rename g0001400 pui_1978
rename g0009200 pui_1979
rename g0017000 pui_1980
rename g0024800 pui_1981
rename g0032600 pui_1982
rename g0040400 pui_1983
rename g0048200 pui_1984
rename g0056000 pui_1985
rename g0063800 pui_1986
rename g0071600 pui_1987
rename g0079400 pui_1988
rename g0087200 pui_1989
rename g0095000 pui_1990
rename g0102800 pui_1991
rename g0110600 pui_1992
rename g0118400 pui_1993
rename g0126200 pui_1994
rename g0135200 pui_1995
rename g0135300 pui_1996
rename g0150800 pui_1997
rename g0150900 pui_1998
rename g0166400 pui_1999
rename g0166500 pui_2000
rename g0182000 pui_2001
rename g0182100 pui_2002
rename g0197600 pui_2003
rename g0197700 pui_2004
rename g0213300 pui_2005
rename g0213400 pui_2006
rename g0226700 pui_2007
rename g0236600 pui_2008
rename g0241700 pui_2009
rename g0253800 pui_2010
rename g0262100 pui_2011
rename g0269500 pui_2012
rename g0277000 pui_2013
rename g0286200 pui_2014
rename g0293800 pui_2015
rename g0300700 pui_2016
rename g0301900 pui_2017
rename g0317700 pui_2018
rename g0318800 pui_2019
rename g0336300 pui_2020
rename g0337500 pui_2021
rename g0355400 pui_2022
rename g0356400 pui_2023

rename g0002700 sui_1978
rename g0009600 sui_1979
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
rename g0119700 sui_1993
rename g0122300 sui_1994
rename g0137900 sui_1996
rename g0153500 sui_1998
rename g0169100 sui_2000
rename g0184600 sui_2001
rename g0184700 sui_2002
rename g0200300 sui_2003
rename g0203000 sui_2004
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
rename r6943900 nonprop_1998
rename r6939500 nonprop_2000
rename t0944800 nonprop_2006
rename t2111200 nonprop_2008
rename t3078600 nonprop_2010
rename t4012700 nonprop_2012
rename t4947600 nonprop_2014
rename t5653600 nonprop_2016

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
rename g0250900 gssi_2010
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
rename g0346500 gssi_2022
rename g0365500 gssi_2023

* Non-taxable transfers (AFDC + food stamps + vet ben)

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
rename g0249100 foodstamp_2009
rename g0257700 foodstamp_2010
rename g0265000 foodstamp_2011
rename g0273400 foodstamp_2012
rename g0279900 foodstamp_2013
rename g0292100 foodstamp_2014
rename g0297100 foodstamp_2015
rename g0308100 foodstamp_2016
rename g0309300 foodstamp_2017
rename g0324900 foodstamp_2018
rename g0326000 foodstamp_2019
rename g0343800 foodstamp_2020
rename g0345100 foodstamp_2021
rename g0362200 foodstamp_2022
rename g0363200 foodstamp_2023

*Veteran benefits
rename r0322800 vetben_1979 
rename r0493300 vetben_1980 
rename r0793500 vetben_1981 
rename r1035400 vetben_1982 
rename r1422100 vetben_1983 
rename r1788500 vetben_1984 
rename r2151600 vetben_1985 
rename r2360300 vetben_1986 
rename r2723500 vetben_1987 
rename r2980900 vetben_1988 
rename r3290200 vetben_1989 
rename r3596900 vetben_1990 
rename r3907900 vetben_1991 
rename r4438300 vetben_1992 
rename r5044500 vetben_1993 
rename r5725900 vetben_1995 
rename r6442400 vetben_1997 
rename r6939900 vetben_1999 
rename r7640800 vetben_2001 
rename r8349900 vetben_2003 
rename t0945800 vetben_2005 
rename t2112500 vetben_2007 
rename t3079900 vetben_2009 
rename t4014000 vetben_2011 
rename t4948900 vetben_2014 
rename t5654700 vetben_2016 
rename t8182700 vetben_2018 
rename t8664200 vetben_2020 
rename t9217200 vetben_2022

gen transfers_1979 = afdc_1979 + foodstamp_1979 + vetben_1979
gen transfers_1980 = afdc_1980 + foodstamp_1980 + vetben_1980
gen transfers_1981 = afdc_1981 + foodstamp_1981 + vetben_1981
gen transfers_1982 = afdc_1982 + foodstamp_1982 + vetben_1982
gen transfers_1983 = afdc_1983 + foodstamp_1983 + vetben_1983
gen transfers_1984 = afdc_1984 + foodstamp_1984 + vetben_1984
gen transfers_1985 = afdc_1985 + foodstamp_1985 + vetben_1985
gen transfers_1986 = afdc_1986 + foodstamp_1986 + vetben_1986
gen transfers_1987 = afdc_1987 + foodstamp_1987 + vetben_1987
gen transfers_1988 = afdc_1988 + foodstamp_1988 + vetben_1988
gen transfers_1989 = afdc_1989 + foodstamp_1989 + vetben_1989
gen transfers_1990 = afdc_1990 + foodstamp_1990 + vetben_1990
gen transfers_1991 = afdc_1991 + foodstamp_1991 + vetben_1991
gen transfers_1992 = afdc_1992 + foodstamp_1992 + vetben_1992
gen transfers_1993 = afdc_1993 + foodstamp_1993 + vetben_1993
gen transfers_1994 = afdc_1994 + foodstamp_1994 + vetben_1993
gen transfers_1995 = afdc_1995 + foodstamp_1995 + vetben_1995
gen transfers_1996 = afdc_1996 + foodstamp_1996 + vetben_1995
gen transfers_1997 = afdc_1997 + foodstamp_1997 + vetben_1997
gen transfers_1998 = afdc_1998 + foodstamp_1998 + vetben_1997
gen transfers_1999 = afdc_1999 + foodstamp_1999 + vetben_1999
gen transfers_2000 = afdc_2000 + foodstamp_2000 + vetben_1999
gen transfers_2001 = afdc_2001 + foodstamp_2001 + vetben_2001
gen transfers_2002 = afdc_2002 + foodstamp_2002
gen transfers_2003 = afdc_2003 + foodstamp_2003 + vetben_2003
gen transfers_2004 = afdc_2004 + foodstamp_2004
gen transfers_2005 = afdc_2005 + foodstamp_2005 + vetben_2005
gen transfers_2006 = afdc_2006 + foodstamp_2006
gen transfers_2007 = afdc_2007 + foodstamp_2007 + vetben_2007
gen transfers_2008 = afdc_2008 + foodstamp_2008
gen transfers_2009 = afdc_2009 + foodstamp_2009 + vetben_2009
gen transfers_2010 = afdc_2010 + foodstamp_2010
gen transfers_2011 = afdc_2011 + foodstamp_2011 + vetben_2011
gen transfers_2012 = afdc_2012 + foodstamp_2012
gen transfers_2013 = afdc_2013 + foodstamp_2013
gen transfers_2014 = afdc_2014 + foodstamp_2014 + vetben_2014
gen transfers_2015 = afdc_2015 + foodstamp_2015
gen transfers_2016 = afdc_2016 + foodstamp_2016 + vetben_2016
gen transfers_2017 = afdc_2017 + foodstamp_2017
gen transfers_2018 = afdc_2018 + foodstamp_2018 + vetben_2018
gen transfers_2019 = afdc_2019 + foodstamp_2019
gen transfers_2020 = afdc_2020 + foodstamp_2020 + vetben_2020
gen transfers_2021 = afdc_2021 + foodstamp_2021
gen transfers_2022 = afdc_2022 + foodstamp_2022 + vetben_2022
gen transfers_2023 = afdc_2023 + foodstamp_2023

drop ///
    afdc_* foodstamp_* vetben_*
	
*Mortgage interest deductions
rename r1791201 mortgage_1985
rename r2154301 mortgage_1986
rename r2362901 mortgage_1987
rename r2758501 mortgage_1988
rename r2983301 mortgage_1989
rename r3293701 mortgage_1990
rename r3911401 mortgage_1992
rename r4394701 mortgage_1993
rename r5047001 mortgage_1994
rename r5728401 mortgage_1996
rename r6426401 mortgage_1998
rename r6944601 mortgage_2000
rename r7646101 mortgage_2002
rename r8349701 mortgage_2004
rename t0945901 mortgage_2006
rename t2112601 mortgage_2008
rename t3079801 mortgage_2010
rename t4013901 mortgage_2012
rename t4948801 mortgage_2014
rename t5654501 mortgage_2016
rename t8182501 mortgage_2018
rename t8664001 mortgage_2020

* Dividend income (Proxy from stock and bonds)
* Weighted Average Yield = (0.60×3%) + (0.40×6.5%) = 4.5%
* Assumes 60% in stocks (3% yield) and 40% in bonds (6.5% yield)

gen dividends_1985 = r1791201 * 0.045
gen dividends_1986 = r2154301 * 0.045
gen dividends_1987 = r2362901 * 0.045
gen dividends_1988 = r2735801 * 0.045
gen dividends_1989 = r2983301 * 0.045
gen dividends_1990 = r3293701 * 0.045
gen dividends_1992 = r3911401 * 0.045
gen dividends_1993 = r4392701 * 0.045
gen dividends_1994 = r5047001 * 0.045
gen dividends_1996 = r5728401 * 0.045
gen dividends_1998 = r6426401 * 0.045
gen dividends_2000 = r6944601 * 0.045

drop ///
    r1791201 r2154301 r2362901 r2735801 r2983301 ///
    r3293701 r3911401 r4392701 r5047001 r5728401 ///
    r6426401 r6944601


* TAXABLE INTEREST INCOME (3% OF SAVINGS BALANCE)
gen intrec_1985 = r1791401 * 0.03
gen intrec_1986 = r2154501 * 0.03
gen intrec_1987 = r2363101 * 0.03
gen intrec_1988 = r2736001 * 0.03
gen intrec_1989 = r2983501 * 0.03
gen intrec_1990 = r3293901 * 0.03
gen intrec_1992 = r3911601 * 0.03
gen intrec_1993 = r4393001 * 0.03
gen intrec_1994 = r5047201 * 0.03
gen intrec_1996 = r5728601 * 0.03
gen intrec_1998 = r6426601 * 0.03
gen intrec_2000 = r6944801 * 0.03
gen intrec_2004 = r8363000 * 0.03
gen intrec_2008 = t2126400 * 0.03
gen intrec_2012 = t4027600 * 0.03
gen intrec_2016 = t5665700 * 0.03
gen intrec_2020 = t8710300 * 0.03

drop ///
    r1791401 r2154501 r2363101 r2736001 r2983501 ///
    r3293901 r3911601 r4393001 r5047201 r5728601 ///
    r6426601 r6944801 r8363000 t2126400 t4027600 ///
    t5656700 t8710300

*  Spouse & children DOB (month/year pairs)
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
rename r7770201 child2month_2002
rename r7770202 child2year_2002
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
rename r7770701 child3month_2002
rename r7770702 child3year_2002
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
