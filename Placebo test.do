*RUN THE REGRESSION_29_JULY_2025.DO FIST UNTILL SUMMARY STATISTICS
* 1. Assign a placebo legalization year (before actual legalization)
bysort Country_code: egen minyear = min(Year)
set seed 12345
bysort Country_code: gen Placebo_Legalization = runiformint(minyear, Year_Legalization - 1)

* 2. Generate placebo event time and dummies
gen placebo_event_time = Year - Placebo_Legalization
keep if placebo_event_time < 0
tabulate placebo_event_time, generate(pl_et)

* 3. Run event-study regression
reghdfe F118 pl_et1-pl_et23 Year Sex Age Marital_status dummy_muslim ///
        GDPpercapitacurrentUS HR_legalisation_year v2juhcind_bin polyarchy_bin ///
        e_fh_status edu_middle edu_upper aver_year_sch v2x_libde, ///
        absorb(country_id) cluster(country_id)

* 4. Output results for plotting
parmest, list(parm estimate stderr min95 max95) norestore
gen years_before_placebo = .
forvalues i = 1/23 {
    local yr = `i' - 24
    quietly replace years_before_placebo = `yr' if parm == "pl_et`i'"
}
twoway (rcap min95 max95 years_before_placebo, lcolor(red)) ///
       (scatter estimate years_before_placebo, mcolor(red) msymbol(circle)), ///
       xlabel(-23(2)-1, angle(45)) xline(0, lpattern(dash) lcolor(black)) ///
       xtitle("Years before placebo legalisation") ///
       ytitle("Change in public acceptance") ///
       title("Placebo Event-Study: Public Acceptance Before Placebo Legalization") ///
       legend(off) graphregion(color(white))
