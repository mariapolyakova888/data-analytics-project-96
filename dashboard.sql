--Посещения по беспл, платн каналам в разрезе за июнь в динамике по дням
select
    to_char(visit_date, 'DD-MM-YYYY') as visit_date,
    case
        when medium = 'organic' then 'organic'
        when medium != 'organic' then 'paid_channel'
    end as channel,
    count(visitor_id) as visitors_count
from sessions
group by 1, 2
order by 1, 2, 3;

--Посещения по платн каналам в разрезе источников для pie chart
select
    s.source,
    to_char(s.visit_date, 'month-YYYY') as visit_month,
    count(s.visitor_id) as visitors_count
from sessions as s
where s.medium != 'organic'
group by 2, 1
order by 2, 1;

--Посещения по беспл каналам в разрезе источников для pie chart
select
    s.source,
    to_char(s.visit_date, 'month-YYYY') as visit_month,
    count(s.visitor_id) as visitors_count
from sessions as s
where s.medium = 'organic'
group by 2, 1
order by 2, 1;

-- Расчет метрик cpu, cpl, cppu, roi по vk, ya за июнь 2023 г.
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
    order by 1 asc, 1 desc
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
    group by 1, 2, 3, 4
    order by 8 desc nulls last, 1 asc, 5 desc, 2 asc, 3 asc, 4 asc
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
    group by 1, 2, 3, 4
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
    group by 1, 2, 3, 4
),

lpcr as (
    select
        lpcr.visit_date,
        lpcr.utm_source,
        lpcr.utm_medium,
        lpcr.utm_campaign,
        lpcr.visitors_count,
        lpcr.leads_count,
        lpcr.purchases_count,
        lpcr.revenue,
        coalesce(vk.daily_spent, ya.daily_spent, 0) as total_cost
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
            and lpcr.utm_campaign = ya.utm_campaign
)

select
    lpcr.utm_source,
    round(sum(lpcr.total_cost) / sum(lpcr.visitors_count), 2) as cpu,
    round(sum(lpcr.total_cost) / sum(lpcr.leads_count), 2) as cpl,
    round(sum(lpcr.total_cost) / sum(lpcr.purchases_count), 2) as cppu,
    round(
        sum(lpcr.revenue - lpcr.total_cost) / sum(lpcr.total_cost) * 100, 2
    ) as roi
from lpcr
where lpcr.total_cost != 0
group by 1
order by 1;



--Создание представления - модель Last Paid Click
create view last_paid_click_mplkv as
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
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where s.medium != 'organic'
    order by 1 asc, 2 desc
)

select *
from last_paid_click as lpc
order by
    lpc.amount desc nulls last,
    lpc.visit_date asc,
    lpc.utm_source asc,
    lpc.utm_medium asc,
    lpc.utm_campaign asc;

--Доходы и расходы за июнь 2023 г.
select
    sum(ac.total_cost) as total_cost,
    sum(ac.revenue) as revenue
from aggregate_costs_mplkv as ac
group by date_trunc('month', ac.visit_date);

--Расчет конверсии из клика в лида, в продажу, всей воронки
with tab as (
    select
        date_trunc('month', s.visit_date)::date as visit_date,
        count(distinct s.visitor_id) as visitors_count,
        count(l.lead_id) as leads_count,
        count(
            case
                when
                    l.closing_reason = 'Успешная продажа' or l.status_id = 142
                    then l.lead_id
            end
        ) as purchases_count
    from sessions as s
    left join leads as l
        on s.visitor_id = l.visitor_id and s.visit_date <= l.created_at
    group by 1
)

select
    round(tab.leads_count / tab.visitors_count * 100, 3) as lcr,
    round(tab.purchases_count / tab.leads_count * 100, 3) as pcr,
    round(
        tab.purchases_count / tab.visitors_count * 100, 3
    ) as cnvrsn
from tab;

--Расчет cpu, cpl, cppu, roi
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
    order by 1 asc, 2 desc
),

last_paid_click as (
    select *
    from t
    order by
        t.amount desc nulls last,
        t.visit_date asc,
        t.utm_source asc,
        t.utm_medium asc,
        t.utm_campaign asc
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
    group by 1, 2, 3, 4
    order by 8 desc nulls last, 1 asc, 5 desc, 2 asc, 3 asc, 4 asc
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
    group by 1, 2, 3, 4
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
    group by 1, 2, 3, 4
),

lpcr as (
    select
        lpcr.visit_date,
        lpcr.utm_source,
        lpcr.utm_medium,
        lpcr.utm_campaign,
        lpcr.visitors_count,
        lpcr.leads_count,
        lpcr.purchases_count,
        lpcr.revenue,
        coalesce(vk.daily_spent, ya.daily_spent, 0) as total_cost
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
            and lpcr.utm_campaign = ya.utm_campaign
)

select
    round((sum(lpcr.total_cost) / sum(lpcr.visitors_count::numeric)), 0) as cpu,
    round((sum(lpcr.total_cost) / sum(lpcr.leads_count::numeric)), 0) as cpl,
    round(
        (sum(lpcr.total_cost) / sum(lpcr.purchases_count::numeric)), 0
    ) as cppu,
    round(
        ((sum(lpcr.revenue) - sum(lpcr.total_cost)) / sum(lpcr.total_cost)), 0
    ) as roi
from lpcr;
