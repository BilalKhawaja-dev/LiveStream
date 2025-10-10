-- User Activity Analysis Queries
-- Requirements: 1.7 (user activity tracking stream starts/stops and payment events)

-- 1. Daily Active Users and Stream Activity
-- Cost Optimization: Uses partition pruning and COUNT DISTINCT for user metrics
SELECT 
    service,
    COUNT(DISTINCT metadata.user_id) as daily_active_users,
    COUNT(*) as total_events,
    COUNT(CASE WHEN message LIKE '%stream_start%' THEN 1 END) as stream_starts,
    COUNT(CASE WHEN message LIKE '%stream_stop%' THEN 1 END) as stream_stops,
    COUNT(CASE WHEN message LIKE '%payment%' THEN 1 END) as payment_events,
    ROUND(
        COUNT(CASE WHEN message LIKE '%stream_start%' THEN 1 END) * 1.0 / 
        NULLIF(COUNT(DISTINCT metadata.user_id), 0), 2
    ) as avg_streams_per_user
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09'
    AND metadata.user_id IS NOT NULL
    AND service IN ('medialive', 'mediastore', 'apigateway', 'payment')
GROUP BY service
ORDER BY daily_active_users DESC;

-- 2. User Session Analysis
-- Cost Optimization: Uses session-based grouping with partition pruning
WITH user_sessions AS (
    SELECT 
        metadata.user_id,
        metadata.session_id,
        service,
        MIN(timestamp) as session_start,
        MAX(timestamp) as session_end,
        COUNT(*) as events_in_session,
        COUNT(CASE WHEN message LIKE '%stream_start%' THEN 1 END) as streams_started,
        COUNT(CASE WHEN message LIKE '%payment%' THEN 1 END) as payments_made
    FROM streaming_logs
    WHERE year = '2024' 
        AND month = '10' 
        AND day = '09'
        AND metadata.user_id IS NOT NULL
        AND metadata.session_id IS NOT NULL
    GROUP BY metadata.user_id, metadata.session_id, service
)
SELECT 
    service,
    COUNT(*) as total_sessions,
    COUNT(DISTINCT metadata.user_id) as unique_users,
    ROUND(AVG(events_in_session), 2) as avg_events_per_session,
    ROUND(AVG(streams_started), 2) as avg_streams_per_session,
    ROUND(AVG(payments_made), 2) as avg_payments_per_session,
    ROUND(
        AVG(
            CAST(session_end AS timestamp) - CAST(session_start AS timestamp)
        ) / 60, 2
    ) as avg_session_duration_minutes
FROM user_sessions
WHERE events_in_session >= 3  -- Filter out very short sessions
GROUP BY service
ORDER BY total_sessions DESC;

-- 3. Stream Engagement Patterns
-- Cost Optimization: Focuses on streaming-specific services with time-based analysis
SELECT 
    EXTRACT(hour FROM CAST(timestamp AS timestamp)) as hour_of_day,
    COUNT(CASE WHEN message LIKE '%stream_start%' THEN 1 END) as stream_starts,
    COUNT(CASE WHEN message LIKE '%stream_stop%' THEN 1 END) as stream_stops,
    COUNT(DISTINCT metadata.user_id) as active_streamers,
    ROUND(
        AVG(CASE 
            WHEN message LIKE '%duration%' 
            THEN CAST(REGEXP_EXTRACT(message, 'duration:(\d+)', 1) AS bigint)
        END), 2
    ) as avg_stream_duration_minutes
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09'
    AND service IN ('medialive', 'mediastore')
    AND metadata.user_id IS NOT NULL
GROUP BY EXTRACT(hour FROM CAST(timestamp AS timestamp))
ORDER BY hour_of_day;

-- 4. Payment Event Analysis
-- Cost Optimization: Filters to payment-specific events and uses aggregation
SELECT 
    EXTRACT(hour FROM CAST(timestamp AS timestamp)) as hour_of_day,
    COUNT(*) as total_payment_events,
    COUNT(DISTINCT metadata.user_id) as unique_paying_users,
    COUNT(CASE WHEN message LIKE '%success%' THEN 1 END) as successful_payments,
    COUNT(CASE WHEN message LIKE '%failed%' OR message LIKE '%error%' THEN 1 END) as failed_payments,
    ROUND(
        (COUNT(CASE WHEN message LIKE '%success%' THEN 1 END) * 100.0) / COUNT(*), 2
    ) as payment_success_rate_percent,
    ROUND(
        AVG(CASE 
            WHEN message LIKE '%amount%' 
            THEN CAST(REGEXP_EXTRACT(message, 'amount:([0-9.]+)', 1) AS double)
        END), 2
    ) as avg_payment_amount
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09'
    AND service = 'payment'
    AND message LIKE '%payment%'
GROUP BY EXTRACT(hour FROM CAST(timestamp AS timestamp))
ORDER BY hour_of_day;

-- 5. User Behavior Cohort Analysis
-- Cost Optimization: Uses window functions efficiently with user segmentation
WITH user_activity_summary AS (
    SELECT 
        metadata.user_id,
        MIN(timestamp) as first_activity,
        MAX(timestamp) as last_activity,
        COUNT(*) as total_events,
        COUNT(CASE WHEN message LIKE '%stream_start%' THEN 1 END) as total_streams,
        COUNT(CASE WHEN message LIKE '%payment%' THEN 1 END) as total_payments,
        COUNT(DISTINCT metadata.session_id) as total_sessions
    FROM streaming_logs
    WHERE year = '2024' 
        AND month = '10' 
        AND day BETWEEN '07' AND '09'  -- 3-day cohort window
        AND metadata.user_id IS NOT NULL
    GROUP BY metadata.user_id
),
user_segments AS (
    SELECT 
        *,
        CASE 
            WHEN total_streams = 0 THEN 'Non-Streamer'
            WHEN total_streams <= 5 THEN 'Light Streamer'
            WHEN total_streams <= 20 THEN 'Regular Streamer'
            ELSE 'Heavy Streamer'
        END as streamer_segment,
        CASE 
            WHEN total_payments = 0 THEN 'Free User'
            WHEN total_payments <= 2 THEN 'Occasional Buyer'
            ELSE 'Frequent Buyer'
        END as payment_segment
    FROM user_activity_summary
)
SELECT 
    streamer_segment,
    payment_segment,
    COUNT(*) as user_count,
    ROUND(AVG(total_events), 2) as avg_events_per_user,
    ROUND(AVG(total_streams), 2) as avg_streams_per_user,
    ROUND(AVG(total_payments), 2) as avg_payments_per_user,
    ROUND(AVG(total_sessions), 2) as avg_sessions_per_user,
    ROUND(
        AVG(
            CAST(last_activity AS timestamp) - CAST(first_activity AS timestamp)
        ) / 3600, 2
    ) as avg_engagement_duration_hours
FROM user_segments
GROUP BY streamer_segment, payment_segment
ORDER BY user_count DESC;

-- 6. Geographic User Activity (if IP geolocation data available)
-- Cost Optimization: Uses IP-based analysis with aggregation
WITH ip_activity AS (
    SELECT 
        SUBSTR(metadata.ip_address, 1, 
            CASE 
                WHEN POSITION('.' IN metadata.ip_address) > 0 
                THEN POSITION('.' IN REVERSE(SUBSTR(metadata.ip_address, 1, 
                    POSITION('.' IN REVERSE(metadata.ip_address)) - 1))) - 1
                ELSE LENGTH(metadata.ip_address)
            END
        ) as ip_prefix,  -- Approximate geographic grouping
        COUNT(DISTINCT metadata.user_id) as unique_users,
        COUNT(*) as total_events,
        COUNT(CASE WHEN message LIKE '%stream_start%' THEN 1 END) as stream_events,
        COUNT(CASE WHEN message LIKE '%payment%' THEN 1 END) as payment_events
    FROM streaming_logs
    WHERE year = '2024' 
        AND month = '10' 
        AND day = '09'
        AND metadata.ip_address IS NOT NULL
        AND metadata.ip_address != ''
    GROUP BY SUBSTR(metadata.ip_address, 1, 
        CASE 
            WHEN POSITION('.' IN metadata.ip_address) > 0 
            THEN POSITION('.' IN REVERSE(SUBSTR(metadata.ip_address, 1, 
                POSITION('.' IN REVERSE(metadata.ip_address)) - 1))) - 1
            ELSE LENGTH(metadata.ip_address)
        END
    )
)
SELECT 
    ip_prefix,
    unique_users,
    total_events,
    stream_events,
    payment_events,
    ROUND((stream_events * 100.0) / NULLIF(total_events, 0), 2) as stream_event_percentage,
    ROUND((payment_events * 100.0) / NULLIF(total_events, 0), 2) as payment_event_percentage
FROM ip_activity
WHERE unique_users >= 10  -- Filter for significant user bases
ORDER BY unique_users DESC
LIMIT 20;

-- 7. User Retention Analysis (Multi-day Activity)
-- Cost Optimization: Uses date-based partitioning across multiple days
WITH daily_users AS (
    SELECT 
        day,
        metadata.user_id,
        COUNT(*) as daily_events
    FROM streaming_logs
    WHERE year = '2024' 
        AND month = '10' 
        AND day BETWEEN '07' AND '09'  -- 3-day retention window
        AND metadata.user_id IS NOT NULL
    GROUP BY day, metadata.user_id
),
user_retention AS (
    SELECT 
        u1.user_id,
        u1.day as day1,
        u2.day as day2,
        u3.day as day3
    FROM (SELECT DISTINCT user_id, day FROM daily_users WHERE day = '07') u1
    LEFT JOIN (SELECT DISTINCT user_id, day FROM daily_users WHERE day = '08') u2
        ON u1.user_id = u2.user_id
    LEFT JOIN (SELECT DISTINCT user_id, day FROM daily_users WHERE day = '09') u3
        ON u1.user_id = u3.user_id
)
SELECT 
    'Day 1 (2024-10-07)' as cohort_day,
    COUNT(*) as total_users,
    COUNT(day2) as retained_day2,
    COUNT(day3) as retained_day3,
    ROUND((COUNT(day2) * 100.0) / COUNT(*), 2) as day2_retention_percent,
    ROUND((COUNT(day3) * 100.0) / COUNT(*), 2) as day3_retention_percent
FROM user_retention;