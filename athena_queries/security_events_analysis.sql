-- Security Events Analysis Queries
-- Requirements: 1.5 (security events tracking authentication attempts and permission changes)

-- 1. Authentication Events Overview
-- Cost Optimization: Uses partition pruning and focuses on security-relevant services
SELECT 
    service,
    COUNT(*) as total_auth_events,
    COUNT(CASE WHEN message LIKE '%login_success%' OR message LIKE '%authenticated%' THEN 1 END) as successful_logins,
    COUNT(CASE WHEN message LIKE '%login_failed%' OR message LIKE '%authentication_failed%' THEN 1 END) as failed_logins,
    COUNT(CASE WHEN message LIKE '%logout%' OR message LIKE '%session_end%' THEN 1 END) as logout_events,
    COUNT(DISTINCT metadata.user_id) as unique_users_involved,
    COUNT(DISTINCT metadata.ip_address) as unique_ip_addresses,
    ROUND(
        (COUNT(CASE WHEN message LIKE '%login_failed%' OR message LIKE '%authentication_failed%' THEN 1 END) * 100.0) / 
        NULLIF(COUNT(CASE WHEN message LIKE '%login%' OR message LIKE '%authentication%' THEN 1 END), 0), 2
    ) as auth_failure_rate_percent
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09'
    AND service IN ('cognito', 'apigateway', 'auth-service')
    AND category = 'security'
GROUP BY service
ORDER BY total_auth_events DESC;

-- 2. Suspicious Authentication Patterns
-- Cost Optimization: Uses specific filtering and LIMIT to reduce data scanned
SELECT 
    metadata.ip_address,
    metadata.user_id,
    COUNT(*) as total_attempts,
    COUNT(CASE WHEN message LIKE '%login_failed%' OR message LIKE '%authentication_failed%' THEN 1 END) as failed_attempts,
    COUNT(CASE WHEN message LIKE '%login_success%' OR message LIKE '%authenticated%' THEN 1 END) as successful_attempts,
    MIN(timestamp) as first_attempt,
    MAX(timestamp) as last_attempt,
    COUNT(DISTINCT metadata.user_agent) as different_user_agents,
    ARRAY_AGG(DISTINCT SUBSTR(metadata.user_agent, 1, 50)) as user_agent_samples
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09'
    AND service IN ('cognito', 'apigateway')
    AND category = 'security'
    AND (message LIKE '%login%' OR message LIKE '%authentication%')
GROUP BY metadata.ip_address, metadata.user_id
HAVING COUNT(CASE WHEN message LIKE '%login_failed%' OR message LIKE '%authentication_failed%' THEN 1 END) >= 5
    OR COUNT(DISTINCT metadata.user_agent) >= 3
ORDER BY failed_attempts DESC, different_user_agents DESC
LIMIT 50;

-- 3. Permission Changes and Authorization Events
-- Cost Optimization: Filters to specific event types with partition pruning
SELECT 
    service,
    EXTRACT(hour FROM CAST(timestamp AS timestamp)) as hour_of_day,
    COUNT(*) as permission_events,
    COUNT(CASE WHEN message LIKE '%permission_granted%' OR message LIKE '%access_granted%' THEN 1 END) as permissions_granted,
    COUNT(CASE WHEN message LIKE '%permission_denied%' OR message LIKE '%access_denied%' THEN 1 END) as permissions_denied,
    COUNT(CASE WHEN message LIKE '%role_change%' OR message LIKE '%privilege_change%' THEN 1 END) as role_changes,
    COUNT(DISTINCT metadata.user_id) as users_affected,
    ARRAY_AGG(DISTINCT 
        CASE 
            WHEN message LIKE '%admin%' THEN 'admin_action'
            WHEN message LIKE '%user%' THEN 'user_action'
            WHEN message LIKE '%system%' THEN 'system_action'
        END
    ) as action_types
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09'
    AND category = 'security'
    AND (message LIKE '%permission%' OR message LIKE '%access%' OR message LIKE '%role%' OR message LIKE '%privilege%')
GROUP BY service, EXTRACT(hour FROM CAST(timestamp AS timestamp))
ORDER BY service, hour_of_day;

-- 4. Brute Force Attack Detection
-- Cost Optimization: Uses time-based windowing with specific IP analysis
WITH failed_login_attempts AS (
    SELECT 
        metadata.ip_address,
        metadata.user_id,
        timestamp,
        message,
        LAG(timestamp) OVER (
            PARTITION BY metadata.ip_address, metadata.user_id 
            ORDER BY timestamp
        ) as prev_attempt_time
    FROM streaming_logs
    WHERE year = '2024' 
        AND month = '10' 
        AND day = '09'
        AND service IN ('cognito', 'apigateway')
        AND category = 'security'
        AND (message LIKE '%login_failed%' OR message LIKE '%authentication_failed%')
),
rapid_attempts AS (
    SELECT 
        metadata.ip_address,
        metadata.user_id,
        COUNT(*) as attempts_in_window,
        MIN(timestamp) as attack_start,
        MAX(timestamp) as attack_end,
        ARRAY_AGG(DISTINCT SUBSTR(message, 1, 100)) as attack_patterns
    FROM failed_login_attempts
    WHERE prev_attempt_time IS NULL 
        OR CAST(timestamp AS timestamp) - CAST(prev_attempt_time AS timestamp) <= INTERVAL '5' MINUTE
    GROUP BY metadata.ip_address, metadata.user_id
    HAVING COUNT(*) >= 10  -- 10+ failed attempts in rapid succession
)
SELECT 
    metadata.ip_address,
    metadata.user_id,
    attempts_in_window,
    attack_start,
    attack_end,
    ROUND(
        CAST(attack_end AS timestamp) - CAST(attack_start AS timestamp), 2
    ) as attack_duration_seconds,
    attack_patterns,
    'POTENTIAL_BRUTE_FORCE' as threat_classification
FROM rapid_attempts
ORDER BY attempts_in_window DESC, attack_duration_seconds ASC
LIMIT 25;

-- 5. Anomalous Access Patterns
-- Cost Optimization: Uses statistical analysis with partition pruning
WITH user_access_baseline AS (
    SELECT 
        metadata.user_id,
        COUNT(*) as total_access_events,
        COUNT(DISTINCT metadata.ip_address) as unique_ips,
        COUNT(DISTINCT EXTRACT(hour FROM CAST(timestamp AS timestamp))) as active_hours,
        MODE() WITHIN GROUP (ORDER BY metadata.ip_address) as most_common_ip,
        ARRAY_AGG(DISTINCT metadata.ip_address) as all_ips_used
    FROM streaming_logs
    WHERE year = '2024' 
        AND month = '10' 
        AND day BETWEEN '07' AND '09'  -- 3-day baseline
        AND category = 'security'
        AND metadata.user_id IS NOT NULL
    GROUP BY metadata.user_id
),
current_day_access AS (
    SELECT 
        metadata.user_id,
        COUNT(*) as today_access_events,
        COUNT(DISTINCT metadata.ip_address) as today_unique_ips,
        ARRAY_AGG(DISTINCT metadata.ip_address) as today_ips_used
    FROM streaming_logs
    WHERE year = '2024' 
        AND month = '10' 
        AND day = '09'
        AND category = 'security'
        AND metadata.user_id IS NOT NULL
    GROUP BY metadata.user_id
)
SELECT 
    b.metadata.user_id,
    b.total_access_events as baseline_events,
    b.unique_ips as baseline_unique_ips,
    c.today_access_events,
    c.today_unique_ips,
    b.most_common_ip,
    c.today_ips_used,
    CASE 
        WHEN c.today_unique_ips > b.unique_ips * 2 THEN 'UNUSUAL_IP_DIVERSITY'
        WHEN c.today_access_events > b.total_access_events * 3 THEN 'UNUSUAL_ACTIVITY_VOLUME'
        WHEN NOT EXISTS (
            SELECT 1 FROM UNNEST(c.today_ips_used) AS ip 
            WHERE ip = b.most_common_ip
        ) THEN 'NEW_IP_ONLY_ACCESS'
        ELSE 'NORMAL'
    END as anomaly_type
FROM user_access_baseline b
JOIN current_day_access c ON b.metadata.user_id = c.metadata.user_id
WHERE c.today_unique_ips > b.unique_ips * 1.5  -- 50% more IPs than baseline
    OR c.today_access_events > b.total_access_events * 2  -- 2x more activity
ORDER BY c.today_unique_ips DESC, c.today_access_events DESC
LIMIT 30;

-- 6. Security Event Timeline Analysis
-- Cost Optimization: Uses time-based aggregation with security focus
SELECT 
    DATE_TRUNC('hour', CAST(timestamp AS timestamp)) as event_hour,
    service,
    COUNT(*) as security_events,
    COUNT(CASE WHEN level = 'error' THEN 1 END) as security_errors,
    COUNT(CASE WHEN message LIKE '%login_failed%' THEN 1 END) as failed_logins,
    COUNT(CASE WHEN message LIKE '%permission_denied%' THEN 1 END) as access_denials,
    COUNT(CASE WHEN message LIKE '%suspicious%' OR message LIKE '%anomaly%' THEN 1 END) as suspicious_events,
    COUNT(DISTINCT metadata.user_id) as users_involved,
    COUNT(DISTINCT metadata.ip_address) as ip_addresses_involved
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09'
    AND category = 'security'
GROUP BY DATE_TRUNC('hour', CAST(timestamp AS timestamp)), service
ORDER BY event_hour, service;

-- 7. Cross-Service Security Correlation
-- Cost Optimization: Joins security events across services with time correlation
WITH security_events_enriched AS (
    SELECT 
        timestamp,
        service,
        metadata.user_id,
        metadata.session_id,
        metadata.ip_address,
        message,
        CASE 
            WHEN message LIKE '%login_failed%' OR message LIKE '%authentication_failed%' THEN 'AUTH_FAILURE'
            WHEN message LIKE '%permission_denied%' OR message LIKE '%access_denied%' THEN 'ACCESS_DENIED'
            WHEN message LIKE '%suspicious%' THEN 'SUSPICIOUS_ACTIVITY'
            WHEN message LIKE '%role_change%' THEN 'PRIVILEGE_CHANGE'
            ELSE 'OTHER_SECURITY'
        END as event_type
    FROM streaming_logs
    WHERE year = '2024' 
        AND month = '10' 
        AND day = '09'
        AND category = 'security'
        AND metadata.user_id IS NOT NULL
)
SELECT 
    s1.metadata.user_id,
    s1.service as primary_service,
    s2.service as secondary_service,
    s1.event_type as primary_event,
    s2.event_type as secondary_event,
    COUNT(*) as correlated_events,
    AVG(CAST(s2.timestamp AS timestamp) - CAST(s1.timestamp AS timestamp)) as avg_time_between_events_seconds,
    MIN(s1.timestamp) as first_occurrence,
    MAX(s2.timestamp) as last_occurrence
FROM security_events_enriched s1
JOIN security_events_enriched s2 
    ON s1.metadata.user_id = s2.metadata.user_id
    AND s1.service != s2.service
    AND CAST(s2.timestamp AS timestamp) > CAST(s1.timestamp AS timestamp)
    AND CAST(s2.timestamp AS timestamp) - CAST(s1.timestamp AS timestamp) <= INTERVAL '10' MINUTE
GROUP BY s1.metadata.user_id, s1.service, s2.service, s1.event_type, s2.event_type
HAVING COUNT(*) >= 2  -- At least 2 correlated events
ORDER BY correlated_events DESC, avg_time_between_events_seconds ASC
LIMIT 25;