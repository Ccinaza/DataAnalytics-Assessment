-- Question 1: High-Value Customers with Multiple Products
-- This query retrieves customers who have both a funded savings plan and a funded investment plan.
-- It calculates the number of savings and investment plans each customer has, and their total deposits.
-- Deposits are summed up from both savings and investment plans and converted from Kobo to Naira.

select
    u.id as owner_id,
    concat(coalesce(u.first_name, ''), ' ', coalesce(u.last_name, '')) as name,
    COUNT(distinct s.id) as savings_count,
    COUNT(distinct p.id) as investment_count,
    coalesce(sum((s.confirmed_amount - s.deduction_amount) / 100 + p.amount / 100), 0) as total_deposits
from
    adashi_staging.users_customuser as u
join
    adashi_staging.savings_savingsaccount as s on u.id = s.owner_id
join
    adashi_staging.plans_plan as p_savings on s.plan_id = p_savings.id
    and p_savings.is_regular_savings = 1
join
    adashi_staging.plans_plan as p on u.id = p.owner_id
    and p.is_a_fund = 1
where
    (s.confirmed_amount - s.deduction_amount) > 0
    and p.amount > 0
group by
    u.id, u.first_name, u.last_name
order by
    total_deposits desc;