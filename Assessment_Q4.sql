select
    u.id as customer_id,
    concat(u.first_name, ' ', u.last_name) as name,

    -- months between now and signup date
    timestampdiff(month, u.date_joined, curdate()) as tenure_months,

    -- total number of valid inflow transactions
    count(s.id) as total_transactions,

    -- estimated CLV using simplified formula
    round(
        (count(s.id) / greatest(timestampdiff(month, u.date_joined, curdate()), 1))
        * 12
        * avg((s.confirmed_amount - s.deduction_amount) * 0.001),
        2
    ) as estimated_clv

from
    adashi_staging.users_customuser as u
left join
    adashi_staging.savings_savingsaccount as s on u.id = s.owner_id
    and (s.confirmed_amount - s.deduction_amount) > 0  -- valid inflow

group by
    u.id, name, tenure_months

order by
    estimated_clv desc
limit 5;