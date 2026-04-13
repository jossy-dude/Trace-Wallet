"""
Vault Pro - FastAPI Backend
Lightweight, scalable financial tracking system
"""
import asyncio
import json
import logging
import os
import socket
import sqlite3
import sys
import threading
import uuid
from datetime import datetime
from pathlib import Path
from typing import Optional, List, Dict, Any

from fastapi import FastAPI, HTTPException, Request, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import uvicorn

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
    ]
)
logger = logging.getLogger("vault_pro")

# Get app data directory
if sys.platform == "win32":
    APP_DIR = Path(os.environ.get('APPDATA', '.')) / "VaultPro"
elif sys.platform == "darwin":
    APP_DIR = Path.home() / "Library" / "Application Support" / "VaultPro"
else:
    APP_DIR = Path.home() / ".vault_pro"

APP_DIR.mkdir(parents=True, exist_ok=True)
DB_PATH = APP_DIR / "vault.db"
CONFIG_PATH = APP_DIR / "config.json"

# Database setup
def init_database():
    """Initialize SQLite database with proper schema"""
    conn = sqlite3.connect(str(DB_PATH))
    cursor = conn.cursor()
    
    # Transactions table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS transactions (
            id TEXT PRIMARY KEY,
            amount REAL NOT NULL,
            transaction_type TEXT NOT NULL,
            category TEXT,
            subcategory TEXT,
            account TEXT,
            counterparty_name TEXT,
            counterparty_phone TEXT,
            description TEXT,
            reference_number TEXT,
            transaction_date TIMESTAMP NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            source TEXT DEFAULT 'manual',
            raw_sms TEXT,
            is_synced INTEGER DEFAULT 0
        )
    ''')
    
    # People table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS people (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phone TEXT UNIQUE,
            email TEXT,
            aliases TEXT,
            notes TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Devices table (for P2P sync)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS devices (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            device_type TEXT,
            ip_address TEXT,
            token TEXT,
            status TEXT DEFAULT 'pending',
            last_seen TIMESTAMP,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Settings table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT
        )
    ''')
    
    conn.commit()
    conn.close()
    logger.info(f"Database initialized at {DB_PATH}")

# Initialize database on startup
init_database()

# FastAPI app
app = FastAPI(title="Vault Pro API", version="1.2.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict to specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic models
class TransactionCreate(BaseModel):
    amount: float
    transaction_type: str  # income, expense, transfer
    category: Optional[str] = None
    subcategory: Optional[str] = None
    account: Optional[str] = None
    counterparty_name: Optional[str] = None
    counterparty_phone: Optional[str] = None
    description: Optional[str] = None
    reference_number: Optional[str] = None
    transaction_date: Optional[datetime] = None
    source: Optional[str] = 'manual'
    raw_sms: Optional[str] = None

class TransactionUpdate(BaseModel):
    amount: Optional[float] = None
    category: Optional[str] = None
    subcategory: Optional[str] = None
    description: Optional[str] = None

class PersonCreate(BaseModel):
    name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    aliases: Optional[List[str]] = []
    notes: Optional[str] = None

class SMSData(BaseModel):
    phone: str
    message: str
    timestamp: Optional[datetime] = None

class BatchSMSData(BaseModel):
    messages: List[SMSData]

class DeviceRegister(BaseModel):
    name: str
    device_type: str
    token: str

# Helper functions
def get_db_connection():
    """Get database connection with row factory"""
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    return conn

def parse_ethiopian_sms(message: str) -> Optional[Dict[str, Any]]:
    """Parse SMS from Ethiopian banks (CBE, Telebirr, BOA)"""
    import re
    
    message = message.strip()
    
    # CBE patterns
    cbe_patterns = [
        r'(?:CBE|Commercial Bank of Ethiopia).*?(?:debited|credited).*?ETB\s*([\d,]+).*?(?:from|to)\s*(.+?)(?:\s|$)',
        r'ETB\s*([\d,]+).*?(?:debited|credited).*(?:from|to)\s*(.+?)(?:\s|$)',
    ]
    
    # Telebirr patterns
    telebirr_patterns = [
        r'(?:Telebirr|telebirr).*?(?:sent|received).*?ETB\s*([\d,]+).*?(?:from|to)\s*(.+?)(?:\s|$)',
        r'ETB\s*([\d,]+).*?(?:sent|received).*(?:from|to)\s*(.+?)(?:\s|$)',
    ]
    
    # BOA patterns
    boa_patterns = [
        r'(?:BOA|Bank of Abyssinia).*?(?:debited|credited).*?ETB\s*([\d,]+).*?(?:from|to)\s*(.+?)(?:\s|$)',
    ]
    
    all_patterns = cbe_patterns + telebirr_patterns + boa_patterns
    
    for pattern in all_patterns:
        match = re.search(pattern, message, re.IGNORECASE)
        if match:
            amount_str = match.group(1).replace(',', '')
            try:
                amount = float(amount_str)
            except ValueError:
                continue
            
            counterparty = match.group(2).strip()
            
            # Determine transaction type
            is_credit = any(word in message.lower() for word in ['credited', 'received', 'deposited'])
            transaction_type = 'income' if is_credit else 'expense'
            
            # Determine bank
            bank = 'Unknown'
            if any(p in pattern for p in cbe_patterns):
                bank = 'CBE'
            elif any(p in pattern for p in telebirr_patterns):
                bank = 'Telebirr'
            elif any(p in pattern for p in boa_patterns):
                bank = 'BOA'
            
            return {
                'amount': amount,
                'transaction_type': transaction_type,
                'counterparty_name': counterparty,
                'account': bank,
                'raw_sms': message,
                'description': f'{bank} transaction',
            }
    
    return None

# UDP Discovery (Syncthing-style)
class DiscoveryService:
    def __init__(self, port=5333, broadcast_interval=30):
        self.port = port
        self.broadcast_interval = broadcast_interval
        self.running = False
        self.discovered_devices = {}
        self.device_id = str(uuid.uuid4())[:8]
        self.thread = None
        
    def start(self):
        """Start UDP discovery service"""
        self.running = True
        self.thread = threading.Thread(target=self._discovery_loop, daemon=True)
        self.thread.start()
        logger.info(f"Discovery service started (ID: {self.device_id})")
        
    def stop(self):
        """Stop UDP discovery service"""
        self.running = False
        if self.thread:
            self.thread.join(timeout=5)
        logger.info("Discovery service stopped")
        
    def _discovery_loop(self):
        """Main discovery loop - broadcast and listen"""
        try:
            # Create UDP socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
            sock.settimeout(5)
            
            # Bind to port for receiving
            sock.bind(('0.0.0.0', self.port))
            
            logger.info(f"UDP discovery listening on port {self.port}")
            
            last_broadcast = 0
            
            while self.running:
                current_time = datetime.now().timestamp()
                
                # Broadcast every 30 seconds
                if current_time - last_broadcast >= self.broadcast_interval:
                    self._broadcast_presence(sock)
                    last_broadcast = current_time
                
                # Listen for incoming broadcasts
                try:
                    data, addr = sock.recvfrom(1024)
                    self._process_discovery_message(data, addr)
                except socket.timeout:
                    continue
                except Exception as e:
                    logger.error(f"Discovery error: {e}")
                    
        except Exception as e:
            logger.error(f"Discovery service failed: {e}")
        finally:
            try:
                sock.close()
            except:
                pass
    
    def _broadcast_presence(self, sock):
        """Broadcast our presence to the network"""
        try:
            message = json.dumps({
                'type': 'vault_pro',
                'device_id': self.device_id,
                'name': 'Vault Pro Desktop',
                'port': 8080,
                'timestamp': datetime.now().isoformat()
            })
            
            sock.sendto(message.encode(), ('<broadcast>', self.port))
            logger.debug(f"Broadcasted presence: {self.device_id}")
        except Exception as e:
            logger.error(f"Broadcast failed: {e}")
    
    def _process_discovery_message(self, data, addr):
        """Process incoming discovery message"""
        try:
            message = json.loads(data.decode())
            
            if message.get('type') == 'vault_pro':
                device_id = message.get('device_id')
                if device_id and device_id != self.device_id:
                    self.discovered_devices[device_id] = {
                        'name': message.get('name', 'Unknown'),
                        'ip': addr[0],
                        'port': message.get('port', 8080),
                        'last_seen': datetime.now().isoformat()
                    }
                    logger.info(f"Discovered device: {message.get('name')} at {addr[0]}")
        except Exception as e:
            logger.error(f"Error processing discovery message: {e}")
    
    def get_discovered_devices(self) -> List[Dict]:
        """Get list of discovered devices"""
        # Remove devices not seen in 90 seconds
        cutoff = datetime.now().timestamp() - 90
        to_remove = []
        
        for device_id, info in self.discovered_devices.items():
            try:
                last_seen = datetime.fromisoformat(info['last_seen']).timestamp()
                if last_seen < cutoff:
                    to_remove.append(device_id)
            except:
                to_remove.append(device_id)
        
        for device_id in to_remove:
            del self.discovered_devices[device_id]
        
        return list(self.discovered_devices.values())

# Global discovery service instance
discovery_service = DiscoveryService()

# API Routes
@app.get("/api/health")
async def health_check():
    """Health check endpoint"""
    try:
        return {
            "status": "healthy",
            "version": "1.2.0",
            "database": "connected",
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/transactions")
async def get_transactions(
    limit: int = 100,
    offset: int = 0,
    transaction_type: Optional[str] = None,
    category: Optional[str] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None
):
    """Get transactions with filtering"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        query = "SELECT * FROM transactions WHERE 1=1"
        params = []
        
        if transaction_type:
            query += " AND transaction_type = ?"
            params.append(transaction_type)
        
        if category:
            query += " AND category = ?"
            params.append(category)
        
        if start_date:
            query += " AND transaction_date >= ?"
            params.append(start_date)
        
        if end_date:
            query += " AND transaction_date <= ?"
            params.append(end_date)
        
        query += " ORDER BY transaction_date DESC LIMIT ? OFFSET ?"
        params.extend([limit, offset])
        
        cursor.execute(query, params)
        rows = cursor.fetchall()
        
        # Get total count
        count_query = "SELECT COUNT(*) FROM transactions WHERE 1=1"
        count_params = []
        
        if transaction_type:
            count_query += " AND transaction_type = ?"
            count_params.append(transaction_type)
        
        if category:
            count_query += " AND category = ?"
            count_params.append(category)
        
        cursor.execute(count_query, count_params)
        total = cursor.fetchone()[0]
        
        conn.close()
        
        transactions = [dict(row) for row in rows]
        
        return {
            "transactions": transactions,
            "total": total,
            "limit": limit,
            "offset": offset
        }
    except Exception as e:
        logger.error(f"Error getting transactions: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/transactions")
async def create_transaction(transaction: TransactionCreate):
    """Create a new transaction"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        transaction_id = str(uuid.uuid4())
        transaction_date = transaction.transaction_date or datetime.now()
        
        cursor.execute('''
            INSERT INTO transactions (
                id, amount, transaction_type, category, subcategory,
                account, counterparty_name, counterparty_phone,
                description, reference_number, transaction_date,
                source, raw_sms
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            transaction_id,
            transaction.amount,
            transaction.transaction_type,
            transaction.category,
            transaction.subcategory,
            transaction.account,
            transaction.counterparty_name,
            transaction.counterparty_phone,
            transaction.description,
            transaction.reference_number,
            transaction_date,
            transaction.source,
            transaction.raw_sms
        ))
        
        conn.commit()
        conn.close()
        
        logger.info(f"Created transaction: {transaction_id}")
        
        return {
            "id": transaction_id,
            "message": "Transaction created successfully"
        }
    except Exception as e:
        logger.error(f"Error creating transaction: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/transactions/batch")
async def create_transactions_batch(transactions: List[TransactionCreate]):
    """Create multiple transactions in batch"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        created_count = 0
        
        for transaction in transactions:
            try:
                transaction_id = str(uuid.uuid4())
                transaction_date = transaction.transaction_date or datetime.now()
                
                cursor.execute('''
                    INSERT INTO transactions (
                        id, amount, transaction_type, category, subcategory,
                        account, counterparty_name, counterparty_phone,
                        description, reference_number, transaction_date,
                        source, raw_sms
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    transaction_id,
                    transaction.amount,
                    transaction.transaction_type,
                    transaction.category,
                    transaction.subcategory,
                    transaction.account,
                    transaction.counterparty_name,
                    transaction.counterparty_phone,
                    transaction.description,
                    transaction.reference_number,
                    transaction_date,
                    transaction.source,
                    transaction.raw_sms
                ))
                created_count += 1
            except Exception as e:
                logger.error(f"Failed to create transaction: {e}")
                continue
        
        conn.commit()
        conn.close()
        
        logger.info(f"Created {created_count}/{len(transactions)} transactions")
        
        return {
            "created": created_count,
            "total": len(transactions),
            "message": f"{created_count} transactions created successfully"
        }
    except Exception as e:
        logger.error(f"Error creating batch transactions: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/sms")
async def receive_sms(sms: SMSData):
    """Receive SMS from mobile device"""
    try:
        parsed = parse_ethiopian_sms(sms.message)
        
        if not parsed:
            return {
                "success": False,
                "message": "Could not parse SMS",
                "raw": sms.message
            }
        
        # Create transaction from parsed SMS
        conn = get_db_connection()
        cursor = conn.cursor()
        
        transaction_id = str(uuid.uuid4())
        transaction_date = sms.timestamp or datetime.now()
        
        cursor.execute('''
            INSERT INTO transactions (
                id, amount, transaction_type, category, subcategory,
                account, counterparty_name, counterparty_phone,
                description, transaction_date, source, raw_sms
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            transaction_id,
            parsed['amount'],
            parsed['transaction_type'],
            parsed.get('category'),
            parsed.get('subcategory'),
            parsed.get('account'),
            parsed.get('counterparty_name'),
            sms.phone,
            parsed.get('description'),
            transaction_date,
            'sms',
            sms.message
        ))
        
        conn.commit()
        conn.close()
        
        logger.info(f"Processed SMS from {sms.phone}, created transaction: {transaction_id}")
        
        return {
            "success": True,
            "transaction_id": transaction_id,
            "parsed": parsed
        }
    except Exception as e:
        logger.error(f"Error processing SMS: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/sms/batch")
async def receive_sms_batch(batch: BatchSMSData):
    """Receive batch of SMS messages from mobile device"""
    try:
        results = []
        
        for sms_data in batch.messages:
            try:
                result = await receive_sms(sms_data)
                results.append(result)
            except Exception as e:
                results.append({
                    "success": False,
                    "error": str(e),
                    "phone": sms_data.phone
                })
        
        success_count = sum(1 for r in results if r.get('success'))
        
        return {
            "total": len(batch.messages),
            "success": success_count,
            "failed": len(batch.messages) - success_count,
            "results": results
        }
    except Exception as e:
        logger.error(f"Error processing batch SMS: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/people")
async def get_people():
    """Get all people/contacts"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT * FROM people ORDER BY name")
        rows = cursor.fetchall()
        conn.close()
        
        people = [dict(row) for row in rows]
        
        # Parse aliases JSON
        for person in people:
            if person.get('aliases'):
                try:
                    person['aliases'] = json.loads(person['aliases'])
                except:
                    person['aliases'] = []
        
        return {"people": people}
    except Exception as e:
        logger.error(f"Error getting people: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/people")
async def create_person(person: PersonCreate):
    """Create a new person/contact"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        person_id = str(uuid.uuid4())
        aliases_json = json.dumps(person.aliases) if person.aliases else '[]'
        
        cursor.execute('''
            INSERT INTO people (id, name, phone, email, aliases, notes)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (person_id, person.name, person.phone, person.email, aliases_json, person.notes))
        
        conn.commit()
        conn.close()
        
        logger.info(f"Created person: {person_id}")
        
        return {
            "id": person_id,
            "message": "Person created successfully"
        }
    except Exception as e:
        logger.error(f"Error creating person: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/dashboard/stats")
async def get_dashboard_stats():
    """Get dashboard statistics"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Total income
        cursor.execute("SELECT SUM(amount) FROM transactions WHERE transaction_type = 'income'")
        total_income = cursor.fetchone()[0] or 0
        
        # Total expenses
        cursor.execute("SELECT SUM(amount) FROM transactions WHERE transaction_type = 'expense'")
        total_expenses = cursor.fetchone()[0] or 0
        
        # Net balance
        net_balance = total_income - total_expenses
        
        # Transaction count
        cursor.execute("SELECT COUNT(*) FROM transactions")
        transaction_count = cursor.fetchone()[0]
        
        # Recent transactions (last 7 days)
        cursor.execute("""
            SELECT COUNT(*) FROM transactions 
            WHERE transaction_date >= datetime('now', '-7 days')
        """)
        recent_count = cursor.fetchone()[0]
        
        conn.close()
        
        return {
            "total_income": total_income,
            "total_expenses": total_expenses,
            "net_balance": net_balance,
            "transaction_count": transaction_count,
            "recent_transactions": recent_count
        }
    except Exception as e:
        logger.error(f"Error getting dashboard stats: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/discovery/start")
async def start_discovery():
    """Start UDP discovery service"""
    try:
        if not discovery_service.running:
            discovery_service.start()
        
        return {
            "status": "started",
            "device_id": discovery_service.device_id
        }
    except Exception as e:
        logger.error(f"Error starting discovery: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/discovery/stop")
async def stop_discovery():
    """Stop UDP discovery service"""
    try:
        discovery_service.stop()
        
        return {
            "status": "stopped"
        }
    except Exception as e:
        logger.error(f"Error stopping discovery: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/discovery/devices")
async def get_discovered_devices():
    """Get list of discovered devices"""
    try:
        devices = discovery_service.get_discovered_devices()
        
        return {
            "devices": devices,
            "count": len(devices)
        }
    except Exception as e:
        logger.error(f"Error getting discovered devices: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/export/csv")
async def export_transactions_csv(
    transaction_type: Optional[str] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None
):
    """Export transactions to CSV format"""
    try:
        from io import StringIO
        import csv
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        query = "SELECT * FROM transactions WHERE 1=1"
        params = []
        
        if transaction_type:
            query += " AND transaction_type = ?"
            params.append(transaction_type)
        
        if start_date:
            query += " AND transaction_date >= ?"
            params.append(start_date)
        
        if end_date:
            query += " AND transaction_date <= ?"
            params.append(end_date)
        
        query += " ORDER BY transaction_date DESC"
        
        cursor.execute(query, params)
        rows = cursor.fetchall()
        conn.close()
        
        # Create CSV
        output = StringIO()
        fieldnames = ['id', 'amount', 'transaction_type', 'category', 'subcategory', 
                      'account', 'counterparty_name', 'counterparty_phone', 
                      'description', 'reference_number', 'transaction_date', 'source']
        
        writer = csv.DictWriter(output, fieldnames=fieldnames)
        writer.writeheader()
        
        for row in rows:
            row_dict = dict(row)
            writer.writerow(row_dict)
        
        csv_content = output.getvalue()
        output.close()
        
        return {
            "csv": csv_content,
            "count": len(rows)
        }
    except Exception as e:
        logger.error(f"Error exporting CSV: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Error handlers
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler"""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "detail": str(exc) if os.getenv('DEBUG') else "An unexpected error occurred"
        }
    )

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """HTTP exception handler"""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.detail
        }
    )

# Startup and shutdown events
@app.on_event("startup")
async def startup_event():
    """Start background services"""
    logger.info("Starting Vault Pro API...")
    
    # Start discovery service in background
    discovery_service.start()
    
    logger.info("Vault Pro API started successfully")

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    logger.info("Shutting down Vault Pro API...")
    discovery_service.stop()
    logger.info("Vault Pro API stopped")

# Main entry point
if __name__ == "__main__":
    print("=" * 60)
    print("Vault Pro API Server")
    print("=" * 60)
    print(f"Database: {DB_PATH}")
    print(f"Config: {CONFIG_PATH}")
    print("=" * 60)
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8080,
        log_level="info"
    )
