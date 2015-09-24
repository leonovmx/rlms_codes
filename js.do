/*
Описание. 
Что тут делается. 
1. Данные берутся из /rlms/_res.dta
gen sector = 1 * private1 + 2 * soe + 3 * budgetnik

./data/js_tabs.xlsx - описательные таблицы, вопрос 1.
*/

// cd "C:/Users/Sony/SkyDrive/"
// cd "C:/Users/Sony/YandexDisk/IEP"
// cd "C:/Users/Maxim/YandexDisk/IEP/"
// cd "/Users/leonovmx/Яндекс.Диск/IEP/"

clear all
set more off, perm
global input_path ./rlms/
global wd ./senik/  // working directory, аналог названия проекта
* global project education
* global output_path ${input_path}
* global pic_path ./${project}/pic/
global result_file = "${input_path}_res.dta"
* LOAD DATA
use "${result_file}", clear

cap log close _all
local date: display %tdCCYY-NN-DD date(c(current_date), "DMY")
log using ${wd}`date'.smcl, replace name("log")

************
*** VARS ***
************
* Какие оставить?

/*
Категории:
1. госсектор (и бюджетники, и госпредприятия) против частного сектора, 
переменная public в наших данных
2. бюджетники против всех остальных (переменная budgetnik)
3. бюджетники против частного сектора (отбросить soe)
4. soe против всех остальных 
5. soe против частного сектора

Таблицы
1. Распределение переменной удовлетворенности работой по трем секторам: 
	- бюджетники,
	- частный сектор, 
	- soe.  
Показатели
	- Cколько человек дали варианты ответов  1,2,3,4,5, 
 	- среднее, 
	- медиана, 
	- общее количество наблюдений.

Вопрос - для какого года это делать. Давайте для последнего (2013), на всякий 
случай проверьте, что во времени нет сильных изменений, я думаю, что их нет.

2. Пулинговые регрессии для зарплат и удовлетворенности для всех категорий (см. 
выше). Т.е. пять отдельных таблиц. Зарплату и удовлетворенность лучше в одну 
таблицу (как у Сеник). Поскольку у нас панельные данные, в регрессиях 
обязательно нужно делать коррекцию на кластеризацию. В стате это легко 
vce(cluster idind). Нужно обязательно проверить робастность результатов 
(т.е. чтобы коэффицент при секторе сильно не варьировался, остальные 
коэффициенты нас в данном случае не волнуют) путем использования разных 
наборов объясняющих переменных. Не забудьте про отрасли, которые вы сделали. 
Также в таблицах обязательно должны быть количество наблюдений и R2.

3. Те же пять таблиц только с панельными регрессиями.
В принципе, все. Поскольку мы много раз будем что-то менять (набор объясняющих 
переменных, определение секторов, вы, кстати, исправили тот недочет, когда 
какие-то чиновники не являются бюджетниками?)
*/

* Смотрим только тех, кто работает и репрезентативных
keep if _origsm == 1
* Оставляем тех, кто работает или в отпуске.
keep if inlist(j1, 1, 2, 3, 4)

/*
gen occ1 = floor(j2code / 1000)
gen occ2 = floor(j2code / 100)
replace occ1 = . if occ1 == 99999
replace occ2 = . if occ2 == 999999

xi i.fo i.ind2 i.occ1 i.occ2 i.year
*/

* Для excel таблицы делаем значения меньше.
foreach x of varlist j1_1_* {
	replace `x' = 6 if `x' == 99999997
	replace `x' = 7 if `x' == 99999998
	replace `x' = 8 if `x' == 99999999
	replace `x' = 9 if `x' == .
} 

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

* 2. пул *
** 2013 only? **

* j1_1_1 - удовлетворённость работой и 
* wage_hour - зарплата часовая

/*
SENIK включает следующие перменные в (в скобках наши перменные)
	1) standard cross-section analysis (more accurately, as we are using panel data,
	repeated cross-section with correction for clustering of errors at the individual level) of (the log
	of) wages between sectors
		- Self-employed
		- Number of children (child_number)
		- Male (male)
		- Married (married)
		- Separated - 
		- Divorced -
		- Widowed -
		- Age (age)
		- Age-squared/1000 (age_sq)
		- Born abroad - 
		- House renter - 
		- Log hours - используем зарплату за час - j6_2 (not log)
		- Education: high (high_educ)
		- Education: A/O/nursing
		- Job tenure (tenure)
		- Job tenure-squared (tenure_sq)
		- Occupation dummies Yes
		- Wave dummies Yes
		- Constant
		
		+ harmwork
		+ fsize_small + fsize_med + fsize_large
		+ ind2
		+ budgetnik public soe
		+ city dummy_Moscow

	2) Panel
		- Self-employed
		- Number of children
		-
		- Married
		- Separated
		- Divorced
		- Widowed
		- 
		- 
		- 
		- House renter
		- Log hours
		- 
		- 
		- 
		- 
		- Occupation dummies Yes
		- Wave dummies Yes
		- Constant
*/

********************************************************************************
*** AUTOMATING *****************************************************************
********************************************************************************
	xtset idind year 

estimates clear
global sec = "budgetnik soe public"
global vars "male married age age_sq j6_2 high_educ tenure tenure_sq fsize_small fsize_med city dummy_Moscow _Ifo_*"
global pnl_vars " married age age_sq j6_2 high_educ tenure tenure_sq fsize_small fsize_med city dummy_Moscow"

global spec1 "_Iyear*"
global spec2 "_Iyear* _Iind2* _Iocc1*"
global spec3 "_Iyear* _Iind2* _Iocc2*"
global spec4 "_Iyear* _Iocc1*"
global spec5 "_Iyear* _Iocc2*"
global spec6 "_Iyear* _Iind2*"

* В спецификацию 7 додавляются все отрасли, кроме 12
	unab not : _Iind2_12 
	unab all : _Iind2* 
	local all : list all - not 
	di "`all'"
	
global spec7 "_Iyear* `all'"

* В спецификацию 8 перемножаем отрасль и бюджетника
foreach x of varlist _Iind2* {
	gen x_`x' = budgetnik * `x'
}

global spec8 "_Iyear* x_*"
global spec9 "_Iyear* x_* _Iind2*"

global n1 = "Budg vs all" 
global n2 = "SOE vs all" 
global n3 = "Public vs all" 
global n4 = "Budg vs private" 
global n5 = "SOE vs private" 
global n6 = "All"

forvalues j = 1/9 {
*** POOLING ********************************************************************
*** WAGE ***********************************************************************
	di _n
	di "POOL. WAGE. Specification `j'"
	di "Start: $S_DATE $S_TIME"

	local nms = "" // имена моделей, которые получились
	local ii = 1
	local keeplist = "" // модели, которые получились
	local vv = "" // коэффициенты при переменных, которые надо показать
	local qq = 0 // количество без ошибок регрессий

	foreach i of global sec {
		cap reg wage_hour ///
			$vars ///
			${spec`j'} ///
			`i' /// 
		if j1_1_1 != ., /// conditions
		vce(cl idind)
		
		if _rc == 0 {
			est sto `i'
			local keeplist = "`keeplist' `i'" 
			local nms = `" `nms' " ${n`ii'} " "'
			local vv = "`vv' `i'"
			local ++qq
		}
		local ++ii
	}

	cap reg wage_hour ///
		$vars ///
		${spec`j'} ///
		budgetnik /// 
	if j1_1_1 != . & soe != 1, /// conditions
	vce(cl idind)
	
	if _rc == 0 {
		est sto b_vs_pr
		local keeplist = "`keeplist' b_vs_pr"
		local nms = `" `nms' " ${n`ii'} " "'
		local vv = "`vv' budgetnik"
		local ++qq
	}
	local ++ii

	cap reg wage_hour ///
		$vars ///
		${spec`j'} ///
		soe  /// 
	if j1_1_1 != . & budgetnik != 1, /// conditions
	vce(cl idind)
	
	if _rc == 0 {
		est sto soe_vs_pr
		local keeplist = "`keeplist' soe_vs_pr"
		local nms = `" `nms' " ${n`ii'} " "'
		local vv = "`vv' soe"
		local ++qq
	}
	local ++ii

	cap reg wage_hour ///
		$vars ///
		${spec`j'} ///
		budgetnik soe  /// 
	if j1_1_1 != ., /// conditions
	vce(cl idind)
	
	if _rc == 0 {
		est sto mall
		local keeplist = "`keeplist' mall"
		local nms = `" `nms' " ${n`ii'} " "'
		local vv = "`vv' budgetnik soe"
		local ++qq
	}

	di `vv'
	local vv : list uniq vv
	di `vv'

	if `j' == 8 {
		local vv = "`vv' x_*"
	}
	if `j' == 9 {
		local vv = "`vv' x_* _Iind2*"
	}

	if `qq' != 0 {
		esttab `keeplist', keep(`vv') r2 aic bic ci ///
		title("Pooling. Wage. Specification `j'") ///
		mtitle(`nms')		
	}
	else {
		di "No OK estimations. Pooling. Wage. Specification `j'"		
	}

	estimates clear

*** SATISFACTION SAT ***********************************************************

	global sat_var = "sat" //"j1_1_1"  or sat(0 1), sat1, j1_1_4
	local nms = ""
	local ii = 1
	local keeplist = ""
	local vv = "" // коэффициенты при переменных, которые надо показать
	local qq = 0 // количество без ошибок регрессий

	di _n
	di "POOL. SATISFACTION with $sat_var. Specification `j'"
	di "Start: $S_DATE $S_TIME"

	foreach i of global sec {
		cap probit $sat_var ///
			$vars ///
			${spec`j'} ///
			`i' /// sector
		if j1_1_1 != . , /// conditions
		vce(cluster idind)
		if _rc == 0 {
			est sto `i'
			local keeplist = "`keeplist' `i'" 
			local nms = `" `nms' " ${n`ii'} " "'
			local vv = "`vv' `i'"
			local ++qq
		}
		local ++ii
	}

	cap probit $sat_var ///
		$vars ///
		${spec`j'} ///
		budgetnik /// 
	if j1_1_1 != . & soe != 1, /// conditions
	vce(cl idind)
	if _rc == 0 {
		est sto b_vs_pr
		local keeplist = "`keeplist' b_vs_pr"
		local nms = `" `nms' " ${n`ii'} " "'
		local vv = "`vv' budgetnik"
		local ++qq
	}
	local ++ii

	cap probit $sat_var  ///
		$vars ///
		${spec`j'} ///
		soe  /// 
	if j1_1_1 != . & budgetnik != 1, /// conditions
	vce(cl idind)
	if _rc == 0 {
		est sto soe_vs_pr
		local keeplist = "`keeplist' soe_vs_pr"
		local nms = `" `nms' " ${n`ii'} " "'
		local vv = "`vv' soe"
		local ++qq
	}
	local ++ii

	cap probit $sat_var ///
		$vars ///
		${spec`j'} ///
		budgetnik soe /// 
	if j1_1_1 != . , /// conditions
	vce(cluster idind)
	if _rc == 0 {
		est sto mall
		local keeplist = "`keeplist' mall"
		local nms = `" `nms' " ${n`ii'} " "'
		local vv = "`vv' budgetnik soe"
		local ++qq
	}

	local vv : list uniq vv

	if `j' == 8 {
		local vv = "`vv' x_*"
	}
	if `j' == 9 {
		local vv = "`vv' x_* _Iind2*"
	}

	if `qq' != 0 {
		esttab `keeplist', keep(`vv') r2 aic bic ci ///
		title("Pooling. Satisfaction. $sat_var. Specification `j'") ///
		mtitle(`nms')
	}
	else {
		di "No OK estimations. Pooling. Satisfaction. $sat_var. Specification `j'"
	}

	estimates clear

*** SATISFACTION nJ1_1_1 *******************************************************
	global sat_var = "nj1_1_1" // or sat(0 1), sat1, j1_1_4
	local nms = "" // имена моделей, которые получились
	local ii = 1
	local keeplist = "" // модели, которые получились
	local vv = "" // коэффициенты при переменных, которые надо показать
	local qq = 0 // количество без ошибок регрессий

	di _n
	di "POOL. SATISFACTION with $sat_var. Specification `j'"
	di "Start: $S_DATE $S_TIME"

	foreach i of global sec {
		cap oprobit $sat_var ///
			$vars ///
			${spec`j'} ///
			`i' /// sector
		if j1_1_1 != . , /// conditions
		vce(cluster idind)
		
		if _rc == 0 {
			est sto `i'
			local keeplist = "`keeplist' `i'" 
			local nms = `" `nms' " ${n`ii'} " "'
			local vv = "`vv' `i'"
			local ++qq
		}
		local ++ii
	}

	cap oprobit $sat_var ///
	$vars ///
	${spec`j'} ///
	budgetnik /// 
	if j1_1_1 != . & soe != 1, /// conditions
	vce(cl idind)
	if _rc == 0 {
		est sto b_vs_pr
		local keeplist = "`keeplist' b_vs_pr"
		local nms = `" `nms' " ${n`ii'} " "'
		local vv = "`vv' budgetnik"
		local ++qq
	}
	local ++ii

	cap oprobit $sat_var  ///
	$vars ///
	${spec`j'} ///
	soe  /// 
	if j1_1_1 != . & budgetnik != 1, /// conditions
	vce(cl idind)
	if _rc == 0 {
		est sto soe_vs_pr
		local keeplist = "`keeplist' soe_vs_pr"
		local nms = `" `nms' " ${n`ii'} " "'
		local vv = "`vv' soe"
		local ++qq
	}
	local ++ii

	cap oprobit $sat_var ///
		$vars ///
		${spec`j'} ///
		budgetnik soe /// 
	if j1_1_1 != . , /// conditions
	vce(cluster idind)
	if _rc == 0 {
		est sto mall
		local keeplist = "`keeplist' mall"
		local nms = `" `nms' " ${n`ii'} " "'
		local vv = "`vv' budgetnik soe"
		local ++qq
	}

	local vv : list uniq vv

	if `j' == 8 {
		local vv = "`vv' x_*"
	}
	if `j' == 9 {
		local vv = "`vv' x_* _Iind2*"
	}

	if `qq' != 0 {
		esttab `keeplist', keep(`vv') r2 aic bic ci ///
		title("Pooling. Satisfaction. $sat_var. Specification `j'") ///
		mtitle(`nms')
	}
	else {
		di "No OK estimations. Pooling. Satisfaction. $sat_var. Specification `j'"
	}

	estimates clear

*** PANEL **********************************************************************
*** WAGE ***********************************************************************

	di _n	
	di "PANEL. WAGE. Specification `j'"
	di "Start: $S_DATE $S_TIME"

	local nms = ""
	local ii = 1
	local keeplist = ""
	local vv = "" // коэффициенты при переменных, которые надо показать
	local qq = 0 // количество без ошибок регрессий

	foreach i of global sec {
		cap xtreg wage_hour ///
		$pnl_vars ///
		${spec`j'} ///
		`i' /// 
		if j1_1_1 != ., /// conditions
		vce(cl idind) fe
		if _rc == 0 {
			est sto `i'
			local keeplist = "`keeplist' `i'" 
			local nms = `" `nms' " ${n`ii'} " "'
			local vv = "`vv' `i'"
			local ++qq
		}
		local ++ii
	}

	cap xtreg wage_hour ///
	$pnl_vars ///
	${spec`j'} ///
	budgetnik /// 
	if j1_1_1 != . & soe != 1, /// conditions
	vce(cl idind) fe
	if _rc == 0 {
		est sto b_vs_pr
		local keeplist = "`keeplist' b_vs_pr"
		local nms = `" `nms' " ${n`ii'} " "'
		local vv = "`vv' budgetnik"
		local ++qq
	}
	local ++ii

	cap xtreg wage_hour ///
	$pnl_vars ///
	${spec`j'} ///
	soe  /// 
	if j1_1_1 != . & budgetnik != 1, /// conditions
	vce(cl idind) fe
	if _rc == 0 {
		est sto soe_vs_pr
		local keeplist = "`keeplist' soe_vs_pr"
		local nms = `" `nms' " ${n`ii'} " "'
		local vv = "`vv' soe"
		local ++qq
	}
	local ++ii

	cap xtreg wage_hour ///
	$pnl_vars ///
	${spec`j'} ///
	budgetnik soe  /// 
	if j1_1_1 != ., /// conditions
	vce(cl idind) fe
	if _rc == 0 {
		est sto mall
		local keeplist = "`keeplist' mall"
		local nms = `" `nms' " ${n`ii'} " "'
		local vv = "`vv' budgetnik soe"
		local ++qq
	}

	local vv : list uniq vv

	if `j' == 8 {
		local vv = "`vv' x_*"
	}
	if `j' == 9 {
		local vv = "`vv' x_* _Iind2*"
	}

	if `qq' != 0 {
		esttab `keeplist', keep(`vv') r2 aic bic ci ///
		title("Panel. Wage. Specification `j'") ///
		mtitle(`nms')
	}
	else {
		di "No OK estimations. Panel. Wage. Specification `j'"
	}

	estimates clear

*** SATISFACTION SAT ***********************************************************
	global sat_var = "sat" //"j1_1_1"  or sat(0 1), sat1, j1_1_4
	local nms = ""
	local ii = 1
	local keeplist = ""
	local vv = "" // коэффициенты при переменных, которые надо показать
	local qq = 0 // количество без ошибок регрессий

	di _n	
	dis "PANEL. SATISFACTION with $sat_var. Specification `j'"
	di "Start: $S_DATE $S_TIME"

	foreach i of global sec {
		cap xtprobit $sat_var ///
		$pnl_vars ///
		${spec`j'} ///
		`i' /// sector
		if j1_1_1 != . , /// conditions
		vce(cluster idind)
		if _rc == 0 {
			est sto `i'
			local keeplist = "`keeplist' `i'" 
			local nms = `" `nms' " ${n`ii'} " "'
			local vv = "`vv' `i'"
			local ++qq
		}
		local ++ii
	}

	cap xtprobit $sat_var ///
	$pnl_vars ///
	${spec`j'} ///
	budgetnik /// 
	if j1_1_1 != . & soe != 1, /// conditions
	vce(cl idind) 
	if _rc == 0 {
		est sto b_vs_pr
		local keeplist = "`keeplist' b_vs_pr"
		local nms = `" `nms' " ${n`ii'} " "'
		local vv = "`vv' budgetnik"
		local ++qq
	}
	local ++ii

	cap xtprobit $sat_var  ///
	$pnl_vars ///
	${spec`j'} ///
	soe  /// 
	if j1_1_1 != . & budgetnik != 1, /// conditions
	vce(cl idind) 
	if _rc == 0 {
		est sto soe_vs_pr
		local keeplist = "`keeplist' soe_vs_pr"
		local nms = `" `nms' " ${n`ii'} " "'
		local vv = "`vv' soe"
		local ++qq
	}
	local ++ii

	cap xtprobit $sat_var ///
	$pnl_vars ///
	${spec`j'} ///
	budgetnik soe /// sector
	if j1_1_1 != . , /// conditions
	vce(cluster idind) 
	if _rc == 0 {
		est sto mall
		local keeplist = "`keeplist' mall"
		local nms = `" `nms' " ${n`ii'} " "'
		local vv = "`vv' budgetnik soe"
		local ++qq
	}

	local vv : list uniq vv

	if `j' == 8 {
		local vv = "`vv' x_*"
	}
	if `j' == 9 {
		local vv = "`vv' x_* _Iind2*"
	}

	if `qq' != 0 {
		esttab `keeplist', keep(`vv') r2 aic bic ci ///
		title("Panel. Satisfaction. $sat_var. Specification `j'") ///
		mtitle(`nms')
	}
	else {
		di "No OK estimations. Panel. Satisfaction. $sat_var. Specification `j'"
	}

	estimates clear

*** SATISFACTION j1_1_1 ********************************************************
	global sat_var = "nj1_1_1" // or sat(0 1), sat1, j1_1_4
	local nms = ""
	local ii = 1
	local keeplist = ""
	local vv = "" // коэффициенты при переменных, которые надо показать
	local qq = 0 // количество без ошибок регрессий

	di _n
	dis "PANEL. SATISFACTION with $sat_var. Specification `j'"
	di "Start: $S_DATE $S_TIME"

	foreach i of global sec {
		cap xtoprobit $sat_var ///
		$pnl_vars ///
		${spec`j'} ///
		`i' /// sector
		if j1_1_1 != . , /// conditions
		vce(cluster idind)
		if _rc == 0 {
			est sto `i'
			local keeplist = "`keeplist' `i'" 
			local nms = `" `nms' " ${n`ii'} " "'
			local vv = "`vv' `i'"
			local ++qq
		}
		local ++ii
	}

	cap xtoprobit $sat_var ///
	$pnl_vars ///
	${spec`j'} ///
	budgetnik /// 
	if j1_1_1 != . & soe != 1, /// conditions
	vce(cl idind) 
	if _rc == 0 {
		est sto b_vs_pr
		local keeplist = "`keeplist' b_vs_pr"
		local nms = `" `nms' " ${n`ii'} " "'
		local vv = "`vv' budgetnik"
		local ++qq
	}
	local ++ii

	cap xtoprobit $sat_var  ///
	$pnl_vars ///
	${spec`j'} ///
	soe  /// 
	if j1_1_1 != . & budgetnik != 1, /// conditions
	vce(cl idind) 
	if _rc == 0 {
		est sto soe_vs_pr
		local keeplist = "`keeplist' soe_vs_pr"
		local nms = `" `nms' " ${n`ii'} " "'
		local vv = "`vv' soe"
		local ++qq
	}
	local ++ii

	cap xtoprobit $sat_var ///
	$pnl_vars ///
	${spec`j'} ///
	budgetnik soe /// sector
	if j1_1_1 != . , /// conditions
	vce(cluster idind) 
	if _rc == 0 {
		est sto mall
		local keeplist = "`keeplist' mall"
		local nms = `" `nms' " ${n`ii'} " "'
		local vv = "`vv' budgetnik soe"
		local ++qq
	}

	local vv : list uniq vv

	if `j' == 8 {
		local vv = "`vv' x_*"
	}
	if `j' == 9 {
		local vv = "`vv' x_* _Iind2*"
	}

	if `qq' != 0 {
		esttab `keeplist', keep(`vv') r2 aic bic ci ///
		title("Panel. Satisfaction. $sat_var. Specification `j'") ///
		mtitle(`nms')
	}
	else {
		di "No OK estimations. Panel. Satisfaction. $sat_var. Specification `j'"
	}	
	
	estimates clear
}

log close _all
