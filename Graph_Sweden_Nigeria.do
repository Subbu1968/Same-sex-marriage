//-------------------------------
// Evolution of Public Support
// for Same‑Sex Marriage (Stata)
//-------------------------------

clear all
set more off

* 1) Time grid: 0 to 100 in 0.1‑year steps
set obs 1001
gen t = ( _n - 1 ) * 0.1

* 2) Common parameters
local alpha = 0.05
local dt    = 0.1

* 3) Sweden trajectory
gen x_sw = . 
replace x_sw = 0.94 in 1
local p_sw = 0.20
local s_sw = 0.70
forvalues j = 2/1001 {
    replace x_sw = x_sw[_n-1] + ///
        `alpha'*(`p_sw' + `s_sw'*x_sw[_n-1])*(1 - x_sw[_n-1])*`dt' ///
      in `j'
}

* 4) Nigeria trajectory
gen x_ni = . 
replace x_ni = 0.07 in 1
local p_ni = 0.05
local s_ni = 0.30
forvalues j = 2/1001 {
    replace x_ni = x_ni[_n-1] + ///
        `alpha'*(`p_ni' + `s_ni'*x_ni[_n-1])*(1 - x_ni[_n-1])*`dt' ///
      in `j'
}

* 5) Create a constant 50% threshold series
gen thresh = 0.5

* 6) Plot all three as lines, then label them via legend(order())
twoway ///
    (line x_sw t, lcolor(blue)  lwidth(medium)) ///
    (line x_ni t, lcolor(green) lwidth(medium)) ///
    (line thresh t, lcolor(red)  lpattern(dash) lwidth(medium)), ///
    legend(order(1 "Sweden" 2 "Nigeria" 3 "Threshold (50%)") cols(1) ring(0) pos(4)) ///
    xlabel(0(10)100) ///
    xtitle("Time (years)") ///
    ylabel(0(.2)1) ///
    ytitle("Public Support x(t)") ///
    title("Evolution of Public Support for Same‑Sex Marriage") ///
    graphregion(color(white))
