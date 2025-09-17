/*****************************************************************
* Discrete-time hazard of first legalization — FINAL
* Reverse-causality safe (strictly pre-determined acceptance)
* Stata 17+
*****************************************************************/
version 17
clear all
set more off

*================== PROJECT DIRECTORY (outputs go here) ==================*
cd "C:\Users\as372d\OneDrive - University of Glasgow\Glasgow_7_July_2023\Glasgow\Projects\Same sex marriage\work file\Insights_paper"

*================== LOG with safe fallback ==================*
capture mkdir "output"
capture log close _all
local D = subinstr(c(current_date)," ","_",.)
local T = subinstr(subinstr(c(current_time),":","",.),".","",.)
capture noisily log using "output\hazard_run_`D'_`T'.log", text replace
if _rc {
    di as err "Can't write in project\output (rc=`_rc'). Falling back to temp dir."
    log using "`c(tmpdir)'\hazard_run_`D'_`T'.log", text replace
}

*================== USER PATHS (HARD-CODED) ==================*
* WVS microdata (Time Series v5.0)
local WVS   "C:\Users\as372d\OneDrive - University of Glasgow\Glasgow_7_July_2023\Glasgow\Projects\Same sex marriage\work file\WVS_Time_Series_1981-2022_stata_v5_0.dta"
* Legalization dataset (direct .dta path)
local LEGAL "C:\Users\as372d\OneDrive - University of Glasgow\Glasgow_7_July_2023\Glasgow\Projects\Same sex marriage\work file\same_sex_marriage_court_10_Aug_2025.dta"
* OPTIONAL country–year covariates (set "" if none), must have: country_code, Year, plus vars
local COVARS ""    // e.g., "C:\...\country_year_covariates.dta"

* End of sample (censor never-legalizers and beyond-sample events)
local ENDYEAR = 2023

* Baseline hazard: 0 = Year FE; 1 = cubic spline
local USE_SPLINE = 0

* Output directory
local OUTDIR "output"
capture mkdir "`OUTDIR'"

*================== QUICK PATH CHECKS ==================*
capture confirm file "`WVS'"
if _rc {
    di as err "WVS file not found: `WVS'"
    exit 601
}
capture confirm file "`LEGAL'"
if _rc {
    di as err "LEGAL file not found: `LEGAL'"
    exit 601
}

*================== STANDARD GRAPH STYLE ==================*
graph set window fontface "Times New Roman"
set scheme s2mono

*================ BUILD WVS ID CROSSWALK =================*
use "`WVS'", clear

* Country id (numeric or string→encode to country_code)
local ctryvar ""
foreach cand in country_code S003 S003A S003B C_COW_NUM COW_NUM COWCODE C_CODE {
    capture confirm variable `cand'
    if _rc==0 & "`ctryvar'"=="" local ctryvar "`cand'"
}
if "`ctryvar'"=="" {
    local ctrystr ""
    foreach sc in country Country COUNTRY S003NAME S003A_NAME country_text countryname {
        capture confirm variable `sc'
        if _rc==0 & "`ctrystr'"=="" local ctrystr "`sc'"
    }
    if "`ctrystr'"!="" encode `ctrystr', gen(country_code)
    else {
        di as error "No country identifier found in WVS."
        exit 198
    }
}
else {
    capture confirm numeric variable `ctryvar'
    if _rc==0 gen long country_code = `ctryvar'
    else      encode `ctryvar', gen(country_code)
}

* ISO3-like string (for mapping legalization file if needed)
local iso3var ""
foreach cand in C_CODE COW_ALPHA ISO3 iso3 iso3c C_ALPH C_ALPHA C3_CODE {
    capture confirm variable `cand'
    if _rc==0 & "`iso3var'"=="" local iso3var "`cand'"
}
tempfile cw
preserve
keep country_code `iso3var'
keep if !missing(country_code)
duplicates drop
if "`iso3var'"=="" {
    gen str3 iso3 = ""
    keep country_code iso3
}
else {
    rename `iso3var' iso3
    replace iso3 = upper(trim(iso3))
}
duplicates drop
save `cw', replace
restore

*================ WVS → COUNTRY–YEAR MEANS =================*
* Year
local yearvar ""
foreach cand in Year year S020 s020 S020A S020_YEAR {
    capture confirm variable `cand'
    if _rc==0 & "`yearvar'"=="" local yearvar "`cand'"
}
if "`yearvar'"=="" {
    di as error "No survey year variable in WVS (Year/year/S020)."
    exit 198
}
rename `yearvar' Year

* Acceptance variable (homosexuality)
local accvar ""
foreach cand in F118 Q182 V203 V200 Q182A Q182_M Q182_R {
    capture confirm variable `cand'
    if _rc==0 & "`accvar'"=="" local accvar "`cand'"
}
if "`accvar'"=="" {
    di as error "No acceptance variable found (F118/Q182/V203/V200)."
    exit 198
}
rename `accvar' F118

* Optional probability weight
local wvar ""
foreach cand in weight wgt w_weight pweight S017 S017A s017 s017a WEIGHT {
    capture confirm variable `cand'
    if _rc==0 & "`wvar'"=="" local wvar "`cand'"
}

keep country_code Year F118 `wvar'
drop if missing(country_code, Year, F118)

tempfile wvs_cy
if "`wvar'"=="" {
    di as txt "Collapsing unweighted to country–year means"
    collapse (mean) F118 (count) nresp=F118, by(country_code Year)
}
else {
    di as txt "Collapsing with weights: `wvar'"
    collapse (mean) F118 (count) nresp=F118 [pw=`wvar'], by(country_code Year)
}
label var F118  "WVS acceptance mean"
label var nresp "Respondents (count)"
save `wvs_cy', replace

*================ LOAD & STANDARDIZE LEGAL =================*
use "`LEGAL'", clear

* Country id in LEGAL
local legal_id ""
foreach cand in country_code ccode iso3 ISO3 C_CODE COUNTRY_ISO3 country Country COUNTRY_NAME {
    capture confirm variable `cand'
    if _rc==0 & "`legal_id'"=="" local legal_id "`cand'"
}
if "`legal_id'"=="" {
    di as error "LEGAL must include a country identifier."
    exit 198
}

* Legalization year → legal_year
local legalvar ""
foreach cand in legal_year year_legalisation year_legalization legalisation_year legalization_year legal_year_first Tc T_c {
    capture confirm variable `cand'
    if _rc==0 & "`legalvar'"=="" local legalvar "`cand'"
}
if "`legalvar'"=="" {
    di as error "LEGAL must include the first nationwide legalization year."
    exit 198
}
rename `legalvar' legal_year
capture confirm numeric variable legal_year
if _rc destring legal_year, replace force

* Map to WVS numeric country_code if needed
capture confirm numeric variable `legal_id'
if _rc==0 {
    gen long country_code = `legal_id'
}
else {
    rename `legal_id' iso3
    replace iso3 = upper(trim(iso3))
    merge m:1 iso3 using `cw', keep(match) nogen
    capture confirm variable country_code
    if _rc {
        di as error "Could not map LEGAL ISO3 to WVS numeric country_code."
        exit 498
    }
}

keep country_code legal_year
duplicates drop
tempfile legal_num
save `legal_num', replace

*================ BUILD COUNTRY–YEAR SKELETON =================*
use `wvs_cy', clear
keep country_code
duplicates drop
tempfile countries
save `countries', replace

use `wvs_cy', clear
bys country_code: egen startyear = min(Year)
keep country_code startyear
duplicates drop
tempfile starts
save `starts', replace

use `countries', clear
merge 1:1 country_code using `starts', nogen
merge 1:1 country_code using `legal_num', nogen

replace startyear = 1981 if missing(startyear)
replace legal_year = . if legal_year > `ENDYEAR'   // censor beyond-sample legalizations
gen endyear = cond(missing(legal_year), `ENDYEAR', legal_year)

gen span = endyear - startyear + 1
expand span
bys country_code: gen Year = startyear + _n - 1
drop span

merge 1:1 country_code Year using `wvs_cy', keep(master match) nogen

* Optional: merge country–year covariates
if "`COVARS'" != "" {
    capture confirm file "`COVARS'"
    if !_rc {
        merge 1:1 country_code Year using "`COVARS'", keep(master match) nogen
    }
}

*================ STRICTLY PRE-DETERMINED ACCEPTANCE =================*
* Carry forward only from the past and then lag to ensure strictly prior
sort country_code Year
by country_code: gen F118_cf = F118
by country_code: replace F118_cf = F118_cf[_n-1] if missing(F118_cf)

xtset country_code Year
gen F118_pre   = L.F118_cf
gen F118_pre01 = F118_pre/10
label var F118_pre01 "Acceptance (last observed prior, 0–1)"

* Placebo "future" acceptance: next observed value AFTER t (should not predict)
gsort country_code -Year
by country_code: gen F118_nextobs = F118
by country_code: replace F118_nextobs = F118_nextobs[_n-1] if missing(F118_nextobs)
gsort country_code Year
gen F118_future01 = F118_nextobs/10
label var F118_future01 "Next observed acceptance (0–1) — placebo"

* Hazard DV and trimming
gen byte legal_this_year = (Year==legal_year) if Year<=legal_year
replace legal_this_year = 0 if missing(legal_this_year)
drop if Year > legal_year & legal_year < .
label var legal_this_year "Hazard: 1 in first legalization year, 0 earlier"

*================ MAIN MODELS =================*
di as res ">>> Estimating models…"
preserve
    if `USE_SPLINE'==0 {
        glm legal_this_year c.F118_pre01 i.Year, family(binomial) link(cloglog) vce(cluster country_code)
        estimates store CLOGLOG_main
    }
    else {
        mkspline y1 1981 1995 2010 2023 = Year
        glm legal_this_year c.F118_pre01 y1*, family(binomial) link(cloglog) vce(cluster country_code)
        estimates store CLOGLOG_main
    }

    di as text "Hazard ratio for +1 point on 1–10 scale (i.e., +0.1 on 0–1):"
    lincom 0.1*F118_pre01, eform

    * ---------- Predictive plot (averaged over Year FEs) ----------
    estimates restore CLOGLOG_main
    quietly margins, at(F118_pre01=(0.3 0.5 0.7 0.9))
    marginsplot,                                                ///
        recast(scatter) recastci(rcap)                          ///
        plotopts(msymbol(O) msize(medsmall) lwidth(medthin))    ///
        ciopts(lwidth(medthick))                                ///
        yscale(range(0 0.9)) ylabel(0(0.1)0.9, angle(0) format(%3.1f)) ///
        xlabel(0.3 0.5 0.7 0.9, format(%3.1f))                  ///
        ytitle("Probability")                                   ///
        xtitle("Acceptance (0–1, last observed prior)")         ///
        title("Predicted annual probability of first-time legalization") ///
        legend(off) graphregion(color(white)) plotregion(margin(zero))  ///
        name(fig_hazard_margins, replace)
    graph export "`OUTDIR'/hazard_margins_aea.png", width(2000) replace
    graph export "`OUTDIR'/hazard_margins_aea.pdf",  replace

    * ---------- Year restricted to 2015 (robust variant) ----------
    quietly count if e(sample) & Year==2015
    if r(N)>0 {
        estimates restore CLOGLOG_main
        quietly margins if Year==2015, at(F118_pre01=(0.3 0.5 0.7 0.9))
        marginsplot,                                                ///
            recast(scatter) recastci(rcap)                          ///
            plotopts(msymbol(O) msize(medium) lwidth(medthin))      ///
            ciopts(lwidth(medthin))                                 ///
            ylabel(0(0.1)1, angle(0) format(%3.1f))                 ///
            xlabel(0.3 0.5 0.7 0.9, format(%3.1f))                  ///
            ytitle("Probability")                                   ///
            xtitle("Acceptance (0–1, last observed prior)")         ///
            title("Predicted probability (Year fixed at 2015)")     ///
            legend(off) graphregion(color(white)) plotregion(margin(zero))   ///
            name(fig_hazard_margins_y2015, replace)
        graph export "`OUTDIR'/hazard_margins_aea_y2015.png", width(2000) replace
        graph export "`OUTDIR'/hazard_margins_aea_y2015.pdf",  replace
    }
    else di as err "Year 2015 not in estimation sample; skipping Year=2015 plot."

    * ---------- Fill the paper sentence: 0.5 → 0.6 ----------
    estimates restore CLOGLOG_main
    quietly margins, at(F118_pre01=(0.5 0.6))
    matrix T = r(table)
    scalar p05 = 100*el(T,1,1)
    scalar p06 = 100*el(T,1,2)
    di as res "Predicted probability at 0.5: " %4.1f p05 "%   |   at 0.6: " %4.1f p06 "%"

    * Placebo test: add future acceptance; it should be ≈ 0 effect
    glm legal_this_year c.F118_pre01 c.F118_future01 i.Year, ///
        family(binomial) link(cloglog) vce(cluster country_code)
    estimates store CLOGLOG_placebo
    di as text "Placebo HRs (expect future ≈ 1):"
    lincom 0.1*F118_pre01,   eform
    lincom 0.1*F118_future01, eform

    * Logit robustness
    logit legal_this_year c.F118_pre01 i.Year, vce(cluster country_code)
    estimates store LOGIT_alt
restore

*================ SAVE OUTPUTS =================*
save "`OUTDIR'/hazard_panel_final.dta", replace

* Export tables
capture which esttab
if _rc==0 {
    esttab CLOGLOG_main CLOGLOG_placebo LOGIT_alt using "`OUTDIR'/hazard_results_final.rtf", ///
        eform b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) replace
    di as result ">>> Results table: `OUTDIR'/hazard_results_final.rtf"
}
else {
    estimates table CLOGLOG_main CLOGLOG_placebo LOGIT_alt, b(%9.3f) se(%9.3f) star stats(N ll)
    log using "`OUTDIR'/hazard_results_final.txt", replace text
    estimates replay CLOGLOG_main
    estimates replay CLOGLOG_placebo
    estimates replay LOGIT_alt
    log close
    di as text "Note: esttab not installed; wrote text table to `OUTDIR'\hazard_results_final.txt"
}

di as result ">>> Figures saved to: `OUTDIR'\hazard_margins_aea.(png|pdf) and *_y2015.(png|pdf)"
di as result ">>> Panel saved:     `OUTDIR'\hazard_panel_final.dta"
di as result ">>> Done."

capture log close
