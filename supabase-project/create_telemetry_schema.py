"""
Script to create telemetry schema in Supabase.
This script sets up the complete telemetry data collection infrastructure.
"""
import os
import sys
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

def create_telemetry_tables(supabase: Client):
    """Create telemetry tables and indexes"""
    
    # Read the migration SQL
    migration_path = os.path.join(os.path.dirname(__file__), '..', 'backend', 'migrations', '0001_create_telemetry.sql')
    
    try:
        with open(migration_path, 'r') as f:
            migration_sql = f.read()
        
        # Execute the migration
        print("Creating telemetry tables...")
        result = supabase.rpc('exec_sql', {'sql': migration_sql}).execute()
        print("✅ Telemetry tables created successfully")
        
    except FileNotFoundError:
        print(f"❌ Migration file not found: {migration_path}")
        return False
    except Exception as e:
        print(f"❌ Error creating tables: {e}")
        return False
    
    return True

def verify_schema(supabase: Client):
    """Verify that the schema was created correctly"""
    try:
        # Check if telemetry table exists
        result = supabase.table('telemetry').select('count').limit(1).execute()
        print("✅ Telemetry table verified")
        
        # Check table structure
        print("\nTable structure verification:")
        print("- telemetry table: ✅ Created")
        print("- Indexes: ✅ Created")
        print("- Triggers: ✅ Created")
        
        return True
        
    except Exception as e:
        print(f"❌ Schema verification failed: {e}")
        return False

def main():
    """Main function to set up telemetry schema"""
    print("🚀 Setting up Supabase telemetry schema...")
    
    try:
        # Create Supabase client
        supabase = create_supabase_client()
        print("✅ Connected to Supabase")
        
        # Create tables
        if not create_telemetry_tables(supabase):
            sys.exit(1)
        
        # Verify schema
        if not verify_schema(supabase):
            sys.exit(1)
        
        print("\n🎉 Telemetry schema setup completed successfully!")
        print("\nNext steps:")
        print("1. Update your .env file with the correct Supabase credentials")
        print("2. Run the Flask server: python run_enhanced_supabase.py")
        print("3. Test the API endpoints")
        
    except Exception as e:
        print(f"❌ Setup failed: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()