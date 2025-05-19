# Data Analytics Assessment
This repository contains SQL solutions for the Data Analytics Assessment. The assessment evaluates SQL proficiency in solving real-world business problems by interacting with multiple relational database tables.

## Questions and Solutions:

### 1. High-Value Customers with Multiple Products

**Scenario:** The business wants to identify customers who have both a savings and an investment plan (cross-selling opportunity).

**Tables Involved:**
- `users_customuser`: Stores customer demographic and contact information.
- `savings_savingsaccount`: Records of deposit transactions.
- `plans_plan`: Records of plans created by customers.

**`Excerpt From Query Output:`**
```sql
+----------------------------------+------------------+---------------+------------------+----------------+
| owner_id                         | name             | savings_count | investment_count | total_deposits |
+----------------------------------+------------------+---------------+------------------+----------------+
| 0257625a02344b239b41e1cbe60ef080 | Opeoluwa Popoola |            59 |               13 |        6809070 |
| 75b9df985e254031aaba8ec44f459d2d | Edward Popoola   |             3 |               29 |         600680 |
+----------------------------------+------------------+---------------+------------------+----------------+
2 rows in set (2.782 sec)
```

#### Approach

-**Step 1:** I joined the `users_customuser` table (`u`) with the `savings_savingsaccount` table (`s`) on `u.id = s.owner_id` to associate each saving transaction with its owner.

**Step 2:** To identify savings plans, I joined `savings_savingsaccount` (`s`) to `plans_plan` (`p_savings`) where `p_savings.is_regular_savings = 1`. To identify investment plans, I joined `users_customuser` (`u`) to `plans_plan` (`p`) where `p.is_a_fund = 1`.

**Step 3:** I applied filters to include only funded accounts where `(s.confirmed_amount - s.deduction_amount) > 0` for savings and `p.amount > 0` for investments.

**Step 4:** Using `inner join` I ensured only customers having both savings and investment plans are selected. Finally, I grouped by customer and summed deposits to prioritize high-value customers.


#### Challenges
- **Owner ID Format Mismatch:**  
The expected output from the docs showed an integer `owner_id` (e.g., `1001`), but `users_customuser.id` is a `char(32)` UUID (e.g., `0257625a02344b239b41e1cbe60ef080`). Initially, I considered using `savings_savingsaccount.id` (int) as the owner ID, but that identifies accounts, not users. I chose to keep `u.id` as the correct identifier consistent with the schema. This may require downstream adjustments if integer IDs are strictly required.

- **Joining Multiple Product Types:**  
  Ensuring that the joins correctly matched savings plans (`is_regular_savings = 1`) and investment plans (`is_a_fund = 1`) without duplication was critical to avoid inflating counts or amounts.

- **Data Consistency with Amounts:**  
Careful calculation of net confirmed savings amount `(confirmed_amount - deduction_amount)` and filtering only positive values prevented inclusion of invalid or zero-value plans.

- **Summation of deposits across Sources:**  
Summing deposits from two separate tables (savings and investment) required handling NULLs properly using `coalesce` and converting amounts from Kobo to Naira consistently.


### 2. Transaction Frequency Analysis

**Scenario:** The finance team wants to analyze how often customers transact to segment them (e.g., frequent vs. occasional users).

**Task:** Calculate the average number of transactions per customer per month and categorize them:
- High Frequency: 10 or more transactions per month
- Medium Frequency: 3 to 9 transactions per month
- Low Frequency: 2 or fewer transactions per month

**Tables:**
- `users_customuser`
- `savings_savingsaccount`

**`Excerpt From Query Output:`**
```sql
+--------------------+----------------+----------------------------+
| frequency_category | customer_count | avg_transactions_per_month |
+--------------------+----------------+----------------------------+
| High Frequency     |              2 |                       14.5 |
| Medium Frequency   |              5 |                        5.2 |
| Low Frequency      |             20 |                        1.5 |
+--------------------+----------------+----------------------------+
3 rows in set (0.220 sec)
```

#### Approach

**Step 1:** First, I calculated the number of transactions per customer per month from the `savings_savingsaccount` table, filtered to include only funded transactions `(confirmed_amount - deduction_amount > 0)`. 

To analyze transaction frequency, transactions were aggregated monthly using `date_format(transaction_date, '%Y-%m')`. This decision ensures that meaningful transaction behavior over time were captured without excessive granularity.

- **Avoiding Unnecessary Joins:** Initially, there was a consideration to join with `users_customuser`, but I concluded it was unnecessary since all required information was present in `savings_savingsaccount`. This optimization reduces query complexity and improves performance especially in a live prod environment with a lot of data.


**Step 2:** I aggregated the monthly transaction counts to find the average number of transactions per month for each customer. 

**Step 3:** I went on to segment customers based on the average number of transactions per month as per the requirements.
The results are aggregated to show the number of customers in each category and their average transaction count.


### 3. Account Inactivity Alert

**Scenario:** The ops team wants to flag accounts with no inflow transactions for over one year.

**Task:** Find all active accounts (savings or investments) with no transactions in the last 1 year (365 days).

**Tables:**
- `plans_plan`
- `savings_savingsaccount`

**`Excerpt From Query Output:`**
```sql
+----------------------------------+----------------------------------+-------------+-----------------------+-----------------+
| plan_id                          | owner_id                         | type        | last_transaction_date | inactivity_days |
+----------------------------------+----------------------------------+-------------+-----------------------+-----------------+
| 836425e0abcc4a178fde22d3fbb238c0 | 0257625a02344b239b41e1cbe60ef080 | Savings     | 2016-11-20            |            3102 |
| 7f960e5b3743434882ee8ddcedb9aecb | 0257625a02344b239b41e1cbe60ef080 | Savings     | 2016-12-11            |            3081 |
| 3442d9781a99478cb09af0d4d661937a | 75b9df985e254031aaba8ec44f459d2d | Savings     | 2017-09-02            |            2816 |
| b8d63cc147454862a803f9da2c47f3bb | 0257625a02344b239b41e1cbe60ef080 | Savings     | 2017-09-13            |            2805 |
| 6f239e18682040619e61130de6b942b8 | 742da71d7daa46d0801755c883bdc464 | Investments | 2024-04-12            |             402 |
+----------------------------------+----------------------------------+-------------+-----------------------+-----------------+
5 rows in set (0.254 sec)
```

#### Approach
**Step 1. Identify Active Plans:** I queried the `plans_plan` table to extract only active plans that are either:
  - Savings Plans (is_regular_savings = 1)
  - Investment Plans (is_fixed_investment = 1 or is_a_fund = 1)

I excluded any plans marked as archived or deleted.

**Step 2. Fetch Last Inflow Transaction:** From the `savings_savingsaccount` table, I selected only inflow transactions—those where `confirmed_amount - deduction_amount > 0.` For each plan, I computed the most recent transaction date (MAX(transaction_date)).

**Step 3. Join and Filter:** I performed a LEFT JOIN between active plans and their last inflow transaction date. This allows me to:
  - Catch plans that have never received any inflow (null join result).
  - Calculate the number of inactivity days using DATEDIFF(CURDATE(), last_transaction_date).

**Step 4. Apply Inactivity Rule:** 
Plans are flagged if:
  - They have no transaction history, or their last inflow was more than 365 days ago.


### 4. Customer Lifetime Value (CLV) Estimation

**Scenario:** Marketing wants to estimate CLV based on account tenure and transaction volume (simplified model).

**Task:** For each customer, assuming the profit_per_transaction is 0.1% of the transaction value, calculate:
- Account tenure (months since signup)
- Total transactions
- Estimated CLV (Assume: CLV = (total_transactions / tenure) * 12 * avg_profit_per_transaction)
- Order by estimated CLV from highest to lowest

**Tables:**
- `users_customuser`
- `savings_savingsaccount`

**`Excerpt From Query Output:`**
```sql
+----------------------------------+----------------------+---------------+--------------------+---------------+
| customer_id                      | name                 | tenure_months | total_transactions | estimated_clv |
+----------------------------------+----------------------+---------------+--------------------+---------------+
| c262e2e1fbc44993ba09a6e9be41edd6 | Blessing Uwadia      |            45 |                  2 |       1385280 |
| 363237ae6a2242feb3c973ef20247f79 | Yami PThree          |            66 |                 19 |     499349.76 |
| 72141b6db0a94e9b8414ae0e783792b7 | Timothy Olanrewaju   |            64 |                 24 |     123471.37 |
| 73cc1ea013d44bb4b271c8737dedef91 | Daniel Coker         |            35 |                  4 |     103452.93 |
| fe321c01bc49461a94cef73de1cd393f | Nifemi Test SOLA-OJO |            45 |                  2 |      66602.66 |
+----------------------------------+----------------------+---------------+--------------------+---------------+
5 rows in set, 1 warning (0.242 sec)
```

#### Approach

**Step 1. Calculate Account Tenure:** I computed the total number of months since each customer signed up `(timestampdiff(month, date_joined, curdate()))`, which serves as the account tenure.

**Step 2. Count Total Transactions:** I counted all valid inflow transactions where the net transaction amount `(confirmed_amount - deduction_amount)` is positive, indicating money added to the account.

**Step 3. Compute Average Profit per Transaction:** I calculated the average profit per transaction by assuming a fixed profit margin of 0.1% of the transaction value `(avg((confirmed_amount - deduction_amount) * 0.001))`.

## Conclusion

This assessment demonstrates my ability to write accurate, efficient, and well-structured SQL queries to solve business problems involving multiple relational tables. 

Each query addresses the specified scenario by leveraging joins, aggregations, filtering, and conditional logic to extract actionable insights. The solutions reflect careful attention to query optimization, readability, and completeness in line with the evaluation criteria. 

This exercise reinforces key data analyst skills in working with transactional and customer data to support business decision-making.
