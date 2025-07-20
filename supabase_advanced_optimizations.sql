-- =====================================================
-- SUPABASE TELEMETRY ADVANCED OPTIMIZATIONS
-- =====================================================
-- This migration adds comprehensive performance optimizations
-- for the telemetry data pipeline including:
-- - Advanced indexing strategies (BRIN, GIN, composite)
-- - Table partitioning for time-series data
-- - Connection pooling configurations
-- - Enhanced RLS policies with performance optimizations
-- - Monitoring and analytics functions
-- - Data retention and cleanup policies
-- =====================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pg_partman" SCHEMA partman;
CREATE EXTENSION IF NOT EXISTS "pgaudit";

-- =====================================================
-- 1. ADVANCED INDEXING OPTIMIZATIONS
-- =====================================================

-- Drop existing basic indexes to replace with optimized ones
DROP INDEX IF EXISTS idx_telemetry_events_timestamp;
DROP INDEX IF EXISTS idx_telemetry_events_event_type;
DROP INDEX IF EXISTS idx_telemetry_events_user_id;
DROP INDEX IF EXISTS idx_telemetry_events_session_id;

-- BRIN index for timestamp (optimal for time-series data)
-- Much smaller than B-tree, perfect for append-only telemetry data
CREATE INDEX CONCURRENTLY idx_telemetry_events_timestamp_brin 
ON public.telemetry_events USING BRIN (timestamp) 
WITH (pages_per_range = 64);

-- Composite indexes for common query patterns
-- User + timestamp for user-specific time range queries
CREATE INDEX CONCURRENTLY idx_telemetry_events_user_time 
ON public.telemetry_events (user_id, timestamp DESC) 
WHERE user_id IS NOT NULL;

-- Event type + timestamp for analytics queries
CREATE INDEX CONCURRENTLY idx_telemetry_events_type_time 
ON public.telemetry_events (event_type, timestamp DESC);

-- Session + timestamp for session analysis
CREATE INDEX CONCURRENTLY idx_telemetry_events_session_time 
ON public.telemetry_events (session_id, timestamp DESC) 
WHERE session_id IS NOT NULL;

-- GIN index for JSONB event_data queries
CREATE INDEX CONCURRENTLY idx_telemetry_events_data_gin 
ON public.telemetry_events USING GIN (event_data);

-- Partial indexes for hot data subsets
-- Index for error events (frequently queried)
CREATE INDEX CONCURRENTLY idx_telemetry_events_errors 
ON public.telemetry_events (timestamp DESC, user_id) 
WHERE event_type IN ('error', 'exception', 'crash');

-- Index for recent data (last 30 days) - most frequently accessed
CREATE INDEX CONCURRENTLY idx_telemetry_events_recent 
ON public.telemetry_events (event_type, user_id, timestamp DESC) 
WHERE timestamp >= (CURRENT_TIMESTAMP - INTERVAL '30 days');

-- Covering index for common analytics queries
CREATE INDEX CONCURRENTLY idx_telemetry_events_analytics 
ON public.telemetry_events (timestamp, event_type) 
INCLUDE (user_id, session_id, event_data);

-- =====================================================
-- 2. TABLE PARTITIONING FOR SCALABILITY
-- =====================================================

-- Create partitioned version of telemetry_events for better performance
-- We'll use monthly partitions for optimal query performance

-- First, create the new partitioned table structure
CREATE TABLE public.telemetry_events_partitioned (
    id UUID DEFAULT uuid_generate_v4(),
    event_type VARCHAR(100) NOT NULL,
    event_data JSONB NOT NULL,
    user_id VARCHAR(255),
    session_id VARCHAR(255),
    timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (id, timestamp)
) PARTITION BY RANGE (timestamp);

-- Set up automated partitioning with pg_partman
SELECT partman.create_parent(
    p_parent_table := 'public.telemetry_events_partitioned',
    p_control := 'timestamp',
    p_interval := 'monthly',
    p_premake := 3,  -- Pre-create 3 future partitions
    p_start_partition := date_trunc('month', CURRENT_DATE - INTERVAL '1 month')::text
);

-- Configure retention policy (keep 12 months of data)
UPDATE partman.part_config 
SET retention = '12 months',
    retention_keep_table = false,
    retention_keep_index = false
WHERE parent_table = 'public.telemetry_events_partitioned';

-- =====================================================
-- 3. ENHANCED RLS POLICIES WITH PERFORMANCE OPTIMIZATIONS
-- =====================================================

-- Drop existing policies to replace with optimized versions
DROP POLICY IF EXISTS "Service role can do everything on telemetry_events" ON public.telemetry_events;
DROP POLICY IF EXISTS "Users can read their own telemetry events" ON public.telemetry_events;

-- Optimized RLS policies using SELECT wrapping for auth.uid() caching
CREATE POLICY "service_role_full_access" ON public.telemetry_events
    FOR ALL TO service_role
    USING (true);

-- Performance-optimized user policy with cached auth.uid()
CREATE POLICY "users_own_data_optimized" ON public.telemetry_events
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()::text) = user_id);

-- Policy for analytics access (read-only aggregated data)
CREATE POLICY "analytics_read_access" ON public.telemetry_events
    FOR SELECT TO authenticated
    USING (
        timestamp >= (CURRENT_TIMESTAMP - INTERVAL '7 days') AND
        event_type NOT IN ('sensitive_action', 'private_data')
    );

-- Apply same optimizations to other tables
DROP POLICY IF EXISTS "Service role can do everything on telemetry_sessions" ON public.telemetry_sessions;
DROP POLICY IF EXISTS "Users can read their own telemetry sessions" ON public.telemetry_sessions;

CREATE POLICY "service_role_sessions_access" ON public.telemetry_sessions
    FOR ALL TO service_role
    USING (true);

CREATE POLICY "users_own_sessions_optimized" ON public.telemetry_sessions
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()::text) = user_id);

-- =====================================================
-- 4. PERFORMANCE MONITORING FUNCTIONS
-- =====================================================

-- Function to get index usage statistics
CREATE OR REPLACE FUNCTION public.get_index_usage_stats()
RETURNS TABLE (
    schemaname TEXT,
    tablename TEXT,
    indexname TEXT,
    idx_scan BIGINT,
    idx_tup_read BIGINT,
    idx_tup_fetch BIGINT,
    idx_blks_read BIGINT,
    idx_blks_hit BIGINT,
    hit_ratio NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.schemaname::TEXT,
        s.tablename::TEXT,
        s.indexrelname::TEXT,
        s.idx_scan,
        s.idx_tup_read,
        s.idx_tup_fetch,
        io.idx_blks_read,
        io.idx_blks_hit,
        CASE 
            WHEN (io.idx_blks_hit + io.idx_blks_read) = 0 THEN 0
            ELSE ROUND(100.0 * io.idx_blks_hit / (io.idx_blks_hit + io.idx_blks_read), 2)
        END as hit_ratio
    FROM pg_stat_user_indexes s
    JOIN pg_statio_user_indexes io ON s.indexrelid = io.indexrelid
    WHERE s.schemaname = 'public'
    ORDER BY s.idx_scan DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to analyze query performance
CREATE OR REPLACE FUNCTION public.get_slow_queries(min_duration_ms INTEGER DEFAULT 1000)
RETURNS TABLE (
    query TEXT,
    calls BIGINT,
    total_time NUMERIC,
    mean_time NUMERIC,
    max_time NUMERIC,
    stddev_time NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pss.query,
        pss.calls,
        ROUND(pss.total_exec_time::NUMERIC, 2) as total_time,
        ROUND(pss.mean_exec_time::NUMERIC, 2) as mean_time,
        ROUND(pss.max_exec_time::NUMERIC, 2) as max_time,
        ROUND(pss.stddev_exec_time::NUMERIC, 2) as stddev_time
    FROM pg_stat_statements pss
    WHERE pss.mean_exec_time > min_duration_ms
    ORDER BY pss.mean_exec_time DESC
    LIMIT 20;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get table size and bloat information
CREATE OR REPLACE FUNCTION public.get_table_stats()
RETURNS TABLE (
    schemaname TEXT,
    tablename TEXT,
    row_count BIGINT,
    total_size TEXT,
    index_size TEXT,
    toast_size TEXT,
    table_size TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        schemaname::TEXT,
        tablename::TEXT,
        n_live_tup as row_count,
        pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
        pg_size_pretty(pg_indexes_size(schemaname||'.'||tablename)) as index_size,
        pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as toast_size,
        pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size
    FROM pg_stat_user_tables
    WHERE schemaname = 'public'
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 5. MATERIALIZED VIEWS FOR ANALYTICS
-- =====================================================

-- High-performance materialized view for daily analytics
CREATE MATERIALIZED VIEW public.telemetry_daily_stats AS
SELECT 
    DATE_TRUNC('day', timestamp) as date,
    event_type,
    COUNT(*) as event_count,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT session_id) as unique_sessions,
    COUNT(DISTINCT ip_address) as unique_ips,
    AVG(EXTRACT(EPOCH FROM (updated_at - created_at))) as avg_processing_time
FROM public.telemetry_events
WHERE timestamp >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY DATE_TRUNC('day', timestamp), event_type
ORDER BY date DESC, event_count DESC;

-- Index on materialized view for fast queries
CREATE INDEX idx_telemetry_daily_stats_date_type 
ON public.telemetry_daily_stats (date DESC, event_type);

-- Hourly stats for real-time monitoring
CREATE MATERIALIZED VIEW public.telemetry_hourly_stats AS
SELECT 
    DATE_TRUNC('hour', timestamp) as hour,
    event_type,
    COUNT(*) as event_count,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT session_id) as unique_sessions,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (updated_at - created_at))) as p95_processing_time
FROM public.telemetry_events
WHERE timestamp >= CURRENT_TIMESTAMP - INTERVAL '7 days'
GROUP BY DATE_TRUNC('hour', timestamp), event_type
ORDER BY hour DESC, event_count DESC;

CREATE INDEX idx_telemetry_hourly_stats_hour_type 
ON public.telemetry_hourly_stats (hour DESC, event_type);

-- =====================================================
-- 6. AUTOMATED MAINTENANCE FUNCTIONS
-- =====================================================

-- Function to refresh materialized views
CREATE OR REPLACE FUNCTION public.refresh_telemetry_stats()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.telemetry_daily_stats;
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.telemetry_hourly_stats;
    
    -- Update table statistics
    ANALYZE public.telemetry_events;
    ANALYZE public.telemetry_sessions;
    ANALYZE public.telemetry_users;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function for data cleanup and maintenance
CREATE OR REPLACE FUNCTION public.cleanup_old_telemetry_data()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Delete events older than 12 months
    DELETE FROM public.telemetry_events 
    WHERE timestamp < CURRENT_TIMESTAMP - INTERVAL '12 months';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Clean up orphaned sessions
    DELETE FROM public.telemetry_sessions 
    WHERE start_time < CURRENT_TIMESTAMP - INTERVAL '12 months';
    
    -- Update user last_seen for users with no recent activity
    UPDATE public.telemetry_users 
    SET last_seen = (
        SELECT MAX(timestamp) 
        FROM public.telemetry_events 
        WHERE telemetry_events.user_id = telemetry_users.user_id
    )
    WHERE last_seen < CURRENT_TIMESTAMP - INTERVAL '30 days';
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 7. TRIGGERS FOR REAL-TIME STATISTICS
-- =====================================================

-- Function to update session statistics in real-time
CREATE OR REPLACE FUNCTION public.update_session_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Update session event count and end time
    UPDATE public.telemetry_sessions 
    SET 
        events_count = events_count + 1,
        end_time = NEW.timestamp,
        duration_seconds = EXTRACT(EPOCH FROM (NEW.timestamp - start_time))::INTEGER,
        updated_at = NOW()
    WHERE session_id = NEW.session_id;
    
    -- Update user statistics
    UPDATE public.telemetry_users 
    SET 
        last_seen = NEW.timestamp,
        total_events = total_events + 1,
        updated_at = NOW()
    WHERE user_id = NEW.user_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for real-time stats updates
DROP TRIGGER IF EXISTS trigger_update_session_stats ON public.telemetry_events;
CREATE TRIGGER trigger_update_session_stats
    AFTER INSERT ON public.telemetry_events
    FOR EACH ROW
    EXECUTE FUNCTION public.update_session_stats();

-- =====================================================
-- 8. CONNECTION POOLING OPTIMIZATIONS
-- =====================================================

-- Configure connection pooling settings for optimal performance
-- These settings optimize for telemetry workloads with many short transactions

-- Increase connection limits for high-throughput telemetry
ALTER SYSTEM SET max_connections = 200;
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET work_mem = '4MB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';

-- Optimize for write-heavy telemetry workloads
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET checkpoint_timeout = '10min';
ALTER SYSTEM SET max_wal_size = '2GB';

-- Enable query plan caching for repeated telemetry inserts
ALTER SYSTEM SET plan_cache_mode = 'force_generic_plan';

-- Configure autovacuum for high-insert tables
ALTER SYSTEM SET autovacuum_vacuum_scale_factor = 0.1;
ALTER SYSTEM SET autovacuum_analyze_scale_factor = 0.05;

-- =====================================================
-- 9. MONITORING VIEWS
-- =====================================================

-- View for real-time performance monitoring
CREATE OR REPLACE VIEW public.telemetry_performance_monitor AS
SELECT 
    'Events per minute' as metric,
    COUNT(*) as value,
    'events' as unit
FROM public.telemetry_events 
WHERE timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 minute'
UNION ALL
SELECT 
    'Active sessions' as metric,
    COUNT(DISTINCT session_id) as value,
    'sessions' as unit
FROM public.telemetry_events 
WHERE timestamp >= CURRENT_TIMESTAMP - INTERVAL '5 minutes'
UNION ALL
SELECT 
    'Unique users (last hour)' as metric,
    COUNT(DISTINCT user_id) as value,
    'users' as unit
FROM public.telemetry_events 
WHERE timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
UNION ALL
SELECT 
    'Database size' as metric,
    pg_database_size(current_database()) / (1024*1024) as value,
    'MB' as unit;

-- View for index health monitoring
CREATE OR REPLACE VIEW public.index_health_monitor AS
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    CASE 
        WHEN idx_scan = 0 THEN 'UNUSED'
        WHEN idx_scan < 100 THEN 'LOW_USAGE'
        WHEN idx_scan < 1000 THEN 'MODERATE_USAGE'
        ELSE 'HIGH_USAGE'
    END as usage_level,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes 
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;

-- =====================================================
-- 10. GRANTS AND PERMISSIONS
-- =====================================================

-- Grant permissions for monitoring functions
GRANT EXECUTE ON FUNCTION public.get_index_usage_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_slow_queries(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_table_stats() TO authenticated;

-- Grant access to monitoring views
GRANT SELECT ON public.telemetry_performance_monitor TO authenticated;
GRANT SELECT ON public.index_health_monitor TO authenticated;
GRANT SELECT ON public.telemetry_daily_stats TO authenticated;
GRANT SELECT ON public.telemetry_hourly_stats TO authenticated;

-- Grant maintenance function access to service role only
GRANT EXECUTE ON FUNCTION public.refresh_telemetry_stats() TO service_role;
GRANT EXECUTE ON FUNCTION public.cleanup_old_telemetry_data() TO service_role;

-- =====================================================
-- OPTIMIZATION COMPLETE
-- =====================================================

-- Log completion
DO $$
BEGIN
    RAISE NOTICE 'Supabase telemetry optimizations completed successfully!';
    RAISE NOTICE 'Applied optimizations:';
    RAISE NOTICE '- Advanced indexing (BRIN, GIN, composite, partial)';
    RAISE NOTICE '- Table partitioning with automated management';
    RAISE NOTICE '- Enhanced RLS policies with performance optimizations';
    RAISE NOTICE '- Monitoring functions and materialized views';
    RAISE NOTICE '- Connection pooling and database tuning';
    RAISE NOTICE '- Automated maintenance and cleanup procedures';
END $$;