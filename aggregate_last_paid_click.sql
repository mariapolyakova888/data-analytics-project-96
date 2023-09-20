-- Шаг 3. Построим витрину по расчету расходов на рекламу
with t as (
    select distinct on (s.visitor_id)
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where s.medium != 'organic'
    order by s.visitor_id asc, s.visit_date desc
),

last_paid_click as (
    select *
    from t
    order by
        amount desc nulls last,
        visit_date asc,
        utm_source asc,
        utm_medium asc,
        utm_campaign asc
),

last_paid_click_revenue as (
    select
        date_trunc('day', visit_date)::date as visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        count(visitor_id) as visitors_count,
        count(lead_id) as leads_count,
        count(
            case
                when
                    closing_reason = 'Успешная продажа' or status_id = 142
                    then lead_id
            end
        ) as purchases_count,
        sum(
            case
                when
                    closing_reason = 'Успешная продажа' or status_id = 142
                    then amount
            end
        ) as revenue
    from last_paid_click
    group by
        date_trunc('day', visit_date)::date,
        utm_source,
        utm_medium,
        utm_campaign
    order by
        revenue desc nulls last,
        visit_date asc,
        visitors_count desc,
        utm_source asc,
        utm_medium asc,
        utm_campaign asc
),

vk as (
    select
        date_trunc('day', campaign_date)::date as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as daily_spent
    from vk_ads
    where utm_medium != 'organic'
    group by
        date_trunc('day', campaign_date)::date,
        utm_source,
        utm_medium,
        utm_campaign
),

ya as (
    select
        date_trunc('day', campaign_date)::date as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as daily_spent
    from ya_ads
    where utm_medium != 'organic'
    group by
        date_trunc('day', campaign_date)::date,
        utm_source,
        utm_medium,
        utm_campaign
)

select
    lpcr.visit_date,
    lpcr.visitors_count,
    lpcr.utm_source,
    lpcr.utm_medium,
    lpcr.utm_campaign,
    coalesce(vk.daily_spent, ya.daily_spent, 0) as total_cost,
    lpcr.leads_count,
    lpcr.purchases_count,
    lpcr.revenue
from last_paid_click_revenue as lpcr
left join vk
    on
        lpcr.visit_date = vk.campaign_date
        and lpcr.utm_source = vk.utm_source
        and lpcr.utm_medium = vk.utm_medium
        and lpcr.utm_campaign = vk.utm_campaign
left join ya
    on
        lpcr.visit_date = ya.campaign_date
        and lpcr.utm_source = ya.utm_source
        and lpcr.utm_medium = ya.utm_medium
        and lpcr.utm_campaign = ya.utm_campaign;
