# CLAUDE.md - AI Assistant Instructions for NLSY79 Project

## Project Context

This is a labor economics research project analyzing NLSY79 panel data. The research examines wage dynamics, human capital accumulation, elasticity of taxable income (ETI), and the skill vs. signaling debate.

**When helping with this project, you are assisting a senior economics/statistics student at CMU working with Professor André Sztutman.**

---

## Quick Reference

### Key Files
| File | Purpose | Status |
|------|---------|--------|
| `Data_process.do` | Main data pipeline (CSV → long format) | Production |
| `Two_Period_Analysis.do` | ETI estimation with TAXSIM | Production |
| `Skill_vs_Signal_Analysis.do` | Human capital vs signaling tests | Production |
| `EDA_DeepDive_OccInd.do` | Exploratory analysis by occ×ind | Production |

### Key Datasets
| File | Format | Observations | Description |
|------|--------|--------------|-------------|
| `merged_data.dta` | Wide | 12,686 | One row per person |
| `merged_data_with_occind.dta` | Wide | 12,686 | With occ_broad/ind_broad |
| `nlsy_long_pre_taxsim.dta` | Long | 583,556 | One row per person-year |

### Critical Variables
- `taxsimid` - Person identifier
- `year` - Calendar year (1978-2023)
- `pwages` - Primary wages
- `page` - Age at income year midpoint
- `hgc` - Highest grade completed (year-specific)
- `pot_exp` - Potential experience (age - education - 6)
- `cumhrs` - Cumulative hours worked (interpolated)
- `occ_broad` - Broad occupation (1-9), 1979-1993 only
- `ind_broad` - Broad industry (1-12), 1979-1993 only
- `mstat` - Marital status for TAXSIM (1=Single, 2=MFJ)

---

## Common Tasks

### 1. Debugging Stata Code

When debugging Stata code for this project:

1. **Check variable existence first:**
   ```stata
   describe varname
   codebook varname
   ```

2. **Check for missing values:**
   ```stata
   count if missing(varname)
   tab varname, missing
   ```

3. **Verify data structure:**
   ```stata
   * Check if wide or long format
   describe, short
   * For long format, verify panel structure
   xtset taxsimid year
   ```

4. **Common issues:**
   - Variables created AFTER a `save` command won't be in that file
   - Biennial years (1994+) have gaps - not all years have data
   - Occupation/industry only available 1979-1993
   - TAXSIM requires specific variable names and valid ranges

### 2. Adding New Variables

When adding new variables:

1. **For wide format (before reshape):**
   ```stata
   gen newvar_1990 = expression
   * Add to reshape command if needed
   ```

2. **For long format (after reshape):**
   ```stata
   gen newvar = expression
   ```

3. **Remember to:**
   - Label the variable: `label var newvar "Description"`
   - Handle missing values appropriately
   - Check for negative NLSY codes (-1 to -5 are missing)

### 3. TAXSIM Requirements

TAXSIM35 has strict input requirements:

| Variable | Valid Range | Notes |
|----------|-------------|-------|
| `mstat` | 1 or 2 | 1=Single, 2=MFJ |
| `page` | 0-100 | Primary taxpayer age |
| `sage` | 0-100 | Spouse age (0 if single) |
| `depx` | 0-15 | Number of dependents |
| `pwages` | ≥ 0 | No negative values |
| All income vars | ≥ 0 | No negative values |

**Validation template:**
```stata
* Before TAXSIM call
replace sage = 0 if sage < 0 | sage > 100 | missing(sage)
replace sage = 0 if mstat != 2
replace page = 0 if page < 0 | page > 100 | missing(page)
replace mstat = 1 if mstat != 1 & mstat != 2
replace depx = 0 if depx < 0 | missing(depx)
replace depx = 15 if depx > 15
foreach v in pwages swages psemp ssemp pui sui {
    replace `v' = 0 if `v' < 0 | missing(`v')
}
```

### 4. Working with Occupation × Industry

**Important:** occ_broad and ind_broad only exist for 1979-1993.

```stata
* Check if data has occ/ind
count if !missing(occ_broad)

* Create occ×ind cell identifier
gen occ_ind_cell = occ_broad * 100 + ind_broad

* For analyses requiring occ/ind
keep if !missing(occ_ind_cell)  // Restricts to 1979-1993
```

### 5. Panel Data Operations

```stata
* Set panel structure
xtset taxsimid year

* Within-person variation
xtreg y x, fe

* Between-person variation
xtreg y x, be

* Variance decomposition
xtreg y, mle
* e(rho) = % of variance that is between-person

* Lagged variables
bysort taxsimid (year): gen y_lag = y[_n-1]

* First difference
bysort taxsimid (year): gen dy = y - y[_n-1]

* Person-level statistics
bysort taxsimid: egen person_mean = mean(y)
bysort taxsimid: egen person_first = first(y)
```

---

## Project-Specific Patterns

### Data Processing Pattern

```stata
* Standard workflow
clear all
set more off

* Load data
use "nlsy_long_pre_taxsim.dta", clear

* Create sample restrictions
gen sample = (pwages > 0 & page >= 16 & page <= 65)

* Analysis on sample
keep if sample == 1

* [Your analysis here]
```

### EDA Pattern for Occupation × Industry

```stata
* Load and merge occ/ind data
use "merged_data_with_occind.dta", clear
keep taxsimid occ_broad_* ind_broad_*
reshape long occ_broad_ ind_broad_, i(taxsimid) j(year)
rename occ_broad_ occ_broad
rename ind_broad_ ind_broad
tempfile occ_ind
save `occ_ind'

use "nlsy_long_pre_taxsim.dta", clear
merge 1:1 taxsimid year using `occ_ind', keep(master match) nogen

* Create cell identifier
gen occ_ind_cell = occ_broad * 100 + ind_broad
```

### Regression Pattern

```stata
* Standard Mincer regression
gen log_wage = ln(pwages) if pwages > 0
gen exp2 = pot_exp^2

reg log_wage pot_exp exp2 educ_years, robust

* With year fixed effects
reg log_wage pot_exp exp2 educ_years i.year, robust

* Panel fixed effects
xtset taxsimid year
xtreg log_wage pot_exp exp2 i.year, fe robust
```

---

## Known Issues and Solutions

### Issue 1: "Variable not found"
**Cause:** Variable created after the save command, or using wrong dataset.
**Solution:** Check which .dta file contains the variable:
```stata
use "filename.dta", clear
describe varname
```

### Issue 2: TAXSIM Crash
**Cause:** Usually invalid input values (e.g., spouse age = 118).
**Solution:** Add validation before TAXSIM call (see Section 3 above).

### Issue 3: Occupation/Industry Missing
**Cause:** Data only available 1979-1993; or using `merged_data.dta` instead of `merged_data_with_occind.dta`.
**Solution:** 
1. Add save command to Data_process.do after line 1048
2. Use the correct dataset

### Issue 4: Cumulative Hours Plateau
**Cause:** Missing interpolation for biennial years.
**Solution:** Already fixed in Data_process.do with Fix #2.

### Issue 5: Wrong Marital Status Counts
**Cause:** Using old mapping (NLSY 2 = separated → TAXSIM 2).
**Solution:** Already fixed in Data_process.do with Fix #1.

---

## Code Style Guidelines

### Stata Code Style

```stata
/*==============================================================================
SECTION HEADER - ALL CAPS, BORDERED
==============================================================================*/

*------------------------------------------------------------------------------
* Subsection header - Title case, dashed border
*------------------------------------------------------------------------------

* Single line comment for clarity

gen variable = expression  // Inline comment if needed

* Use meaningful variable names
gen log_pwages = ln(pwages)  // Good
gen x1 = ln(pwages)          // Bad

* Label all created variables
label var log_pwages "Log of primary wages"

* Use preserve/restore for temporary operations
preserve
keep if condition
collapse (mean) meanvar=var, by(group)
restore
```

### File Organization

1. Header with purpose, author, date
2. Clear all and set more off
3. Log file
4. Data loading
5. Variable creation
6. Analysis sections
7. Output/save
8. Log close

---

## Asking for Help

When asking Claude for help with this project, provide:

1. **The error message** (exact text)
2. **The code that caused it** (relevant section)
3. **Which .do file** you're working in
4. **Which .dta file** you're using
5. **What you're trying to accomplish**

### Example Good Prompt

> I'm running EDA_DeepDive_OccInd.do and getting error "variable occ_broad_1990 not found" when loading merged_data_with_occind.dta. I need to analyze wage distributions by occupation × industry. The file should have been created by Data_process.do but seems to be missing the broad occupation categories.

### Example Bad Prompt

> It's not working, fix it.

---

## Research Background

### Elasticity of Taxable Income (ETI)

ETI measures how taxable income responds to changes in marginal tax rates:

```
ETI = (Δ log(taxable income)) / (Δ log(1 - marginal tax rate))
```

**Identification strategy:** Use tax reforms (EGTRRA 2001, JGTRRA 2003, TCJA 2017) as natural experiments. Compare workers with similar pre-reform incomes who face different tax changes.

### Skill vs. Signaling

**Human Capital Theory:** Wages grow because workers acquire skills through education and experience.

**Signaling Theory:** Education/experience reveals pre-existing ability; wages grow as employers learn worker quality.

**Key test:** If signaling dominates, wage growth should decrease as tenure increases (employer learning complete). If human capital dominates, wage growth should track skill proxies like cumulative hours.

### Why Occupation × Industry Matters

Returns to experience and cumulative hours may differ by sector:
- Finance: High returns to signaling (employer learning matters)
- Manufacturing: High returns to skill (learning-by-doing matters)
- Service: Mixed effects

---

## Useful Stata Commands

```stata
* Data inspection
describe
summarize var, detail
codebook var
tab var1 var2, missing
table var1 var2, stat(mean outcome)

* Panel data
xtset id time
xtdescribe
xtsum var

* Regression
reg y x1 x2, robust
reg y x1 x2 i.year, cluster(id)
xtreg y x1 x2, fe robust
xtreg y x1 x2, re robust

* Collapse for aggregation
collapse (mean) mean_y=y (count) n=y, by(group)

* Reshape
reshape long stub_, i(id) j(time)
reshape wide stub_, i(id) j(time)

* Merging
merge 1:1 id year using "file.dta"
merge m:1 id using "file.dta"

* By-group operations
bysort group: gen group_n = _N
bysort group (time): gen lag_y = y[_n-1]
bysort group: egen group_mean = mean(y)

* Graphs
histogram var, bin(30)
graph box y, over(group)
twoway scatter y x || lfit y x
twoway line y1 x || line y2 x
```

---

## Version Control Notes

When making changes to code:

1. **Test changes on a copy first**
2. **Document what you changed and why**
3. **Keep the original working version**
4. **Add version comments:**
   ```stata
   * Version 1.2 - Added Fix #6 spouse age validation
   ```

---

## Contact and Resources

- **NLSY79 Documentation:** https://www.nlsinfo.org/content/cohorts/nlsy79
- **TAXSIM35:** https://taxsim.nber.org/taxsim35/
- **Stata Documentation:** https://www.stata.com/manuals/

For project-specific questions, refer to conversation history with Claude or contact the research team.
