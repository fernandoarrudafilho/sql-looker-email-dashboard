-- =====================================================
-- SQL Advanced + Looker Studio Project
-- Clean & Reliable Version
-- Objective:
-- Build a final dataset with account/email KPIs
-- and Top 10 Countries ranking by:
-- 1. Total Accounts
-- 2. Total Emails Sent
-- =====================================================

WITH account_base AS (

SELECT
    s.date AS data_account,
    COALESCE(sp.country, 'Unknown') AS country,
    a.send_interval,
    a.is_verified,
    a.is_unsubscribed,
    COUNT(DISTINCT a.id) AS account_cnt

FROM `data-analytics-mate.DA.account` AS a

LEFT JOIN `data-analytics-mate.DA.account_session` AS acs
    ON a.id = acs.account_id

LEFT JOIN `data-analytics-mate.DA.session` AS s
    ON acs.ga_session_id = s.ga_session_id

LEFT JOIN `data-analytics-mate.DA.session_params` AS sp
    ON s.ga_session_id = sp.ga_session_id

GROUP BY 1,2,3,4,5

),

email_base AS (

SELECT
    DATE_ADD(s.date, INTERVAL es.sent_date DAY) AS data_account,
    COALESCE(sp.country, 'Unknown') AS country,
    a.send_interval,
    a.is_verified,
    a.is_unsubscribed,

    COUNT(DISTINCT es.id_message) AS sent_msg,
    COUNT(DISTINCT eo.id_message) AS open_msg,
    COUNT(DISTINCT ev.id_message) AS visit_msg

FROM `data-analytics-mate.DA.account` AS a

LEFT JOIN `data-analytics-mate.DA.email_sent` AS es
    ON a.id = es.id_account

LEFT JOIN `data-analytics-mate.DA.email_open` AS eo
    ON es.id_message = eo.id_message

LEFT JOIN `data-analytics-mate.DA.email_visit` AS ev
    ON es.id_message = ev.id_message

LEFT JOIN `data-analytics-mate.DA.account_session` AS acs
    ON a.id = acs.account_id

LEFT JOIN `data-analytics-mate.DA.session` AS s
    ON acs.ga_session_id = s.ga_session_id

LEFT JOIN `data-analytics-mate.DA.session_params` AS sp
    ON s.ga_session_id = sp.ga_session_id

GROUP BY 1,2,3,4,5

),

merged_data AS (

SELECT
    COALESCE(a.data_account, e.data_account) AS data_account,
    COALESCE(a.country, e.country) AS country,
    COALESCE(a.send_interval, e.send_interval) AS send_interval,
    COALESCE(a.is_verified, e.is_verified) AS is_verified,
    COALESCE(a.is_unsubscribed, e.is_unsubscribed) AS is_unsubscribed,

    COALESCE(a.account_cnt, 0) AS account_cnt,
    COALESCE(e.sent_msg, 0) AS sent_msg,
    COALESCE(e.open_msg, 0) AS open_msg,
    COALESCE(e.visit_msg, 0) AS visit_msg

FROM account_base a

FULL OUTER JOIN email_base e
ON a.data_account = e.data_account
AND a.country = e.country
AND a.send_interval = e.send_interval
AND a.is_verified = e.is_verified
AND a.is_unsubscribed = e.is_unsubscribed

),

country_totals AS (

SELECT
    country,
    SUM(account_cnt) AS total_accounts,
    SUM(sent_msg) AS total_sent

FROM merged_data
GROUP BY country

),

country_rank AS (

SELECT
    country,
    total_accounts,
    total_sent,

    DENSE_RANK() OVER (
        ORDER BY total_accounts DESC
    ) AS rank_accounts,

    DENSE_RANK() OVER (
        ORDER BY total_sent DESC
    ) AS rank_sent

FROM country_totals

)

SELECT
    m.data_account,
    m.country,
    m.send_interval,
    m.is_verified,
    m.is_unsubscribed,

    m.account_cnt,
    m.sent_msg,
    m.open_msg,
    m.visit_msg,

    c.total_accounts,
    c.total_sent,

    c.rank_accounts,
    c.rank_sent

FROM merged_data m

LEFT JOIN country_rank c
ON m.country = c.country

WHERE c.rank_accounts <= 10
   OR c.rank_sent <= 10

ORDER BY m.data_account DESC;