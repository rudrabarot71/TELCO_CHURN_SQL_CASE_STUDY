
-- QUESTION 1) Which contract type has the highest churn rate?

-- LOGIC: Group all customers by their contract type (Month-to-Month, One Year, Two Year),
-- then calculate the total customers, number of churned customers, and churn rate (%)
-- for each group to identify which contract type retains customers the least.

-- FINDING: Month-to-Month contracts have the highest churn rate at 42%, which is
-- 21x higher than Two Year contracts (2%).

SELECT 
    contract,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) AS churned_customers,
    ROUND(SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) * 100 / COUNT(*), 0) AS churn_rate_pct
FROM churn
GROUP BY contract
ORDER BY churn_rate_pct DESC;



-- QUESTION 2) Which payment method has the highest churn rate?

--LOGIC: A CTE (churn_summary) first aggregates total customers and churned customers
-- by payment method. The outer query then calculates the churn rate (%) by dividing
-- churned customers by total customers, making the logic cleaner and easier to read.

-- FINDING: Electronic check users have the highest churn rate at 45%, which is
-- 3x higher than credit card users (15%).

WITH churn_summary AS (
    SELECT 
        paymentmethod,
        COUNT(*) AS total_customers,
        SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) AS churned_customers
    FROM churn
    GROUP BY paymentmethod
)
SELECT 
    paymentmethod,
    total_customers,
    churned_customers,
    ROUND(churned_customers * 100 / total_customers, 0) AS churn_rate_pct
FROM churn_summary
ORDER BY churn_rate_pct DESC;

-- QUESTION 3) What is the churn rate by customer tenure bucket?

-- LOGIC : A CTE (tenure_segments) first assigns each customer to a tenure bucket
-- (New, Early Loyal, Developing Loyal, Long-Term Loyal) using a CASE statement.
-- The outer query then aggregates total customers, churned customers, and churn rate (%)
-- per bucket using COUNT and NULLIF to avoid verbose CASE WHEN expressions.

-- FINDING: New customers (0-12 months) have the highest churn rate at 47%, which is
-- 4.7x higher than Long-Term Loyal customers (10%).

WITH tenure_segments AS (
    SELECT *,
        CASE 
            WHEN tenure BETWEEN 0 AND 12 THEN 'New'
            WHEN tenure BETWEEN 13 AND 24 THEN 'Early Loyal'
            WHEN tenure BETWEEN 25 AND 48 THEN 'Developing Loyal'
            WHEN tenure BETWEEN 49 AND 72 THEN 'Long-Term Loyal'
        END AS tenure_bucket
    FROM churn
)
SELECT 
    tenure_bucket,
    COUNT(*) AS total_customers,
    COUNT(NULLIF(churn, 'No')) AS churned_customers,
    ROUND(CAST(COUNT(NULLIF(churn, 'No')) AS FLOAT) * 100.0 / COUNT(*), 0) AS churn_rate_pct
FROM tenure_segments
GROUP BY tenure_bucket
ORDER BY churn_rate_pct DESC;


-- QUESTION 4) Which payment method has the highest churn rate? 

-- LOGIC: Group all customers by their payment method and calculate total customers,
-- churned customers ,churn rate (%) for each group to identify 
-- which payment method is most associated with churn.

-- FINDING: Electronic check users have the highest churn rate at 45%, which is
-- 3x higher than credit card users (15%).

SELECT 
    paymentmethod,
    COUNT(*) AS total_customers,
    COUNT(NULLIF(churn, 'No')) AS churned_customers,
    ROUND(CAST(COUNT(NULLIF(churn, 'No')) AS FLOAT) * 100.0 / COUNT(*), 0) AS churn_rate_pct
FROM churn
GROUP BY paymentmethod
ORDER BY churn_rate_pct DESC;


-- QUESTION 5) Do customers without online security or tech support churn more than those who have it?

-- LOGIC: A CTE (protection_segments) first categorizes each customer into one of three
-- segments (No Protection, Partial Protection, Full Protection) based on their online
-- security and tech support subscription status. Customers with 'No Internet Service'
-- are excluded as they are not eligible for these add-ons. The outer query then
-- aggregates total customers, churned customers and churn rate (%) per segment.

-- FINDING: Customers with No Protection have the highest churn rate at 49%, which is
-- 5.4x higher than fully protected customers (9%).

WITH protection_segments AS (
    SELECT *,
        CASE 
            WHEN onlinesecurity = 'No' AND techsupport = 'No' THEN 'No Protection'
            WHEN onlinesecurity = 'Yes' AND techsupport = 'Yes' THEN 'Full Protection'
            ELSE 'Partial Protection'
        END AS protection_segment
    FROM churn
    WHERE onlinesecurity != 'No Internet Service' 
      AND techsupport != 'No Internet Service'
)
SELECT 
    protection_segment,
    COUNT(*) AS total_customers,
    COUNT(NULLIF(churn, 'No')) AS customers_churned,
    ROUND(CAST(COUNT(NULLIF(churn, 'No')) AS FLOAT) * 100.0 / COUNT(*), 0) AS churn_rate_pct
FROM protection_segments
GROUP BY protection_segment
ORDER BY churn_rate_pct DESC;
