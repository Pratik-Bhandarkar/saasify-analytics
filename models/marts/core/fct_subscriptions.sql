{{
    config(
        materialized='incremental',
        unique_key='subscription_id',
        incremental_strategy='merge'
    )
}}

with subscriptions as (

    select * from {{ ref('stg_subscriptions') }}

    {% if is_incremental() %}
        where changed_at > (select max(changed_at) from {{ this }})
    {% endif %}

),

accounts as (

    select
        account_id,
        account_name,
        plan_type,
        country,
        industry

    from {{ ref('stg_accounts') }}

),

final as (

    select
        -- primary key
        s.subscription_id,

        -- foreign keys
        s.account_id,

        -- account context
        a.account_name,
        a.country,
        a.industry,

        -- subscription details
        s.plan_from,
        s.plan_to,
        s.change_reason,
        s.changed_at,

        -- financials (raw cents and converted dollars)
        s.mrr_usd,
        {{ cents_to_dollars('s.mrr_usd') }}     as mrr_dollars,
        s.mrr_change_usd,
        {{ cents_to_dollars('s.mrr_change_usd') }} as mrr_change_dollars,

        -- derived flags
        case
            when s.change_reason = 'upgrade'
            then true else false
        end                                     as is_upgrade,

        case
            when s.change_reason in ('downgrade', 'churn')
            then true else false
        end                                     as is_contraction,

        case
            when s.change_reason = 'churn'
            then true else false
        end                                     as is_churn

    from subscriptions as s
    left join accounts as a
        on s.account_id = a.account_id

)

select * from final