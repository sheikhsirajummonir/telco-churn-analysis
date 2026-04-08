-- ============================================
-- PROJECT: Telco Customer Churn Analysis
-- AUTHOR: Siraj
-- DATE: April 2026
-- TOOL: SQL Server (SSMS)
-- ============================================

Use TelcoChurn;
Go

-- *****************************************************************************
-- *****************************************************************************
-- Batch 1. Creating a View to segment tenure

CREATE or ALTER VIEW churn_enriched AS
SELECT *,
    CASE 
        WHEN tenure >= 0  AND tenure <= 12 THEN 'New (Less than 1 year)'
        WHEN tenure >= 13 AND tenure <= 24 THEN 'Established (1 - 2 years)'
        WHEN tenure >= 25 AND tenure <= 48 THEN 'Loyal (2 - 4 years)'
        WHEN tenure >= 49 THEN 'Champion (Greater than 4 years)'
    END AS TenureSegment
FROM churn;
GO

-- *****************************************************************************
-- *****************************************************************************

-- ============================================
-- SECTION 1: DATA VALIDATION
-- ============================================

-- 1.1 Check row count
Select count(*) from dbo.churn;

-- Preview first 10 rows 
select top 10 * from churn;

-- Check for blank in total charges
select * from churn
where TotalCharges is null;

-- Check data type of TotalCharges
Select column_name, data_type
from INFORMATION_SCHEMA.columns
where table_name = 'churn'
and column_name in ('TotalCharges','tenure','monthlycharges');


-- Changing to float for calculations
ALTER Table churn
Alter column TotalCharges float;

ALTER Table churn
Alter column tenure float;


ALTER Table churn
Alter column monthlycharges float;


-- Filling nulls with 0 in TotalCharges column as they have not been charged yet
UPDATE churn
set TotalCharges = 0
where TotalCharges is null;



-- ============================================
-- SECTION 2: CUSTOMER OVERVIEW
-- ============================================


-- 2.1 Overall Churn Rate

-- ** Churn Rate is 26.54 % ** --
SELECT 
    COUNT(*) AS TotalCustomers,
    SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) AS ChurnedCustomers,
    CAST(ROUND(100.0 * SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS DECIMAL(10,2)) AS ChurnRate
FROM churn;

-- 2.1b Churn ratio percentage
-- ** Churn Ratio percentage is 36.54 % ** --

SELECT 
    CAST(ROUND(
        sum(CASE WHEN churn = 'Yes' THEN 1 else 0 END) * 100.0 / 
        NULLIF(sum(CASE WHEN churn = 'Yes' THEN 0 else 1 END), 0), 
    2) AS DECIMAL(10,2)) AS churn_ratio_percentage
FROM churn;


-- 2.2 Customer Distribution by Contract Type, Gender, Senior Citizen Status

-- ** Month-month non-seniors has the most users at 43 % of total ** 
SELECT 
    Contract,
    Gender,
    CASE WHEN SeniorCitizen = 1 THEN 'Senior' ELSE 'Non-Senior' END AS SeniorCitizenStatus,
    COUNT(*) AS CustomerCount,
    CAST(
	ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2)
	AS DECIMAL(10,2)) AS PctOfTotal
FROM churn
GROUP BY Contract, Gender, SeniorCitizen
ORDER BY PctOfTotal desc;


-- 2.3 Average Tenure and Monthly Charges
-- ** Month-Month Contract type has 3x lower average tenure than Two year Contract type **
SELECT 
    Contract,
    Gender,
    CASE WHEN SeniorCitizen = 1 THEN 'Senior' ELSE 'Non-Senior' END AS SeniorCitizenStatus,
    COUNT(*) AS CustomerCount,
    CAST(
	ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2)
	AS DECIMAL(10,2)) AS PctOfTotal,
	CAST(AVG(CAST(tenure as float)) as Decimal(10,2)) as Average_tenure,
	CAST(AVG(MonthlyCharges) as decimal(10,2)) as average_monthly_charges,
	CAST(SUM(MonthlyCharges) as decimal(10,2)) as total_monthly_charges
FROM churn 
GROUP BY Contract, Gender, SeniorCitizen
ORDER BY Average_tenure;


-- ============================================
-- SECTION 3: CHURN ANALYSIS
-- ============================================



-- 3.1 Churn Rate by Contract Type
-- ** Churn Rate is significantly higher for Month-Month Contract type
SELECT 
    Contract,
    COUNT(*) AS TotalCustomers,
    SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) AS ChurnCount,
    CAST(ROUND(100.0 * SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS DECIMAL(10,2)) AS ChurnRate
FROM churn
GROUP BY Contract
ORDER BY ChurnRate DESC;


-- 3.2 Churn Rate by Senior Citizen Status
-- ** Seniors are churning more
SELECT 
	case when SeniorCitizen = 0 then 'Non-Senior' else 'Senior' end as SeniorCitizen, 
	count(*) as TotalCustomers,
	sum(case when churn = 'Yes' then 1 else 0 end) as churn,
	CAST(ROUND(100.0 * SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS DECIMAL(10,2)) AS ChurnRate
	from churn
	group by SeniorCitizen
	order by churnrate desc;

-- 3.3 Affect of tenure on churn - Do newer customers churn more?
-- ** Less than 1 year customers are churning at 47.44 % of overall churns
with segmented_data as(
select 
case 
	when tenure >= 0 and tenure <= 12 then 'New (Less than 1 year)'
	when tenure >= 13 and tenure <= 24 then 'Established (1 - 2 years)'
	when tenure >= 25 and tenure <= 48 then 'Loyal (2 - 4 years)'
	when tenure >= 49  then 'Champion (Greater than 4 years)'
end as tenure_segment, churn
from churn
)
select tenure_segment, 
count(*) as total_customers,
sum(case when churn = 'Yes' then 1 else 0 end) as churn_count,
cast(sum(case when churn = 'Yes' then 1 else 0 end) * 100.0 
/ count(*) as decimal(10,2)) as churn_rate
from segmented_data
group by tenure_segment
ORDER BY 
    CASE tenure_segment
        WHEN 'New (Less than 1 year)' THEN 1
        WHEN 'Established (1 - 2 years)' THEN 2
        WHEN 'Loyal (2 - 4 years)' THEN 3
        WHEN 'Champion (Greater than 4 years)' THEN 4
    END;



-- 3.4 Churn rate by payment method

-- ** Customers using Electronic Check payment method are churning more at 45 %

select paymentmethod, 
count(*) as cnt, 
sum(case when churn = 'Yes' then 1 else 0 end) as churn_count,
cast(100.0 * sum(case when churn = 'Yes' then 1 else 0 end) / count(*) as decimal(10,2))  as churn_rate
from churn
group by PaymentMethod
order by churn_rate desc


-- ============================================
-- SECTION 4: REVENUE IMPACT
-- ============================================

-- 4.1 Monthly Revenue lost due to Churn & Average Monthly Charge of churned vs retained customers
-- ====================================================================================================================
-- Churned customers were the higher value segment 
--	— paying 21% more per month than retained customers. 
--	Despite being only 26% of the base, they accounted for 30.5% of monthly revenue 
--	— making churn significantly more expensive than headcount alone suggests.
-- ====================================================================================================================

select 
case when churn = 'Yes' then 'Churned' else 'Retained' end as churn_flag,
count(*) as totalCustomers,
cast(round(avg(MonthlyCharges),2) as decimal(10,2)) as AverageMonthlyCharges,
cast(round(sum(MonthlyCharges),2) as decimal(10,2)) as TotalMonthlyCharges,
CAST(SUM(MonthlyCharges) * 12 AS DECIMAL(10,2)) AS EstimatedAnnualRevenueLost,
cast(round(100.0 * sum(MonthlyCharges),2) / sum(sum(MonthlyCharges)) over () as decimal(10,2)) as TotalChargesPerc
from churn
group by churn;


-- 4.2 Derived Metrics -- Quantifying the revenue impact of churn
-- Calculating % of customer base and how much more churned customers paid vs retained
-- ====================================================================================================================
-- ** Churned customers had average monthly charges 21.5 percent more that Retained customers
-- ====================================================================================================================
WITH base AS (
    SELECT 
        CASE WHEN Churn = 'Yes' THEN 'Churned' ELSE 'Retained' END AS ChurnStatus,
        COUNT(*) AS TotalCustomers,
        CAST(ROUND(AVG(MonthlyCharges), 2) AS DECIMAL(10,2)) AS AvgMonthlyCharges,
        CAST(ROUND(SUM(MonthlyCharges), 2) AS DECIMAL(10,2)) AS TotalMonthlyCharges
    FROM churn
    GROUP BY Churn
)
SELECT 
    ChurnStatus,
    TotalCustomers,
    CAST(100.0 * TotalCustomers / SUM(TotalCustomers) OVER() AS DECIMAL(10,2)) AS PctOfCustomerBase,
    AvgMonthlyCharges,
    CAST(100.0 * AvgMonthlyCharges / MIN(AvgMonthlyCharges) OVER() - 100 AS DECIMAL(10,2)) AS PctMoreThanOther
FROM base
ORDER BY ChurnStatus DESC;


-- 4.3 Customer Segment at Highest Revenue Risk
-- INSIGHT: Which contract + tenure combination represents the highest revenue at risk
-- ====================================================================================================================
-- "The highest priority retention intervention should target Month-to-month customers in their first year. 
-- This single segment drives 49% of monthly revenue loss. 
-- A targeted incentive to convert New Month-to-month customers to One year contracts 
-- could significantly reduce overall churn impact."
-- ====================================================================================================================

SELECT 
    Contract,
    TenureSegment,
    COUNT(*) AS ChurnedCustomers,
    CAST(ROUND(SUM(MonthlyCharges), 2) AS DECIMAL(10,2)) AS TotalMonthlyRevenueLost,
    CAST(ROUND(100.0 * SUM(MonthlyCharges) / SUM(SUM(MonthlyCharges)) OVER(), 2) AS DECIMAL(10,2)) AS PctOfTotalRevenueLost,
    CAST(ROUND(AVG(MonthlyCharges), 2) AS DECIMAL(10,2)) AS AvgMonthlyChargePerCustomer
FROM churn_enriched
WHERE Churn = 'Yes'
GROUP BY Contract, TenureSegment
ORDER BY PctOfTotalRevenueLost DESC;



-- ============================================
-- SECTION 5: SERVICE & PRODUCT ANALYSIS
-- ============================================

-- 5.1 Do Customers with add-on services churn less?
-- ====================================================================================================================
-- Customers with Online Security are significantly more loyal 
-- — churning at nearly half the overall rate. 
-- Streaming service customers however show above average churn, 
-- suggesting these add-ons attract less committed customers or don't create enough stickiness to retain them.
-- ====================================================================================================================
select 
case when churn = 'Yes' then 'Churned' else 'Retained' end as churnStatus,
count(*) as totalCount,
cast(round(100.0 * count(*) / 
	sum(count(*)) over (),2)as decimal(10,2)) as churn_perc,
sum(case when streamingtv = 'Yes' then 1 else 0 end) as streamingtvCount,
cast(round(100.0 * sum(case when streamingtv = 'Yes' then 1 else 0 end) / 
	sum(sum(case when streamingtv = 'Yes' then 1 else 0 end)) over (),2) as decimal(10,2)) as streamingtvPerc_churned,
sum(case when streamingmovies = 'Yes' then 1 else 0 end) as streamingmoviesCount,
cast(round(100.0 * sum(case when streamingmovies = 'Yes' then 1 else 0 end) / 
	sum(sum(case when streamingmovies = 'Yes' then 1 else 0 end)) over (),2) as decimal(10,2)) as streamingmoviesPerc_churned,
sum(case when OnlineSecurity = 'Yes' then 1 else 0 end) as OnlineSecurityCount,
cast(round(100.0 * sum(case when OnlineSecurity = 'Yes' then 1 else 0 end) / 
	sum(sum(case when OnlineSecurity = 'Yes' then 1 else 0 end)) over (),2) as decimal(10,2)) as OnlineSecurityPerc_churned
from churn
group by churn



-- 5.2 Does phone service vs internet affect churn
-- ====================================================================================================================
-- Phone only customers churn at nearly a quarter of the overall rate, making them the most stable segment in 
-- the business.
-- ====================================================================================================================
select PhoneService, InternetService, Churn from churn;

select 
case when churn = 'Yes' then 'Churned' else 'Retained' end as churnStatus,
count(*) as totalCount,
cast(round(100.0 * count(*) / 
	sum(count(*)) over (),2)as decimal(10,2)) as churn_perc,
sum(case when PhoneService = 'Yes'  and InternetService = 'No' then 1 else 0 end) as OnlyPhoneService,
cast(round(100.0 * sum(case when PhoneService = 'Yes'  and InternetService = 'No' then 1 else 0 end) /
sum(sum(case when PhoneService = 'Yes'  and InternetService = 'No' then 1 else 0 end)) over (),2) as decimal(10,2))
as PercOnlyPhoneService,

sum(case when PhoneService = 'No'  and InternetService <> 'No' then 1 else 0 end) as OnlyInternetService,
cast(round(100.0 * sum(case when PhoneService = 'No'  and InternetService <> 'No' then 1 else 0 end) /
sum(sum(case when PhoneService = 'No'  and InternetService <> 'No' then 1 else 0 end)) over (),2) as decimal(10,2))
as PercOnlyInternetService,

sum(case when PhoneService = 'Yes'  and InternetService <> 'No' then 1 else 0 end) as BothServices,
cast(round(100.0 * sum(case when PhoneService = 'Yes'  and InternetService <> 'No' then 1 else 0 end) /
sum(sum(case when PhoneService = 'Yes'  and InternetService <> 'No' then 1 else 0 end)) over (),2) as decimal(10,2))
as PercBothServices

from churn
group by churn


-- 5.3 Which Internet Service type has the highest churn
-- ====================================================================================================================
-- Fiber Optic Internet service type has significantly higher churn rate than the base churn rate- 
-- for dsl it is lower than base


-- "Fiber Optic customers churn at nearly double the overall rate, 
-- accounting for 69% of all churned customers. This suggests either pricing, service quality, 
-- or competitive alternatives are driving dissatisfaction specifically among the high-value internet segment."
-- ====================================================================================================================

select case when churn = 'Yes' then 'Churned' else 'Retained' end as churnStatus,
count(*) as totalCount,
cast(round(100.0 * count(*) / 
	sum(count(*)) over (),2)as decimal(10,2)) as churn_perc,
	sum(case when InternetService = 'DSL' then 1 else 0 end) as DSL_count,
	cast(round(100.0 * sum(case when InternetService = 'DSL' then 1 else 0 end) / 
	sum(sum(case when InternetService = 'DSL' then 1 else 0 end)) over (),2) as decimal(10,2)) 
	as PercDSLCount,
	sum(case when InternetService = 'Fiber optic' then 1 else 0 end) as FO_count,
	cast(round(100.0 * sum(case when InternetService = 'Fiber optic' then 1 else 0 end) / 
	sum(sum(case when InternetService = 'Fiber optic' then 1 else 0 end)) over (),2) as decimal(10,2)) 
	as PercFOCount,
	SUM(CASE WHEN InternetService = 'No' THEN 1 ELSE 0 END) AS NoInternet_count,
CAST(ROUND(100.0 * SUM(CASE WHEN InternetService = 'No' THEN 1 ELSE 0 END) /
    SUM(SUM(CASE WHEN InternetService = 'No' THEN 1 ELSE 0 END)) OVER(), 2) AS DECIMAL(10,2)) 
    AS PercNoInternet
	from churn
	group by churn



-- 5.4 Among Month-to-month New customers on Fiber Optic — 
-- how many churned, what revenue did they represent, and what was their average monthly charge?"


-- ====================================================================================================================
-- "Month-to-month New Fiber Optic customers account for 38.22% 
-- of all monthly revenue lost to churn — the single highest risk segment in the entire dataset"

-- Fiber Optic month-to-month combined: 38.22 + 14.92 + 13.69 + 5.39 = 72.22%

-- "Month-to-month Fiber Optic customers across all tenure segments account for 72.22% of total monthly revenue lost"
-- ====================================================================================================================
SELECT * FROM 
(
SELECT 
    Contract,
    TenureSegment,
	InternetService,
    COUNT(*) AS ChurnedCustomers,
    CAST(ROUND(SUM(MonthlyCharges), 2) AS DECIMAL(10,2)) AS TotalMonthlyRevenueLost,
    CAST(ROUND(100.0 * SUM(MonthlyCharges) / SUM(SUM(MonthlyCharges)) OVER(), 2) AS DECIMAL(10,2)) AS PctOfTotalRevenueLost,
    CAST(ROUND(AVG(MonthlyCharges), 2) AS DECIMAL(10,2)) AS AvgMonthlyChargePerCustomer
FROM churn_enriched
WHERE Churn = 'Yes'
GROUP BY Contract, TenureSegment, InternetService
) A
WHERE Contract = 'Month-to-month'
and InternetService <> 'No'
ORDER BY PctOfTotalRevenueLost DESC
;

-- ********************************************************************************************************************
-- Business recommendation is now crystal clear
-- "Retention efforts should prioritise Month-to-month Fiber Optic customers — particularly in their first year. 
-- Converting this single segment to annual contracts could recover up to 38% of monthly revenue currently lost to churn."

-- ********************************************************************************************************************