--Шаг 2. Запрос для витрины по модели атрибуции лидов Last Paid Click:
with last_touch as (
    select distinct on (visitor_id)
        visitor_id,
        max(visit_date) as visit_date,
        source,
        medium,
        campaign
    from sessions
    where
        medium != 'organic'
    group by visitor_id, visit_date, source, medium, campaign
    order by visitor_id, visit_date desc
)

select
    last_touch.visitor_id,
    last_touch.visit_date,
    last_touch.source as utm_source,
    last_touch.medium as utm_medium,
    last_touch.campaign as utm_campaign,
    l.lead_id,
    l.created_at,
    l.amount,
    l.closing_reason,
    l.status_id
from last_touch
left join leads as l
    on
        last_touch.visitor_id = l.visitor_id
order by
    l.amount desc nulls last,
    last_touch.visit_date, utm_source, utm_medium, utm_campaign asc;