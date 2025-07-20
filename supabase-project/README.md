# Supabase Project Setup

This directory contains utilities and scripts for setting up and managing the Supabase telemetry database.

## Files

### `create_telemetry_schema.py`
Script to create the telemetry schema in your Supabase database. This sets up:
- Telemetry table with 40+ fields for comprehensive drone data
- Optimized indexes for performance
- Triggers for automatic timestamp updates
- Comments and documentation

**Usage:**
```bash
python create_telemetry_schema.py
```

### `verify_telemetry_pipeline.py`
Comprehensive test script that verifies the entire telemetry pipeline:
- Supabase connectivity
- Flask API health
- Telemetry data parsing and storage
- Batch operations
- Data retrieval
- Performance testing

**Usage:**
```bash
# Make sure Flask server is running first
python run_enhanced_supabase.py &

# Then run verification
python verify_telemetry_pipeline.py
```

### `supabase/migrations/`
Contains Supabase migration files:
- `20250720062804_init_telemetry.sql` - Initial telemetry schema

## Setup Instructions

1. **Configure Environment Variables:**
   ```bash
   cp ../backend/.env.example ../backend/.env
   # Edit .env with your Supabase credentials
   ```

2. **Create Database Schema:**
   ```bash
   python create_telemetry_schema.py
   ```

3. **Start Flask Server:**
   ```bash
   cd ../backend
   python run_enhanced_supabase.py
   ```

4. **Verify Pipeline:**
   ```bash
   python verify_telemetry_pipeline.py
   ```

## Database Schema

The telemetry table includes fields for:
- **Flight Control**: mode, armed status, flight time
- **Attitude**: roll, pitch, yaw angles and rates
- **GPS Data**: coordinates, altitude, speed, fix quality
- **Sensors**: accelerometer, magnetometer, barometer
- **Battery**: voltage, current, consumption
- **Motors**: PWM outputs for up to 8 motors
- **PID Controllers**: P, I, D values for all axes
- **RC Inputs**: stick positions and auxiliary channels
- **System Status**: failsafe, vibration, temperature

## Performance Optimizations

The schema includes several performance optimizations:
- **Indexes**: Optimized for time-series queries
- **Data Types**: Efficient numeric types for telemetry data
- **Triggers**: Automatic timestamp updates
- **Comments**: Full documentation for all fields

## Troubleshooting

### Common Issues

1. **"Missing Supabase credentials"**
   - Check that `.env` file exists and contains valid credentials
   - Verify `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`

2. **"Table already exists"**
   - The migration is idempotent and safe to run multiple times
   - Use `IF NOT EXISTS` clauses prevent conflicts

3. **"Connection refused"**
   - Ensure Flask server is running on the correct port
   - Check firewall settings
   - Verify network connectivity to Supabase

### Verification Checklist

- [ ] Environment variables configured
- [ ] Supabase project accessible
- [ ] Database schema created
- [ ] Flask server running
- [ ] API endpoints responding
- [ ] Data parsing working
- [ ] Batch operations functional
- [ ] Performance acceptable

## Next Steps

After successful setup:
1. Apply advanced optimizations from `../supabase_advanced_optimizations.sql`
2. Configure monitoring and alerting
3. Set up automated backups
4. Implement data retention policies
5. Scale based on usage patterns