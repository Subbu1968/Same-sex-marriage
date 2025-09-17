* Clear and set up the data
clear
set obs 101

* Create a variable x from 0 to 1
gen x = (_n-1)/100

* Parameters
local alpha 0.01
local p 0.05

* Compute dx/dt for different s values
gen dxdt_s03 = `alpha'*(`p' + 0.3*x)*(1-x)
gen dxdt_s07 = `alpha'*(`p' + 0.7*x)*(1-x)
gen dxdt_s12 = `alpha'*(`p' + 1.2*x)*(1-x)

* Optional: zero line for reference
gen zero = 0

* Draw the graph
twoway ///
    (line dxdt_s03 x, lcolor(brown) lwidth(medthick) lpattern(solid)) ///
    (line dxdt_s07 x, lcolor(orange_red) lwidth(medthick) lpattern(solid)) ///
    (line dxdt_s12 x, lcolor(green) lwidth(medthick) lpattern(solid)) ///
    (line zero x, lcolor(black) lwidth(medthick) lpattern(dash)) ///
    , ///
    legend(order(1 "s = 0.3" 2 "s = 0.7" 3 "s = 1.2") ///
           ring(0) pos(11) ///
           region(style(none)) ///
           col(1)) ///
    xtitle("Support for Same-Sex Marriage, x") ///
    ytitle("Instantaneous rate of change, dx/dt") ///
    title("Instantaneous Rate of Change in Support vs. Current Support") ///
    graphregion(color(white)) ///
    ylabel(, angle(horizontal)) ///
    xlabel(0(.2)1)

