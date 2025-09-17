*-------------------------------------------------------------*
*      Placebo Permutation Test for Staggered Event Study      *
*     -- FULL PIPELINE, PUBLICATION-READY FIGURE --           *
*-------------------------------------------------------------*

* 1. Set working directory and file paths
local workdir "C:\Users\as372d\OneDrive - University of Glasgow\Glasgow_7_July_2023\Glasgow\Projects\Same sex marriage\work file\Insights_paper"
cd "`workdir'"

* 2. Load original data
use "`workdir'\same_sex_marri_wvs_legal_relig_GDPpc_Hrights_Freedom_Demo_edu.dta", clear

* 3. Set variable lists/macros
local outcome F118
local controls Year Sex Age Marital_status dummy_muslim GDPpercapitacurrentUS HR_legalisation_year v2juhcind_bin polyarchy_bin e_fh_status edu_middle edu_upper aver_year_sch v2x_libde
local reps = 500
local pre_events = 23

*-------------------------------------------------------------*
*    (A) Get Observed Maximum Absolute Pre-Treatment Effect   *
*-------------------------------------------------------------*
gen event_time = Year - Year_Legalization
keep if event_time < 0 & !missing(event_time)
tabulate event_time, generate(et)
reghdfe `outcome' et1-et`pre_events' `controls', absorb(country_id) cluster(country_id)

parmest, list(parm estimate) norestore
keep if substr(parm,1,2)=="et"
gen abs_est = abs(estimate)
egen obs_max = max(abs_est)
scalar obs_max = obs_max[1]
display "Observed maximum absolute pre-treatment effect: " obs_max

save "`workdir'\temp_event_results.dta", replace
* Reload original data for permutation
use "`workdir'\same_sex_marri_wvs_legal_relig_GDPpc_Hrights_Freedom_Demo_edu.dta", clear

*-------------------------------------------------------------*
*    (B) Placebo Permutation Loop                             *
*-------------------------------------------------------------*
preserve
capture postclose placebo_results
postfile placebo_results int(perm_num) double(maxabs) using "`workdir'\placebo_perm_results.dta", replace

forvalues perm = 1/`reps' {
    display as text "Permutation `perm'"
    restore, preserve
    set seed `=12345+`perm''
    bysort country_id: egen minyear = min(Year)
    bysort country_id: gen Placebo_Legalization = runiformint(minyear, Year_Legalization - 1)
    gen placebo_event_time = Year - Placebo_Legalization
    drop if placebo_event_time >= 0 | missing(placebo_event_time)
    capture drop pl_et*
    tabulate placebo_event_time, generate(pl_et)
    capture noisily reghdfe `outcome' pl_et1-pl_et`pre_events' `controls', absorb(country_id) cluster(country_id)
    parmest, list(parm estimate) norestore
    keep if substr(parm,1,5)=="pl_et"
    gen abs_est = abs(estimate)
    egen maxabs = max(abs_est)
    post placebo_results (`perm') (maxabs[1])
    drop abs_est maxabs
}
postclose placebo_results
restore

*-------------------------------------------------------------*
*    (C) Plot Permutation Distribution with Observed Value    *
*-------------------------------------------------------------*
use "`workdir'\placebo_perm_results.dta", clear

* Re-load observed max for overlay
use "`workdir'\temp_event_results.dta", clear
scalar obs_max = obs_max[1]
use "`workdir'\placebo_perm_results.dta", clear

* Set axis range so observed value always in plot
summarize maxabs
local x_min = min(r(min), obs_max) - 0.01
if `x_min' < 0 local x_min = 0
local x_max = max(r(max), obs_max) + 0.01

* Plot histogram
histogram maxabs, percent color(ltblue%60) ///
    xtitle("Max |Coefficient| on Placebo Pre-Treatment Dummy") ///
    ytitle("Percent") ///
    title("Placebo Distribution: Max Abs Pre-Treatment Effect") ///
    xline(`=obs_max', lcolor(red) lpattern(dash)) ///
    xscale(range(`x_min' `x_max')) ///
    legend(off) ///
    graphregion(color(white))

* Save figure
graph export "`workdir'\placebo_permutation_hist.png", replace width(1000)

*-------------------------------------------------------------*
*    (D) Calculate and Display Empirical P-value              *
*-------------------------------------------------------------*
count if maxabs >= obs_max
local greater_eq = r(N)
count
local total = r(N)
display "Empirical p-value = " (`greater_eq')/(`total')

*-------------------------------------------------------------*
*    END                                                      *
*-------------------------------------------------------------*
