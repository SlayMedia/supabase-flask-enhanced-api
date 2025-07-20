-- Migration: Create telemetry table for drone flight data
-- This table stores parsed telemetry data with 40+ fields including flight metrics, PID data, motor outputs, GPS data, etc.

CREATE TABLE IF NOT EXISTS public.telemetry (
    -- Primary key and metadata
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Flight Control and Status
    flight_mode VARCHAR(50),
    armed BOOLEAN,
    flight_time_seconds NUMERIC(10,2),
    cpu_load_percent NUMERIC(5,2),
    
    -- Attitude and Orientation (degrees)
    roll_degrees NUMERIC(8,3),
    pitch_degrees NUMERIC(8,3),
    yaw_degrees NUMERIC(8,3),
    heading_degrees NUMERIC(8,3),
    
    -- Angular Rates (degrees/second)
    roll_rate_dps NUMERIC(8,3),
    pitch_rate_dps NUMERIC(8,3),
    yaw_rate_dps NUMERIC(8,3),
    
    -- Accelerometer (m/s²)
    accel_x_ms2 NUMERIC(8,3),
    accel_y_ms2 NUMERIC(8,3),
    accel_z_ms2 NUMERIC(8,3),
    
    -- GPS Data
    gps_fix_type INTEGER,
    gps_satellites INTEGER,
    gps_latitude NUMERIC(12,8),
    gps_longitude NUMERIC(12,8),
    gps_altitude_m NUMERIC(8,2),
    gps_speed_ms NUMERIC(8,3),
    gps_course_degrees NUMERIC(8,3),
    gps_hdop NUMERIC(6,2),
    gps_vdop NUMERIC(6,2),
    
    -- Barometer and Altitude
    baro_altitude_m NUMERIC(8,2),
    baro_pressure_pa NUMERIC(10,2),
    baro_temperature_c NUMERIC(6,2),
    
    -- Battery and Power
    battery_voltage_v NUMERIC(6,3),
    battery_current_a NUMERIC(8,3),
    battery_consumed_mah NUMERIC(10,1),
    battery_remaining_percent NUMERIC(5,2),
    
    -- Motor Outputs (PWM values, typically 1000-2000)
    motor1_pwm INTEGER,
    motor2_pwm INTEGER,
    motor3_pwm INTEGER,
    motor4_pwm INTEGER,
    motor5_pwm INTEGER,
    motor6_pwm INTEGER,
    motor7_pwm INTEGER,
    motor8_pwm INTEGER,
    
    -- PID Controller Data
    pid_roll_p NUMERIC(8,4),
    pid_roll_i NUMERIC(8,4),
    pid_roll_d NUMERIC(8,4),
    pid_pitch_p NUMERIC(8,4),
    pid_pitch_i NUMERIC(8,4),
    pid_pitch_d NUMERIC(8,4),
    pid_yaw_p NUMERIC(8,4),
    pid_yaw_i NUMERIC(8,4),
    pid_yaw_d NUMERIC(8,4),
    
    -- RC (Remote Control) Inputs
    rc_roll INTEGER,
    rc_pitch INTEGER,
    rc_throttle INTEGER,
    rc_yaw INTEGER,
    rc_aux1 INTEGER,
    rc_aux2 INTEGER,
    rc_aux3 INTEGER,
    rc_aux4 INTEGER,
    
    -- Velocity and Position
    velocity_x_ms NUMERIC(8,3),
    velocity_y_ms NUMERIC(8,3),
    velocity_z_ms NUMERIC(8,3),
    position_x_m NUMERIC(10,3),
    position_y_m NUMERIC(10,3),
    position_z_m NUMERIC(10,3),
    
    -- Additional Sensors
    magnetometer_x NUMERIC(8,3),
    magnetometer_y NUMERIC(8,3),
    magnetometer_z NUMERIC(8,3),
    temperature_c NUMERIC(6,2),
    humidity_percent NUMERIC(5,2),
    
    -- System Status
    failsafe_active BOOLEAN,
    vibration_x NUMERIC(8,3),
    vibration_y NUMERIC(8,3),
    vibration_z NUMERIC(8,3),
    
    -- Raw telemetry data for debugging
    raw_data TEXT,
    
    -- Parsing metadata
    parser_version VARCHAR(20),
    data_source VARCHAR(100)
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_telemetry_created_at ON public.telemetry(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_telemetry_flight_mode ON public.telemetry(flight_mode);
CREATE INDEX IF NOT EXISTS idx_telemetry_armed ON public.telemetry(armed);
CREATE INDEX IF NOT EXISTS idx_telemetry_gps_fix ON public.telemetry(gps_fix_type);
CREATE INDEX IF NOT EXISTS idx_telemetry_battery_voltage ON public.telemetry(battery_voltage_v);

-- Create a composite index for GPS coordinates (for spatial queries)
CREATE INDEX IF NOT EXISTS idx_telemetry_gps_coords ON public.telemetry(gps_latitude, gps_longitude) 
WHERE gps_latitude IS NOT NULL AND gps_longitude IS NOT NULL;

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_telemetry_updated_at 
    BEFORE UPDATE ON public.telemetry 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Add RLS (Row Level Security) policies if needed
-- ALTER TABLE public.telemetry ENABLE ROW LEVEL SECURITY;

-- Grant permissions (adjust as needed for your security model)
-- GRANT ALL ON public.telemetry TO authenticated;
-- GRANT ALL ON public.telemetry TO service_role;

-- Add comments for documentation
COMMENT ON TABLE public.telemetry IS 'Stores parsed drone telemetry data with flight metrics, sensor readings, and control outputs';
COMMENT ON COLUMN public.telemetry.flight_mode IS 'Current flight mode (e.g., MANUAL, STABILIZE, AUTO)';
COMMENT ON COLUMN public.telemetry.gps_fix_type IS 'GPS fix quality: 0=No fix, 1=Dead reckoning, 2=2D, 3=3D, 4=GNSS+DR';
COMMENT ON COLUMN public.telemetry.motor1_pwm IS 'Motor 1 PWM output (typically 1000-2000 microseconds)';
COMMENT ON COLUMN public.telemetry.raw_data IS 'Original unparsed telemetry string for debugging';