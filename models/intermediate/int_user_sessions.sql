with events as (

    select * from {{ ref('stg_events') }}

),

users as (

    select * from {{ ref('stg_users') }}

),

-- assign session boundaries
-- a new session starts when the gap between events exceeds 30 minutes
events_with_session_flag as (

    select
        event_id,
        user_id,
        account_id,
        event_type,
        event_at,

        -- flag the start of a new session
        -- if time since previous event > 30 min, this is a new session
        case
            when datediff('minute',
                lag(event_at) over (
                    partition by user_id
                    order by event_at
                ),
                event_at
            ) > 30
            or lag(event_at) over (
                partition by user_id
                order by event_at
            ) is null
            then 1
            else 0
        end                         as is_session_start

    from events

),

-- assign a session number to each event
events_with_session_id as (

    select
        event_id,
        user_id,
        account_id,
        event_type,
        event_at,
        is_session_start,

        -- cumulative sum of session starts = session number per user
        sum(is_session_start) over (
            partition by user_id
            order by event_at
            rows between unbounded preceding and current row
        )                           as user_session_number

    from events_with_session_flag

),

-- aggregate to session level
session_aggregates as (

    select
        user_id,
        account_id,
        user_session_number,
        min(event_at)               as session_start_at,
        max(event_at)               as session_end_at,
        count(*)                    as events_in_session,
        datediff('minute',
            min(event_at),
            max(event_at))          as session_duration_minutes

    from events_with_session_id
    group by user_id, account_id, user_session_number

),

-- join back to user attributes
final as (

    select
        -- keys
        s.user_id,
        s.account_id,
        s.user_session_number,

        -- user attributes
        u.role,
        u.engagement_tier,

        -- session metrics
        s.session_start_at,
        s.session_end_at,
        s.events_in_session,
        s.session_duration_minutes

    from session_aggregates as s
    left join users as u
        on s.user_id = u.user_id

)

select * from final