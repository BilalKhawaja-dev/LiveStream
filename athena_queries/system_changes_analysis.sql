-- System Changes Analysis Queries
-- Requirements: 1.8 (system changes recording configuration updates and deployments)

-- 1. Deployment and Configuration Change Overview
-- Cost Optimization: Uses partition pruning and focuses on system change events
SELECT 
    service,
    COUNT(*) as total_system_events,
    COUNT(CASE WHEN message LIKE '%deployment%' OR message LIKE '%deploy%' THEN 1 END) as deployment_events,
    COUNT(CASE WHEN message LIKE '%configuration%' OR message LIKE '%config%' THEN 1 END) as config_changes,
    COUNT(CASE WHEN message LIKE '%update%' OR message LIKE '%upgrade%' THEN 1 END) as update_events,
    COUNT(CASE WHEN message LIKE '%rollback%' OR message LIKE '%revert%' THEN 1 END) as rollback_events,
    COUNT(CASE WHEN level = 'error' THEN 1 END) as failed_changes,
    COUNT(DISTINCT metadata.user_id) as users_making_changes,
    ROUND(
        (COUNT(CASE WHEN level = 'error' THEN 1 END) * 100.0) / COUNT(*), 2
    ) as change_failure_rate_percent
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09'
    AND category = 'system-changes'
GROUP BY service
ORDER BY total_system_events DESC;

-- 2. Deployment Timeline and Success Rate
-- Cost Optimization: Uses time-based aggregation with deployment focus
SELECT 
    service,
    EXTRACT(hour FROM CAST(timestamp AS timestamp)) as deployment_hour,
    COUNT(*) as deployment_attempts,
    COUNT(CASE WHEN message LIKE '%success%' OR message LIKE '%completed%' THEN 1 END) as successful_deployments,
    COUNT(CASE WHEN message LIKE '%failed%' OR message LIKE '%error%' OR level = 'error' THEN 1 END) as failed_deployments,
    COUNT(CASE WHEN message LIKE '%rollback%' THEN 1 END) as rollbacks_triggered,
    ROUND(
        (COUNT(CASE WHEN message LIKE '%success%' OR message LIKE '%completed%' THEN 1 END) * 100.0) / COUNT(*), 2
    ) as deployment_success_rate_percent,
    ARRAY_AGG(DISTINCT 
        CASE 
            WHEN message LIKE '%version%' THEN REGEXP_EXTRACT(message, 'version[:\s]+([^\s,]+)', 1)
            WHEN message LIKE '%build%' THEN REGEXP_EXTRACT(message, 'build[:\s]+([^\s,]+)', 1)
        END
    ) as versions_deployed
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09'
    AND category = 'system-changes'
    AND (message LIKE '%deployment%' OR message LIKE '%deploy%')
GROUP BY service, EXTRACT(hour FROM CAST(timestamp AS timestamp))
ORDER BY service, deployment_hour;

-- 3. Configuration Change Impact Analysis
-- Cost Optimization: Correlates config changes with system performance
WITH config_changes AS (
    SELECT 
        service,
        timestamp as change_time,
        message as change_description,
        metadata.user_id as changed_by,
        CASE 
            WHEN message LIKE '%database%' THEN 'DATABASE_CONFIG'
            WHEN message LIKE '%network%' OR message LIKE '%vpc%' THEN 'NETWORK_CONFIG'
            WHEN message LIKE '%security%' OR message LIKE '%iam%' THEN 'SECURITY_CONFIG'
            WHEN message LIKE '%scaling%' OR message LIKE '%capacity%' THEN 'SCALING_CONFIG'
            WHEN message LIKE '%monitoring%' THEN 'MONITORING_CONFIG'
            ELSE 'OTHER_CONFIG'
        END as config_type
    FROM streaming_logs
    WHERE year = '2024' 
        AND month = '10' 
        AND day = '09'
        AND category = 'system-changes'
        AND (message LIKE '%configuration%' OR message LIKE '%config%')
),
post_change_errors AS (
    SELECT 
        service,
        timestamp as error_time,
        level,
        message as error_message
    FROM streaming_logs
    WHERE year = '2024' 
        AND month = '10' 
        AND day = '09'
        AND level = 'error'
)
SELECT 
    c.service,
    c.config_type,
    COUNT(*) as config_changes_count,
    COUNT(DISTINCT c.changed_by) as users_making_changes,
    COUNT(e.error_time) as errors_within_1hour,
    ROUND(
        (COUNT(e.error_time) * 100.0) / COUNT(*), 2
    ) as error_rate_post_change_percent,
    ARRAY_AGG(DISTINCT SUBSTR(c.change_description, 1, 100)) as change_samples,
    ARRAY_AGG(DISTINCT SUBSTR(e.error_message, 1, 100)) as related_errors
FROM config_changes c
LEFT JOIN post_change_errors e 
    ON c.service = e.service
    AND CAST(e.error_time AS timestamp) > CAST(c.change_time AS timestamp)
    AND CAST(e.error_time AS timestamp) <= CAST(c.change_time AS timestamp) + INTERVAL '1' HOUR
GROUP BY c.service, c.config_type
ORDER BY config_changes_count DESC, error_rate_post_change_percent DESC;

-- 4. System Update and Maintenance Windows
-- Cost Optimization: Analyzes maintenance patterns with time-based grouping
SELECT 
    service,
    DATE_TRUNC('hour', CAST(timestamp AS timestamp)) as maintenance_window,
    COUNT(*) as maintenance_events,
    COUNT(CASE WHEN message LIKE '%update%' OR message LIKE '%upgrade%' THEN 1 END) as updates,
    COUNT(CASE WHEN message LIKE '%patch%' THEN 1 END) as patches,
    COUNT(CASE WHEN message LIKE '%restart%' OR message LIKE '%reboot%' THEN 1 END) as restarts,
    COUNT(CASE WHEN message LIKE '%backup%' THEN 1 END) as backup_operations,
    COUNT(CASE WHEN level = 'error' THEN 1 END) as maintenance_errors,
    AVG(CASE 
        WHEN message LIKE '%duration%' 
        THEN CAST(REGEXP_EXTRACT(message, 'duration[:\s]+(\d+)', 1) AS bigint)
    END) as avg_maintenance_duration_minutes,
    ARRAY_AGG(DISTINCT 
        CASE 
            WHEN message LIKE '%downtime%' THEN 'DOWNTIME_REQUIRED'
            WHEN message LIKE '%rolling%' THEN 'ROLLING_UPDATE'
            WHEN message LIKE '%blue-green%' THEN 'BLUE_GREEN_DEPLOYMENT'
            WHEN message LIKE '%canary%' THEN 'CANARY_DEPLOYMENT'
        END
    ) as deployment_strategies
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09'
    AND category = 'system-changes'
    AND (message LIKE '%maintenance%' OR message LIKE '%update%' OR message LIKE '%patch%')
GROUP BY service, DATE_TRUNC('hour', CAST(timestamp AS timestamp))
HAVING COUNT(*) >= 3  -- Significant maintenance activity
ORDER BY service, maintenance_window;

-- 5. Change Approval and Audit Trail
-- Cost Optimization: Tracks change management process with user attribution
SELECT 
    service,
    metadata.user_id as change_initiator,
    COUNT(*) as total_changes_initiated,
    COUNT(CASE WHEN message LIKE '%approved%' THEN 1 END) as approved_changes,
    COUNT(CASE WHEN message LIKE '%rejected%' OR message LIKE '%denied%' THEN 1 END) as rejected_changes,
    COUNT(CASE WHEN message LIKE '%emergency%' OR message LIKE '%hotfix%' THEN 1 END) as emergency_changes,
    COUNT(CASE WHEN message LIKE '%scheduled%' THEN 1 END) as scheduled_changes,
    ROUND(
        (COUNT(CASE WHEN message LIKE '%approved%' THEN 1 END) * 100.0) / 
        NULLIF(COUNT(CASE WHEN message LIKE '%approved%' OR message LIKE '%rejected%' THEN 1 END), 0), 2
    ) as approval_rate_percent,
    MIN(timestamp) as first_change_time,
    MAX(timestamp) as last_change_time,
    ARRAY_AGG(DISTINCT 
        CASE 
            WHEN message LIKE '%critical%' THEN 'CRITICAL'
            WHEN message LIKE '%high%' THEN 'HIGH'
            WHEN message LIKE '%medium%' THEN 'MEDIUM'
            WHEN message LIKE '%low%' THEN 'LOW'
        END
    ) as change_priorities
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09'
    AND category = 'system-changes'
    AND metadata.user_id IS NOT NULL
    AND (message LIKE '%change%' OR message LIKE '%approval%' OR message LIKE '%request%')
GROUP BY service, metadata.user_id
ORDER BY total_changes_initiated DESC;

-- 6. Infrastructure Scaling Events
-- Cost Optimization: Analyzes auto-scaling and capacity changes
SELECT 
    service,
    EXTRACT(hour FROM CAST(timestamp AS timestamp)) as scaling_hour,
    COUNT(*) as scaling_events,
    COUNT(CASE WHEN message LIKE '%scale_up%' OR message LIKE '%scale-up%' THEN 1 END) as scale_up_events,
    COUNT(CASE WHEN message LIKE '%scale_down%' OR message LIKE '%scale-down%' THEN 1 END) as scale_down_events,
    COUNT(CASE WHEN message LIKE '%auto%' THEN 1 END) as auto_scaling_events,
    COUNT(CASE WHEN message LIKE '%manual%' THEN 1 END) as manual_scaling_events,
    AVG(CASE 
        WHEN message LIKE '%capacity%' 
        THEN CAST(REGEXP_EXTRACT(message, 'capacity[:\s]+(\d+)', 1) AS bigint)
    END) as avg_target_capacity,
    AVG(CASE 
        WHEN message LIKE '%instances%' 
        THEN CAST(REGEXP_EXTRACT(message, 'instances[:\s]+(\d+)', 1) AS bigint)
    END) as avg_instance_count,
    ARRAY_AGG(DISTINCT 
        CASE 
            WHEN message LIKE '%cpu%' THEN 'CPU_TRIGGER'
            WHEN message LIKE '%memory%' THEN 'MEMORY_TRIGGER'
            WHEN message LIKE '%load%' THEN 'LOAD_TRIGGER'
            WHEN message LIKE '%schedule%' THEN 'SCHEDULED_TRIGGER'
        END
    ) as scaling_triggers
FROM streaming_logs
WHERE year = '2024' 
    AND month = '10' 
    AND day = '09'
    AND category = 'system-changes'
    AND (message LIKE '%scale%' OR message LIKE '%capacity%' OR message LIKE '%instances%')
GROUP BY service, EXTRACT(hour FROM CAST(timestamp AS timestamp))
ORDER BY service, scaling_hour;

-- 7. Change Rollback and Recovery Analysis
-- Cost Optimization: Analyzes failure recovery patterns
WITH change_events AS (
    SELECT 
        service,
        timestamp,
        message,
        metadata.user_id,
        CASE 
            WHEN message LIKE '%deployment%' THEN 'DEPLOYMENT'
            WHEN message LIKE '%configuration%' THEN 'CONFIGURATION'
            WHEN message LIKE '%update%' THEN 'UPDATE'
            ELSE 'OTHER'
        END as change_type,
        CASE 
            WHEN message LIKE '%rollback%' OR message LIKE '%revert%' THEN 'ROLLBACK'
            WHEN level = 'error' OR message LIKE '%failed%' THEN 'FAILURE'
            WHEN message LIKE '%success%' OR message LIKE '%completed%' THEN 'SUCCESS'
            ELSE 'IN_PROGRESS'
        END as change_status
    FROM streaming_logs
    WHERE year = '2024' 
        AND month = '10' 
        AND day = '09'
        AND category = 'system-changes'
),
rollback_analysis AS (
    SELECT 
        c1.service,
        c1.change_type,
        c1.timestamp as failure_time,
        c2.timestamp as rollback_time,
        c1.metadata.user_id as change_initiator,
        c2.metadata.user_id as rollback_initiator,
        CAST(c2.timestamp AS timestamp) - CAST(c1.timestamp AS timestamp) as time_to_rollback,
        c1.message as failure_reason,
        c2.message as rollback_action
    FROM change_events c1
    JOIN change_events c2 
        ON c1.service = c2.service
        AND c1.change_status = 'FAILURE'
        AND c2.change_status = 'ROLLBACK'
        AND CAST(c2.timestamp AS timestamp) > CAST(c1.timestamp AS timestamp)
        AND CAST(c2.timestamp AS timestamp) <= CAST(c1.timestamp AS timestamp) + INTERVAL '2' HOUR
)
SELECT 
    service,
    change_type,
    COUNT(*) as rollback_incidents,
    COUNT(DISTINCT change_initiator) as users_requiring_rollback,
    AVG(time_to_rollback) as avg_rollback_time_seconds,
    MIN(time_to_rollback) as fastest_rollback_seconds,
    MAX(time_to_rollback) as slowest_rollback_seconds,
    ARRAY_AGG(DISTINCT SUBSTR(failure_reason, 1, 100)) as common_failure_reasons,
    ROUND(
        (COUNT(*) * 100.0) / 
        (SELECT COUNT(*) FROM change_events WHERE service = rollback_analysis.service AND change_type = rollback_analysis.change_type), 2
    ) as rollback_rate_percent
FROM rollback_analysis
GROUP BY service, change_type
ORDER BY rollback_incidents DESC, avg_rollback_time_seconds DESC;