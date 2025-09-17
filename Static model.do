* Set range of s
range s 0.1 2 50
* Set parameters
local c 0.2
local pF 0.1

* Compute threshold for baseline
gen xstar = (1 + `c' - `pF') / (2*s)

* Compare with higher c and pF
local c2 0.5
local pF2 0.3
gen xstar_c2 = (1 + `c2' - `pF') / (2*s)
gen xstar_pF2 = (1 + `c' - `pF2') / (2*s)

* Plot all on same graph
twoway ///
  (line xstar s, lcolor(blue) lwidth(medthick) lpattern(solid) ) ///
  (line xstar_c2 s, lcolor(red) lwidth(medthick) lpattern(dash)) ///
  (line xstar_pF2 s, lcolor(green) lwidth(medthick) lpattern(dot)) ///
  , legend(order(1 "Baseline" 2 "Higher cost c" 3 "Higher penalty pF")) ///
    ytitle("Critical Threshold x*") xtitle("Social Norm Strength (s)") ///
    title("Static Compliance Threshold as a Function of Norm Strength")
