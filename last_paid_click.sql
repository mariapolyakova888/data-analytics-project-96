--Шаг 2. Запрос для витрины по модели атрибуции лидов Last Paid Click:
select distinct on (s.visitor_id)
    s.visitor_id,
    max(s.visit_date) as visit_date,
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
        and s.medium in (
            'cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'telegram', 'social'
        )
where
    s.medium in (
        'cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'telegram', 'social'
    )
group by 1, s.visit_date, 3, 4, 5, 6, 7, 8, 9, 10
order by 1, 2, 3, 4, 5 asc;
