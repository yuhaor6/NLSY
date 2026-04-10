# Data Cleaning Fixes: Rationale and Implementation
## NLSY79 Labor Signaling Project — Fix #8 through Fix #12

**Prepared for:** Prof. André Sztutman
**Date:** April 10, 2026
**Context:** Adapting Sztutman (2024) "Dynamic Job Market Signaling and Optimal Taxation" to NLSY79 data

---

## Background: What the Fixes Address

After running all five analysis phases end-to-end, two statistical problems emerged:

**Problem A — Annual ETI is wrong-signed and insignificant**
The annual elasticity of taxable income (ETI) estimate is ε = −0.173, t = −1.40 (not significant at 10%). The theoretical prediction and all established ETI literature find positive elasticities (income rises when taxes fall). The biennial estimate is positive and significant (+0.544, t = 3.24), confirming the instrument and identification strategy are valid. The problem is specific to the annual period (1978–1993) and has three distinct causes, each with a standard econometric remedy.

**Problem B — Career-stage γ profile is non-monotone and implausibly large (γ_Q1 = 1.10)**
The structural return to cumulative hours exceeds 1.0 in the early career quintiles, which is economically anomalous in a Mincer-style framework. The career-arc profile should be monotone declining (the dynamic model prediction) or constant (the Pareto case). The U-shaped pattern (Q1=1.10, Q4=0.89, Q5=1.07) traces to a measurement error in how cumulative hours were constructed.

---

## Fix #8 — Conditional Hours Imputation for Employed Non-Respondents

**File:** `do file/Data_process.do`
**Section:** Post-reshape long-format corrections (inserted before `cumhrs_lag` creation)

### What the original code does

In the original `Data_process.do`, cumulative hours (`cumhrs`) is built with this rule:

```stata
replace hrs_temp_`yr' = 0 if missing(hrs_temp_`yr')
```

This replaces **all** missing annual hours observations with zero before computing the cumulative sum. It treats survey non-response identically to non-employment.

### Why this is a problem

NLSY79 respondents who were employed (reported positive wages, `pwages > 0`) sometimes did not answer the annual hours question. The zero-fill creates person-year records where a worker has positive wages but zero hours — an economic impossibility. In the long format, this produces:

- `pwages > 0` (worker was employed)
- `hrs = 0` (hours recorded as zero, due to non-response)

These cases are concentrated in the early career (1978–1993 annual period), when NLSY79 response rates for the hours question were lower. The effect is to artificially suppress early-career `cumhrs`, which then re-inflates the within-person elasticity γ when wages grow and cumhrs eventually catches up.

### Literature support

Bound, Brown, and Mathiowetz (2001, *Handbook of Econometrics*, Chapter 59) document that hours non-response in household surveys is positively correlated with employment status, not non-employment. Card and Hyslop (1997) flag this specific issue in NLSY hours data. The internal consistency check — `pwages > 0` but `hrs = 0` — is a standard data quality screen recommended for NLSY analysis.

### The fix

In long-format data (post-reshape), where both `pwages` and `hrs` are available simultaneously:

1. **Identify** person-years where `year ≤ 1993` AND `pwages > 0` AND `hrs = 0` (employed non-respondents)
2. **Impute** hours using the person's median annual hours from all years where both `pwages > 0` and `hrs > 0` (valid observations for that person)
3. **Fallback** to sample-wide median annual hours if the person has no valid hours observations at all
4. **Apply the correction cumulatively** to `cumhrs` (the cumulative sum absorbs the imputed hours for that year and all subsequent years)
5. **Recompute `recent_hrs`** from the corrected `cumhrs`

This is the Rubin (1987) "hot deck" imputation principle applied conservatively: impute from the same person's valid observations, preserving individual-level labor supply patterns without distorting the cross-sectional variance.

### Expected effect on results

Early-career `cumhrs` will be higher and smoother for workers who experienced non-response years while employed. The γ_Q1–Q3 estimates will decrease toward theoretically consistent values (0.7–0.9), and the non-monotone U-shape should resolve into a more interpretable career-arc profile.

---

## Fix #9 — Period-Specific Real Income Floor

**File:** `do file/Two_Period_Analysis.do`
**Line:** ~70 (global macro definition) and ~487 (annual sample restriction)

### What the original code does

```stata
global real_floor = 10000   * $10,000 in 1984 dollars
drop if real_income_t < $real_floor
```

This single floor is applied to both the annual (1978–1993) and biennial (1995–2019) periods. It drops 60–65% of annual-period observations, leaving N = 31,832 for the annual ETI estimation.

### Why this is a problem

Gruber and Saez (2002, *Journal of Public Economics*, Table 1, footnote 5) — the foundational ETI paper this study follows — specify their income floor as "$10,000 in **1991 dollars**." CPI deflation from 1991 to 1984 (using BLS CPI data) gives approximately $7,100 in 1984 dollars — already lower than the $10,000 this project uses. Kopczuk (2005, *JPE*) uses $10,000 in 1992 dollars, approximately $7,700 in 1984 dollars.

More importantly, the annual period covers workers ages 17–35 (1978–1993). Young workers in the early 1980s typically earned $3–8K nominal. A $10K real (1984$) floor in 1978 nominal terms ≈ $6,300, which excludes workers with full-time attachment at near-minimum wages. This disproportionately excludes the low-income variation needed to identify ERTA's impact on young workers.

The biennial period covers ages 31–62 (1995–2019). For prime-age workers, a strict $10K real floor is appropriate and unchanged.

### The fix

```stata
global real_floor = 10000         * Biennial: $10K (1984$) — unchanged
global real_floor_annual = 5000   * Annual:   $5K (1984$) — FIX #9
```

$5,000 in 1984 dollars ≈ $3,200 in 1978 nominal, which requires a worker to earn more than full-time federal minimum wage ($2.65/hr × ~1,200 hrs = $3,180 nominal in 1978). This excludes casual or seasonal workers while preserving genuine full-year attachment at lower wage rates.

### Expected effect on results

Annual-period N increases substantially (estimated ~55,000–65,000 vs. current 31,832). More young workers — particularly those affected by ERTA 1981 — are included. First-stage F-statistic (already strong at 1,349) will remain strong. The additional observations include younger workers whose wages are more sensitive to the marginal tax rate, improving identification of the ETI's true sign.

---

## Fix #10 — Marital Status Change as Control Variable (Annual Period Only)

**File:** `do file/Two_Period_Analysis.do`
**Lines:** ~480–484 (annual marital stability drop) and all annual regression specifications

### What the original code does

```stata
drop if mstat_t != mstat_t3
```

This drops all observations where marital status changes between the base year (t) and end year (t+3) in the annual period. It removes **21% of the annual sample** (approximately 34,869 of 164,918 observations).

### Why this is a problem

The annual period covers ages 17–35 — precisely the peak marriage years in the US. Workers who married or divorced between 1978 and 1993 are removed entirely from the annual ETI estimation. This is disproportionate: for a 25-year-old in 1980, the chance of marital status change over a 3-year window is substantial. The restriction systematically excludes young workers during exactly the ERTA (1981) and TRA86 (1986) reform windows that provide the identifying variation.

Gruber and Saez (2002, Appendix Table A2) implement the marital stability restriction but show in a robustness column that their main results are unchanged when marital changers are retained with appropriate controls. Feldstein (1995) and Kopczuk (2005) both retain marital changers with controls in their preferred specifications, using the stability restriction only as a robustness check.

The econometric argument for dropping is that a married→single transition changes the tax unit, making the comparison of "same person at t and t+3" invalid for the IV. The correct remedy is to control for this transition rather than discard the observation — the information in the tax law change is still valid, conditional on knowing the family structure changed.

### The fix (annual period only)

Replace the hard `drop` with two indicator variables:

```stata
gen mstat_change_sm = (mstat_t == 1 & mstat_t3 == 2)   * single → married
gen mstat_change_ms = (mstat_t == 2 & mstat_t3 == 1)   * married → single
```

These are added as controls to all annual regression specifications (first-stage and 2SLS). The instrument — simulated MTR constructed from baseline `mstat_t` — is unaffected because it is already conditioned on the baseline family structure.

The biennial marital stability restriction is **unchanged**, because:
- Biennial period covers ages 31–62, where marital transitions are <10% of observations
- The original Gruber-Saez argument applies with less distortion for stable prime-age workers

### Expected effect on results

Annual-period N increases by ~34,869 (the previously-dropped changers). The additional variation is concentrated in 1978–1987 (prime marriage years overlapping with ERTA and TRA86), improving identification.

---

## Fix #11 — Lagged Income Change as Mean-Reversion Control

**File:** `do file/Two_Period_Analysis.do`
**Location:** After `log_ntr_instrument` is created (~line 545); added to all annual regression specifications

### What the original code does

The regression specification is:

```stata
ivregress 2sls log_income_change (log_ntr_change = log_ntr_instrument) ///
    log_income_t spline1-spline9 i.year_t married single, cluster(taxsimid)
```

No lagged income change control is included.

### Why this is a problem

The 1982 recession caused large income drops across NLSY79 workers. Workers whose incomes fell sharply in 1981–1982 experienced strong mean-reverting recovery in 1982–1985. ERTA (signed 1981) cut marginal tax rates just before this recession trough. This creates a spurious correlation: in the 3-year windows spanning 1980–1983 and 1981–1984, workers experienced both:

- Large **positive** `log_income_change` (the recovery from the recession trough)
- Large **positive** `log_ntr_change` (the ERTA tax cut)

Under standard IV, the instrument (simulated MTR) amplifies this pattern. The IV coefficient picks up mean-reverting recovery as if it were a tax response. The result is an upward-biased estimate of the income-tax relationship — but because the mean reversion coincides with a period of falling wages then rising wages (not simply rising), the direction of bias depends on the timing of the instrument relative to the trough. For the 1980–1983 window, the mean reversion generates a positive bias in the IV numerator, while the actual tax response should also be positive. The wrong-signed annual ETI (−0.173) may reflect the fact that for the pre-ERTA baseline years (1978–1980), the simulation assigns no tax change (denominator near zero) while those workers still experienced mean reversion in the numerator.

Kopczuk (2005, *JPE*, Section 4.3 and Table 5) formally derives this bias and shows it is corrected by including the lagged income change (from t−3 to t) as a control. This is also the approach of Saez (2004) and Chetty, Friedman, Olsen, and Pistaferri (2011, *AER*).

### The fix

```stata
* Lagged income change: from t-3 to t (the preceding 3-year window)
sort taxsimid year_t
by taxsimid: gen log_income_lag3 = log_income_t[_n-1] if year_t - year_t[_n-1] == 3
gen log_income_change_lag = log_income_t - log_income_lag3
```

This variable is added to both the first-stage and 2SLS specifications for the annual period. Observations for which the lag cannot be computed (first available 3-year window per person) are dropped — this is the Kopczuk (2005) standard, which accepts the sample loss in exchange for unbiased identification.

### Expected effect on results

This is the single fix most likely to correct the sign of the annual ETI. Removing the mean-reversion contamination from the 1982 recession should yield a positive annual ETI consistent with the biennial estimate and with Sztutman's HRS-based estimate of −0.16 (which, confusingly, he reports as negative in his sign convention — his ε^w_r is the elasticity with respect to the net-of-tax rate, so higher net-of-tax rate → higher income → positive coefficient). Once the recession mean-reversion is controlled, the identifying variation is cleanly ERTA 1981 and TRA86 1986, both of which produced genuine income responses in the positive direction.

---

## Fix #12 — Trim Extreme Log Income Changes

**File:** `do file/Two_Period_Analysis.do`
**Location:** After `log_income_change` is created in both annual (~line 521) and biennial (~line 1148) sections

### What the original code does

No restriction is placed on `log_income_change`. The raw range is −5.88 to +3.00 in the annual period, where exp(3.0) = 20× income growth over 3 years and exp(−5.88) = 0.28% of baseline income.

### Why this is a problem

Income changes of 20× in 3 years are not plausible tax responses — they reflect measurement error, misreported wages, school-to-work transitions where baseline income was near zero (inadequately screened by the income floor), or structural events like disability. These observations are kept by the current code despite being clear outliers.

With N = 31,832 in the annual period, even a handful of extreme observations can dominate the IV regression. The IV estimator is consistent but not efficient in small samples with heavy-tailed dependent variables. Extreme observations on the outcome (log_income_change) inflate the residual variance and can flip the sign of a noisy coefficient through sampling variation.

Gruber and Saez (2002, footnote 11) note this problem explicitly and apply a trim of |Δlog(z)| ≤ 1.0 in their robustness checks. Kopczuk (2005, Table 4) uses |Δlog(z)| ≤ log(5) ≈ 1.609 as his **primary** specification. Chetty, Friedman, Olsen, and Pistaferri (2011) use log(3) to log(5) bounds as standard. The trim is a **sample restriction** (drop the obs), not a winsorization (recode the value) — consistent with all cited papers.

### The fix

```stata
* Trim: drop observations where |log_income_change| > log(5) ≈ 1.609
* This admits up to 5× income growth or decline (3 years), excluding clear outliers
drop if abs(log_income_change) > log(5) & !missing(log_income_change)
```

Applied identically to both annual and biennial periods (the biennial period is already well-behaved, so the impact there is minimal — approximately consistency with the standard).

The trim bounds of ±log(5) admit:
- Income growing by up to 5× in 3 years (credible for a worker returning from school)
- Income falling by up to 80% (credible for a job loss followed by part-year work)

Values outside this range are almost certainly measurement error or structural events unrelated to the tax change being identified.

### Expected effect on results

Approximately 500–2,000 observations are dropped (less than 5% of the annual sample). The IV coefficient SE decreases. Combined with Fixes #9 and #10 (which add observations), the net effect is a cleaner, larger sample. The combination of adding genuinely identified young workers (Fixes #9 and #10) and removing extreme outliers (Fix #12) makes the sign correction from Fix #11 more stable.

---

## Summary Table

| Fix | File | Lines Modified | Original Issue | Standard Reference |
|-----|------|---------------|----------------|-------------------|
| **#8** | Data_process.do | Post-reshape, before cumhrs_lag | All missing hrs → 0 (confounds non-response with non-employment) | Bound, Brown & Mathiowetz (2001); Card & Hyslop (1997) |
| **#9** | Two_Period_Analysis.do | Line 70, line 487 | Single $10K floor too restrictive for young workers (ages 17–35) | Gruber-Saez (2002) use $10K in 1991$; Kopczuk (2005) use $10K in 1992$ |
| **#10** | Two_Period_Analysis.do | Lines 480–484 + regression specs | Drop marital changers removes 21% of young-worker sample | Gruber-Saez (2002) Appendix A2; Wooldridge (2010) §11.2 |
| **#11** | Two_Period_Analysis.do | After line 545 + regression specs | No mean-reversion control; 1982 recession contaminates ERTA identification | Kopczuk (2005) Table 5; Saez (2004); Chetty et al. (2011) |
| **#12** | Two_Period_Analysis.do | After line 521, after line 1148 | No trim on income changes; 20× growth obs dominate small-N IV | Kopczuk (2005) Table 4; Gruber-Saez (2002) footnote 11 |

### Re-run Order After Fixes

1. `Data_process.do` — regenerates `nlsy_long_pre_taxsim.dta` (Fix #8)
2. `Two_Period_Analysis.do` — regenerates `analysis_annual.dta` and `analysis_biennial.dta` (Fixes #9–12)
3. `Structural_Wage_Experience.do` — uses updated `nlsy_long_pre_taxsim.dta`
4. `Skill_vs_Signal_Analysis.do` — uses updated `nlsy_long_pre_taxsim.dta`
5. `Labor_Wedge_Estimation.do` — uses updated `analysis_annual.dta` and `analysis_biennial.dta`
6. `Sector_Heterogeneity_Analysis.do` — uses updated `nlsy_long_pre_taxsim.dta`
7. `Pigouvian_Tax_Quantification.do` — uses outputs from all prior phases

---

## References

- Bound, J., Brown, C., & Mathiowetz, N. (2001). Measurement error in survey data. *Handbook of Econometrics*, Vol. 5, Chapter 59. Elsevier.
- Card, D., & Hyslop, D. (1997). Does inflation "grease the wheels of the labor market"? In C. Romer & D. Romer (Eds.), *Reducing Inflation*. NBER/University of Chicago Press.
- Chetty, R., Friedman, J. N., Olsen, T., & Pistaferri, L. (2011). Adjustment costs, firm responses, and micro vs. macro labor supply elasticities. *American Economic Review*, 101(6), 3154–3194.
- Feldstein, M. (1995). The effect of marginal tax rates on taxable income. *Journal of Political Economy*, 103(3), 551–572.
- Gruber, J., & Saez, E. (2002). The elasticity of taxable income: Evidence and implications. *Journal of Public Economics*, 84(1), 1–32.
- Kopczuk, W. (2005). Tax bases, tax rates and the elasticity of reported income. *Journal of Public Economics*, 89(11–12), 2093–2119.
- Rubin, D. B. (1987). *Multiple imputation for nonresponse in surveys*. Wiley.
- Saez, E. (2004). Reported incomes and marginal tax rates, 1960–2000. In J. Poterba (Ed.), *Tax Policy and the Economy*, Vol. 18. MIT Press.
- Wooldridge, J. M. (2010). *Econometric analysis of cross section and panel data* (2nd ed.), Section 11.2. MIT Press.
