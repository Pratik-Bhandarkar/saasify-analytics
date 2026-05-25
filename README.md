# SaaSify Analytics

A production-style analytics engineering project built with dbt Core and DuckDB.
Simulates the data stack of a B2B SaaS company - from raw event and billing data
through to ML-ready churn risk models.

![dbt](https://img.shields.io/badge/dbt-1.11.8-orange)
![DuckDB](https://img.shields.io/badge/DuckDB-1.10.1-yellow)
![Python](https://img.shields.io/badge/Python-3.10.6-blue)
![Tests](https://img.shields.io/badge/tests-48%20passing-brightgreen)
![CI](https://github.com/Pratik-Bhandarkar/saasify-analytics/actions/workflows/dbt_ci.yml/badge.svg)
---

## Lineage Graph

![DAG](docs/dag.png)

---

## Project Background

SaaSify sells a project-management tool to other businesses. As the first
Analytics Engineer, I built a dbt pipeline that transforms raw product and
billing data into clean, tested, analytics-ready models.

The pipeline also integrates AI-generated churn and expansion scores into a
composite risk model - the kind of work that sits at the intersection of
analytics engineering and ML.

---

## Stack

| Tool | Version | Purpose |
|------|---------|---------|
| dbt Core | 1.11.8 | Transformation engine |
| dbt-duckdb | 1.10.1 | DuckDB adapter |
| DuckDB | local | Warehouse (file-based, no setup needed) |
| dbt-utils | 1.3.0 | Extended test library |

---

## Data Model

The project follows a layered architecture:

**Seeds** - Five CSV files representing raw operational data: accounts, users,
product events, subscription changes, and ML-generated AI signals.

**Staging** - One view per source. Renames columns, casts types, filters
deleted records, and parses JSON event properties. Nothing downstream ever
touches raw tables directly.

**Intermediate** - Two models that do the heavy lifting before marts.
`int_account_activity` aggregates product events per account.
`int_user_sessions` sessionizes user events using a 30-minute inactivity
threshold and window functions.

**Marts (Core)** - Three business-facing tables materialized as tables.
`dim_accounts` and `dim_users` are dimension tables enriched with activity
metrics. `fct_subscriptions` is the grain-documented fact table for MRR
and churn analysis.

**Marts (AI)** - `fct_account_health` joins product signals with AI scores.
`mart_churn_risk` adds a composite risk score (weighted formula across ML
output, inactivity, and adoption signals) and a `recommended_action` column
that a downstream LLM can use to generate personalized sales outreach.

**Snapshots** - `snp_account_plans` tracks plan changes over time using
SCD Type 2, enabling historical "what plan was this account on in Q2?" queries.

---

## Key Business Questions This Project Answers

- Which accounts are at risk of churning and why?
- Which accounts are ready for an upgrade conversation?
- How engaged are users with specific product features?
- What is the MRR impact of upgrades and churns over time?
- What plan was a given account on at any point in history?

---

## AI Use Case

`mart_churn_risk` doubles as a feature store for the ML team and a
data source for LLM-generated sales outreach. The `recommended_action`
column segments every account into `urgent_outreach`, `expansion_opportunity`,
`monitor_closely`, or `healthy_no_action`.

A downstream job can query accounts where `recommended_action = 'urgent_outreach'`
and pass each row to an LLM to generate a personalized email for the account manager.

---

## Data Quality

48 tests across all layers including:
- Primary key uniqueness and not-null checks on every model
- Accepted value validation on all categorical columns
- Referential integrity between fact and dimension tables
- Custom singular test asserting MRR is never negative
- dbt-utils expression tests on composite scores

---

## How to Run Locally

**Requirements:** Python 3.10+, Git

```bash
# Clone the repo
git clone https://github.com/Pratik-Bhandarkar/saasify-analytics.git
cd saasify-analytics

# Create and activate virtual environment
python -m venv venv
venv\Scripts\activate          # Windows
source venv/bin/activate       # Mac/Linux

# Install dbt
pip install dbt-duckdb

# Configure profiles.yml
# Create C:\Users\<you>\.dbt\profiles.yml with DuckDB connection
# See profiles.yml.example for the template

# Install packages
dbt deps

# Load seed data
dbt seed

# Run all models
dbt run

# Run all tests
dbt test

# View documentation
dbt docs generate && dbt docs serve
```

---

## Project Structure

```
models/
├── staging/          # One view per source. Clean, rename, cast.
├── intermediate/     # Aggregations and sessionization logic.
└── marts/
    ├── core/         # dim_accounts, dim_users, fct_subscriptions
    └── ai/           # fct_account_health, mart_churn_risk

macros/               # cents_to_dollars, classify_engagement, generate_schema_name
snapshots/            # snp_account_plans (SCD Type 2)
seeds/                # Raw CSV data
tests/                # Singular tests
```
