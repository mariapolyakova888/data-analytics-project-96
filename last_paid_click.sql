--Шаг 2. Запрос для витрины по модели атрибуции лидов Last Paid Click:
with last_touch as (
    select distinct on (s.visitor_id)
        s.visitor_id,
        max(s.visit_date) as visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign
    from sessions as s
    where
        s.medium != 'organic'
    group by 1, s.visit_date, 3, 4, 5
    order by s.visitor_id, s.visit_date desc
)

select
    last_touch.visitor_id,
    last_touch.visit_date,
    last_touch.utm_source,
    last_touch.utm_medium,
    last_touch.utm_campaign,
    l.lead_id,
    l.created_at,
    l.amount,
    l.closing_reason,
    l.status_id
from last_touch
left join leads as l
    on
        last_touch.visitor_id = l.visitor_id
        and last_touch.utm_medium != 'organic'
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
order by 8 desc nulls last, 2, 3, 4, 5 asc;