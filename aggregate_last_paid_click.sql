--Шаг 3. Построение витрины - расчет расходов на рекламу по модели атрибуции Last Paid Click:
with tab as (
    select
        date_trunc('day', campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as daily_spent
    from vk_ads
    where utm_medium != 'organic'
    group by 1, 2, 3, 4
    order by 1, 3, 4 asc
),

tab1 as (
    select
        date_trunc('day', campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as daily_spent
    from ya_ads
    where utm_medium != 'organic'
    group by 1, 2, 3, 4
    order by 1, 3, 4 asc
)

select
    date_trunc('day', lpc.visit_date) as visit_date,
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign,
    count(lpc.visitor_id) as visitors_count,
    case
	    when tab.daily_spent is not null then tab.daily_spent
	    when tab1.daily_spent is not null then tab1.daily_spent
	    else 0
	end as total_cost,
    count(lpc.lead_id) as leads_count,
    count(lpc.status_id) as purchases_count,
    sum(lpc.amount) as revenue
from last_paid_click_mplkv as lpc --в базе данных marketingdb создано представление last_paid_click_mplkv
left join tab
    on
        date_trunc('day', lpc.visit_date) = tab.campaign_date
        and lpc.utm_source = tab.utm_source
        and lpc.utm_medium = tab.utm_medium
        and lpc.utm_campaign = tab.utm_campaign
left join tab1
    on
        date_trunc('day', lpc.visit_date) = tab1.campaign_date
        and lpc.utm_source = tab1.utm_source
        and lpc.utm_medium = tab1.utm_medium
        and lpc.utm_campaign = tab1.utm_campaign
where lpc.status_id = 142
group by
    visit_date,
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign,
    tab.daily_spent,
    tab1.daily_spent
order by
    revenue desc nulls last, visitors_count desc,
    visit_date, lpc.utm_source, lpc.utm_medium, lpc.utm_campaign asc;