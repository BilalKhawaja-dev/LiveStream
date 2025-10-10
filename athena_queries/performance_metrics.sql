-- Performance Metrics Analysis Queries
-- Requirements: 1.6 (performance metrics capturing latency and resource usage data)

-- 1. Service Performance Overview (Last 24 Hours)
-- Cost Optimization: Uses partition pruning and aggregation to reduce data scanned
SELECT 
    service,
    COUNT(*) as total_requests,
    ROUND(AVG(metrics.latency_ms), 2) as avg_latency_ms,
    ROUND(PERCENTILE_APPROX(metrics.latency_ms, 0.50), 2) as p50_latency_ms,
    ROUND(PERCENTILE_APPROX(metrics.latency_ms, 0.95), 2) as p95_latency_ms,
    ROUND(PERCENTILE_APPROX(metrics.latency_ms, 0.99), 2) as p99_latency_ms,
    MAX(metrics.latency_ms) as max_latency_ms,
    ROUND(AVG(metrics.memory_usage_mb), 2) as avg_memory_mb,
    ROUND(AVG(metrics.cpu_usage_percent), 2) as avg_cpu_percent
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09'
    AND metrics.latency_ms IS NOT NULL
GROUP BY service
ORDER BY avg_latency_ms DESC;

-- 2. Performance Trends Over Time (Hourly Breakdown)
-- Cost Optimization: Limited time range with specific column selection
SELECT 
    service,
    year,
    month,
    day,
    hour,
    COUNT(*) as request_count,
    ROUND(AVG(metrics.latency_ms), 2) as avg_latency_ms,
    ROUND(PERCENTILE_APPROX(metrics.latency_ms, 0.95), 2) as p95_latency_ms,
    ROUND(AVG(metrics.memory_usage_mb), 2) as avg_memory_mb,
    ROUND(AVG(metrics.cpu_usage_percent), 2) as avg_cpu_percent
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day BETWEEN '07' AND '09'  -- 3-day window
    AND metrics.latency_ms IS NOT NULL
GROUP BY service, year, month, day, hour
ORDER BY year, month, day, hour, service;

-- 3. High Latency Requests Analysis
-- Cost Optimization: Uses LIMIT and specific filtering to reduce result size
SELECT 
    service,
    timestamp,
    metadata.request_id,
    metadata.user_id,
    metrics.latency_ms,
    metrics.memory_usage_mb,
    metrics.cpu_usage_percent,
    SUBSTR(message, 1, 200) as message_preview
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09'
    AND metrics.latency_ms > 5000  -- Requests over 5 seconds
ORDER BY metrics.latency_ms DESC
LIMIT 100;

-- 4. Resource Usage Patterns by Service
-- Cost Optimization: Aggregated data with partition pruning
SELECT 
    service,
    CASE 
        WHEN metrics.memory_usage_mb < 100 THEN 'Low (< 100MB)'
        WHEN metrics.memory_usage_mb < 500 THEN 'Medium (100-500MB)'
        WHEN metrics.memory_usage_mb < 1000 THEN 'High (500MB-1GB)'
        ELSE 'Very High (> 1GB)'
    END as memory_category,
    CASE 
        WHEN metrics.cpu_usage_percent < 25 THEN 'Low (< 25%)'
        WHEN metrics.cpu_usage_percent < 50 THEN 'Medium (25-50%)'
        WHEN metrics.cpu_usage_percent < 75 THEN 'High (50-75%)'
        ELSE 'Very High (> 75%)'
    END as cpu_category,
    COUNT(*) as request_count,
    ROUND(AVG(metrics.latency_ms), 2) as avg_latency_ms
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09'
    AND metrics.memory_usage_mb IS NOT NULL
    AND metrics.cpu_usage_percent IS NOT NULL
GROUP BY service, 
    CASE 
        WHEN metrics.memory_usage_mb < 100 THEN 'Low (< 100MB)'
        WHEN metrics.memory_usage_mb < 500 THEN 'Medium (100-500MB)'
        WHEN metrics.memory_usage_mb < 1000 THEN 'High (500MB-1GB)'
        ELSE 'Very High (> 1GB)'
    END,
    CASE 
        WHEN metrics.cpu_usage_percent < 25 THEN 'Low (< 25%)'
        WHEN metrics.cpu_usage_percent < 50 THEN 'Medium (25-50%)'
        WHEN metrics.cpu_usage_percent < 75 THEN 'High (50-75%)'
        ELSE 'Very High (> 75%)'
    END
ORDER BY service, memory_category, cpu_category;

-- 5. Performance Correlation Analysis
-- Cost Optimization: Uses sampling and specific time window
SELECT 
    service,
    CORR(metrics.latency_ms, metrics.memory_usage_mb) as latency_memory_correlation,
    CORR(metrics.latency_ms, metrics.cpu_usage_percent) as latency_cpu_correlation,
    CORR(metrics.memory_usage_mb, metrics.cpu_usage_percent) as memory_cpu_correlation,
    COUNT(*) as sample_size
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09'
    AND hour >= '12'  -- Focus on recent data
    AND metrics.latency_ms IS NOT NULL
    AND metrics.memory_usage_mb IS NOT NULL
    AND metrics.cpu_usage_percent IS NOT NULL
GROUP BY service
HAVING COUNT(*) >= 100  -- Ensure statistical significance
ORDER BY service;

-- 6. Service Performance Comparison (SLA Monitoring)
-- Cost Optimization: Pre-aggregated metrics with partition pruning
WITH performance_sla AS (
    SELECT 
        service,
        COUNT(*) as total_requests,
        COUNT(CASE WHEN metrics.latency_ms <= 1000 THEN 1 END) as requests_under_1s,
        COUNT(CASE WHEN metrics.latency_ms <= 3000 THEN 1 END) as requests_under_3s,
        COUNT(CASE WHEN metrics.latency_ms <= 5000 THEN 1 END) as requests_under_5s
    FROM streaming_logs
    WHERE year = '2024' 
        AND month = '10' 
        AND day = '09'
        AND metrics.latency_ms IS NOT NULL
    GROUP BY service
)
SELECT 
    service,
    total_requests,
    ROUND((requests_under_1s * 100.0) / total_requests, 2) as sla_1s_percent,
    ROUND((requests_under_3s * 100.0) / total_requests, 2) as sla_3s_percent,
    ROUND((requests_under_5s * 100.0) / total_requests, 2) as sla_5s_percent,
    CASE 
        WHEN (requests_under_3s * 100.0) / total_requests >= 95 THEN 'GOOD'
        WHEN (requests_under_3s * 100.0) / total_requests >= 90 THEN 'WARNING'
        ELSE 'CRITICAL'
    END as sla_status
FROM performance_sla
ORDER BY sla_3s_percent DESC;

-- 7. Peak Performance Analysis (Identify Performance Bottlenecks)
-- Cost Optimization: Uses window functions efficiently with partition pruning
WITH hourly_performance AS (
    SELECT 
        service,
        hour,
        COUNT(*) as requests_per_hour,
        AVG(metrics.latency_ms) as avg_latency,
        MAX(metrics.latency_ms) as max_latency,
        AVG(metrics.memory_usage_mb) as avg_memory,
        AVG(metrics.cpu_usage_percent) as avg_cpu
    FROM streaming_logs
    WHERE year = '2024' 
        AND month = '10' 
        AND day = '09'
        AND metrics.latency_ms IS NOT NULL
    GROUP BY service, hour
),
performance_ranking AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY service ORDER BY avg_latency DESC) as latency_rank,
        ROW_NUMBER() OVER (PARTITION BY service ORDER BY requests_per_hour DESC) as load_rank
    FROM hourly_performance
)
SELECT 
    service,
    hour,
    requests_per_hour,
    ROUND(avg_latency, 2) as avg_latency_ms,
    max_latency as max_latency_ms,
    ROUND(avg_memory, 2) as avg_memory_mb,
    ROUND(avg_cpu, 2) as avg_cpu_percent,
    CASE 
        WHEN latency_rank <= 3 THEN 'HIGH_LATENCY_HOUR'
        WHEN load_rank <= 3 THEN 'HIGH_LOAD_HOUR'
        ELSE 'NORMAL'
    END as performance_category
FROM performance_ranking
WHERE latency_rank <= 5 OR load_rank <= 5  -- Top 5 hours by latency or load
ORDER BY service, avg_latency DESC;