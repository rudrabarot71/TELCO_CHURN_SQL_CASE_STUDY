# 📊 Telco Customer Churn Analysis

## Problem Statement

This project analyzes customer churn for a telecom company to identify which customer segments are most at risk of leaving. The primary stakeholder is the **Customer Retention Team**, who will use these insights to design targeted retention strategies and reduce overall churn. The dataset contains demographic, account, and service subscription data for 7,043 customers.

---

## Dataset Overview

- **Source:** [Kaggle — Telco Customer Churn](https://www.kaggle.com/datasets/blastchar/telco-customer-churn/data)
- **Row Count:** 7,043 customers
- **Date Range:** Not applicable (snapshot data)
- **Key Columns:**
  - `customerID` — Unique identifier (excluded from analysis)
  - `tenure` — Months the customer has been with the company (0–72)
  - `Contract` — Month-to-month, One year, Two year
  - `PaymentMethod` — Electronic check, Mailed check, Bank transfer, Credit card
  - `OnlineSecurity`, `TechSupport` — Yes / No / No internet service
  - `MonthlyCharges`, `TotalCharges` — Customer billing info
  - `Churn` — Target variable (Yes / No)
- **Known Data Quality Issues:**
  - `TotalCharges` is stored as a string with 11 blank rows that require handling
  - `SeniorCitizen` is numeric (0/1) while all other binary columns are Yes/No strings
  - `OnlineSecurity` and `TechSupport` contain a third value `'No Internet Service'` which must be excluded in service-based analysis

---

## Business Questions

1. Which contract type has the highest churn rate?
2. Which payment method has the highest churn rate? *(CTE approach)*
3. What is the churn rate by customer tenure bucket?
4. Which payment method has the highest churn rate? *(NULLIF approach)*
5. Do customers without online security or tech support churn more than those who have it?

---

## Queries

### Question 1: Which contract type has the highest churn rate?

```sql
-- LOGIC: Group all customers by their contract type (Month-to-Month, One Year, Two Year),
-- then calculate the total customers, number of churned customers, and churn rate (%)
-- for each group to identify which contract type retains customers the least.

-- FINDING: Month-to-Month contracts have the highest churn rate at 42%, which is
-- 21x higher than Two Year contracts (2%).

-- INSIGHT: Incentivizing customers to upgrade to annual or bi-annual contracts
-- could serve as an effective retention strategy and reduce overall churn.

SELECT 
    contract,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) AS churned_customers,
    ROUND(SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) * 100 / COUNT(*), 0) AS churn_rate_pct
FROM churn
GROUP BY contract
ORDER BY churn_rate_pct DESC;
```

---

### Question 2: Which payment method has the highest churn rate? *(CTE approach)*

```sql
-- LOGIC: A CTE (churn_summary) first aggregates total customers and churned customers
-- by payment method. The outer query then calculates the churn rate (%) by dividing
-- churned customers by total customers, making the logic cleaner and easier to read.

-- FINDING: Electronic check users have the highest churn rate at 45%, which is
-- 3x higher than credit card users (15%).

-- INSIGHT: Incentivizing customers to switch from electronic check to automatic payment
-- methods could serve as a passive but effective retention strategy to reduce churn.

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
```

---

### Question 3: What is the churn rate by customer tenure bucket?

```sql
-- LOGIC: A CTE (tenure_segments) first assigns each customer to a tenure bucket
-- (New, Early Loyal, Developing Loyal, Long-Term Loyal) using a CASE statement.
-- The outer query then aggregates total customers, churned customers, and churn rate (%)
-- per bucket using COUNT and NULLIF to avoid verbose CASE WHEN expressions.

-- FINDING: New customers (0-12 months) have the highest churn rate at 47%, which is
-- 4.7x higher than Long-Term Loyal customers (10%).

-- INSIGHT: The business should prioritize retention efforts such as onboarding programs,
-- early engagement offers, and proactive support during the first 12 months to
-- significantly reduce overall churn.

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
```

---

### Question 4: Which payment method has the highest churn rate? *(NULLIF approach)*

```sql
-- LOGIC: Group all customers by their payment method and calculate total customers,
-- churned customers, and churn rate (%) for each group to identify which payment method
-- is most associated with churn. NULLIF is used as a concise alternative to CASE WHEN
-- for counting churned customers.

-- FINDING: Electronic check users have the highest churn rate at 45%, which is
-- 3x higher than credit card users (15%).

-- INSIGHT: Incentivizing customers to switch from electronic check to automatic payment
-- methods could serve as a passive but effective retention strategy to reduce churn.

SELECT 
    paymentmethod,
    COUNT(*) AS total_customers,
    COUNT(NULLIF(churn, 'No')) AS churned_customers,
    ROUND(CAST(COUNT(NULLIF(churn, 'No')) AS FLOAT) * 100.0 / COUNT(*), 0) AS churn_rate_pct
FROM churn
GROUP BY paymentmethod
ORDER BY churn_rate_pct DESC;
```

---

### Question 5: Do customers without online security or tech support churn more than those who have it?

```sql
-- LOGIC: A CTE (protection_segments) first categorizes each customer into one of three
-- segments (No Protection, Partial Protection, Full Protection) based on their online
-- security and tech support subscription status. Customers with 'No Internet Service'
-- are excluded as they are not eligible for these add-ons. The outer query then
-- aggregates total customers, churned customers and churn rate (%) per segment.

-- FINDING: Customers with No Protection have the highest churn rate at 49%, which is
-- 5.4x higher than fully protected customers (9%).

-- INSIGHT: Promoting and incentivizing online security and tech support add-ons to
-- unprotected customers could serve as an effective retention strategy, reducing churn
-- while simultaneously growing add-on revenue.

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
```

---

## Results + Insights

| # | Question | Key Finding | Business Meaning |
|---|---|---|---|
| Q1 | Which contract type has the highest churn rate? | Month-to-Month contracts churn at 42%, 21x higher than Two Year contracts (2%) | Long-term contracts are a powerful retention lever |
| Q2 | Which payment method has the highest churn rate? | Electronic check users churn at 45%, 3x higher than credit card users (15%) | Auto-pay adoption could passively reduce churn |
| Q3 | What is the churn rate by customer tenure bucket? | New customers (0-12 months) churn at 47%, 4.7x higher than Long-Term Loyal customers (10%) | The first 12 months are the most critical retention window |
| Q4 | Which payment method has the highest churn rate? | Electronic check users churn at 45%, 3x higher than credit card users (15%) | Same insight demonstrated using NULLIF instead of CASE WHEN |
| Q5 | Do unprotected customers churn more? | No Protection customers churn at 49%, 5.4x higher than Full Protection customers (9%) | Add-on services are strongly tied to customer retention |

---

## 3 Recommendations

1. **Target Month-to-Month customers with contract upgrade offers** — A discount or loyalty reward for switching to an annual or two-year plan could dramatically reduce the 42% churn rate in this segment.

2. **Launch an onboarding retention program for new customers (0–12 months)** — Since nearly half of new customers churn, a structured onboarding experience with proactive check-ins and early engagement incentives could significantly reduce early dropout.

3. **Incentivize electronic check users to switch to auto-pay** — Offering a small monthly discount for switching to bank transfer or credit card payments could passively reduce churn, given that electronic check users churn at 3x the rate of auto-pay customers.

---

## Next Question to Explore

**Does monthly charge amount influence churn rate?**

If higher-paying customers churn more, it would suggest price sensitivity is a key driver — which could inform tiered pricing or loyalty discount strategies. This would require bucketing `MonthlyCharges` into low, medium, and high segments and analyzing churn rate across each, potentially combined with contract type for deeper insight.
