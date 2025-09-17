/*****************************************************************
* Same-sex marriage mechanisms: Parliament vs Court
* Merge Excel -> WVS using ONLY COW_ALPHA; export unmatched
* Robust route-column detection + margins/AME exports (RTF & CSV)
* FIGURES: x-axis labeled "Acceptance"
*****************************************************************/
*=========================== LOG START ===========================*
version 17
set more off
set linesize 255

* -- Force project path (try both variants) --
capture cd "C:\Users\as372d\OneDrive - University of Glasgow\Glasgow_7_July_2023\Glasgow\Projects\Same sex marriage\work file\Insights_paper"
if _rc {
    capture cd "C:\Users\as372d\OneDrive - University of Glasgow\Glasgow\Projects\Same sex marriage\work file\Insights_paper"
}
display as text "PWD: " c(pwd)

* -- Force absolute output folder + create if missing --
local OUTDIR "C:\Users\as372d\OneDrive - University of Glasgow\Glasgow_7_July_2023\Glasgow\Projects\Same sex marriage\work file\Insights_paper\output"
capture mkdir "`OUTDIR'"

* -- Close any open logs, then open deterministic logs in that exact folder --
capture log close _all
capture cmdlog close

log using "`OUTDIR'\run_main.smcl", replace name(smcl)
log using "`OUTDIR'\run_main.txt",  text replace name(txt)
cmdlog using "`OUTDIR'\commands_main.txt", replace

display as result ">>> Logging to:"
display as result "    `OUTDIR'\run_main.txt"
display as result "    `OUTDIR'\run_main.smcl"
display as result "    `OUTDIR'\commands_main.txt"

* Optional: session header
about
*========================= LOG START (END) =======================*



version 17
clear all
set more off
set scheme s2mono
set linesize 255

*---------------------- WORKING DIRECTORY ----------------------*
capture cd "C:\Users\as372d\OneDrive - University of Glasgow\Glasgow_7_July_2023\Glasgow\Projects\Same sex marriage\work file\Insights_paper"
if _rc capture cd "C:\Users\as372d\OneDrive - University of Glasgow\Glasgow_7_July_2023\Glasgow\Projects\Same sex marriage\work file\Insights_paper"
if _rc di as error "Set a valid working directory at the top."
if _rc exit 170
pwd

*--------------------------- INPUTS ---------------------------*
local WVS   "WVS_Time_Series_1981-2022_stata_v5_0.dta"
local EXCEL "Same-sex_marriage__ALL-country_channel_table.xlsx"
local ENDYEAR = 2025

capture mkdir "output"
local OUTDIR "output"

*******************************************************
* 1) WVS: panel id & make COW_ALPHA -> country_code crosswalk
*******************************************************
use "`WVS'", clear

capture confirm variable COW_NUM
if _rc di as err "WVS lacks COW_NUM."
if _rc describe
if _rc exit 198
capture confirm numeric variable COW_NUM
if _rc destring COW_NUM, replace force
gen long country_code = COW_NUM
label var country_code "Country id (COW_NUM)"

* Find a 3-letter code column (prefer COW_ALPHA / code_alpha / iso3*)
local alpha ""
foreach cand in COW_ALPHA cow_alpha code_alpha CODE_ALPHA iso3 ISO3 ISO3C S003A_ISO3 {
    capture confirm variable `cand'
    if !_rc {
        capture confirm string variable `cand'
        if !_rc & "`alpha'"=="" {
            local alpha "`cand'"
        }
    }
}

if "`alpha'"=="" {
    ds, has(type string)
    local strvars `r(varlist)'
    foreach v of local strvars {
        local lbl : variable label `v'
        if "`alpha'"=="" {
            if ustrregexm(ustrlower("`lbl'"), "cow[_ ]?alpha|code[_ ]?alpha|country[_ ]?alpha|iso") {
                local alpha "`v'"
            }
        }
    }
}

if "`alpha'"=="" di as err "No 3-letter code in WVS."
if "`alpha'"=="" exit 198

tempfile cw_alpha
preserve
    keep country_code `alpha'
    rename `alpha' COW_ALPHA
    replace COW_ALPHA = upper(trim(COW_ALPHA))
    drop if missing(COW_ALPHA) | COW_ALPHA==""
    contract COW_ALPHA country_code, freq(nobs)
    bys COW_ALPHA: egen nmax = max(nobs)
    keep if nobs==nmax
    bys COW_ALPHA: gen rk = _n
    keep if rk==1
    keep COW_ALPHA country_code
    save `cw_alpha', replace
restore

*******************************************************
* 2) WVS survey-year acceptance (S020 -> Year)
*******************************************************
capture confirm variable S020
if _rc di as err "S020 (survey year) not found."
if _rc exit 198
capture confirm numeric variable S020
if _rc destring S020, replace force
rename S020 Year
label var Year "Survey year (WVS S020)"

* Homosexuality acceptance item (prefer F118)
local accvar ""
foreach cand in F118 Q182 V203 V200 {
    capture confirm variable `cand'
    if !_rc & "`accvar'"=="" {
        local accvar "`cand'"
    }
}

if "`accvar'"=="" di as err "Homosexuality item not found."
if "`accvar'"=="" exit 198
if "`accvar'"!="F118" rename `accvar' F118

keep country_code Year F118
drop if missing(country_code, Year, F118)

collapse (mean) F118, by(country_code Year)
gen double F118_raw01 = F118/10
label var F118_raw01 "Acceptance (survey-year, 0–1)"
tempfile wvs_svy
save `wvs_svy', replace

*******************************************************
* 3) Excel import (routes) – robust header detection
*******************************************************
import excel "`EXCEL'", firstrow clear   // add sheet("YourSheetName") if needed

capture confirm variable COW_ALPHA
if _rc di as err "Excel lacks COW_ALPHA."
if _rc describe
if _rc exit 198
replace COW_ALPHA = upper(trim(COW_ALPHA))

* Legalization year
local legvar ""
capture confirm variable year
if !_rc local legvar "year"
capture confirm variable legal_year
if "`legvar'"=="" & !_rc local legvar "legal_year"
if "`legvar'"=="" di as err "No legalization year column (year/legal_year)."
if "`legvar'"=="" exit 198
rename `legvar' legal_year
destring legal_year, replace force

* Robustly find route columns
local leg ""
local cour ""
capture ds *parl*
if "`leg'"=="" & "`r(varlist)'"!="" local leg : word 1 of `r(varlist)'
capture ds *Parl*
if "`leg'"=="" & "`r(varlist)'"!="" local leg : word 1 of `r(varlist)'
capture ds *PARL*
if "`leg'"=="" & "`r(varlist)'"!="" local leg : word 1 of `r(varlist)'
capture ds *legislat*parlia*
if "`leg'"=="" & "`r(varlist)'"!="" local leg : word 1 of `r(varlist)'
capture ds *Legislation*parliament*
if "`leg'"=="" & "`r(varlist)'"!="" local leg : word 1 of `r(varlist)'

capture ds *court*decision*
if "`cour'"=="" & "`r(varlist)'"!="" local cour : word 1 of `r(varlist)'
capture ds *decision*court*
if "`cour'"=="" & "`r(varlist)'"!="" local cour : word 1 of `r(varlist)'
capture ds *court*ct*
if "`cour'"=="" & "`r(varlist)'"!="" local cour : word 1 of `r(varlist)'
capture ds *court*
if "`cour'"=="" & "`r(varlist)'"!="" local cour : word 1 of `r(varlist)'

capture confirm variable `leg'
local rc_leg  = _rc
capture confirm variable `cour'
local rc_cour = _rc
if `rc_leg'  di as err "Could not detect parliament route column. See variables below:"
if `rc_leg'  describe
if `rc_leg'  exit 198
if `rc_cour' di as err "Could not detect court route column. See variables below:"
if `rc_cour' describe
if `rc_cour' exit 198

di as txt "Detected parliament column:  `leg'"
di as txt "Detected court column:       `cour'"

rename `leg'  parl
rename `cour' court
label var parl  "Legislation_ct (parliament)"
label var court "court_decision_ct (court)"

gen legal_year_parl  = cond(parl==1, legal_year, .)
gen legal_year_court = cond(court==1, legal_year, .)

keep COW_ALPHA legal_year* parl court
tempfile legal_excel
save `legal_excel', replace

* Diagnostics
use `legal_excel', clear
count
di as txt "Excel rows: " r(N)
quietly duplicates report COW_ALPHA
di as txt "Distinct COW_ALPHA in Excel: " r(unique_value)
capture noisily tab parl
capture noisily tab court

*******************************************************
* 4) Merge Excel → WVS using ONLY COW_ALPHA (show & save unmatched)
*******************************************************
use `legal_excel', clear
replace COW_ALPHA = upper(trim(COW_ALPHA))
merge m:1 COW_ALPHA using `cw_alpha', gen(_malpha)

count if _malpha==1
di as error "Unmatched after COW_ALPHA merge: " r(N)
preserve
    keep if _malpha==1
    export excel COW_ALPHA parl court legal_year using ///
        "`OUTDIR'/unmatched_after_alpha.xlsx", firstrow(variables) replace
restore

keep if _malpha==3
drop _malpha

quietly egen _tag = tag(country_code)
count if _tag
di as text "Countries matched into analysis (COW_ALPHA only): " r(N)
drop _tag
tempfile legal_m
save `legal_m', replace

*******************************************************
* 5) Annual risk set; forward-fill Acceptance; strict 1-year lag
*******************************************************
use `wvs_svy', clear
bys country_code: egen startyear = min(Year)
keep country_code startyear
duplicates drop
tempfile starts
save `starts', replace

use `legal_m', clear
merge m:1 country_code using `starts', nogen
replace startyear = 1981 if missing(startyear)

egen legal_year_any = rowmin(legal_year_parl legal_year_court)
gen endyear = cond(missing(legal_year_any), `ENDYEAR', legal_year_any)
gen span = endyear - startyear + 1
expand span
bys country_code: gen Year = startyear + _n - 1
drop span

merge 1:1 country_code Year using `wvs_svy', keep(master match) nogen
bys country_code (Year): gen double F118_ff = F118_raw01
bys country_code (Year): replace F118_ff = F118_ff[_n-1] if missing(F118_ff)

xtset country_code Year
gen double F118_use = L.F118_ff
label var F118_use "Acceptance (filled & 1-yr lag, 0–1)"
drop if missing(F118_use)

gen byte parl_this_year  = (Year==legal_year_parl)
replace   parl_this_year = 0 if missing(parl_this_year)
gen byte court_this_year = (Year==legal_year_court)
replace   court_this_year = 0 if missing(court_this_year)
assert !(parl_this_year==1 & court_this_year==1)

gen byte event_cat = 0
replace event_cat = 1 if parl_this_year==1
replace event_cat = 2 if court_this_year==1
label define ev 0 "no event" 1 "parliament" 2 "court"
label values event_cat ev

gen Year_c  = Year - 2000
gen period5 = floor((Year-1980)/5)
label var period5 "5-year bins"

tempfile panel
save `panel', replace

*******************************************************
* 6) Cause-specific hazards (adaptive baseline)
*******************************************************
use `panel', clear
di as txt "Obs in panel (after lag): " _N
tab event_cat

count if parl_this_year==1
local nparl = r(N)
count if court_this_year==1
local ncourt = r(N)

local base_parl ""
if `nparl' >= 21 local base_parl "i.Year"
if `nparl' < 21 & `nparl' >= 5 local base_parl "i.period5"
if `nparl' < 5  & `nparl' >= 2 local base_parl "c.Year_c"
if `nparl' < 2  local base_parl ""

local base_court ""
if `ncourt' >= 21 local base_court "i.Year"
if `ncourt' < 21 & `ncourt' >= 5 local base_court "i.period5"
if `ncourt' < 5  & `ncourt' >= 2 local base_court "c.Year_c"
if `ncourt' < 2  local base_court ""

if `nparl' > 0 di as txt "Parliament events: `nparl'  | Baseline: `base_parl'"
if `nparl' > 0 glm parl_this_year  c.F118_use `base_parl', family(binomial) link(cloglog) vce(cluster country_code)
if `nparl' > 0 estimates store CLOGLOG_parl
if `nparl' > 0 di as res "Parliament: HR for +1 on Acceptance (1–10):"
if `nparl' > 0 lincom 0.1*F118_use, eform

if `ncourt' > 0 di as txt "Court events: `ncourt'  | Baseline: `base_court'"
if `ncourt' > 0 glm court_this_year c.F118_use `base_court', family(binomial) link(cloglog) vce(cluster country_code)
if `ncourt' > 0 estimates store CLOGLOG_court
if `ncourt' > 0 di as res "Court: HR for +1 on Acceptance (1–10):"
if `ncourt' > 0 lincom 0.1*F118_use, eform

capture which esttab
if _rc==0 & `nparl'>0 & `ncourt'>0 esttab CLOGLOG_parl CLOGLOG_court using "`OUTDIR'/mechanism_cause_specific.rtf", eform b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) replace title("Cause-specific discrete-time hazards (adaptive baseline)")

*******************************************************
* 7) Multinomial route comparison + margins plots
*******************************************************
local both = (`nparl'>0 & `ncourt'>0)
if `both' mlogit event_cat c.F118_use c.Year_c, baseoutcome(0) vce(cluster country_code)
if `both' estimates store MNL
if `both' test [1]_b[F118_use] = [2]_b[F118_use]
if `both' mlogit, rrr

* Margins plots with Acceptance on X-axis
if `both' estimates restore MNL
if `both' margins, at(F118_use=(0.3(0.1)0.9)) predict(outcome(1))
if `both' marginsplot, ytitle("Pr(parliament)") xtitle("Acceptance (filled & 1-yr lag, 0–1)") title("Predicted probability: Parliament route") name(g_parl, replace)
if `both' graph export "`OUTDIR'/mechanism_margins_parl.png", as(png) replace width(2000)

if `both' estimates restore MNL
if `both' margins, at(F118_use=(0.3(0.1)0.9)) predict(outcome(2))
if `both' marginsplot, ytitle("Pr(court)") xtitle("Acceptance (filled & 1-yr lag, 0–1)") title("Predicted probability: Court route") name(g_court, replace)
if `both' graph export "`OUTDIR'/mechanism_margins_court.png", as(png) replace width(2000)

if `both' graph combine g_parl g_court, col(2) iscale(0.9) title("Predicted probabilities by route") name(g_comb, replace)
if `both' graph export "`OUTDIR'/mechanism_margins_combined.png", as(png) replace width(2400)

*******************************************************
* 8) EXPORT: margins tables (Pr) and AMEs (ΔPr) — RTF + CSV
*******************************************************

* ---- 8A) Predicted probabilities across Acceptance (multinomial) ----
if (`both') {
    estimates restore MNL
    margins, at(F118_use=(0.3(0.1)0.9)) predict(outcome(1)) post ///
        saving("`OUTDIR'/margins_parliament_table.dta", replace)
    estimates store MARG_parl

    estimates restore MNL
    margins, at(F118_use=(0.3(0.1)0.9)) predict(outcome(2)) post ///
        saving("`OUTDIR'/margins_court_table.dta", replace)
    estimates store MARG_court
}

* Pretty RTFs (if esttab available)
capture which esttab
if _rc==0 & (`both') {
    esttab MARG_parl  using "`OUTDIR'/margins_parliament.rtf", replace ///
        title("Predicted Pr(parliament) across Acceptance") ///
        nonotes cells("b(fmt(4)) se(fmt(4)) p(fmt(3))")
    esttab MARG_court using "`OUTDIR'/margins_court.rtf", replace ///
        title("Predicted Pr(court) across Acceptance") ///
        nonotes cells("b(fmt(4)) se(fmt(4)) p(fmt(3))")
}

* CSV exports
preserve
    capture confirm file "`OUTDIR'/margins_parliament_table.dta"
    if !_rc {
        use "`OUTDIR'/margins_parliament_table.dta", clear
        export delimited using "`OUTDIR'/margins_parliament.csv", replace
    }
    capture confirm file "`OUTDIR'/margins_court_table.dta"
    if !_rc {
        use "`OUTDIR'/margins_court_table.dta", clear
        export delimited using "`OUTDIR'/margins_court.csv", replace
    }
restore

* ---- 8B) Average Marginal Effects of Acceptance by route (multinomial) ----
if (`both') {
    estimates restore MNL
    margins, dydx(F118_use) predict(outcome(1)) post ///
        saving("`OUTDIR'/ame_parliament_mnl_table.dta", replace)
    estimates store AME_parl_mnl

    estimates restore MNL
    margins, dydx(F118_use) predict(outcome(2)) post ///
        saving("`OUTDIR'/ame_court_mnl_table.dta", replace)
    estimates store AME_court_mnl
}

* RTF with SEs (and stars).  <-- remove p()
capture which esttab
if _rc==0 & (`both') {
    esttab AME_parl_mnl AME_court_mnl using "`OUTDIR'/ame_mnl_by_route.rtf", replace ///
        title("Average marginal effect of Acceptance on Pr(legalisation) by route (multinomial)") ///
        b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) label
}

* (Optional) Alternate RTF with p-values instead of SEs:
if _rc==0 & (`both') {
    esttab AME_parl_mnl AME_court_mnl using "`OUTDIR'/ame_mnl_by_route_pvals.rtf", replace ///
        title("AME of Acceptance by route (multinomial) — p-values") ///
        b(4) p(3) label
}

* CSV exports (unchanged)
preserve
    capture confirm file "`OUTDIR'/ame_parliament_mnl_table.dta"
    if !_rc {
        use "`OUTDIR'/ame_parliament_mnl_table.dta", clear
        export delimited using "`OUTDIR'/ame_parliament_mnl.csv", replace
    }
    capture confirm file "`OUTDIR'/ame_court_mnl_table.dta"
    if !_rc {
        use "`OUTDIR'/ame_court_mnl_table.dta", clear
        export delimited using "`OUTDIR'/ame_court_mnl.csv", replace
    }
restore

* ---- 8C) AMEs from cause-specific hazards (probability scale) ----
capture estimates restore CLOGLOG_parl
if !_rc {
    margins, dydx(F118_use) post saving("`OUTDIR'/ame_parliament_hazard_table.dta", replace)
    estimates store AME_parl_haz
    capture which esttab
    if _rc==0 {
        esttab AME_parl_haz using "`OUTDIR'/ame_parliament_hazard.rtf", replace ///
            title("AME of Acceptance on annual probability (parliament, cloglog)") ///
            b(5) se(5)
    }
    preserve
        use "`OUTDIR'/ame_parliament_hazard_table.dta", clear
        export delimited using "`OUTDIR'/ame_parliament_hazard.csv", replace
    restore
}

capture estimates restore CLOGLOG_court
if !_rc {
    margins, dydx(F118_use) post saving("`OUTDIR'/ame_court_hazard_table.dta", replace)
    estimates store AME_court_haz
    capture which esttab
    if _rc==0 {
        esttab AME_court_haz using "`OUTDIR'/ame_court_hazard.rtf", replace ///
            title("AME of Acceptance on annual probability (court, cloglog)") ///
            b(5) se(5)
    }
    preserve
        use "`OUTDIR'/ame_court_hazard_table.dta", clear
        export delimited using "`OUTDIR'/ame_court_hazard.csv", replace
    restore
}

*============================ LOG END ============================*
display as result ">>> Logs saved in:"
display as result "    `OUTDIR'\run_main.txt"
display as result "    `OUTDIR'\run_main.smcl"
display as result "    `OUTDIR'\commands_main.txt"

* Close logs cleanly
capture log close smcl
capture log close txt
capture cmdlog close

* Optional: convert SMCL to PDF or plain text
capture noisily translate "`OUTDIR'\run_main.smcl" "`OUTDIR'\run_main.pdf", replace
capture noisily translate "`OUTDIR'\run_main.smcl" "`OUTDIR'\run_main_fromsmcl.txt", replace
*========================== LOG END (END) ========================*
