-- Database initialization script for streaming platform
-- This script creates the necessary tables and indexes for the application

-- Note: Database is already created by Aurora cluster configuration
-- Connect to the streaming_platform database

-- Create ENUM types for PostgreSQL
CREATE TYPE user_role AS ENUM ('viewer', 'creator', 'admin', 'support', 'analyst', 'developer');
CREATE TYPE subscription_tier AS ENUM ('bronze', 'silver', 'gold');
CREATE TYPE subscription_status AS ENUM ('active', 'cancelled', 'expired');
CREATE TYPE stream_status AS ENUM ('scheduled', 'live', 'ended', 'cancelled');
CREATE TYPE ticket_type AS ENUM ('technical', 'billing', 'content', 'account', 'general');
CREATE TYPE ticket_priority AS ENUM ('low', 'medium', 'high', 'urgent');
CREATE TYPE ticket_status AS ENUM ('open', 'in_progress', 'resolved', 'closed');
CREATE TYPE metric_type AS ENUM ('viewer_count', 'chat_activity', 'quality_metrics', 'engagement');
CREATE TYPE payment_type AS ENUM ('subscription', 'donation', 'refund');
CREATE TYPE payment_status AS ENUM ('pending', 'succeeded', 'failed', 'cancelled', 'refunded');
CREATE TYPE content_type AS ENUM ('stream', 'chat', 'profile', 'comment');
CREATE TYPE moderation_service AS ENUM ('rekognition', 'comprehend', 'manual');
CREATE TYPE moderation_status AS ENUM ('approved', 'flagged', 'rejected', 'under_review');

-- Users table for user profiles and authentication data
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY,
    cognito_id VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    display_name VARCHAR(255),
    role user_role NOT NULL DEFAULT 'viewer',
    subscription_tier subscription_tier NOT NULL DEFAULT 'bronze',
    subscription_status subscription_status NOT NULL DEFAULT 'active',
    subscription_renewal_date TIMESTAMP,
    avatar_url VARCHAR(500),
    preferences JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP
);

-- Create indexes for users table
CREATE INDEX IF NOT EXISTS idx_users_cognito_id ON users(cognito_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_subscription_tier ON users(subscription_tier);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

-- Streams table for stream configuration and metadata
CREATE TABLE IF NOT EXISTS streams (
    id VARCHAR(36) PRIMARY KEY,
    creator_id VARCHAR(36) NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    status stream_status NOT NULL DEFAULT 'scheduled',
    media_live_channel_id VARCHAR(255),
    s3_media_prefix VARCHAR(500),
    scheduled_start TIMESTAMP,
    actual_start TIMESTAMP,
    end_time TIMESTAMP,
    viewer_count INT DEFAULT 0,
    max_viewers INT DEFAULT 0,
    total_views INT DEFAULT 0,
    chat_enabled BOOLEAN DEFAULT TRUE,
    recording_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create indexes for streams table
CREATE INDEX IF NOT EXISTS idx_streams_creator_id ON streams(creator_id);
CREATE INDEX IF NOT EXISTS idx_streams_status ON streams(status);
CREATE INDEX IF NOT EXISTS idx_streams_category ON streams(category);
CREATE INDEX IF NOT EXISTS idx_streams_scheduled_start ON streams(scheduled_start);
CREATE INDEX IF NOT EXISTS idx_streams_created_at ON streams(created_at);

-- Support tickets table for customer service
CREATE TABLE IF NOT EXISTS support_tickets (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    creator_id VARCHAR(36),
    type ticket_type NOT NULL,
    priority ticket_priority NOT NULL DEFAULT 'medium',
    status ticket_status NOT NULL DEFAULT 'open',
    subject VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    assigned_to VARCHAR(36),
    context JSONB,
    ai_suggestions JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP NULL,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE SET NULL
);

-- Create indexes for support_tickets table
CREATE INDEX IF NOT EXISTS idx_support_tickets_user_id ON support_tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_creator_id ON support_tickets(creator_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_type ON support_tickets(type);
CREATE INDEX IF NOT EXISTS idx_support_tickets_priority ON support_tickets(priority);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON support_tickets(status);
CREATE INDEX IF NOT EXISTS idx_support_tickets_assigned_to ON support_tickets(assigned_to);
CREATE INDEX IF NOT EXISTS idx_support_tickets_created_at ON support_tickets(created_at);

-- Stream analytics table for performance metrics
CREATE TABLE IF NOT EXISTS stream_analytics (
    id VARCHAR(36) PRIMARY KEY,
    stream_id VARCHAR(36) NOT NULL,
    metric_type metric_type NOT NULL,
    metric_value DECIMAL(10,2) NOT NULL,
    metadata JSONB,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (stream_id) REFERENCES streams(id) ON DELETE CASCADE
);

-- Create indexes for stream_analytics table
CREATE INDEX IF NOT EXISTS idx_stream_analytics_stream_id ON stream_analytics(stream_id);
CREATE INDEX IF NOT EXISTS idx_stream_analytics_metric_type ON stream_analytics(metric_type);
CREATE INDEX IF NOT EXISTS idx_stream_analytics_recorded_at ON stream_analytics(recorded_at);

-- Payment transactions table for billing and revenue tracking
CREATE TABLE IF NOT EXISTS payment_transactions (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    stripe_payment_intent_id VARCHAR(255) UNIQUE,
    stripe_subscription_id VARCHAR(255),
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'GBP',
    type payment_type NOT NULL,
    status payment_status NOT NULL,
    description TEXT,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create indexes for payment_transactions table
CREATE INDEX IF NOT EXISTS idx_payment_transactions_user_id ON payment_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_stripe_payment_intent_id ON payment_transactions(stripe_payment_intent_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_stripe_subscription_id ON payment_transactions(stripe_subscription_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_type ON payment_transactions(type);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_status ON payment_transactions(status);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_created_at ON payment_transactions(created_at);

-- Content moderation table for AI-powered content review
CREATE TABLE IF NOT EXISTS content_moderation (
    id VARCHAR(36) PRIMARY KEY,
    content_type content_type NOT NULL,
    content_id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    moderation_service moderation_service NOT NULL,
    confidence_score DECIMAL(5,4),
    flags JSONB,
    status moderation_status NOT NULL,
    reviewed_by VARCHAR(36),
    reviewed_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL
);

-- Create indexes for content_moderation table
CREATE INDEX IF NOT EXISTS idx_content_moderation_content_type ON content_moderation(content_type);
CREATE INDEX IF NOT EXISTS idx_content_moderation_content_id ON content_moderation(content_id);
CREATE INDEX IF NOT EXISTS idx_content_moderation_user_id ON content_moderation(user_id);
CREATE INDEX IF NOT EXISTS idx_content_moderation_status ON content_moderation(status);
CREATE INDEX IF NOT EXISTS idx_content_moderation_created_at ON content_moderation(created_at);

-- System configuration table for application settings
CREATE TABLE IF NOT EXISTS system_config (
    id VARCHAR(36) PRIMARY KEY,
    config_key VARCHAR(255) UNIQUE NOT NULL,
    config_value JSONB NOT NULL,
    description TEXT,
    category VARCHAR(100),
    is_sensitive BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for system_config table
CREATE INDEX IF NOT EXISTS idx_system_config_config_key ON system_config(config_key);
CREATE INDEX IF NOT EXISTS idx_system_config_category ON system_config(category);

-- Insert default system configuration
INSERT INTO system_config (id, config_key, config_value, description, category) VALUES
(gen_random_uuid()::text, 'subscription_tiers', '{"bronze": {"quality": "720p", "price": 9.99}, "silver": {"quality": "1080p", "price": 19.99}, "gold": {"quality": "4k", "price": 39.99}}', 'Subscription tier configuration', 'billing'),
(gen_random_uuid()::text, 'streaming_settings', '{"max_concurrent_streams": 1000, "default_quality": "1080p", "enable_chat": true}', 'Default streaming settings', 'streaming'),
(gen_random_uuid()::text, 'ai_moderation', '{"rekognition_confidence_threshold": 0.8, "comprehend_confidence_threshold": 0.7, "auto_approve_threshold": 0.9}', 'AI moderation thresholds', 'moderation'),
(gen_random_uuid()::text, 'support_settings', '{"auto_assign_tickets": true, "escalation_timeout_hours": 24, "ai_suggestions_enabled": true}', 'Support system configuration', 'support')
ON CONFLICT (config_key) DO NOTHING;

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

-- Create functions for common operations (PostgreSQL uses functions instead of procedures)
CREATE OR REPLACE FUNCTION create_support_ticket(
    p_user_id VARCHAR(36),
    p_type ticket_type,
    p_priority ticket_priority,
    p_subject VARCHAR(255),
    p_description TEXT,
    p_context JSONB DEFAULT NULL
) RETURNS VARCHAR(36) AS $$
DECLARE
    ticket_id VARCHAR(36);
BEGIN
    ticket_id := gen_random_uuid()::text;
    
    INSERT INTO support_tickets (
        id, user_id, type, priority, subject, description, context
    ) VALUES (
        ticket_id, p_user_id, p_type, p_priority, p_subject, p_description, p_context
    );
    
    RETURN ticket_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_stream_metrics(
    p_stream_id VARCHAR(36),
    p_viewer_count INT,
    p_chat_activity INT
) RETURNS VOID AS $$
BEGIN
    -- Update stream viewer count
    UPDATE streams 
    SET viewer_count = p_viewer_count,
        max_viewers = GREATEST(max_viewers, p_viewer_count),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_stream_id;
    
    -- Insert analytics records
    INSERT INTO stream_analytics (id, stream_id, metric_type, metric_value, recorded_at) VALUES
    (gen_random_uuid()::text, p_stream_id, 'viewer_count', p_viewer_count, CURRENT_TIMESTAMP),
    (gen_random_uuid()::text, p_stream_id, 'chat_activity', p_chat_activity, CURRENT_TIMESTAMP);
END;
$$ LANGUAGE plpgsql;

-- Create composite indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_streams_creator_status ON streams(creator_id, status);
CREATE INDEX IF NOT EXISTS idx_support_tickets_user_status ON support_tickets(user_id, status);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_user_type ON payment_transactions(user_id, type);
CREATE INDEX IF NOT EXISTS idx_stream_analytics_stream_type_time ON stream_analytics(stream_id, metric_type, recorded_at);

-- Create triggers for updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_streams_updated_at BEFORE UPDATE ON streams
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_support_tickets_updated_at BEFORE UPDATE ON support_tickets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payment_transactions_updated_at BEFORE UPDATE ON payment_transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_system_config_updated_at BEFORE UPDATE ON system_config
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Grant permissions for application user (will be created separately)
-- These will be executed after the application user is created
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
-- GRANT EXECUTE ON FUNCTION create_support_ticket TO app_user;
-- GRANT EXECUTE ON FUNCTION update_stream_metrics TO app_user;-
- Additional tables for advanced features

-- Chat messages table for real-time chat storage
CREATE TABLE IF NOT EXISTS chat_messages (
    id VARCHAR(36) PRIMARY KEY,
    stream_id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    message TEXT NOT NULL,
    message_type VARCHAR(50) DEFAULT 'text',
    metadata JSONB,
    moderation_status moderation_status DEFAULT 'approved',
    moderated_by VARCHAR(36),
    moderated_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    
    FOREIGN KEY (stream_id) REFERENCES streams(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (moderated_by) REFERENCES users(id) ON DELETE SET NULL
);

-- Create indexes for chat_messages table
CREATE INDEX IF NOT EXISTS idx_chat_messages_stream_id ON chat_messages(stream_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_user_id ON chat_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON chat_messages(created_at);
CREATE INDEX IF NOT EXISTS idx_chat_messages_expires_at ON chat_messages(expires_at);
CREATE INDEX IF NOT EXISTS idx_chat_messages_moderation_status ON chat_messages(moderation_status);

-- Video content table for uploaded video metadata
CREATE TABLE IF NOT EXISTS video_content (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    s3_upload_key VARCHAR(500),
    s3_processed_keys JSONB, -- Store different quality versions
    thumbnail_url VARCHAR(500),
    duration_seconds INT,
    file_size_bytes BIGINT,
    processing_status VARCHAR(50) DEFAULT 'uploaded',
    mediaconvert_job_id VARCHAR(255),
    quality_levels JSONB, -- Available quality levels
    view_count INT DEFAULT 0,
    like_count INT DEFAULT 0,
    visibility VARCHAR(50) DEFAULT 'public', -- public, private, unlisted
    moderation_status moderation_status DEFAULT 'approved',
    moderated_by VARCHAR(36),
    moderated_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (moderated_by) REFERENCES users(id) ON DELETE SET NULL
);

-- Create indexes for video_content table
CREATE INDEX IF NOT EXISTS idx_video_content_user_id ON video_content(user_id);
CREATE INDEX IF NOT EXISTS idx_video_content_category ON video_content(category);
CREATE INDEX IF NOT EXISTS idx_video_content_processing_status ON video_content(processing_status);
CREATE INDEX IF NOT EXISTS idx_video_content_visibility ON video_content(visibility);
CREATE INDEX IF NOT EXISTS idx_video_content_moderation_status ON video_content(moderation_status);
CREATE INDEX IF NOT EXISTS idx_video_content_created_at ON video_content(created_at);

-- User sessions table for activity tracking
CREATE TABLE IF NOT EXISTS user_sessions (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    ip_address INET,
    user_agent TEXT,
    device_info JSONB,
    location_info JSONB,
    activity_data JSONB, -- Track user activities during session
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP NULL,
    duration_seconds INT,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create indexes for user_sessions table
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_session_token ON user_sessions(session_token);
CREATE INDEX IF NOT EXISTS idx_user_sessions_started_at ON user_sessions(started_at);
CREATE INDEX IF NOT EXISTS idx_user_sessions_last_activity ON user_sessions(last_activity);

-- Moderation logs table for audit trail
CREATE TABLE IF NOT EXISTS moderation_logs (
    id VARCHAR(36) PRIMARY KEY,
    content_type content_type NOT NULL,
    content_id VARCHAR(36) NOT NULL,
    moderator_id VARCHAR(36) NOT NULL,
    action VARCHAR(100) NOT NULL, -- approve, reject, flag, escalate, etc.
    reason TEXT,
    previous_status moderation_status,
    new_status moderation_status NOT NULL,
    confidence_score DECIMAL(5,4),
    ai_analysis JSONB,
    manual_review_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (moderator_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create indexes for moderation_logs table
CREATE INDEX IF NOT EXISTS idx_moderation_logs_content_type ON moderation_logs(content_type);
CREATE INDEX IF NOT EXISTS idx_moderation_logs_content_id ON moderation_logs(content_id);
CREATE INDEX IF NOT EXISTS idx_moderation_logs_moderator_id ON moderation_logs(moderator_id);
CREATE INDEX IF NOT EXISTS idx_moderation_logs_action ON moderation_logs(action);
CREATE INDEX IF NOT EXISTS idx_moderation_logs_created_at ON moderation_logs(created_at);

-- Analytics events table for custom event tracking
CREATE TABLE IF NOT EXISTS analytics_events (
    id VARCHAR(36) PRIMARY KEY,
    event_type VARCHAR(100) NOT NULL,
    user_id VARCHAR(36),
    session_id VARCHAR(36),
    stream_id VARCHAR(36),
    event_data JSONB NOT NULL,
    client_timestamp TIMESTAMP,
    server_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    user_agent TEXT,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (session_id) REFERENCES user_sessions(id) ON DELETE SET NULL,
    FOREIGN KEY (stream_id) REFERENCES streams(id) ON DELETE SET NULL
);

-- Create indexes for analytics_events table
CREATE INDEX IF NOT EXISTS idx_analytics_events_event_type ON analytics_events(event_type);
CREATE INDEX IF NOT EXISTS idx_analytics_events_user_id ON analytics_events(user_id);
CREATE INDEX IF NOT EXISTS idx_analytics_events_session_id ON analytics_events(session_id);
CREATE INDEX IF NOT EXISTS idx_analytics_events_stream_id ON analytics_events(stream_id);
CREATE INDEX IF NOT EXISTS idx_analytics_events_server_timestamp ON analytics_events(server_timestamp);

-- Create additional views for advanced features
CREATE OR REPLACE VIEW chat_activity_summary AS
SELECT 
    cm.stream_id,
    s.title as stream_title,
    COUNT(cm.id) as total_messages,
    COUNT(DISTINCT cm.user_id) as unique_chatters,
    COUNT(CASE WHEN cm.moderation_status = 'flagged' THEN 1 END) as flagged_messages,
    MIN(cm.created_at) as first_message_at,
    MAX(cm.created_at) as last_message_at
FROM chat_messages cm
JOIN streams s ON cm.stream_id = s.id
WHERE cm.created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY cm.stream_id, s.title;

CREATE OR REPLACE VIEW video_content_summary AS
SELECT 
    vc.user_id,
    u.username,
    COUNT(vc.id) as total_videos,
    COUNT(CASE WHEN vc.processing_status = 'completed' THEN 1 END) as processed_videos,
    COUNT(CASE WHEN vc.visibility = 'public' THEN 1 END) as public_videos,
    SUM(vc.view_count) as total_views,
    SUM(vc.like_count) as total_likes,
    AVG(vc.duration_seconds) as avg_duration_seconds
FROM video_content vc
JOIN users u ON vc.user_id = u.id
GROUP BY vc.user_id, u.username;

CREATE OR REPLACE VIEW user_engagement_metrics AS
SELECT 
    u.id as user_id,
    u.username,
    COUNT(DISTINCT us.id) as total_sessions,
    AVG(us.duration_seconds) as avg_session_duration,
    COUNT(DISTINCT ae.id) as total_events,
    COUNT(DISTINCT cm.id) as total_chat_messages,
    COUNT(DISTINCT vc.id) as total_videos_uploaded,
    MAX(us.last_activity) as last_activity
FROM users u
LEFT JOIN user_sessions us ON u.id = us.user_id
LEFT JOIN analytics_events ae ON u.id = ae.user_id
LEFT JOIN chat_messages cm ON u.id = cm.user_id
LEFT JOIN video_content vc ON u.id = vc.user_id
WHERE u.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY u.id, u.username;

-- Create additional functions for advanced features
CREATE OR REPLACE FUNCTION log_moderation_action(
    p_content_type content_type,
    p_content_id VARCHAR(36),
    p_moderator_id VARCHAR(36),
    p_action VARCHAR(100),
    p_reason TEXT,
    p_previous_status moderation_status,
    p_new_status moderation_status,
    p_confidence_score DECIMAL(5,4) DEFAULT NULL,
    p_ai_analysis JSONB DEFAULT NULL,
    p_manual_notes TEXT DEFAULT NULL
) RETURNS VARCHAR(36) AS $
DECLARE
    log_id VARCHAR(36);
BEGIN
    log_id := gen_random_uuid()::text;
    
    INSERT INTO moderation_logs (
        id, content_type, content_id, moderator_id, action, reason,
        previous_status, new_status, confidence_score, ai_analysis, manual_review_notes
    ) VALUES (
        log_id, p_content_type, p_content_id, p_moderator_id, p_action, p_reason,
        p_previous_status, p_new_status, p_confidence_score, p_ai_analysis, p_manual_notes
    );
    
    RETURN log_id;
END;
$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION track_analytics_event(
    p_event_type VARCHAR(100),
    p_user_id VARCHAR(36),
    p_session_id VARCHAR(36),
    p_stream_id VARCHAR(36),
    p_event_data JSONB,
    p_client_timestamp TIMESTAMP DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS VARCHAR(36) AS $
DECLARE
    event_id VARCHAR(36);
BEGIN
    event_id := gen_random_uuid()::text;
    
    INSERT INTO analytics_events (
        id, event_type, user_id, session_id, stream_id, event_data,
        client_timestamp, ip_address, user_agent
    ) VALUES (
        event_id, p_event_type, p_user_id, p_session_id, p_stream_id, p_event_data,
        p_client_timestamp, p_ip_address, p_user_agent
    );
    
    RETURN event_id;
END;
$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION start_user_session(
    p_user_id VARCHAR(36),
    p_session_token VARCHAR(255),
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_device_info JSONB DEFAULT NULL,
    p_location_info JSONB DEFAULT NULL
) RETURNS VARCHAR(36) AS $
DECLARE
    session_id VARCHAR(36);
BEGIN
    session_id := gen_random_uuid()::text;
    
    INSERT INTO user_sessions (
        id, user_id, session_token, ip_address, user_agent, device_info, location_info
    ) VALUES (
        session_id, p_user_id, p_session_token, p_ip_address, p_user_agent, p_device_info, p_location_info
    );
    
    RETURN session_id;
END;
$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION end_user_session(
    p_session_id VARCHAR(36)
) RETURNS VOID AS $
DECLARE
    session_start TIMESTAMP;
BEGIN
    SELECT started_at INTO session_start 
    FROM user_sessions 
    WHERE id = p_session_id;
    
    UPDATE user_sessions 
    SET ended_at = CURRENT_TIMESTAMP,
        duration_seconds = EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - session_start))::INT
    WHERE id = p_session_id;
END;
$ LANGUAGE plpgsql;

-- Create triggers for new tables
CREATE TRIGGER update_video_content_updated_at BEFORE UPDATE ON video_content
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create partitioning for high-volume tables (analytics_events and chat_messages)
-- This is for PostgreSQL 10+ with native partitioning

-- Partition analytics_events by month
CREATE TABLE IF NOT EXISTS analytics_events_template (
    LIKE analytics_events INCLUDING ALL
) PARTITION BY RANGE (server_timestamp);

-- Create initial partitions for current and next month
DO $
DECLARE
    current_month_start DATE;
    next_month_start DATE;
    current_partition_name TEXT;
    next_partition_name TEXT;
BEGIN
    current_month_start := DATE_TRUNC('month', CURRENT_DATE);
    next_month_start := current_month_start + INTERVAL '1 month';
    
    current_partition_name := 'analytics_events_' || TO_CHAR(current_month_start, 'YYYY_MM');
    next_partition_name := 'analytics_events_' || TO_CHAR(next_month_start, 'YYYY_MM');
    
    -- Create current month partition
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF analytics_events_template 
                    FOR VALUES FROM (%L) TO (%L)', 
                   current_partition_name, current_month_start, next_month_start);
    
    -- Create next month partition
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF analytics_events_template 
                    FOR VALUES FROM (%L) TO (%L)', 
                   next_partition_name, next_month_start, next_month_start + INTERVAL '1 month');
END
$;

-- Add cleanup job for old data (this would typically be handled by a scheduled job)
CREATE OR REPLACE FUNCTION cleanup_old_data() RETURNS VOID AS $
BEGIN
    -- Clean up expired chat messages
    DELETE FROM chat_messages 
    WHERE expires_at IS NOT NULL AND expires_at < CURRENT_TIMESTAMP;
    
    -- Clean up old user sessions (older than 90 days)
    DELETE FROM user_sessions 
    WHERE started_at < CURRENT_DATE - INTERVAL '90 days';
    
    -- Clean up old analytics events (older than 1 year)
    DELETE FROM analytics_events 
    WHERE server_timestamp < CURRENT_DATE - INTERVAL '1 year';
    
    -- Clean up old moderation logs (older than 2 years)
    DELETE FROM moderation_logs 
    WHERE created_at < CURRENT_DATE - INTERVAL '2 years';
END;
$ LANGUAGE plpgsql;

-- Grant permissions for new tables and functions
-- GRANT SELECT, INSERT, UPDATE, DELETE ON chat_messages TO app_user;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON video_content TO app_user;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON user_sessions TO app_user;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON moderation_logs TO app_user;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON analytics_events TO app_user;
-- GRANT EXECUTE ON FUNCTION log_moderation_action TO app_user;
-- GRANT EXECUTE ON FUNCTION track_analytics_event TO app_user;
-- GRANT EXECUTE ON FUNCTION start_user_session TO app_user;
-- GRANT EXECUTE ON FUNCTION end_user_session TO app_user;
-- GRANT EXECUTE ON FUNCTION cleanup_old_data TO app_user;