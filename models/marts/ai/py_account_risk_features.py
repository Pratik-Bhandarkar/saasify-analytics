import pandas as pd
from scipy import stats


def model(dbt, session):

    dbt.config(materialized="table")

    churn_risk = dbt.ref("mart_churn_risk")
    df = churn_risk.df()

    # Feature 1: Risk score buckets
    df["risk_bucket"] = pd.cut(
        df["composite_risk_score"],
        bins=[0, 0.25, 0.50, 0.75, 1.0],
        labels=["low", "medium", "high", "critical"],
        include_lowest=True
    )
    df["risk_bucket"] = df["risk_bucket"].astype(str)

    # Feature 2: Zscore normalization of days since last event
    days = df["days_since_last_event"].fillna(
        df["days_since_last_event"].median()
    )
    df["days_since_event_zscore"] = stats.zscore(days).round(4)

    # Feature 3: Composite engagement score
    df["engagement_score"] = (
        (df["total_events"] / df["total_events"].max()) * 0.5
        + (df["active_user_count"] / df["active_user_count"].max()) * 0.3
        + (df["is_active_last_30_days"] * 0.2)
    ).round(4)

    result = df[[
        "account_id",
        "account_name",
        "plan_type",
        "composite_risk_score",
        "risk_bucket",
        "churn_score",
        "expansion_score",
        "recommended_action",
        "days_since_last_event",
        "days_since_event_zscore",
        "total_events",
        "active_user_count",
        "engagement_score",
        "feature_is_active",
        "feature_is_power_user",
        "feature_is_high_value"
    ]]

    return result