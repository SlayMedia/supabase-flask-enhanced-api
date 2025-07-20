"""
Enhanced Flask server with Supabase integration for telemetry data storage.
Extends the existing telemetry parsing with database persistence.
"""
import os
import logging
from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
from datetime import datetime
import json
from telemetry_storage import telemetry_storage
from supabase_client import supabase_client

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Simple telemetry parser class
class SimpleTelemetryParser:
    """Simple telemetry parser for key-value pair data"""
    
    def parse_telemetry_line(self, raw_data: str) -> dict:
        """Parse a telemetry line in key:value,key:value format"""
        try:
            parsed_data = {}
            
            # Handle different formats
            if ',' in raw_data:
                # Key-value pairs separated by commas
                pairs = raw_data.strip().split(',')
                for pair in pairs:
                    if ':' in pair:
                        key, value = pair.split(':', 1)
                        parsed_data[key.strip().lower()] = self._convert_value(value.strip())
            else:
                # Single key-value pair
                if ':' in raw_data:
                    key, value = raw_data.split(':', 1)
                    parsed_data[key.strip().lower()] = self._convert_value(value.strip())
            
            # Add metadata
            parsed_data['raw_data'] = raw_data
            parsed_data['parser_version'] = '1.0'
            parsed_data['data_source'] = 'flask_api'
            
            return parsed_data
            
        except Exception as e:
            logger.error(f"Error parsing telemetry: {e}")
            return {
                'raw_data': raw_data,
                'parser_version': '1.0',
                'data_source': 'flask_api',
                'parse_error': str(e)
            }
    
    def _convert_value(self, value: str):
        """Convert string value to appropriate type"""
        try:
            # Try integer first
            if '.' not in value:
                return int(value)
            # Try float
            return float(value)
        except ValueError:
            # Return as string
            return value
    
    def get_current_timestamp(self) -> str:
        """Get current timestamp in ISO format"""
        return datetime.utcnow().isoformat()
    
    def get_field_definitions(self) -> dict:
        """Get field definitions for telemetry data"""
        return {
            'roll': 'Roll angle in degrees',
            'pitch': 'Pitch angle in degrees', 
            'yaw': 'Yaw angle in degrees',
            'alt': 'Altitude in meters',
            'gps_lat': 'GPS latitude',
            'gps_lon': 'GPS longitude',
            'bat_v': 'Battery voltage',
            'armed': 'Armed status (0/1)',
            'raw_data': 'Original telemetry string',
            'parser_version': 'Parser version',
            'data_source': 'Data source identifier'
        }

# Initialize telemetry parser
telemetry_parser = SimpleTelemetryParser()

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint with Supabase status"""
    try:
        supabase_healthy = supabase_client.health_check()
        batch_status = telemetry_storage.get_batch_status()
        
        return jsonify({
            'status': 'healthy',
            'timestamp': telemetry_parser.get_current_timestamp(),
            'supabase_connected': supabase_healthy,
            'batch_status': batch_status
        }), 200
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({
            'status': 'unhealthy',
            'error': str(e)
        }), 500

@app.route('/telemetry/parse', methods=['POST'])
def parse_telemetry():
    """Parse telemetry data and optionally store to Supabase"""
    try:
        # Get raw telemetry data
        raw_data = request.get_data(as_text=True)
        if not raw_data:
            return jsonify({'error': 'No telemetry data provided'}), 400
        
        # Parse telemetry
        parsed_data = telemetry_parser.parse_telemetry_line(raw_data)
        
        # Check if storage is requested
        store_data = request.args.get('store', 'true').lower() == 'true'
        
        response = {
            'success': True,
            'parsed_data': parsed_data,
            'timestamp': telemetry_parser.get_current_timestamp()
        }
        
        if store_data:
            # Store to Supabase
            storage_success = telemetry_storage.add_telemetry_data(parsed_data)
            response['stored'] = storage_success
            response['batch_status'] = telemetry_storage.get_batch_status()
            
            if not storage_success:
                logger.warning("Failed to store telemetry data to Supabase")
        
        return jsonify(response), 200
        
    except Exception as e:
        logger.error(f"Error parsing telemetry: {e}")
        return jsonify({
            'error': f'Failed to parse telemetry: {str(e)}',
            'timestamp': telemetry_parser.get_current_timestamp()
        }), 500

@app.route('/telemetry/batch/flush', methods=['POST'])
def flush_telemetry_batch():
    """Manually flush pending telemetry batch to Supabase"""
    try:
        success = telemetry_storage.flush_batch()
        batch_status = telemetry_storage.get_batch_status()
        
        return jsonify({
            'success': success,
            'message': 'Batch flushed successfully' if success else 'Batch flush failed',
            'batch_status': batch_status,
            'timestamp': telemetry_parser.get_current_timestamp()
        }), 200 if success else 500
        
    except Exception as e:
        logger.error(f"Error flushing batch: {e}")
        return jsonify({
            'error': f'Failed to flush batch: {str(e)}',
            'timestamp': telemetry_parser.get_current_timestamp()
        }), 500

@app.route('/telemetry/batch/status', methods=['GET'])
def get_batch_status():
    """Get current batch status"""
    try:
        batch_status = telemetry_storage.get_batch_status()
        return jsonify({
            'batch_status': batch_status,
            'timestamp': telemetry_parser.get_current_timestamp()
        }), 200
        
    except Exception as e:
        logger.error(f"Error getting batch status: {e}")
        return jsonify({
            'error': f'Failed to get batch status: {str(e)}',
            'timestamp': telemetry_parser.get_current_timestamp()
        }), 500

@app.route('/telemetry/query', methods=['GET'])
def query_telemetry():
    """Query telemetry data from Supabase"""
    try:
        # Get query parameters
        limit = int(request.args.get('limit', 100))
        offset = int(request.args.get('offset', 0))
        order_by = request.args.get('order_by', 'created_at')
        order_desc = request.args.get('desc', 'true').lower() == 'true'
        
        # Build query
        query = supabase_client.client.table('telemetry').select('*')
        
        if order_desc:
            query = query.order(order_by, desc=True)
        else:
            query = query.order(order_by)
        
        query = query.range(offset, offset + limit - 1)
        
        # Execute query
        response = query.execute()
        
        return jsonify({
            'success': True,
            'data': response.data,
            'count': len(response.data),
            'limit': limit,
            'offset': offset,
            'timestamp': telemetry_parser.get_current_timestamp()
        }), 200
        
    except Exception as e:
        logger.error(f"Error querying telemetry: {e}")
        return jsonify({
            'error': f'Failed to query telemetry: {str(e)}',
            'timestamp': telemetry_parser.get_current_timestamp()
        }), 500

@app.route('/config', methods=['GET'])
def get_config():
    """Get current configuration"""
    try:
        return jsonify({
            'telemetry_fields': telemetry_parser.get_field_definitions(),
            'batch_size': telemetry_storage.batch_size,
            'max_retries': telemetry_storage.max_retries,
            'supabase_project_id': os.getenv('SUPABASE_PROJECT_ID'),
            'timestamp': telemetry_parser.get_current_timestamp()
        }), 200
    except Exception as e:
        logger.error(f"Error getting config: {e}")
        return jsonify({
            'error': f'Failed to get config: {str(e)}',
            'timestamp': telemetry_parser.get_current_timestamp()
        }), 500

if __name__ == '__main__':
    # Ensure Supabase connection on startup
    try:
        if supabase_client.health_check():
            logger.info("Supabase connection verified successfully")
        else:
            logger.warning("Supabase connection check failed - continuing anyway")
    except Exception as e:
        logger.error(f"Supabase initialization error: {e}")
    
    # Start Flask server
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_DEBUG', 'True').lower() == 'true'
    
    logger.info(f"Starting Flask server on port {port} with debug={debug}")
    app.run(host='0.0.0.0', port=port, debug=debug)