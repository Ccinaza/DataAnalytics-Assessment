-- Calculate average transactions per customer per month and categorize by frequency

with customer_monthly_txn as (
    select
        s.owner_id,
        date_format(s.transaction_date, '%Y-%m') AS txn_month,
        count(*) as transactions_in_month
    from
        adashi_staging.savings_savingsaccount as s
    where
        (s.confirmed_amount - s.deduction_amount) > 0  -- only funded transactions
    group by
        s.owner_id,
        txn_month
),

customer_avg_txn as (
    select
        owner_id,
        AVG(transactions_in_month) AS avg_txn_per_month
    from
        customer_monthly_txn
    group by
        owner_id
)

select
    case
        when avg_txn_per_month >= 10 then 'High Frequency'
        when avg_txn_per_month between 3 and 9 then 'Medium Frequency'
        else 'Low Frequency'
    end as frequency_category,
    count(*) as customer_count,
    round(avg(avg_txn_per_month), 1) as avg_transactions_per_month
from
    customer_avg_txn
group by
    frequency_category
order by
    case
        when frequency_category = 'High Frequency' then 1
        when frequency_category = 'Medium Frequency' then 2
        else 3
    end;
