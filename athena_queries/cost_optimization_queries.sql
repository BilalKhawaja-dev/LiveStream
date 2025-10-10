-- Cost Optimization and Query Performance Analysis
-- Additional queries focused on cost management and query optimization techniques

-- 1. Data Volume and Storage Cost Analysis
-- Cost Optimization: Analyzes data patterns to optimize storage tiers
SELECT 
    service,
    year,
    month,
    day,
    COUNT(*) as log_events_count,
    ROUND(SUM(LENGTH(message)) / 1024.0 / 1024.0, 2) as estimated_size_mb,
    COUNT(CASE WHEN level = 'error' THEN 1 END) as error_events,
    COUNT(CASE WHEN level = 'warning' THEN 1 END) as warning_events,
    COUNT(CASE WHEN level = 'info' THEN 1 END) as info_events,
    COUNT(CASE WHEN level = 'debug' THEN 1 END) as debug_events,
    ROUND(
        (COUNT(CASE WHEN level IN ('error', 'warning') THEN 1 END) * 100.0) / COUNT(*), 2
    ) as critical_log_percentage
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day BETWEEN '07' AND '09'  -- 3-day analysis
GROUP BY service, year, month, day
ORDER BY estimated_size_mb DESC, service, year, month, day;

-- 2. Query Performance Optimization - Partition Effectiveness
-- Cost Optimization: Validates partition pruning effectiveness
SELECT 
    'Partition Analysis' as analysis_type,
    COUNT(*) as total_records,
    COUNT(DISTINCT year) as unique_years,
    COUNT(DISTINCT month) as unique_months,
    COUNT(DISTINCT day) as unique_days,
    COUNT(DISTINCT hour) as unique_hours,
    COUNT(DISTINCT service) as unique_services,
    MIN(timestamp) as earliest_log,
    MAX(timestamp) as latest_log,
    ROUND(
        COUNT(*) / (COUNT(DISTINCT year) * COUNT(DISTINCT month) * COUNT(DISTINCT day) * COUNT(DISTINCT hour)), 2
    ) as avg_records_per_partition
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09';

-- 3. Log Level Distribution for Retention Optimization
-- Cost Optimization: Helps determine which log levels to retain longer
WITH log_level_stats AS (
    SELECT 
        service,
        level,
        COUNT(*) as event_count,
        ROUND(SUM(LENGTH(message)) / 1024.0 / 1024.0, 2) as size_mb,
        COUNT(DISTINCT metadata.user_id) as unique_users_affected,
        MIN(timestamp) as first_occurrence,
        MAX(timestamp) as last_occurrence
    FROM streaming_logs
    WHERE year = '2024' 
        AND month = '10' 
        AND day = '09'
    GROUP BY service, level
)
SELECT 
    service,
    level,
    event_count,
    size_mb,
    unique_users_affected,
    ROUND((event_count * 100.0) / SUM(event_count) OVER (PARTITION BY service), 2) as percentage_of_service_logs,
    ROUND((size_mb * 100.0) / SUM(size_mb) OVER (PARTITION BY service), 2) as percentage_of_service_size,
    CASE 
        WHEN level = 'error' THEN 'RETAIN_LONG'
        WHEN level = 'warning' THEN 'RETAIN_MEDIUM'
        WHEN level = 'info' AND unique_users_affected > 100 THEN 'RETAIN_MEDIUM'
        WHEN level = 'debug' THEN 'RETAIN_SHORT'
        ELSE 'RETAIN_STANDARD'
    END as retention_recommendation
FROM log_level_stats
ORDER BY service, event_count DESC;

-- 4. Columnar Storage Optimization Analysis
-- Cost Optimization: Identifies frequently queried columns for Parquet optimization
SELECT 
    'Column Usage Analysis' as analysis_type,
    COUNT(CASE WHEN timestamp IS NOT NULL THEN 1 END) as timestamp_usage,
    COUNT(CASE WHEN service IS NOT NULL THEN 1 END) as service_usage,
    COUNT(CASE WHEN category IS NOT NULL THEN 1 END) as category_usage,
    COUNT(CASE WHEN level IS NOT NULL THEN 1 END) as level_usage,
    COUNT(CASE WHEN message IS NOT NULL THEN 1 END) as message_usage,
    COUNT(CASE WHEN metadata.user_id IS NOT NULL THEN 1 END) as user_id_usage,
    COUNT(CASE WHEN metadata.session_id IS NOT NULL THEN 1 END) as session_id_usage,
    COUNT(CASE WHEN metadata.ip_address IS NOT NULL THEN 1 END) as ip_address_usage,
    COUNT(CASE WHEN metrics.latency_ms IS NOT NULL THEN 1 END) as latency_usage,
    COUNT(CASE WHEN metrics.memory_usage_mb IS NOT NULL THEN 1 END) as memory_usage,
    COUNT(CASE WHEN metrics.cpu_usage_percent IS NOT NULL THEN 1 END) as cpu_usage
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09';

-- 5. Query Result Caching Opportunities
-- Cost Optimization: Identifies common query patterns for caching
WITH query_patterns AS (
    SELECT 
        service,
        category,
        level,
        EXTRACT(hour FROM CAST(timestamp AS timestamp)) as query_hour,
        COUNT(*) as pattern_frequency
    FROM streaming_logs
    WHERE year = '2024' 
        AND month = '10' 
        AND day = '09'
    GROUP BY service, category, level, EXTRACT(hour FROM CAST(timestamp AS timestamp))
)
SELECT 
    service,
    category,
    level,
    COUNT(*) as hourly_patterns,
    SUM(pattern_frequency) as total_matching_records,
    ROUND(AVG(pattern_frequency), 2) as avg_records_per_hour,
    ROUND(STDDEV(pattern_frequency), 2) as pattern_consistency,
    CASE 
        WHEN COUNT(*) >= 20 AND STDDEV(pattern_frequency) < AVG(pattern_frequency) * 0.5 THEN 'HIGH_CACHE_VALUE'
        WHEN COUNT(*) >= 10 THEN 'MEDIUM_CACHE_VALUE'
        ELSE 'LOW_CACHE_VALUE'
    END as caching_recommendation
FROM query_patterns
GROUP BY service, category, level
HAVING COUNT(*) >= 5  -- At least 5 hours of data
ORDER BY total_matching_records DESC;

-- 6. Data Compression Effectiveness Analysis
-- Cost Optimization: Analyzes message content for compression opportunities
SELECT 
    service,
    category,
    COUNT(*) as message_count,
    ROUND(AVG(LENGTH(message)), 2) as avg_message_length,
    ROUND(MIN(LENGTH(message)), 2) as min_message_length,
    ROUND(MAX(LENGTH(message)), 2) as max_message_length,
    COUNT(DISTINCT message) as unique_messages,
    ROUND((COUNT(DISTINCT message) * 100.0) / COUNT(*), 2) as message_uniqueness_percent,
    ROUND(SUM(LENGTH(message)) / 1024.0 / 1024.0, 2) as total_size_mb,
    CASE 
        WHEN (COUNT(DISTINCT message) * 100.0) / COUNT(*) < 10 THEN 'HIGH_COMPRESSION_POTENTIAL'
        WHEN (COUNT(DISTINCT message) * 100.0) / COUNT(*) < 50 THEN 'MEDIUM_COMPRESSION_POTENTIAL'
        ELSE 'LOW_COMPRESSION_POTENTIAL'
    END as compression_potential
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09'
GROUP BY service, category
ORDER BY total_size_mb DESC;

-- 7. Cost-Effective Query Patterns Template
-- Cost Optimization: Template for writing cost-effective queries
SELECT 
    'Query Best Practices' as guidance_type,
    'Always include partition columns (year, month, day, hour) in WHERE clause' as rule_1,
    'Use specific date ranges instead of open-ended queries' as rule_2,
    'Select only required columns, avoid SELECT *' as rule_3,
    'Use LIMIT clause for exploratory queries' as rule_4,
    'Leverage aggregation to reduce result set size' as rule_5,
    'Use CASE statements for conditional logic instead of multiple queries' as rule_6,
    'Consider using APPROX functions for large datasets' as rule_7,
    'Use workgroup query limits to prevent runaway costs' as rule_8;

-- Example of cost-optimized query structure:
-- SELECT 
--     service,                          -- Specific columns only
--     COUNT(*) as event_count,          -- Aggregation reduces result size
--     APPROX_PERCENTILE(metrics.latency_ms, 0.95) as p95_latency  -- Approximate functions for large datasets
-- FROM streaming_logs
-- WHERE year = '2024'                   -- Partition pruning
--     AND month = '10'                  -- Partition pruning
--     AND day = '09'                    -- Partition pruning
--     AND hour BETWEEN '12' AND '14'    -- Specific time range
--     AND service IN ('medialive', 'mediastore')  -- Filter early
-- GROUP BY service                      -- Aggregation
-- ORDER BY event_count DESC
-- LIMIT 10;                            -- Limit result size