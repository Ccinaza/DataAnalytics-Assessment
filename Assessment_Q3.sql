-- cte to get the most recent inflow transaction per plan
with last_transaction as (
    select
        s.plan_id,
        max(date(s.transaction_date)) as last_transaction_date  -- extract latest inflow date
    from
        adashi_staging.savings_savingsaccount s
    where
        (s.confirmed_amount - s.deduction_amount) > 0  -- only considers inflow transactions
    group by
        s.plan_id  -- one row per plan
)

select
    p.id as plan_id,
    p.owner_id,

    -- classifies each plan as 'savings', 'investments', or 'unknown'
    case
        when p.is_regular_savings = 1 then 'Savings'
        when p.is_fixed_investment = 1 or p.is_a_fund = 1 then 'Investments'
        else 'Unknown'
    end as type,

    -- shows last transaction date or marks as 'Never' if no transaction exists
    case
        when lt.last_transaction_date is null then 'Never'
        else date_format(lt.last_transaction_date, '%Y-%m-%d')
    end as last_transaction_date,

    -- calculates inactivity in days or returns null if no transaction
    if(
        lt.last_transaction_date is null,
        null,
        datediff(curdate(), lt.last_transaction_date)
    ) as inactivity_days

from
    adashi_staging.plans_plan p

-- joins with the last_transaction cte to bring in recent inflow info
left join
    last_transaction lt on p.id = lt.plan_id

where
    p.is_archived = 0  -- only includes active (non-archived) plans
    and p.is_deleted = 0  -- excludes deleted plans
    and (  -- filters for only relevant plan types
        p.is_regular_savings = 1
        or p.is_fixed_investment = 1
        or p.is_a_fund = 1
    )
    and (  -- includes plans with no inflow or inactive for over 365 days
        lt.last_transaction_date is null
        or datediff(curdate(), lt.last_transaction_date) > 365
    )

order by
    inactivity_days desc;  -- shows longest inactive plans first
