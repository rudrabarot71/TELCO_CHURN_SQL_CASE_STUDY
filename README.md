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
2. Which payment method has the highest churn rate?
3. What is the churn rate by customer tenure bucket?
4. Which customer segments, based on tenure and monthly charge levels, have the highest churn rate?
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

### Question 4: Which customer segments, based on tenure and monthly charge levels, have the highest churn rate?

```sql
-- LOGIC: A CTE (segmented_data) first assigns each customer to a tenure bucket
-- (New, Early Loyal, Developing Loyal, Long-Term Loyal) and a monthly charge segment
-- (Low, Medium, High) using CASE statements. The outer query then aggregates total customers,
-- churned customers, and churn rate (%) for each combination
-- to efficiently identify high-risk customer segments.

-- FINDING: New customers with High monthly charges have the highest churn rate at 73%, 
-- which is over 24x higher than Long-Term Loyal customers with Low charges (3%).

WITH segmented_data AS (
    SELECT *,
        CASE 
            WHEN tenure BETWEEN 0 AND 12 THEN 'New'
            WHEN tenure BETWEEN 13 AND 24 THEN 'Early Loyal'
            WHEN tenure BETWEEN 25 AND 48 THEN 'Developing Loyal'
            WHEN tenure BETWEEN 49 AND 72 THEN 'Long-Term Loyal'
        END AS tenure_bucket,
        CASE 
            WHEN monthlycharges < 50 THEN 'Low'
            WHEN monthlycharges BETWEEN 50 AND 80 THEN 'Medium'
            ELSE 'High'
        END AS charge_segment
    FROM churn
)
SELECT 
    tenure_bucket,
    charge_segment,
    COUNT(*) AS total_customers,
    COUNT(NULLIF(churn, 'No')) AS churned_customers,
    ROUND(CAST(COUNT(NULLIF(churn, 'No')) AS FLOAT) * 100.0 / COUNT(*), 0) AS churn_rate_pct
FROM segmented_data
GROUP BY tenure_bucket, charge_segment
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

|    | Question                                                                                         | Key Finding                                                         | Business Meaning                                                                                                            |
| -- | ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| Q1 | Which contract type has the highest churn rate?                                                  | Month-to-Month churn is drastically higher than long-term contracts | Moving customers to long-term contracts is the most impactful way to reduce churn and improve retention stability           |
| Q2 | Which payment method has the highest churn rate?                                                 | Electronic check users churn significantly more than auto-pay users | Promoting auto-pay can reduce churn by increasing convenience and reducing payment friction                                 |
| Q3 | What is the churn rate by customer tenure bucket?                                                | New customers churn far more than long-term customers               | Retention efforts should be heavily focused on the first few months, as early experience drives long-term loyalty           |
| Q4 | Which customer segments, based on tenure and monthly charge levels, have the highest churn rate? | New + High-paying customers have the highest churn                  | High-value customers are most vulnerable early, so targeted onboarding and pricing strategies can prevent high revenue loss |
| Q5 | Do customers without online security or tech support churn more than those who have it?          | Customers without protection churn far more                         | Increasing adoption of add-on services can improve retention while also driving additional revenue                          |

---

## 3 Recommendations

1. **Drive migration to long-term contracts for high-risk customers** — Prioritize month-to-month customers—especially those early in their lifecycle—with targeted incentives such as limited-time discounts or bundled value offers. This directly addresses the highest churn segment and improves revenue predictability.

2. **Strengthen early-stage customer experience** — Implement a structured onboarding program with proactive engagement (welcome journeys, usage guidance, early support touchpoints). Reducing friction early can significantly lower churn and increase lifetime value.

3. **Increase adoption of auto-pay and value-added services** — Encourage customers to switch from electronic checks to auto-pay through small incentives, while also promoting add-on services like tech support and online security. This both reduces churn risk and increases customer stickiness and revenue per user.
---

## Next Question to Explore

**How much revenue is lost due to churn, and which segments contribute the most to this loss?**

This would shift the analysis from who is churning to which churn matters most financially, helping prioritize high-value customer retention strategies.
