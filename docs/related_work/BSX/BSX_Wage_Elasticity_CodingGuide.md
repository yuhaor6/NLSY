# BSX Wage Elasticity: Coding Handoff Guide for Claude Code

**Target audience:** An AI coding agent operating inside a Stata project.  
**Scope:** Implement Priority 1 only — the wage/productivity elasticity regression from Becko, Sztutman & Xia (2024), adapted to an NLSY79 project.  
**Date:** March 2026

---

## 1. Objective

### 1.1 What to implement

A 2SLS regression estimating the elasticity of taxable income with respect to hourly wage changes, using a leave-one-out (LOO) industry wage instrument. This is the wage-side analog of the Gruber-Saez tax elasticity regression already implemented in this project.

The regression equation (BSX Eq. 30):

```
Δlog(z_{i,t+3}) = α + ε_w · Δlog(w_{i,t+3}) + δ_t + γ·M_{i,t} + Σ θ_j · SPLINE_j(z_{i,t}) + ε_{i,t}
```

where `Δlog(z)` is the 3-year change in log broad taxable income, `Δlog(w)` is the 3-year change in log hourly wage, and the instrument for `Δlog(w)` is a leave-one-out average wage change of others in the same base-year industry.

### 1.2 Why this is the right first priority

- It uses existing data and infrastructure (Stata, annual period, industry codes already merged).
- It produces the second elasticity needed for any engagement with BSX's sorting mechanism.
- The tax elasticity regression is already complete; this parallels that pipeline closely.
- It does not require R, new packages, or new data extracts.

### 1.3 Classification

| Component | Classification |
|-----------|---------------|
| Regression equation (DV, controls, FE) | **Paper-faithful** |
| Instrument design (LOO within industry) | **Paper-faithful in design** |
| Instrument identification strength in NLSY | **Exploratory approximation** (broad cells, single cohort) |
| Hourly wage construction | **Project-specific adaptation** (BSX measure wages directly; we derive them) |
| Sample restriction to 1979–1993 | **Project-specific adaptation** (industry codes unavailable after 1993) |

---

## 2. Paper-to-Project Mapping

### 2.1 What the paper does (BSX Eq. 30–31, SIPP data)

- **DV:** 3-year change in log broad taxable income.
- **Endogenous regressor:** 3-year change in log hourly wage. Hourly wage is measured directly from a SIPP survey question ("What is your hourly rate of pay?").
- **Instrument:** Leave-one-out average wage change within base-year industry cohort. Constructed from individual-level earnings and hours (not industry aggregates). See BSX Eq. 31.
- **Controls:** Year FE, married dummy, 10-piece income splines.
- **Data:** SIPP 2000–2013, rotating panel with multiple age cohorts, large industry cells.

### 2.2 What this project currently has

- **Taxable income (broad):** Already constructed. Variable name: computed in Two_Period_Analysis.do as the sum of `pwages + swages + psemp + ssemp + pui + sui + gssi + transfers + nonprop + pensions + dividends + intrec + rentpaid + otherprop + pbusinc + sbusinc` (components vary; inspect the existing code to confirm the exact definition used).
- **Annual hours worked:** Variable `hrs` in `nlsy_long_pre_taxsim.dta`. Self-reported annual hours. Available 1978–2019 (with biennial interpolation after 1993).
- **Industry codes:** Variable `ind_broad` (12 categories, 1970 Census broad industry). Available for 1979–1993 only. Must be merged from `occ_ind_data.dta` or `merged_data_with_occind.dta` into the long-format analysis data.
- **Tax elasticity pipeline (annual period):** Complete in `Two_Period_Analysis.do`. Produces `analysis_annual.dta` with 3-year paired observations, splines, sample restrictions, instruments, and regression results.
- **CPI data:** `BLS_CPI.dta` with variables `year` and `CPI`.

### 2.3 What needs adaptation

| Element | Paper (SIPP) | Project (NLSY) | Adaptation required |
|---------|-------------|----------------|---------------------|
| Hourly wage | Directly surveyed | Must construct: `pwages / hrs` | Yes — creates mechanical overlap and measurement error concerns |
| Industry classification | Presumably finer industry codes, all years | 12 broad categories, 1979–1993 only | Restricts analysis to annual period; broader cells reduce instrument power |
| LOO cohort sizes | Large (SIPP is big, finer industries) | Smaller (12,686 people / 12 industries ≈ 1,000 per industry on average, but varies by year and after sample restrictions) | Must verify cell sizes; may need to drop thin cells |
| Multiple cohorts | SIPP has workers of all ages | NLSY79 is one birth cohort (ages ~17–35 in annual period) | Age and calendar year are confounded; industry-lifecycle interactions cannot be separated |

### 2.4 What should NOT be assumed

- **Do not assume hourly wages are clean.** They are derived from `pwages / hrs`, both self-reported. Division bias and outliers are expected.
- **Do not assume the LOO instrument satisfies the exclusion restriction as strongly as in SIPP.** The identification argument is weaker here (see Section 7).
- **Do not assume industry codes are available after 1993.** They are not. The wage regression is annual-period only.
- **Do not assume the existing `analysis_annual.dta` already contains hours or industry variables.** It was built for the tax elasticity and likely does not. You will need to build a parallel or extended analysis dataset.
- **Do not assume the spline cutpoints or sample restrictions from the tax regression carry over without re-verification.** The wage regression sample may differ (additional requirement of valid hours and industry at both endpoints).
- **Do not assume `ε_w = 1 + ζ` is a testable prediction.** It is a model implication under specific functional form assumptions (quasilinear utility, constant labor supply elasticity, no tax avoidance). Departures could reflect model misspecification, measurement differences, or identification differences. Present the comparison descriptively.

---

## 3. Files to Inspect First

### 3.1 Files Claude Code MUST read before writing any code

| File | Why | What to extract |
|------|-----|-----------------|
| `Two_Period_Analysis.do` | This is the existing tax elasticity pipeline. The wage elasticity do-file should parallel its structure closely. | Exact taxable income definition, spline construction method, sample restriction sequence, CPI handling, paired-observation creation logic, regression specification, first-stage diagnostics |
| `Data_process.do` (or `Data_process_CORRECTED.do`) | Understand the reshape and variable construction pipeline. | How `hrs` is created, how `ind_broad` is created, what the final `nlsy_long_pre_taxsim.dta` contains |
| `EDA_Wage_Analysis.do` | Contains the occupation/industry merge logic (from `merged_data_with_occind.dta`). Also contains hourly wage-related exploratory code that may have useful snippets. | The merge command for `occ_ind_long`, the `ind_broad` labels, any existing `log_pwages` construction |

### 3.2 Files to reference for design decisions

| File | Purpose |
|------|---------|
| `BSX_Implementation_Memo_v2.docx` | Contains the full identification risk analysis. Consult Part 4 (mechanical overlap, exclusion restriction, measurement error) before making design choices. |
| `Becko_Sztutman_Xia.pdf` (uploaded paper) | Pages 21–22 for Eq. 30–31 (wage regression and instrument), page 20 for sample restrictions, Appendix C.3 for taxable income definition |

### 3.3 Background files (do not need to read in full)

| File | Role |
|------|------|
| `Skill_vs_Signal_Analysis.do` | Separate analysis; not relevant to wage elasticity |
| `BLS_CPI.dta` | Will be used but structure is known: `year`, `CPI` |

---

## 4. Required Variable Crosswalk

For each paper variable, the closest project equivalent and its status.

| Paper variable | Paper definition | Project variable(s) | Match quality | Construction notes |
|---------------|-----------------|---------------------|---------------|-------------------|
| `z` (taxable income) | Broad income: labor + interest + dividends + pensions + UI + business + property + nonprop income | Sum of income components in `nlsy_long_pre_taxsim.dta`. Inspect `Two_Period_Analysis.do` for the exact formula used in `taxable_income` or equivalent. | **Exact** (same definition as tax regression) | Must use the same definition as the tax elasticity for comparability. Copy the construction code. |
| `w` (hourly wage) | Directly measured in SIPP survey | Not available directly. Must construct: `pwages / hrs` | **Approximate** | `pwages` is primary wage earnings. `hrs` is annual hours worked at all jobs (verify: may be total hours, not primary-job hours). Division creates mechanical overlap with `z` since `pwages` is the largest component of `z`. |
| `Δlog(w_{i,t+3})` | 3-year change in log hourly wage | Must construct from above | **Approximate** | Requires valid positive hourly wages at both t and t+3. |
| LOO instrument `Δŵ` | Eq. 31: log(Σ_{j≠i} I_{j,t+3} / Σ_{j≠i} H_{j,t+3}) − log(Σ_{j≠i} I_{j,t} / Σ_{j≠i} H_{j,t}) where I = primary earnings, H = hours, sum over others in base-year industry | Must construct from `pwages`, `hrs`, `ind_broad` | **Approximate** | BSX use primary-job earnings and hours (SIPP has this distinction). NLSY `pwages` is primary wages; `hrs` may be total hours (verify). Also: BSX may use finer industry codes than our 12 broad categories. |
| Industry cohort `C(i,t)` | All other SIPP workers in same industry at base year | All other NLSY respondents with same `ind_broad` in base year | **Approximate** | Cohort sizes will be smaller and industry classification is coarser than BSX. |
| Year FE `δ_t` | Year dummies | `i.year` or `i.year_t` (inspect naming in Two_Period_Analysis.do) | **Exact** | |
| Married dummy `M_{i,t}` | Marital status indicator | `married` or `mstat` (inspect naming convention) | **Exact** | BSX use base-year marital status |
| 10-piece income spline | Linear splines at deciles of log base-year income | Already constructed in Two_Period_Analysis.do as `spline1`–`spline9` | **Exact** | Use the same spline cutpoints as the tax regression for comparability. But note: splines must be computed on the wage regression sample specifically if that sample differs from the tax regression sample. |
| Income weight | Weights proportional to base-year income (capped) | Already constructed in Two_Period_Analysis.do as `income_weight` | **Exact** | Same construction. |
| `hrs` (hours worked) | SIPP: hours at primary job | NLSY: `hrs` = annual hours. Verify whether this is primary job or all jobs. | **Approximate** | If `hrs` includes hours across multiple jobs but `pwages` is primary-job wages, the ratio `pwages/hrs` underestimates the true primary-job hourly wage. Check the NLSY codebook for the exact definition of the `hrs` variable. |

---

## 5. Step-by-Step Coding Plan

### Overview of stages

| Stage | Goal | Effort | Produces |
|-------|------|--------|----------|
| 0 | Inspect existing code; confirm variable definitions | Read-only | Notes on variable names, data structure |
| 1 | Construct hourly wages and apply quality filters | Small do-file section | Hourly wage variable, trimming diagnostics |
| 2 | Merge industry codes into analysis-ready long data | Small merge step | Dataset with `ind_broad` |
| 3 | Create 3-year paired observations with wage and industry variables | Moderate; parallels Two_Period_Analysis.do | Paired dataset |
| 4 | Construct the LOO industry wage instrument | Core new code | Instrument variable, cohort size diagnostics |
| 5 | Apply sample restrictions | Parallels existing pipeline | Sample flow table |
| 6 | Create regression variables (splines, weights, dummies) | Parallels existing pipeline | Analysis-ready dataset |
| 7 | Run regressions and diagnostics | Core output | First-stage F, OLS, 2SLS, reduced form |
| 8 | Robustness checks | Extensions | Alternative DV, dropped thin industries, etc. |

---

### Stage 0: Inspect existing code

**Goal:** Confirm variable names, data structure, and the taxable income definition used in the tax regression, before writing any new code.

**Actions:**

1. Open `Two_Period_Analysis.do`. Find and record:
   - The exact formula for taxable income (`taxable_income` or however it is named).
   - The variable names for the base-year income, log income, net-of-tax rate, instrument.
   - The paired-observation creation logic (how 3-year leads are generated).
   - The sample restriction sequence and the variable names for the restriction flags.
   - The spline construction code (which variable is used, how decile cutpoints are computed).
   - The regression command (exact `ivregress` syntax).
   - The variable name for year FE and marital status dummy.

2. Open `nlsy_long_pre_taxsim.dta` (via `use ... , clear` then `describe` or `codebook`). Confirm:
   - `hrs` exists and is numeric.
   - `pwages` exists and is numeric.
   - `ind_broad` does NOT exist in this file (it must be merged separately).
   - The years available and the panel structure (`xtset taxsimid year`).

3. Open `merged_data_with_occind.dta` or the occ/ind merge section of `EDA_Wage_Analysis.do`. Confirm how `ind_broad` is brought into long format.

**Output:** No code files. A mental model (or commented notes at the top of the new do-file) documenting the exact variable names and structures.

**Verify before moving on:** You can articulate the exact taxable income formula, the exact spline construction, and the exact merge pathway for `ind_broad`.

---

### Stage 1: Construct hourly wages

**Goal:** Create a log hourly wage variable with quality trimming.

**File to create/edit:** New do-file: `BSX_Wage_Elasticity.do`. All subsequent stages go into this file.

**Data tasks:**

```stata
use "nlsy_long_pre_taxsim.dta", clear

* Restrict to annual period where industry codes exist
keep if year >= 1979 & year <= 1993

* Construct hourly wage
* ADAPTATION NOTE: BSX measure hourly wages directly from SIPP survey.
* We derive them from annual earnings / annual hours.
* This introduces measurement error and mechanical overlap with taxable income.
gen hourly_wage = pwages / hrs if hrs > 0 & pwages > 0

* Quality trimming
* Floor: 520 hours/year = 10 hrs/week for 52 weeks (excludes trivial employment)
* Ceiling: 4160 hours/year = 80 hrs/week for 52 weeks (excludes reporting errors)
replace hourly_wage = . if hrs < 520 | hrs > 4160

* Real hourly wage outlier check (in nominal terms, flag for review)
* Do NOT hardcode a dollar floor/ceiling yet — first inspect the distribution
gen log_hourly_wage = ln(hourly_wage)
```

**Diagnostics to produce:**

```stata
* Distribution of annual hours (to verify reasonableness)
summarize hrs if hrs > 0, detail
histogram hrs if hrs > 0 & hrs < 5000, bin(50) title("Distribution of Annual Hours (1979-1993)")

* Distribution of constructed hourly wages
summarize hourly_wage, detail
histogram log_hourly_wage if !missing(log_hourly_wage), bin(50) title("Distribution of Log Hourly Wage")

* Fraction of observations lost to hours trimming
count if pwages > 0 & hrs > 0
local total = r(N)
count if pwages > 0 & hrs > 0 & (hrs < 520 | hrs > 4160)
local trimmed = r(N)
di "Observations trimmed by hours filter: `trimmed' / `total' = " %5.3f `trimmed'/`total'
```

**Verify before moving on:**

- [ ] `hourly_wage` has a sensible distribution (median roughly $5–$20 in nominal terms for 1979–1993).
- [ ] `log_hourly_wage` has no extreme outliers (check p1, p99).
- [ ] The hours trimming drops a reasonable fraction (<20%) of positive-earnings observations.
- [ ] If the trimming fraction is very large (>30%), re-examine whether `hrs` is being measured as intended. It might be weekly hours, not annual hours. Check the codebook.

**Bug indicators:**

- Hourly wage median below $1 or above $100 → hours variable is probably weekly, not annual, or vice versa.
- Very large fraction of `hrs = 0` or `hrs = .` → missing data pattern; inspect by year.
- `log_hourly_wage` has a spike at a single value → possible NLSY top-coding in `pwages` or `hrs`.

---

### Stage 2: Merge industry codes

**Goal:** Attach `ind_broad` to the working dataset.

**Data tasks:**

The industry codes live in the wide-format `merged_data_with_occind.dta` and must be reshaped to long before merging. Follow the pattern in `EDA_Wage_Analysis.do`:

```stata
* Save current data
tempfile main_annual
save `main_annual', replace

* Load wide-format data with industry codes
use "merged_data_with_occind.dta", clear
keep taxsimid ind_broad_*

* Reshape to long
reshape long ind_broad_, i(taxsimid) j(year)
rename ind_broad_ ind_broad

* Keep only annual period
keep if year >= 1979 & year <= 1993

tempfile ind_long
save `ind_long', replace

* Merge back
use `main_annual', clear
merge 1:1 taxsimid year using `ind_long', keep(master match) nogen
```

**Diagnostics:**

```stata
* Coverage
count if !missing(ind_broad)
count if missing(ind_broad) & pwages > 0
tab ind_broad if !missing(ind_broad), sort
tab year if !missing(ind_broad)
```

**Verify before moving on:**

- [ ] `ind_broad` is populated for a substantial fraction of observations (>50%) in years 1979–1993.
- [ ] All 12 industry categories have observations (no empty categories).
- [ ] There are no `ind_broad` values outside {1, 2, ..., 12}.

**Bug indicators:**

- `ind_broad` is entirely missing → the merge failed or `merged_data_with_occind.dta` does not contain industry variables. Check if the file exists and what variables it contains.
- `ind_broad` exists only for a few years → the reshape may have gone wrong. Verify the wide-format variable names (`ind_broad_1979`, `ind_broad_1980`, etc.).

---

### Stage 3: Create 3-year paired observations

**Goal:** Generate the paired dataset with base-year (t) and end-year (t+3) variables for both income and wages.

**Data tasks:**

This must mirror the paired-observation logic in `Two_Period_Analysis.do`. Inspect that file for the exact approach. The general pattern:

```stata
* Ensure sorted
sort taxsimid year

* Verify panel structure: consecutive annual data
by taxsimid: gen year_gap = year - year[_n-1]
tab year_gap if year_gap != .
* ALL gaps should be 1. If not, investigate.

* Create 3-year leads
by taxsimid: gen pwages_t3     = pwages[_n+3]
by taxsimid: gen hrs_t3        = hrs[_n+3]
by taxsimid: gen hourly_wage_t3 = hourly_wage[_n+3]
by taxsimid: gen log_hw_t3     = log_hourly_wage[_n+3]
by taxsimid: gen mstat_t3      = mstat[_n+3]      // or mstat_nlsy — use correct name
by taxsimid: gen year_t3       = year[_n+3]
by taxsimid: gen ind_broad_t3  = ind_broad[_n+3]

* Also create leads for ALL income components needed for taxable income
* CRITICAL: Copy the exact same income components used in Two_Period_Analysis.do
* Example (verify actual variable list):
by taxsimid: gen swages_t3  = swages[_n+3]
by taxsimid: gen psemp_t3   = psemp[_n+3]
* ... (all components of taxable income)

* Construct taxable income at t and t+3
* CRITICAL: Use the EXACT same formula as Two_Period_Analysis.do
* Example (verify):
gen taxable_income_t = pwages + swages + psemp + ssemp + pui + sui + gssi + nonprop + pensions + dividends + intrec + otherprop + pbusinc + sbusinc
gen taxable_income_t3 = pwages_t3 + swages_t3 + ... // same components with _t3 suffix

* Rename base-year variables for clarity
rename year year_t
rename ind_broad ind_broad_t
rename hourly_wage hourly_wage_t
rename log_hourly_wage log_hw_t
* ... etc as needed

* Drop observations without valid pairs
drop if missing(year_t3)

* Verify year gap is exactly 3
gen year_diff = year_t3 - year_t
tab year_diff
assert year_diff == 3
drop year_diff
```

**Verify before moving on:**

- [ ] All pairs have exactly a 3-year gap.
- [ ] Base years range from 1979 to 1990 (since leads go to 1982–1993).
- [ ] Both `taxable_income_t` and `taxable_income_t3` have sensible distributions.
- [ ] Both `log_hw_t` and `log_hw_t3` are populated for a reasonable number of observations.

**Bug indicators:**

- Year gaps ≠ 3 → panel is not sorted correctly, or there are missing years in the annual data.
- `taxable_income_t` values are 0 or negative for a large fraction → income components may be missing (coded as 0 vs. `.`). Check how missing income is handled.
- Very few observations have valid hourly wages at both endpoints → hours data may be sparse.

---

### Stage 4: Construct the LOO industry wage instrument

**Goal:** For each individual i in base year t, compute the leave-one-out average wage change of all other workers in the same industry.

This is the core new code. It implements BSX Eq. 31.

**Data tasks:**

```stata
* Step 1: Compute totals within industry-year cells at t and t+3
* Need: total pwages and total hrs for each industry × year, 
*        AND individual's own contribution to subtract out

* Base year (t) industry totals
bysort ind_broad_t year_t: egen ind_total_earnings_t = total(pwages)
bysort ind_broad_t year_t: egen ind_total_hours_t    = total(hrs)
bysort ind_broad_t year_t: egen ind_count_t          = count(pwages)

* Leave-one-out at base year
gen loo_earnings_t = ind_total_earnings_t - pwages
gen loo_hours_t    = ind_total_hours_t - hrs
gen loo_count_t    = ind_count_t - 1

* End year (t+3) industry totals
* IMPORTANT: Cohort is defined by BASE-YEAR industry (ind_broad_t), not end-year industry.
* Workers are assigned to their t industry even if they switch by t+3.
* We need earnings and hours at t+3 for the same set of people who were in this 
* industry at t. This means we sum pwages_t3 and hrs_t3 by ind_broad_t (not ind_broad_t3).

bysort ind_broad_t year_t: egen ind_total_earnings_t3 = total(pwages_t3) if !missing(pwages_t3) & !missing(hrs_t3)
bysort ind_broad_t year_t: egen ind_total_hours_t3    = total(hrs_t3)    if !missing(pwages_t3) & !missing(hrs_t3)
bysort ind_broad_t year_t: egen ind_count_t3          = count(pwages_t3) if !missing(pwages_t3) & !missing(hrs_t3)

* Leave-one-out at end year
gen loo_earnings_t3 = ind_total_earnings_t3 - pwages_t3
gen loo_hours_t3    = ind_total_hours_t3 - hrs_t3
gen loo_count_t3    = ind_count_t3 - 1

* Step 2: Construct the instrument
gen loo_avg_wage_t  = loo_earnings_t  / loo_hours_t
gen loo_avg_wage_t3 = loo_earnings_t3 / loo_hours_t3

gen loo_instrument = ln(loo_avg_wage_t3) - ln(loo_avg_wage_t)

* Step 3: Quality filters on the instrument
* Drop if LOO cohort is too small at either endpoint
replace loo_instrument = . if loo_count_t < 5 | loo_count_t3 < 5

* Drop if LOO hours are zero or negative (would produce missing or infinite wage)
replace loo_instrument = . if loo_hours_t <= 0 | loo_hours_t3 <= 0
```

**CRITICAL NOTES for Claude Code:**

1. The `bysort` for t+3 totals must group by `ind_broad_t` and `year_t`, NOT by `ind_broad_t3` or `year_t3`. The cohort is defined by base-year industry membership.

2. The `total()` and `count()` at t+3 should only include observations that have valid `pwages_t3` and `hrs_t3`. If some people in the base-year industry cohort have missing data at t+3 (attrition, missing hours), they should be excluded from the sum, and the LOO subtraction must account for whether the focal individual i has valid t+3 data.

3. There is an edge case: if individual i has missing `pwages_t3` or `hrs_t3`, they should not be included in `ind_total_earnings_t3` or `ind_total_hours_t3`, and their `loo_instrument` should be missing. The `if` condition on the `egen` handles this, but verify that the `gen loo_earnings_t3 = ind_total_earnings_t3 - pwages_t3` line does not produce nonsensical results for observations where i was excluded from the total.

4. A safer approach is to construct the LOO totals using a loop or a merge-based strategy rather than relying on `bysort + egen` with conditional totals. The `egen` approach can produce subtle bugs when the `if` condition excludes some observations from the `total()` but the subsequent subtraction operates on all observations. **If in doubt, use the explicit merge approach below instead.**

**Alternative (safer) construction via collapse + merge:**

```stata
* Preserve the main dataset
preserve

* Compute industry-year totals at base year
* Include only observations with valid wages and hours
keep if !missing(pwages) & !missing(hrs) & hrs > 0 & !missing(ind_broad_t)
collapse (sum) ind_total_earn_t=pwages ind_total_hrs_t=hrs (count) ind_n_t=pwages, by(ind_broad_t year_t)
tempfile ind_totals_t
save `ind_totals_t', replace

restore
preserve

* Compute industry-year totals at end year (t+3), grouped by BASE-YEAR industry
keep if !missing(pwages_t3) & !missing(hrs_t3) & hrs_t3 > 0 & !missing(ind_broad_t)
collapse (sum) ind_total_earn_t3=pwages_t3 ind_total_hrs_t3=hrs_t3 (count) ind_n_t3=pwages_t3, by(ind_broad_t year_t)
tempfile ind_totals_t3
save `ind_totals_t3', replace

restore

* Merge back
merge m:1 ind_broad_t year_t using `ind_totals_t', keep(master match) nogen
merge m:1 ind_broad_t year_t using `ind_totals_t3', keep(master match) nogen

* LOO: subtract own values
gen loo_earn_t  = ind_total_earn_t  - pwages
gen loo_hrs_t   = ind_total_hrs_t   - hrs
gen loo_n_t     = ind_n_t - 1

gen loo_earn_t3 = ind_total_earn_t3 - pwages_t3
gen loo_hrs_t3  = ind_total_hrs_t3  - hrs_t3
gen loo_n_t3    = ind_n_t3 - 1

* Instrument
gen loo_instrument = ln(loo_earn_t3 / loo_hrs_t3) - ln(loo_earn_t / loo_hrs_t)

* Quality filter
replace loo_instrument = . if loo_n_t < 5 | loo_n_t3 < 5
replace loo_instrument = . if loo_hrs_t <= 0 | loo_hrs_t3 <= 0
```

**Diagnostics:**

```stata
* Cohort sizes
summarize loo_n_t loo_n_t3, detail
tab ind_broad_t, summarize(loo_n_t)

* Instrument distribution
summarize loo_instrument, detail
histogram loo_instrument if !missing(loo_instrument), bin(50) ///
    title("Distribution of LOO Wage Instrument") ///
    xtitle("LOO Δlog(avg industry wage)")

* Check: instrument should have mean near aggregate wage growth
* and standard deviation reflecting cross-industry dispersion
di "Mean instrument: " %6.4f r(mean)
di "SD instrument:   " %6.4f r(sd)

* Cross-tab: instrument by industry (should vary across industries)
tab ind_broad_t, summarize(loo_instrument)
```

**Verify before moving on:**

- [ ] Cohort sizes (loo_n_t) have median > 30 for most industries. If median < 10, the instrument will be very noisy.
- [ ] The instrument has reasonable variation (SD > 0.01). If SD ≈ 0, there is no identifying variation.
- [ ] The instrument varies across industries (the cross-tab should show different means).
- [ ] The instrument varies across base years (this captures temporal wage shocks).
- [ ] No infinite or extreme values in the instrument.

**Bug indicators:**

- All `loo_instrument` values are identical → the `bysort` grouping is wrong (e.g., missing `year_t` in the group).
- `loo_instrument` is missing for nearly all observations → the `if` conditions in `egen` or the merge excluded too many people. Check how many observations have valid `pwages_t3` and `hrs_t3`.
- Extreme values (|instrument| > 2) for a substantial fraction → check whether `loo_hrs_t` or `loo_hrs_t3` is very small for some cells, producing extreme average wages.

**Design problem (not a bug):** If cohort sizes are very small (median < 20), the instrument will be noisy and the first-stage F may be low. This is a design limitation of using broad industry categories with a single-cohort sample. It cannot be fixed by better code — it requires different data or coarser industry groupings (e.g., collapsing 12 categories to 6).

---

### Stage 5: Apply sample restrictions

**Goal:** Apply the same restriction sequence as the tax regression, plus wage-specific restrictions.

**Data tasks:**

```stata
* Track sample flow
local N_start = _N
di "Starting observations: `N_start'"

* 1. Marital stability (same as tax regression)
*    Use the same variable names as Two_Period_Analysis.do
drop if mstat_t != mstat_t3     // or however marital stability is coded
local N_mstat = _N
di "After marital stability: `N_mstat'"

* 2. Real income floor (same as tax regression)
*    Need CPI to deflate. Merge if not already present.
*    Use the same dollar threshold as Two_Period_Analysis.do
*    INSPECT Two_Period_Analysis.do for the exact code.
merge m:1 year_t using "BLS_CPI.dta", keep(master match) nogen keepusing(CPI)
rename CPI cpi_t
gen real_income_t = taxable_income_t * ($cpi_1984 / cpi_t)
drop if real_income_t < $real_floor
local N_income = _N
di "After real income floor: `N_income'"

* 3. Positive taxable income at t+3
drop if taxable_income_t3 <= 0
local N_pos = _N
di "After positive end income: `N_pos'"

* 4. Valid hourly wages at BOTH t and t+3
*    THIS IS NEW — not in the tax regression
drop if missing(log_hw_t) | missing(log_hw_t3)
local N_wage = _N
di "After valid hourly wages: `N_wage'"

* 5. Valid LOO instrument
drop if missing(loo_instrument)
local N_iv = _N
di "After valid LOO instrument: `N_iv'"

* 6. (Optional) EITC exclusion if used in tax regression
*    Check Two_Period_Analysis.do for this

* Report sample flow
di ""
di "===== SAMPLE FLOW ====="
di "Start:                   `N_start'"
di "After marital stability: `N_mstat'"
di "After income floor:      `N_income'"
di "After positive end inc:  `N_pos'"
di "After valid wages:       `N_wage'"
di "After valid instrument:  `N_iv'"
di "========================"
```

**Verify before moving on:**

- [ ] Final sample size is > 10,000 (ideally > 20,000). If much smaller, the regression will lack power.
- [ ] The sample flow is monotonically decreasing (no step accidentally adds observations).
- [ ] The wage restriction (step 4) does not drop a disproportionate number of observations. If it does, investigate why — perhaps `hrs` is missing for many year-industry cells.

---

### Stage 6: Create regression variables

**Goal:** Construct the dependent variable, endogenous regressor, splines, weights, and fixed effects.

**Data tasks:**

```stata
* Dependent variable
gen log_income_t  = ln(taxable_income_t)
gen log_income_t3 = ln(taxable_income_t3)
gen delta_log_income = log_income_t3 - log_income_t

* Endogenous regressor
gen delta_log_wage = log_hw_t3 - log_hw_t

* 10-piece income splines at deciles of log base-year income
* CRITICAL: Use the SAME construction method as Two_Period_Analysis.do
* Copy the exact spline code from that file, or:
_pctile log_income_t, p(10 20 30 40 50 60 70 80 90)
forvalues j = 1/9 {
    gen spline`j' = max(0, log_income_t - r(r`j'))
}

* Income weights (same as tax regression — inspect Two_Period_Analysis.do)
gen income_weight = min(taxable_income_t, 1000000)  // cap at $1M — verify

* Marital status dummy
* VERIFY the correct variable name from Two_Period_Analysis.do
gen married = (mstat_t == 2)  // TAXSIM coding: 2 = married filing jointly

* Year fixed effects: will use i.year_t in the regression
```

**Verify before moving on:**

- [ ] `delta_log_income` and `delta_log_wage` have reasonable distributions (|mean| < 1, SD between 0.1 and 2).
- [ ] Splines are non-negative and monotonically ordered (spline1 ≥ spline2 ≥ ... ≥ spline9 in level, since higher cutpoints produce lower spline values).
- [ ] `income_weight` is positive for all observations.

---

### Stage 7: Run regressions and diagnostics

**Goal:** Produce the main results: OLS, first stage, 2SLS, and reduced form.

**Regression tasks:**

```stata
* ============================================================
* FIRST STAGE
* ============================================================
di ""
di "===== FIRST STAGE: LOO Instrument → Δlog(wage) ====="
regress delta_log_wage loo_instrument ///
    log_income_t spline1-spline9 i.year_t married ///
    [aweight=income_weight], cluster(taxsimid)

* Record first-stage F
test loo_instrument
local fs_F = r(F)
di "First-stage F-statistic: `fs_F'"

* ============================================================
* OLS (for comparison — known to be biased)
* ============================================================
di ""
di "===== OLS: Δlog(income) on Δlog(wage) ====="
regress delta_log_income delta_log_wage ///
    log_income_t spline1-spline9 i.year_t married ///
    [aweight=income_weight], cluster(taxsimid)
estimates store ols_wage

* ============================================================
* 2SLS: MAIN SPECIFICATION
* ============================================================
di ""
di "===== 2SLS: Wage Elasticity ====="
ivregress 2sls delta_log_income ///
    (delta_log_wage = loo_instrument) ///
    log_income_t spline1-spline9 i.year_t married ///
    [aweight=income_weight], cluster(taxsimid)
estimates store iv_wage
estat firststage

* ============================================================
* REDUCED FORM (instrument directly on income — valid even if
* exclusion restriction is debatable)
* ============================================================
di ""
di "===== REDUCED FORM: LOO instrument → Δlog(income) ====="
regress delta_log_income loo_instrument ///
    log_income_t spline1-spline9 i.year_t married ///
    [aweight=income_weight], cluster(taxsimid)
estimates store rf_wage
```

**Output to produce:**

```stata
* Summary table
estimates table ols_wage iv_wage rf_wage, ///
    keep(delta_log_wage loo_instrument) ///
    b(%9.4f) se(%9.4f) stats(N r2 F)

* Save analysis dataset
save "bsx_wage_analysis.dta", replace
```

**Verify before moving on:**

- [ ] First-stage F > 10 (Stock-Yogo threshold). If F < 10, the instrument is weak. Report LIML as a robustness check.
- [ ] First-stage coefficient is positive (higher industry wages → higher individual wages).
- [ ] 2SLS coefficient (wage elasticity) is positive. BSX's theory predicts ε_w > 0. A negative or very large (>5) estimate suggests problems.
- [ ] OLS coefficient is larger than 2SLS coefficient (expected, because OLS has upward bias from mechanical overlap).
- [ ] Reduced-form coefficient is positive and significant if the first stage is strong.
- [ ] Sample size reported in the regression output matches the final sample count from Stage 5.

**Bug indicators:**

- First-stage F ≈ 0 → instrument has no predictive power. Either the merge went wrong or industry cells are too small.
- 2SLS coefficient is negative and large → possible sign error in instrument construction. Check that the instrument is `log(wage_t3) - log(wage_t)`, not the reverse.
- Sample size in regression is much smaller than expected → Stata dropped observations due to missing values in a control variable. Check which variables have missings.
- `estat firststage` reports a different F than the manual `test` → this is normal; `estat firststage` uses a different formula. Report both.

**Design problem (not a bug):**

- First-stage F between 5 and 10 → instrument is weak but not hopeless. Report LIML alongside 2SLS. Note this in interpretation.
- 2SLS SE is very large (coefficient not significant) even with F > 10 → low power. This is expected with broad industry cells and a single cohort. The reduced-form effect may still be informative.

---

### Stage 8: Robustness checks

**Goal:** Address specific identification concerns from the memo (Part 4).

**Robustness 1: Alternative DV (Δlog(pwages) instead of Δlog(z)).**

This directly addresses the mechanical overlap concern from memo Section 4.1.

```stata
* Construct alternative DV using only primary wages
gen log_pwages_t  = ln(pwages) if pwages > 0
gen log_pwages_t3 = ln(pwages_t3) if pwages_t3 > 0
gen delta_log_pwages = log_pwages_t3 - log_pwages_t

* Re-run 2SLS with alternative DV
ivregress 2sls delta_log_pwages ///
    (delta_log_wage = loo_instrument) ///
    log_income_t spline1-spline9 i.year_t married ///
    [aweight=income_weight], cluster(taxsimid)
estimates store iv_wage_alt_dv
```

Interpretation: If the coefficient on `delta_log_wage` is close to 1, it means the instrument is mostly capturing the pwages component of income mechanically. A coefficient between 0 and 1 (but not exactly 1) is more informative.

**Robustness 2: Drop thin industry cells.**

```stata
* Drop industries with < 30 workers at base year
drop if loo_n_t < 30

* Re-run 2SLS
ivregress 2sls delta_log_income ///
    (delta_log_wage = loo_instrument) ///
    log_income_t spline1-spline9 i.year_t married ///
    [aweight=income_weight], cluster(taxsimid)
estimates store iv_wage_thick_cells
```

**Robustness 3: LIML (robust to weak instruments).**

```stata
ivregress liml delta_log_income ///
    (delta_log_wage = loo_instrument) ///
    log_income_t spline1-spline9 i.year_t married ///
    [aweight=income_weight], cluster(taxsimid)
estimates store liml_wage
```

**Robustness 4: Compare to tax elasticity on the SAME sample.**

This is Priority 2 from the memo. It requires that the tax elasticity be re-estimated on the wage-regression sample (which is a subset of the tax-regression sample).

```stata
* This requires the tax instrument (simulated MTR) to be available in this dataset.
* If it is not, merge it from analysis_annual.dta by taxsimid and year_t.
* Then re-run the tax 2SLS on this sample.
```

This step requires Yuhao's approval before proceeding (see Section 7).

---

## 6. Validation and Diagnostics

### 6.1 Summary of required logs/tables/figures

| Stage | Output | Format | Purpose |
|-------|--------|--------|---------|
| 1 | Hours and wage distributions | `summarize, detail` + histograms | Verify hourly wage construction |
| 2 | Industry code coverage | `tab ind_broad` by year | Verify merge |
| 4 | LOO cohort sizes by industry | `tab ind_broad_t, summarize(loo_n_t)` | Assess instrument quality |
| 4 | Instrument distribution | `summarize` + histogram | Verify instrument variation |
| 5 | Sample flow table | Display in log | Document attrition |
| 7 | First-stage regression | Full `regress` output | F-stat, coefficient, R² |
| 7 | OLS, 2SLS, reduced form | `estimates table` | Main results |
| 7 | `estat firststage` | Stata output | Formal weak-instrument diagnostics |
| 8 | Robustness table | `estimates table` across specs | Sensitivity |

### 6.2 What indicates a likely bug vs. a design problem

| Symptom | Likely bug | Likely design problem |
|---------|-----------|----------------------|
| All instrument values identical | `bysort` grouping wrong | — |
| First-stage F = 0 | Merge failed; instrument not populated | — |
| First-stage F between 1 and 10 | — | Broad industry cells, small sample |
| 2SLS coefficient negative and large | Sign error in instrument | — |
| 2SLS coefficient > 5 | — | Weak instrument bias (even with F > 10, finite-sample bias can be large) |
| Sample size drops to < 1,000 | Overly restrictive filters | Too much missing data in hours or industry |
| OLS ≈ 2SLS | — | Either the instrument is irrelevant (no endogeneity) or both are biased the same way |
| Robustness 1 coefficient ≈ 1.0 exactly | — | Mechanical overlap is dominant; instrument moves pwages but not other income |

---

## 7. Boundaries and Cautions

### 7.1 What Claude Code must NOT overclaim

- **Do not state that the wage elasticity is "identified" or "causal" without qualification.** The identification rests on the LOO instrument satisfying an exclusion restriction that is stronger in SIPP than in NLSY. Present results as "estimated using an instrumental variables strategy inspired by BSX (2024), adapted to NLSY79 data with broader industry cells and a single-cohort design."

- **Do not claim the comparison ε_w vs. ζ tests for tax avoidance.** It is consistent with several interpretations (see memo Section 4.3). Present the comparison descriptively.

- **Do not describe the instrument as "the same" as BSX.** It follows the same design but uses different data (NLSY vs. SIPP), different industry granularity (12 broad vs. presumably finer), and different wage measurement (constructed vs. survey-measured).

### 7.2 What adaptation choices must be flagged in code comments

Every place where the implementation departs from the paper must have a comment of the form:

```stata
* ADAPTATION: [description]. BSX use [what they do]. We use [what we do] because [reason].
```

Specific points to flag:

1. Hourly wage is constructed from `pwages / hrs`, not directly measured.
2. Industry classification is 12 broad categories (1970 Census), not finer industry codes.
3. Sample is restricted to 1979–1993 (annual period) due to industry code availability.
4. NLSY is a single birth cohort; age and calendar year are confounded.
5. LOO cohort sizes are smaller than BSX's SIPP cohorts.
6. `hrs` may be total hours (all jobs) rather than primary-job hours — to be verified.

### 7.3 What requires Yuhao's approval before proceeding

- **Hours variable definition.** Before constructing hourly wages, verify with Yuhao whether `hrs` in the NLSY data refers to hours at the primary job or total hours across all jobs. This affects interpretation. If total hours, the constructed hourly wage `pwages / hrs` underestimates the primary-job rate. Proceeding with a potentially wrong definition would contaminate all downstream results.

- **Collapsing industry categories.** If cohort sizes are too small with 12 categories, one option is collapsing to 6–8 broader groups. This is a research design choice, not a coding choice.

- **Re-estimating the tax elasticity on the wage-regression sample.** Robustness 4 in Stage 8 changes the tax elasticity estimate. Yuhao should confirm whether this is desired.

- **Choice of hours trimming thresholds.** The 520–4160 range is a reasonable default, but Yuhao may prefer different cutoffs based on the data distribution.

---

## 8. Suggested File Naming

### 8.1 Convention

All files related to the BSX extension use the prefix `bsx_`. Analysis files include the period (annual/biennial) and the specification (wage/tax).

### 8.2 File inventory

| File | Type | Contents |
|------|------|----------|
| `BSX_Wage_Elasticity.do` | Do-file | Main implementation (Stages 1–8) |
| `bsx_wage_elasticity_log.txt` | Log | Full Stata log from the do-file |
| `bsx_wage_analysis.dta` | Dataset | Final analysis dataset with all constructed variables |
| `bsx_wage_sample_flow.txt` | Table | Sample attrition table (text or log) |
| `bsx_wage_fs_scatter.png` | Figure | First-stage scatter: instrument vs. Δlog(wage) |
| `bsx_wage_instrument_hist.png` | Figure | Histogram of LOO instrument |
| `bsx_wage_hours_hist.png` | Figure | Histogram of annual hours (diagnostic) |
| `bsx_wage_hw_hist.png` | Figure | Histogram of log hourly wage (diagnostic) |
| `bsx_wage_cohort_sizes.txt` | Table | Industry cohort sizes by ind_broad and year |
| `bsx_wage_results_table.txt` | Table | OLS, 2SLS, reduced form, robustness estimates |
| `bsx_wage_comparison.txt` | Table | Side-by-side: wage elasticity vs. tax elasticity (same sample) |

### 8.3 Log discipline

The do-file should open a log at the top and close it at the bottom:

```stata
log using "bsx_wage_elasticity_log.txt", replace text
* ... all code ...
log close
```

Every `di` statement producing a key result should be prefixed with a label for easy `grep`:

```stata
di "[RESULT] First-stage F: `fs_F'"
di "[RESULT] 2SLS wage elasticity: " _b[delta_log_wage]
di "[RESULT] 2SLS wage SE: " _se[delta_log_wage]
di "[SAMPLE] Final N: " e(N)
```
