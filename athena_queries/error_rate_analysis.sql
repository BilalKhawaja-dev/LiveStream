-- Error Rate Analysis Queries
-- Requirements: 1.4 (application-level logs categorized as errors, warnings, or info)

-- 1. Overall Error Rate by Service (Last 24 Hours)
-- Cost Optimization: Uses partition pruning and specific column selection
SELECT 
    service,
    COUNT(*) as total_logs,
    COUNT(CASE WHEN level = 'error' THEN 1 END) as error_count,
    COUNT(CASE WHEN level = 'warning' THEN 1 END) as warning_count,
    ROUND(
        (COUNT(CASE WHEN level = 'error' THEN 1 END) * 100.0) / COUNT(*), 
        2
    ) as error_rate_percent,
    ROUND(
        (COUNT(CASE WHEN level = 'warning' THEN 1 END) * 100.0) / COUNT(*), 
        2
    ) as warning_rate_percent
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09'
    AND hour >= '00'  -- Adjust based on current time
GROUP BY service
ORDER BY error_rate_percent DESC;

-- 2. Error Trends Over Time (Hourly Breakdown)
-- Cost Optimization: Limited to specific date range with partition pruning
SELECT 
    service,
    year,
    month,
    day,
    hour,
    COUNT(CASE WHEN level = 'error' THEN 1 END) as error_count,
    COUNT(CASE WHEN level = 'warning' THEN 1 END) as warning_count,
    COUNT(*) as total_logs
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day BETWEEN '07' AND '09'  -- 3-day window
    AND level IN ('error', 'warning', 'info')
GROUP BY service, year, month, day, hour
ORDER BY year, month, day, hour, service;

-- 3. Top Error Messages by Frequency
-- Cost Optimization: Uses LIMIT to reduce result set size
SELECT 
    service,
    message,
    COUNT(*) as occurrence_count,
    MIN(timestamp) as first_seen,
    MAX(timestamp) as last_seen
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09'
    AND level = 'error'
GROUP BY service, message
ORDER BY occurrence_count DESC
LIMIT 50;

-- 4. Error Rate by User Activity (for user-facing services)
-- Cost Optimization: Filters to specific services and uses column pruning
SELECT 
    metadata.user_id,
    service,
    COUNT(*) as total_requests,
    COUNT(CASE WHEN level = 'error' THEN 1 END) as error_count,
    ROUND(
        (COUNT(CASE WHEN level = 'error' THEN 1 END) * 100.0) / COUNT(*), 
        2
    ) as user_error_rate_percent
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09'
    AND service IN ('apigateway', 'cognito', 'payment')
    AND metadata.user_id IS NOT NULL
GROUP BY metadata.user_id, service
HAVING COUNT(*) >= 10  -- Filter users with significant activity
ORDER BY user_error_rate_percent DESC
LIMIT 100;

-- 5. Critical Error Patterns (Cascading Failures)
-- Cost Optimization: Uses specific time window and service filtering
SELECT 
    DATE_TRUNC('minute', CAST(timestamp AS timestamp)) as minute_window,
    service,
    COUNT(*) as error_count,
    COUNT(DISTINCT metadata.request_id) as unique_requests_affected,
    ARRAY_AGG(DISTINCT SUBSTR(message, 1, 100)) as error_samples
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09'
    AND hour >= '12'  -- Focus on recent hours
    AND level = 'error'
GROUP BY DATE_TRUNC('minute', CAST(timestamp AS timestamp)), service
HAVING COUNT(*) >= 5  -- Identify error spikes
ORDER BY minute_window DESC, error_count DESC;

-- 6. Service Dependency Error Analysis
-- Cost Optimization: Joins on partition-pruned data
WITH service_errors AS (
    SELECT 
        service,
        metadata.request_id,
        timestamp,
        message,
        ROW_NUMBER() OVER (PARTITION BY metadata.request_id ORDER BY timestamp) as error_sequence
    FROM streaming_logs
    WHERE year = '2024' 
        AND month = '10' 
        AND day = '09'
        AND level = 'error'
        AND metadata.request_id IS NOT NULL
)
SELECT 
    s1.service as primary_service,
    s2.service as secondary_service,
    COUNT(*) as cascading_error_count,
    AVG(CAST(s2.timestamp AS timestamp) - CAST(s1.timestamp AS timestamp)) as avg_cascade_delay_seconds
FROM service_errors s1
JOIN service_errors s2 
    ON s1.metadata.request_id = s2.metadata.request_id
    AND s1.error_sequence < s2.error_sequence
    AND CAST(s2.timestamp AS timestamp) - CAST(s1.timestamp AS timestamp) <= INTERVAL '5' MINUTE
GROUP BY s1.service, s2.service
ORDER BY cascading_error_count DESC
LIMIT 20;