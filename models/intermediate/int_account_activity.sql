with accounts as (

    select * from {{ ref('stg_accounts') }}

),

events as (

    select * from {{ ref('stg_events') }}

),

event_aggregates as (

    select
        account_id,

        -- volume metrics
        count(*)                                    as total_events,
        count(distinct user_id)                     as active_user_count,

        -- feature usage breakdown
        count(
            case when event_type = 'feature_used'
            then 1 end)                             as feature_event_count,
        count(
            case when event_type = 'page_view'
            then 1 end)                             as page_view_count,

        -- specific feature usage
        count(
            case when event_feature = 'reporting'
            then 1 end)                             as reporting_usage_count,
        count(
            case when event_feature = 'api_access'
            then 1 end)                             as api_usage_count,
        count(
            case when event_feature = 'export'
            then 1 end)                             as export_usage_count,

        -- recency
        max(event_at)                               as last_event_at,
        min(event_at)                               as first_event_at,

        -- 30-day activity flag
        max(case
            when event_at >= current_timestamp - interval '30 days'
            then 1 else 0
        end)                                        as is_active_last_30_days

    from events
    group by account_id

),

joined as (

    select
        -- account attributes
        a.account_id,
        a.account_name,
        a.plan_type,
        a.plan_rank,
        a.country,
        a.industry,
        a.employee_count,
        a.created_at                                as account_created_at,

        -- activity metrics (coalesce handles accounts with zero events)
        coalesce(e.total_events, 0)                 as total_events,
        coalesce(e.active_user_count, 0)            as active_user_count,
        coalesce(e.feature_event_count, 0)          as feature_event_count,
        coalesce(e.page_view_count, 0)              as page_view_count,
        coalesce(e.reporting_usage_count, 0)        as reporting_usage_count,
        coalesce(e.api_usage_count, 0)              as api_usage_count,
        coalesce(e.export_usage_count, 0)           as export_usage_count,
        coalesce(e.is_active_last_30_days, 0)       as is_active_last_30_days,

        -- recency
        e.last_event_at,
        e.first_event_at,
        datediff('day',
            e.last_event_at,
            current_timestamp)                      as days_since_last_event

    from accounts as a
    left join event_aggregates as e
        on a.account_id = e.account_id

)

select * from joined