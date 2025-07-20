"""
Script to verify the telemetry data pipeline is working correctly.
Tests the complete flow from data ingestion to storage and retrieval.
"""
import os
import sys
import json
import time
import requests
from datetime import datetime
from supabase import create_client, Client
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def create_supabase_client() -> Client:
    """Create and return Supabase client"""
    url = os.getenv('SUPABASE_URL')
    key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
    
    if not url or not key:
        raise ValueError("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variables")
    
    return create_client(url, key)

def test_supabase_connection(supabase: Client) -> bool:
    """Test direct Supabase connection"""
    try:
        result = supabase.table('telemetry').select('count').limit(1).execute()
        print("✅ Direct Supabase connection: OK")
        return True
    except Exception as e:
        print(f"❌ Direct Supabase connection failed: {e}")
        return False

def test_flask_api_health(base_url: str) -> bool:
    """Test Flask API health endpoint"""
    try:
        response = requests.get(f"{base_url}/health", timeout=10)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Flask API health: {data.get('status', 'unknown')}")
            print(f"   Supabase connected: {data.get('supabase_connected', False)}")
            return data.get('supabase_connected', False)
        else:
            print(f"❌ Flask API health check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Flask API connection failed: {e}")
        return False

def test_telemetry_parsing(base_url: str) -> bool:
    """Test telemetry data parsing endpoint"""
    try:
        # Test data
        test_telemetry = "roll:15.2,pitch:8.1,yaw:45.0,alt:150,bat_v:12.4,armed:1"
        
        response = requests.post(
            f"{base_url}/telemetry/parse",
            data=test_telemetry,
            headers={'Content-Type': 'text/plain'},
            params={'store': 'true'},
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                print("✅ Telemetry parsing: OK")
                print(f"   Parsed fields: {len(data.get('parsed_data', {}))}")
                print(f"   Stored to Supabase: {data.get('stored', False)}")
                return True
            else:
                print(f"❌ Telemetry parsing failed: {data}")
                return False
        else:
            print(f"❌ Telemetry parsing request failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Telemetry parsing test failed: {e}")
        return False

def test_batch_operations(base_url: str) -> bool:
    """Test batch operations"""
    try:
        # Check batch status
        response = requests.get(f"{base_url}/telemetry/batch/status", timeout=10)
        if response.status_code == 200:
            data = response.json()
            print("✅ Batch status check: OK")
            print(f"   Pending records: {data.get('batch_status', {}).get('pending_records', 0)}")
            
            # Test manual flush
            flush_response = requests.post(f"{base_url}/telemetry/batch/flush", timeout=10)
            if flush_response.status_code == 200:
                flush_data = flush_response.json()
                print(f"✅ Batch flush: {flush_data.get('message', 'OK')}")
                return True
            else:
                print(f"❌ Batch flush failed: {flush_response.status_code}")
                return False
        else:
            print(f"❌ Batch status check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Batch operations test failed: {e}")
        return False

def test_data_retrieval(base_url: str, supabase: Client) -> bool:
    """Test data retrieval from both API and direct Supabase"""
    try:
        # Test API query
        response = requests.get(f"{base_url}/telemetry/query?limit=5", timeout=10)
        if response.status_code == 200:
            data = response.json()
            api_count = data.get('count', 0)
            print(f"✅ API data retrieval: {api_count} records")
        else:
            print(f"❌ API data retrieval failed: {response.status_code}")
            return False
        
        # Test direct Supabase query
        result = supabase.table('telemetry').select('*').limit(5).execute()
        db_count = len(result.data)
        print(f"✅ Direct DB query: {db_count} records")
        
        return True
        
    except Exception as e:
        print(f"❌ Data retrieval test failed: {e}")
        return False

def test_configuration(base_url: str) -> bool:
    """Test configuration endpoint"""
    try:
        response = requests.get(f"{base_url}/config", timeout=10)
        if response.status_code == 200:
            data = response.json()
            print("✅ Configuration endpoint: OK")
            print(f"   Batch size: {data.get('batch_size', 'unknown')}")
            print(f"   Max retries: {data.get('max_retries', 'unknown')}")
            print(f"   Telemetry fields: {len(data.get('telemetry_fields', {}))}")
            return True
        else:
            print(f"❌ Configuration endpoint failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Configuration test failed: {e}")
        return False

def run_performance_test(base_url: str, num_requests: int = 10) -> bool:
    """Run a simple performance test"""
    try:
        print(f"\n🚀 Running performance test ({num_requests} requests)...")
        
        start_time = time.time()
        successful_requests = 0
        
        for i in range(num_requests):
            test_data = f"roll:{15.2 + i},pitch:{8.1 + i},alt:{150 + i*10},test_id:{i}"
            
            response = requests.post(
                f"{base_url}/telemetry/parse",
                data=test_data,
                headers={'Content-Type': 'text/plain'},
                params={'store': 'true'},
                timeout=5
            )
            
            if response.status_code == 200:
                successful_requests += 1
            
            if i % 5 == 0:
                print(f"   Progress: {i+1}/{num_requests}")
        
        end_time = time.time()
        duration = end_time - start_time
        
        print(f"✅ Performance test completed:")
        print(f"   Successful requests: {successful_requests}/{num_requests}")
        print(f"   Total time: {duration:.2f}s")
        print(f"   Requests per second: {num_requests/duration:.2f}")
        
        return successful_requests == num_requests
        
    except Exception as e:
        print(f"❌ Performance test failed: {e}")
        return False

def main():
    """Main function to run all pipeline tests"""
    print("🔍 Verifying Supabase telemetry pipeline...\n")
    
    # Configuration
    flask_host = os.getenv('FLASK_HOST', 'localhost')
    flask_port = os.getenv('FLASK_PORT', '5000')
    base_url = f"http://{flask_host}:{flask_port}"
    
    print(f"Testing Flask API at: {base_url}")
    print(f"Supabase URL: {os.getenv('SUPABASE_URL', 'Not set')}\n")
    
    try:
        # Create Supabase client
        supabase = create_supabase_client()
        
        # Run tests
        tests = [
            ("Supabase Connection", lambda: test_supabase_connection(supabase)),
            ("Flask API Health", lambda: test_flask_api_health(base_url)),
            ("Telemetry Parsing", lambda: test_telemetry_parsing(base_url)),
            ("Batch Operations", lambda: test_batch_operations(base_url)),
            ("Data Retrieval", lambda: test_data_retrieval(base_url, supabase)),
            ("Configuration", lambda: test_configuration(base_url)),
        ]
        
        passed_tests = 0
        total_tests = len(tests)
        
        for test_name, test_func in tests:
            print(f"\n--- {test_name} ---")
            if test_func():
                passed_tests += 1
            else:
                print(f"❌ {test_name} failed")
        
        # Performance test (optional)
        if passed_tests == total_tests:
            if run_performance_test(base_url):
                passed_tests += 1
                total_tests += 1
        
        # Summary
        print(f"\n{'='*50}")
        print(f"PIPELINE VERIFICATION SUMMARY")
        print(f"{'='*50}")
        print(f"Tests passed: {passed_tests}/{total_tests}")
        
        if passed_tests == total_tests:
            print("🎉 All tests passed! Pipeline is working correctly.")
            print("\nYour telemetry pipeline is ready for production use.")
        else:
            print(f"❌ {total_tests - passed_tests} test(s) failed. Please check the configuration.")
            sys.exit(1)
        
    except Exception as e:
        print(f"❌ Pipeline verification failed: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()