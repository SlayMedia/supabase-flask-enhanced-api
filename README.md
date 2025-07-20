# Supabase Flask Enhanced API

Advanced Supabase integration with Flask API featuring real-time streaming, analytics, caching, monitoring, and visualization capabilities for telemetry data processing.

## 🚀 Features

### Core Capabilities
- **Advanced Supabase Integration**: Optimized database operations with connection pooling
- **Real-time Telemetry Streaming**: Live data processing and storage
- **Batch Processing**: Efficient bulk data operations with retry logic
- **Performance Monitoring**: Built-in metrics and health checks
- **Analytics & Visualization**: Materialized views and performance dashboards
- **Caching Layer**: Redis integration for improved performance
- **Database Optimizations**: Advanced indexing, partitioning, and query optimization

### Enhanced Flask API Features
- **RESTful Endpoints**: Comprehensive API for telemetry data operations
- **Authentication**: Secure API access with token-based authentication
- **Error Handling**: Robust error handling with detailed logging
- **Health Monitoring**: Real-time system health and performance metrics
- **Scalable Architecture**: Designed for high-throughput telemetry workloads

## 📋 Table of Contents

- [Installation](#installation)
- [Configuration](#configuration)
- [API Endpoints](#api-endpoints)
- [Database Schema](#database-schema)
- [Performance Optimizations](#performance-optimizations)
- [Monitoring & Analytics](#monitoring--analytics)
- [Development](#development)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)

## 🛠 Installation

### Prerequisites
- Python 3.8+
- PostgreSQL 12+ (via Supabase)
- Redis (optional, for caching)

### Quick Start

1. **Clone the repository:**
```bash
git clone https://github.com/SlayMedia/supabase-flask-enhanced-api.git
cd supabase-flask-enhanced-api
```

2. **Install dependencies:**
```bash
pip install -r requirements.txt
```

3. **Configure environment variables:**
```bash
cp backend/.env.example backend/.env
# Edit backend/.env with your Supabase credentials
```

4. **Run database migrations:**
```bash
cd backend
python -c "from supabase_client import supabase_client; print('Supabase connected:', supabase_client.health_check())"
```

5. **Start the Flask server:**
```bash
python run_enhanced_supabase.py
```

## ⚙️ Configuration

### Environment Variables

Create a `.env` file in the `backend/` directory:

```env
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
SUPABASE_ACCESS_TOKEN=your_access_token
SUPABASE_PROJECT_ID=your_project_id

# Flask Configuration
FLASK_ENV=development
FLASK_DEBUG=True
PORT=5000

# Optional: Redis Configuration
REDIS_URL=redis://localhost:6379
```

### Database Setup

1. **Apply the telemetry table migration:**
```sql
-- Run the SQL from backend/migrations/0001_create_telemetry.sql
```

2. **Apply advanced optimizations:**
```sql
-- Run the SQL from supabase_advanced_optimizations.sql
```

## 🔌 API Endpoints

### Health & Status

#### `GET /health`
Check system health and Supabase connectivity.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-07-20T22:41:31Z",
  "supabase_connected": true,
  "batch_status": {
    "pending_records": 0,
    "batch_size": 500,
    "batch_full": false,
    "supabase_healthy": true
  }
}
```

### Telemetry Processing

#### `POST /telemetry/parse`
Parse and optionally store telemetry data.

**Request Body:** Raw telemetry string (e.g., "roll:15.2,pitch:8.1,alt:150")

**Query Parameters:**
- `store` (boolean): Whether to store data in Supabase (default: true)

**Response:**
```json
{
  "success": true,
  "parsed_data": {
    "roll": 15.2,
    "pitch": 8.1,
    "alt": 150,
    "raw_data": "roll:15.2,pitch:8.1,alt:150",
    "parser_version": "1.0",
    "data_source": "flask_api"
  },
  "stored": true,
  "batch_status": {
    "pending_records": 1,
    "batch_size": 500,
    "batch_full": false
  },
  "timestamp": "2025-07-20T22:41:31Z"
}
```

#### `GET /telemetry/query`
Query stored telemetry data.

**Query Parameters:**
- `limit` (int): Number of records to return (default: 100)
- `offset` (int): Offset for pagination (default: 0)
- `order_by` (string): Field to order by (default: "created_at")
- `desc` (boolean): Descending order (default: true)

**Response:**
```json
{
  "success": true,
  "data": [...],
  "count": 100,
  "limit": 100,
  "offset": 0,
  "timestamp": "2025-07-20T22:41:31Z"
}
```

### Batch Operations

#### `POST /telemetry/batch/flush`
Manually flush pending telemetry batch to Supabase.

**Response:**
```json
{
  "success": true,
  "message": "Batch flushed successfully",
  "batch_status": {
    "pending_records": 0,
    "batch_size": 500,
    "batch_full": false
  },
  "timestamp": "2025-07-20T22:41:31Z"
}
```

#### `GET /telemetry/batch/status`
Get current batch processing status.

### Configuration

#### `GET /config`
Get current system configuration.

**Response:**
```json
{
  "telemetry_fields": {
    "roll": "Roll angle in degrees",
    "pitch": "Pitch angle in degrees",
    "yaw": "Yaw angle in degrees",
    "alt": "Altitude in meters",
    "gps_lat": "GPS latitude",
    "gps_lon": "GPS longitude",
    "bat_v": "Battery voltage",
    "armed": "Armed status (0/1)"
  },
  "batch_size": 500,
  "max_retries": 3,
  "supabase_project_id": "your_project_id",
  "timestamp": "2025-07-20T22:41:31Z"
}
```

## 🗄️ Database Schema

### Telemetry Table

The main telemetry table supports 40+ fields for comprehensive drone flight data:

```sql
CREATE TABLE public.telemetry (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Flight Control
    flight_mode VARCHAR(50),
    armed BOOLEAN,
    flight_time_seconds NUMERIC(10,2),
    
    -- Attitude (degrees)
    roll_degrees NUMERIC(8,3),
    pitch_degrees NUMERIC(8,3),
    yaw_degrees NUMERIC(8,3),
    
    -- GPS Data
    gps_latitude NUMERIC(12,8),
    gps_longitude NUMERIC(12,8),
    gps_altitude_m NUMERIC(8,2),
    
    -- Battery
    battery_voltage_v NUMERIC(6,3),
    battery_current_a NUMERIC(8,3),
    
    -- Motor Outputs
    motor1_pwm INTEGER,
    motor2_pwm INTEGER,
    motor3_pwm INTEGER,
    motor4_pwm INTEGER,
    
    -- Raw data for debugging
    raw_data TEXT,
    parser_version VARCHAR(20),
    data_source VARCHAR(100)
);
```

### Indexes and Optimizations

- **BRIN indexes** for time-series data
- **Composite indexes** for common query patterns
- **Partial indexes** for hot data subsets
- **GIN indexes** for JSONB queries

## 🚀 Performance Optimizations

### Database Optimizations

1. **Advanced Indexing Strategy:**
   - BRIN indexes for timestamp columns (optimal for time-series)
   - Composite indexes for user+time queries
   - Partial indexes for frequently accessed subsets

2. **Table Partitioning:**
   - Monthly partitions for scalability
   - Automated partition management with pg_partman
   - 12-month data retention policy

3. **Connection Pooling:**
   - Optimized connection limits
   - Write-heavy workload tuning
   - Query plan caching

### Application Optimizations

1. **Batch Processing:**
   - Configurable batch sizes (default: 500 records)
   - Exponential backoff retry logic
   - Chunked inserts for large datasets

2. **Memory Management:**
   - Streaming data processing
   - Garbage collection between batches
   - Efficient data type usage

3. **Caching Layer:**
   - Redis integration for frequently accessed data
   - Query result caching
   - Session state management

## 📊 Monitoring & Analytics

### Real-time Monitoring

The system includes comprehensive monitoring capabilities:

1. **Performance Metrics:**
   - Events per minute
   - Active sessions
   - Database size and health
   - Index usage statistics

2. **Materialized Views:**
   - Daily analytics aggregations
   - Hourly statistics for real-time monitoring
   - Performance trend analysis

3. **Health Checks:**
   - Supabase connectivity monitoring
   - Batch processing status
   - System resource utilization

### Analytics Functions

```sql
-- Get index usage statistics
SELECT * FROM public.get_index_usage_stats();

-- Analyze slow queries
SELECT * FROM public.get_slow_queries(1000);

-- Get table size information
SELECT * FROM public.get_table_stats();
```

## 🔧 Development

### Project Structure

```
supabase-flask-enhanced-api/
├── backend/
│   ├── run_enhanced_supabase.py    # Main Flask application
│   ├── supabase_client.py          # Supabase client wrapper
│   ├── telemetry_storage.py        # Batch storage handler
│   ├── telemetry_parser.py         # Telemetry data parser
│   ├── requirements.txt            # Python dependencies
│   ├── .env                        # Environment configuration
│   └── migrations/
│       └── 0001_create_telemetry.sql
├── supabase-project/
│   ├── create_telemetry_schema.py  # Schema creation script
│   ├── verify_telemetry_pipeline.py # Pipeline verification
│   └── supabase/
│       └── migrations/
├── supabase_advanced_optimizations.sql
├── README.md
└── .gitignore
```

### Testing

1. **Health Check:**
```bash
curl http://localhost:5000/health
```

2. **Submit Telemetry:**
```bash
curl -X POST http://localhost:5000/telemetry/parse \
  -H "Content-Type: text/plain" \
  -d "roll:15.2,pitch:8.1,alt:150,bat_v:12.4"
```

3. **Query Data:**
```bash
curl "http://localhost:5000/telemetry/query?limit=10"
```

### Adding New Features

1. **Extend Telemetry Parser:**
   - Add new field mappings in `telemetry_parser.py`
   - Update field definitions in `get_field_definitions()`

2. **Add New Endpoints:**
   - Implement in `run_enhanced_supabase.py`
   - Follow existing error handling patterns

3. **Database Changes:**
   - Create migration files in `migrations/`
   - Update schema documentation

## 🚀 Deployment

### Production Deployment

1. **Environment Setup:**
```bash
export FLASK_ENV=production
export FLASK_DEBUG=False
export SUPABASE_URL=your_production_url
export SUPABASE_SERVICE_ROLE_KEY=your_production_key
```

2. **Database Optimizations:**
```bash
# Apply production optimizations
psql -f supabase_advanced_optimizations.sql
```

3. **Process Management:**
```bash
# Using gunicorn for production
pip install gunicorn
gunicorn -w 4 -b 0.0.0.0:5000 run_enhanced_supabase:app
```

### Docker Deployment

```dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY backend/ .
EXPOSE 5000

CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "run_enhanced_supabase:app"]
```

## 🔍 Troubleshooting

### Common Issues

1. **Supabase Connection Failed:**
   - Verify environment variables
   - Check network connectivity
   - Validate service role key permissions

2. **Batch Processing Errors:**
   - Check batch size configuration
   - Monitor memory usage
   - Review error logs for specific failures

3. **Performance Issues:**
   - Monitor index usage with `get_index_usage_stats()`
   - Check slow queries with `get_slow_queries()`
   - Verify materialized view refresh schedule

### Logging

Application logs include:
- Request/response details
- Database operation status
- Batch processing metrics
- Error stack traces

### Monitoring Commands

```bash
# Check system health
curl http://localhost:5000/health

# Monitor batch status
curl http://localhost:5000/telemetry/batch/status

# Get configuration
curl http://localhost:5000/config
```

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📞 Support

For support and questions:
- Create an issue in the GitHub repository
- Check the troubleshooting section
- Review the API documentation

---

**Built with ❤️ for high-performance telemetry data processing**