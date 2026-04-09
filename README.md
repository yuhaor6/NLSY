# Signaling vs. Human Capital: Wage Dynamics in the NLSY79

This project uses the **National Longitudinal Survey of Youth 1979 (NLSY79)** to study wage dynamics, labor-market signaling, and the elasticity of taxable income. All analysis is conducted in Stata.

---

## Research Questions

1. **Skill vs. Signaling** — Does early-career wage growth reflect genuine skill formation (human capital) or employer learning / signaling strategies?
2. **Elasticity of Taxable Income** — What is the elasticity of taxable income with respect to hourly wage changes, following Becko, Sztutman & Xia (2024)?
3. **Two-Period Wage Analysis** — How do wage responses to tax incentives differ across the annual-survey era (1978–1993) and the biennial-survey era (1995–2019), following Gruber & Saez?

---

## Repository Structure

```
.
├── scripts/                        # Stata do-files (run in order)
│   ├── Data process.do             # 1. Import, merge, and clean raw NLSY data
│   ├── EDA_Wage_Analysis.do        # 2. Exploratory wage dynamics analysis
│   ├── EDA_DeepDive_OccInd.do      # 3. Occupation × industry deep dive
│   ├── Skill_vs_Signal_Analysis.do # 4. Signaling vs. human capital tests
│   ├── Two_Period_Analysis.do      # 5. Gruber-Saez two-period ETI analysis
│   └── BSX_Wage_Elasticity.do      # 6. BSX wage elasticity (IV regression)
├── output/
│   ├── graphs/                     # Generated figures
│   └── logs/                       # Stata log files
└── scrap work/                     # Exploratory / draft files
```

---

## Data

The scripts expect the following raw input files (not included in this repository — download directly from the [NLSY79 Investigator](https://www.nlsinfo.org/investigator/pages/login)):

| File | Contents |
|---|---|
| `NLSY_All_Data.csv` | Main respondent-level extract |
| `left_out.csv` | Additional variables not in the main extract |
| `Occupation_Industry.csv` | Occupation and industry codes by wave |
| `demo_x_hour.csv` | Demographics and hours worked |
| `BLS_CPI.dta` | BLS CPI series for real-income calculations |

TAXSIM output files (`taxsim_out.dta`, `taxsim_out_fixedreal.dta`, `taxsim_out_nominal.dta`) are stored in `scrap work/` and are produced by submitting constructed tax records to [NBER TAXSIM](https://taxsim.nber.org/).

---

## Scripts

### 1. `Data process.do`
Imports and merges all raw CSV files, then constructs key variables:
- Race/ethnicity and sex
- AFQT percentile scores (1980, 1989, 2006 revisions)
- Wave-specific wages, hours, education, marital status, and occupation/industry
- Potential experience, cumulative hours (with interpolation for non-survey years)
- Age alignment to income years
- TAXSIM-compatible spouse-age validation

**Output:** `nlsy_long_pre_taxsim.dta`, `merged_data_with_occind.dta`

### 2. `EDA_Wage_Analysis.do`
Exploratory analysis of wage dynamics:
- Mincer-style wages vs. potential experience
- Wages vs. cumulative hours worked
- Wages vs. age
- Work intensity (cumulative hours / age)

### 3. `EDA_DeepDive_OccInd.do`
Comprehensive occupation × industry analysis:
- Cell-size histograms and heatmaps
- Distributional wage moments by cell
- Wage profiles by experience, stratified by occupation × industry
- Within-person vs. between-person wage variation decomposition
- Occupation/industry switching and associated wage changes

### 4. `Skill_vs_Signal_Analysis.do`
Tests the human capital vs. signaling/employer-learning distinction using the NLSY79 panel:

| Test | Human Capital Prediction | Employer Learning Prediction |
|---|---|---|
| AFQT × Experience interaction (Altonji-Pierret) | Constant AFQT effect | AFQT effect *increases* with experience |
| Recent hours ("face time") | Small effect | Large effect |
| Wage variance over experience | Constant | Rises then stabilizes |
| OLS vs. fixed-effects coefficients | Similar | FE much smaller |
| Sheepskin effects (degree returns) | Small | Large |

### 5. `Two_Period_Analysis.do`
Replicates the Gruber-Saez (2002) ETI framework over two survey regimes:
- **Period 1** (1978–1993, annual): 3-year log-differences; ages ≈ 17–35; covers ERTA 1981 and TRA 1986
- **Period 2** (1995–2019, biennial): 2-year log-differences; ages ≈ 31–62; covers EGTRRA 2001, JGTRRA 2003, TCJA 2017

Constructs broad taxable income, marginal tax rates via TAXSIM, and estimates ETI using an instrumental-variables strategy.

### 6. `BSX_Wage_Elasticity.do`
Implements the wage/productivity elasticity regression from **Becko, Sztutman & Xia (2024)**, adapted to NLSY79:
- Dependent variable: 3-year change in log broad taxable income
- Endogenous variable: 3-year change in log hourly wage (`pwages / hrs`)
- Instrument: leave-one-out industry average wage change (BSX Eq. 31)
- Controls: time fixed effects, marital status, 9-piece income spline

> **Note:** Because NLSY79 reports primary wages but total hours across all jobs, the constructed hourly wage underestimates the primary-job wage for workers holding multiple jobs. This is a known measurement limitation relative to the SIPP data used in the original BSX paper.

---

## Running the Analysis

1. Place all raw data files in your Stata working directory.
2. Run the scripts in order:
   ```stata
   do "Data process.do"
   do "EDA_Wage_Analysis.do"
   do "EDA_DeepDive_OccInd.do"
   do "Skill_vs_Signal_Analysis.do"
   do "Two_Period_Analysis.do"
   do "BSX_Wage_Elasticity.do"
   ```
3. Logs are saved as `.txt` files in the working directory; graphs are saved to `output/graphs/`.

---

## References

- Altonji, J. G., & Pierret, C. R. (2001). Employer learning and statistical discrimination. *Quarterly Journal of Economics*, 116(1), 313–350.
- Becko, J., Sztutman, A., & Xia, C. (2024). Wage elasticity of taxable income. Working paper.
- Gruber, J., & Saez, E. (2002). The elasticity of taxable income: Evidence and implications. *Journal of Public Economics*, 84(1), 1–32.
- Bureau of Labor Statistics. NLSY79. https://www.bls.gov/nls/nlsy79.htm
