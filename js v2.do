/*
Описание. 

	Отличается от v1 иным представленем

Что тут делается. 
1. Данные берутся из /rlms/_res.dta
gen sector = 1 * private1 + 2 * soe + 3 * budgetnik

./data/js_tabs.xlsx - описательные таблицы, вопрос 1.
*/

// cd "C:/Users/Sony/SkyDrive/"
// cd "C:/Users/Sony/YandexDisk/IEP"
// cd "C:/Users/Maxim/YandexDisk/IEP/"
// cd "/Users/leonovmx/Яндекс.Диск/IEP/"

*** LOG ************************************************************************

* Доработать логи, на каждую спецификацию надо свой лог
cap log close _all // закрываем, есл какие-то открыты

local date: display %tdCCYY-NN-DD date(c(current_date), "DMY") // название лог файла с датой
log using ${wd}`date'.smcl, replace name("log") // начинается лог

*** START **********************************************************************

clear all
set more off, perm
global input_path ./rlms/
global wd ./senik/  // working directory, аналог названия проекта
* global pic_path ./${project}/pic/
global result_file = "${input_path}_res.dta" // отсюда данные беруться
* LOAD DATA
use "${result_file}", clear

* Смотрим только тех, кто работает и репрезентативных
keep if _origsm == 1
* Оставляем тех, кто работает или в отпуске.
keep if inlist(j1, 1, 2, 3, 4)



* Для excel таблицы делаем значения меньше.
foreach x of varlist j1_1_* {
	replace `x' = 6 if `x' == 99999997
	replace `x' = 7 if `x' == 99999998
	replace `x' = 8 if `x' == 99999999
	replace `x' = 9 if `x' == .
} 

*** DESCRIPTIVE ****************************************************************
* Проверить, перекочевало из старой версии

local y = 2013 // год для которого надо сделать исследование
* Выгружаем данные, на них строятся статистики в excel
* ? Вопрос задавался не во все года. Исключить какие-то года.
export excel year j1_1_1 sector using ${wd}data/js_tabs.xlsx if year == `y', ///
	sh("1-desc-2013") sheetreplace nolabel firstrow(var)
export excel year j1_1_1 sector using ${wd}data/js_tabs.xlsx , ///
	sh("1-desc-all") sheetreplace nolabel firstrow(var)

* Медиана в 2013
cap summarize j1_1_1 if j1_1_1 <= 5 & sector == 3 & year == `y', detail // Бюджетник
putexcel C14 = (r(p50)) using ${wd}data/js_tabs.xlsx, sheet("1-results-2013") mod
cap summarize j1_1_1 if j1_1_1 <= 5 & sector == 2 & year == `y', detail // Гос. пред.
putexcel E14 = (r(p50)) using ${wd}data/js_tabs.xlsx, sheet("1-results-2013") mod
cap summarize j1_1_1 if j1_1_1 <= 5 & sector == 1 & year == `y', detail // Частный
putexcel G14 = (r(p50)) using ${wd}data/js_tabs.xlsx, sheet("1-results-2013") mod

* Медиана во все года
cap summarize j1_1_1 if j1_1_1 <= 5 & sector == 3 , detail // Бюджетник
putexcel C14 = (r(p50)) using ${wd}data/js_tabs.xlsx, sheet("1-results-all") mod
cap summarize j1_1_1 if j1_1_1 <= 5 & sector == 2, detail // Гос. пред.
putexcel E14 = (r(p50)) using ${wd}data/js_tabs.xlsx, sheet("1-results-all") mod
cap summarize j1_1_1 if j1_1_1 <= 5 & sector == 1, detail // Частный
putexcel G14 = (r(p50)) using ${wd}data/js_tabs.xlsx, sheet("1-results-all") mod

* Удаление пропущенных
foreach x of varlist j1_1_* {
	replace `x' = . if `x' >= 6
}

* Делаем перменную доволен / недовлен
gen sat = 1 if inlist(j1_1_1, 1, 2, 3)
replace sat = 0 if inlist(j1_1_1, 4, 5)

gen sat1 = 1 if inlist(j1_1_1, 1, 2)
replace sat1 = 0 if inlist(j1_1_1, 3, 4, 5)

* Generate new j1_1_1, where 1 - is totaly upset with work
gen nj1_1_1 = 1 if j1_1_1 == 5
replace nj1_1_1 = 2 if j1_1_1 == 4
replace nj1_1_1 = 3 if j1_1_1 == 3
replace nj1_1_1 = 4 if j1_1_1 == 2
replace nj1_1_1 = 5 if j1_1_1 == 1

********************************************************************************
*** AUTOMATING *****************************************************************
********************************************************************************

xtset idind year 

/*
Для каждой спецификации для каждого из пула или панели 
в таблице в столбце должны стоять коэффициенты при секторе и 
при отрасли и/или отрасил * сектор, а столбцы будут отличаться друг от друга
переменной слева (зарплата / удовлетворённость)
*/

global n1 = "Budg vs all" 
global n2 = "SOE vs all" 
global n3 = "Public vs all" 
global n4 = "Budg vs private" 
global n5 = "SOE vs private" 
global n6 = "All"

estimates clear
global sec = "budgetnik soe public" // сектора
global vars "male married age age_sq j6_2 high_educ tenure tenure_sq fsize_small fsize_med city dummy_Moscow _Ifo_*" // переменные для пула
global pnl_vars " married age age_sq j6_2 high_educ tenure tenure_sq fsize_small fsize_med city dummy_Moscow" // переменные для панели

global spec1 "_Iyear*"
global spec2 "_Iyear* _Iind2* _Iocc1*"
global spec3 "_Iyear* _Iind2* _Iocc2*"
global spec4 "_Iyear* _Iocc1*"
global spec5 "_Iyear* _Iocc2*"
global spec6 "_Iyear* _Iind2*"
* В спецификацию 8 перемножаем отрасль и бюджетника
foreach x of varlist _Iind2* {
	gen x_`x' = budgetnik * `x'
}
global spec7 "_Iyear* x_*"
global spec8 "_Iyear* x_* _Iind2*"

forvalues i = 1/8 {
* di "***** SPECIFICATION `i' *****"

	forvalues j = 1/6 {
	
*	di "***** ${n`j'} *****"
/*		if inlist(`j',1,2,3) {
			local s = sec[`j']
			local c "1"
		}
*/
		if `j' == 1 {
			local s = "budgetnik"
			local c = 1
		}
		if `j' == 2 {
			local s = "soe"
			local c = 1
		}
		if `j' == 3 {
			local s = "public"
			local c = 1
		}
		if `j' == 4 {
			local s = "budgetnik"
			local c "soe != 1"
		}
		if `j' == 5 {
			local s = "soe"
			local c "budgetnik != 1"
		}
		if `j' == 6 {
			local s = "budgetnik soe"
			local c = 1
		}
		foreach k in "" "xt"  { // panel or not?
			if "`k'" != "xt" {
				local opt = "vce(cl idind)"
				local v = ""
				di "***** POOL *****"
			}
			else {
				local v = "pnl_"
				di "***** PANEL *****"
			}
		
		*** WAGE ***	
		
		di _n	
		di "***** SPECIFICATION `i' *****"
		di "***** ${n`j'} *****"
		di "***** PANEL *****"
		di "***** WAGE *****"
		di _n	
		
		`k'reg wage_hour ///
			${`v'vars} ///
			${spec`i'} ///
			`s' ///
			if `c' , ///
			`opt'
	
		*** SAT ***
		di _n	
		di "***** SPECIFICATION `i' *****"
		di "***** ${n`j'} *****"
		di "***** PANEL *****"
		di "***** SAT *****"
		di _n	
		
			`k'probit sat ///
			${`v'vars} ///
			${spec`i'} ///
			`s' ///
			if `c' , ///
			`opt'
			
		*** nj1_1_1 ***
		di _n	
		di "***** SPECIFICATION `i' *****"
		di "***** ${n`j'} *****"
		di "***** PANEL *****"
		di "****** NJ1_1_1 *****"
		di _n	
		
			`k'oprobit nj1_1_1 ///
			${`v'vars} ///
			${spec`i'} ///
			`s' ///
			if `c' , ///
			`opt'
		}
	}
}
