-- Database initialization script for streaming platform
-- This script creates the necessary tables and indexes for the application

-- Create database if it doesn't exist
CREATE DATABASE IF NOT EXISTS streaming_platform;
USE streaming_platform;

-- Users table for user profiles and authentication data
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY,
    cognito_id VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    display_name VARCHAR(255),
    role ENUM('viewer', 'creator', 'admin', 'support', 'analyst', 'developer') NOT NULL DEFAULT 'viewer',
    subscription_tier ENUM('bronze', 'silver', 'gold') NOT NULL DEFAULT 'bronze',
    subscription_status ENUM('active', 'cancelled', 'expired') NOT NULL DEFAULT 'active',
    subscription_renewal_date DATETIME,
    avatar_url VARCHAR(500),
    preferences JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    
    INDEX idx_cognito_id (cognito_id),
    INDEX idx_email (email),
    INDEX idx_username (username),
    INDEX idx_role (role),
    INDEX idx_subscription_tier (subscription_tier),
    INDEX idx_created_at (created_at)
);

-- Streams table for stream configuration and metadata
CREATE TABLE IF NOT EXISTS streams (
    id VARCHAR(36) PRIMARY KEY,
    creator_id VARCHAR(36) NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    status ENUM('scheduled', 'live', 'ended', 'cancelled') NOT NULL DEFAULT 'scheduled',
    media_live_channel_id VARCHAR(255),
    s3_media_prefix VARCHAR(500),
    scheduled_start DATETIME,
    actual_start DATETIME,
    end_time DATETIME,
    viewer_count INT DEFAULT 0,
    max_viewers INT DEFAULT 0,
    total_views INT DEFAULT 0,
    chat_enabled BOOLEAN DEFAULT TRUE,
    recording_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_creator_id (creator_id),
    INDEX idx_status (status),
    INDEX idx_category (category),
    INDEX idx_scheduled_start (scheduled_start),
    INDEX idx_created_at (created_at)
);

-- Support tickets table for customer service
CREATE TABLE IF NOT EXISTS support_tickets (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    creator_id VARCHAR(36),
    type ENUM('technical', 'billing', 'content', 'account', 'general') NOT NULL,
    priority ENUM('low', 'medium', 'high', 'urgent') NOT NULL DEFAULT 'medium',
    status ENUM('open', 'in_progress', 'resolved', 'closed') NOT NULL DEFAULT 'open',
    subject VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    assigned_to VARCHAR(36),
    context JSON,
    ai_suggestions JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP NULL,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_creator_id (creator_id),
    INDEX idx_type (type),
    INDEX idx_priority (priority),
    INDEX idx_status (status),
    INDEX idx_assigned_to (assigned_to),
    INDEX idx_created_at (created_at)
);

-- Stream analytics table for performance metrics
CREATE TABLE IF NOT EXISTS stream_analytics (
    id VARCHAR(36) PRIMARY KEY,
    stream_id VARCHAR(36) NOT NULL,
    metric_type ENUM('viewer_count', 'chat_activity', 'quality_metrics', 'engagement') NOT NULL,
    metric_value DECIMAL(10,2) NOT NULL,
    metadata JSON,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (stream_id) REFERENCES streams(id) ON DELETE CASCADE,
    INDEX idx_stream_id (stream_id),
    INDEX idx_metric_type (metric_type),
    INDEX idx_recorded_at (recorded_at)
);

-- Payment transactions table for billing and revenue tracking
CREATE TABLE IF NOT EXISTS payment_transactions (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    stripe_payment_intent_id VARCHAR(255) UNIQUE,
    stripe_subscription_id VARCHAR(255),
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'GBP',
    type ENUM('subscription', 'donation', 'refund') NOT NULL,
    status ENUM('pending', 'succeeded', 'failed', 'cancelled', 'refunded') NOT NULL,
    description TEXT,
    metadata JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_stripe_payment_intent_id (stripe_payment_intent_id),
    INDEX idx_stripe_subscription_id (stripe_subscription_id),
    INDEX idx_type (type),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
);

-- Content moderation table for AI-powered content review
CREATE TABLE IF NOT EXISTS content_moderation (
    id VARCHAR(36) PRIMARY KEY,
    content_type ENUM('stream', 'chat', 'profile', 'comment') NOT NULL,
    content_id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    moderation_service ENUM('rekognition', 'comprehend', 'manual') NOT NULL,
    confidence_score DECIMAL(5,4),
    flags JSON,
    status ENUM('approved', 'flagged', 'rejected', 'under_review') NOT NULL,
    reviewed_by VARCHAR(36),
    reviewed_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_content_type (content_type),
    INDEX idx_content_id (content_id),
    INDEX idx_user_id (user_id),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
);

-- System configuration table for application settings
CREATE TABLE IF NOT EXISTS system_config (
    id VARCHAR(36) PRIMARY KEY,
    config_key VARCHAR(255) UNIQUE NOT NULL,
    config_value JSON NOT NULL,
    description TEXT,
    category VARCHAR(100),
    is_sensitive BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_config_key (config_key),
    INDEX idx_category (category)
);

-- Insert default system configuration
INSERT IGNORE INTO system_config (id, config_key, config_value, description, category) VALUES
(UUID(), 'subscription_tiers', '{"bronze": {"quality": "720p", "price": 9.99}, "silver": {"quality": "1080p", "price": 19.99}, "gold": {"quality": "4k", "price": 39.99}}', 'Subscription tier configuration', 'billing'),
(UUID(), 'streaming_settings', '{"max_concurrent_streams": 1000, "default_quality": "1080p", "enable_chat": true}', 'Default streaming settings', 'streaming'),
(UUID(), 'ai_moderation', '{"rekognition_confidence_threshold": 0.8, "comprehend_confidence_threshold": 0.7, "auto_approve_threshold": 0.9}', 'AI moderation thresholds', 'moderation'),
(UUID(), 'support_settings', '{"auto_assign_tickets": true, "escalation_timeout_hours": 24, "ai_suggestions_enabled": true}', 'Support system configuration', 'support');

-- Create views for common queries
CREATE OR REPLACE VIEW active_streams AS
SELECT 
    s.*,
    u.username as creator_username,
    u.display_name as creator_display_name
FROM streams s
JOIN users u ON s.creator_id = u.id
WHERE s.status = 'live';

CREATE OR REPLACE VIEW user_subscription_summary AS
SELECT 
    u.id,
    u.username,
    u.email,
    u.subscription_tier,
    u.subscription_status,
    u.subscription_renewal_date,
    COUNT(s.id) as total_streams,
    COUNT(CASE WHEN s.status = 'live' THEN 1 END) as active_streams,
    COALESCE(SUM(s.total_views), 0) as total_views
FROM users u
LEFT JOIN streams s ON u.id = s.creator_id
GROUP BY u.id, u.username, u.email, u.subscription_tier, u.subscription_status, u.subscription_renewal_date;

-- Create stored procedures for common operations
DELIMITER //

CREATE PROCEDURE IF NOT EXISTS CreateSupportTicket(
    IN p_user_id VARCHAR(36),
    IN p_type VARCHAR(50),
    IN p_priority VARCHAR(20),
    IN p_subject VARCHAR(255),
    IN p_description TEXT,
    IN p_context JSON
)
BEGIN
    DECLARE ticket_id VARCHAR(36) DEFAULT (SELECT UUID());
    
    INSERT INTO support_tickets (
        id, user_id, type, priority, subject, description, context
    ) VALUES (
        ticket_id, p_user_id, p_type, p_priority, p_subject, p_description, p_context
    );
    
    SELECT ticket_id as id;
END //

CREATE PROCEDURE IF NOT EXISTS UpdateStreamMetrics(
    IN p_stream_id VARCHAR(36),
    IN p_viewer_count INT,
    IN p_chat_activity INT
)
BEGIN
    -- Update stream viewer count
    UPDATE streams 
    SET viewer_count = p_viewer_count,
        max_viewers = GREATEST(max_viewers, p_viewer_count),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_stream_id;
    
    -- Insert analytics records
    INSERT INTO stream_analytics (id, stream_id, metric_type, metric_value, recorded_at) VALUES
    (UUID(), p_stream_id, 'viewer_count', p_viewer_count, CURRENT_TIMESTAMP),
    (UUID(), p_stream_id, 'chat_activity', p_chat_activity, CURRENT_TIMESTAMP);
END //

DELIMITER ;

-- Create indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_streams_creator_status ON streams(creator_id, status);
CREATE INDEX IF NOT EXISTS idx_support_tickets_user_status ON support_tickets(user_id, status);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_user_type ON payment_transactions(user_id, type);
CREATE INDEX IF NOT EXISTS idx_stream_analytics_stream_type_time ON stream_analytics(stream_id, metric_type, recorded_at);

-- Grant permissions for application user (will be created separately)
-- These will be executed after the application user is created
-- GRANT SELECT, INSERT, UPDATE, DELETE ON streaming_platform.* TO 'app_user'@'%';
-- GRANT EXECUTE ON PROCEDURE streaming_platform.CreateSupportTicket TO 'app_user'@'%';
-- GRANT EXECUTE ON PROCEDURE streaming_platform.UpdateStreamMetrics TO 'app_user'@'%';

COMMIT;