"""
Telemetry data storage module with batching and error handling.
Handles bulk inserts to Supabase with retry logic and chunking.
"""
import logging
import time
from typing import List, Dict, Any, Optional
from datetime import datetime
import json
from supabase_client import supabase_client

logger = logging.getLogger(__name__)

class TelemetryStorage:
    """Handles telemetry data storage to Supabase with batching and error handling"""
    
    def __init__(self, batch_size: int = 500, max_retries: int = 3):
        self.batch_size = batch_size
        self.max_retries = max_retries
        self.pending_batch: List[Dict[str, Any]] = []
        
    def add_telemetry_data(self, telemetry_data: Dict[str, Any]) -> bool:
        """
        Add telemetry data to pending batch.
        Returns True if data was added successfully.
        """
        try:
            # Add timestamp if not present
            if 'created_at' not in telemetry_data:
                telemetry_data['created_at'] = datetime.utcnow().isoformat()
            
            # Add to pending batch
            self.pending_batch.append(telemetry_data)
            
            # Check if batch is full and needs to be flushed
            if len(self.pending_batch) >= self.batch_size:
                return self.flush_batch()
            
            return True
            
        except Exception as e:
            logger.error(f"Error adding telemetry data to batch: {e}")
            return False
    
    def flush_batch(self) -> bool:
        """
        Flush the current batch to Supabase.
        Returns True if all data was successfully stored.
        """
        if not self.pending_batch:
            return True
        
        try:
            success = self._write_telemetry_batch(self.pending_batch)
            if success:
                logger.info(f"Successfully flushed batch of {len(self.pending_batch)} records")
                self.pending_batch.clear()
            return success
            
        except Exception as e:
            logger.error(f"Error flushing batch: {e}")
            return False
    
    def _write_telemetry_batch(self, data: List[Dict[str, Any]]) -> bool:
        """
        Write a batch of telemetry data to Supabase with chunking and retry logic.
        """
        if not data:
            return True
        
        # Split into chunks if batch is too large
        chunks = [data[i:i + self.batch_size] for i in range(0, len(data), self.batch_size)]
        
        for chunk_idx, chunk in enumerate(chunks):
            success = self._write_chunk_with_retry(chunk, chunk_idx)
            if not success:
                logger.error(f"Failed to write chunk {chunk_idx + 1}/{len(chunks)}")
                return False
        
        return True
    
    def _write_chunk_with_retry(self, chunk: List[Dict[str, Any]], chunk_idx: int) -> bool:
        """
        Write a single chunk with exponential backoff retry logic.
        """
        for attempt in range(self.max_retries):
            try:
                response = (
                    supabase_client.client
                    .table("telemetry")
                    .insert(chunk)
                    .execute()
                )
                
                if response.data:
                    logger.debug(f"Chunk {chunk_idx + 1} written successfully on attempt {attempt + 1}")
                    return True
                else:
                    logger.warning(f"No data returned for chunk {chunk_idx + 1}, attempt {attempt + 1}")
                
            except Exception as e:
                wait_time = (2 ** attempt) * 0.5  # Exponential backoff: 0.5s, 1s, 2s
                logger.warning(
                    f"Attempt {attempt + 1}/{self.max_retries} failed for chunk {chunk_idx + 1}: {e}. "
                    f"Retrying in {wait_time}s..."
                )
                
                if attempt < self.max_retries - 1:
                    time.sleep(wait_time)
                else:
                    logger.error(f"All {self.max_retries} attempts failed for chunk {chunk_idx + 1}")
        
        return False
    
    def get_batch_status(self) -> Dict[str, Any]:
        """Get current batch status information"""
        return {
            'pending_records': len(self.pending_batch),
            'batch_size': self.batch_size,
            'batch_full': len(self.pending_batch) >= self.batch_size,
            'supabase_healthy': supabase_client.health_check()
        }

# Global storage instance
telemetry_storage = TelemetryStorage()