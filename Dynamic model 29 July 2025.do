clear
set obs 101
gen t = _n - 1

* Parameters
local x0 = 0.2          // initial support
local alpha = 0.05      // speed of adaptation
local p = 0.1           // external influence
local xstar = 0.5       // legalization threshold

* Three values of s
local s1 = 0.3
local s2 = 0.7
local s3 = 1.2

* Function for x(t):
* x(t) = ((p + s*x0)*exp(alpha*(p+s)*t) - p*(1-x0)) / ((1-x0)*s + (p + s*x0)*exp(alpha*(p+s)*t))

* For s1
gen x1_num = (`p' + `s1'*`x0') * exp(`alpha'*(`p'+`s1')*t) - `p'*(1-`x0')
gen x1_den = (1-`x0')*`s1' + (`p' + `s1'*`x0')*exp(`alpha'*(`p'+`s1')*t)
gen x1 = x1_num / x1_den

* For s2
gen x2_num = (`p' + `s2'*`x0') * exp(`alpha'*(`p'+`s2')*t) - `p'*(1-`x0')
gen x2_den = (1-`x0')*`s2' + (`p' + `s2'*`x0')*exp(`alpha'*(`p'+`s2')*t)
gen x2 = x2_num / x2_den

* For s3
gen x3_num = (`p' + `s3'*`x0') * exp(`alpha'*(`p'+`s3')*t) - `p'*(1-`x0')
gen x3_den = (1-`x0')*`s3' + (`p' + `s3'*`x0')*exp(`alpha'*(`p'+`s3')*t)
gen x3 = x3_num / x3_den

* Plot
twoway ///
    (line x1 t, lcolor(blue) lpattern(solid)) ///
    (line x2 t, lcolor(green) lpattern(dot) lwidth(thick)) ///
    (line x3 t, lcolor(red) lpattern(dash)) ///
    (function y = `xstar', range(0 100) lcolor(black) lpattern(dash)) ///
    , legend(order(1 "s = 0.3" 2 "s = 0.7" 3 "s = 1.2" 4 "Legalization threshold (x*)") ///
             ring(0) position(4) region(lcolor(white)) cols(1)) ///
    ytitle("Proportion supporting x(t)") xtitle("Time (years)") ///
    title("Dynamic Evolution of Public Support for Same-Sex Marriage")


