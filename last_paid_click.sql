--Шаг 2. Построим витрину для модели атрибуции Last Paid Click

with last_paid_click as (
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
    left join leads as l on s.visitor_id = l.visitor_id
    where s.medium != 'organic'
    order by s.visitor_id asc, s.visit_date desc
)

select *
from last_paid_click
order by
    amount desc nulls last,
    visit_date asc,
    utm_source asc,
    utm_medium asc,
    utm_campaign asc;