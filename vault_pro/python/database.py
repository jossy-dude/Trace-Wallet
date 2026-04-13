"""
Database Service - Replaces Dart Isar database with SQLite
Handles all database operations for transactions and people
"""
import sqlite3
import json
import os
from datetime import datetime
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import List, Optional, Dict, Any

@dataclass
class VaultTransaction:
    id: int = 0
    raw_text: str = ""
    amount: Optional[float] = None
    balance: Optional[float] = None
    fee: Optional[float] = None
    date: str = ""
    sender_alias: Optional[str] = None
    category: Optional[str] = None
    ai_summary: Optional[str] = None
    is_approved: bool = False
    sent_to_dad: bool = False
    date_added: str = ""

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'VaultTransaction':
        return cls(**data)

@dataclass
class VaultPerson:
    id: int = 0
    name: str = ""
    aliases: List[str] = None
    monthly_fee: float = 0.0
    total_transactions: int = 0
    total_amount: float = 0.0

    def __post_init__(self):
        if self.aliases is None:
            self.aliases = []

    def to_dict(self) -> Dict[str, Any]:
        return {
            'id': self.id,
            'name': self.name,
            'aliases': json.dumps(self.aliases),
            'monthly_fee': self.monthly_fee,
            'total_transactions': self.total_transactions,
            'total_amount': self.total_amount
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'VaultPerson':
        data = data.copy()
        if isinstance(data.get('aliases'), str):
            data['aliases'] = json.loads(data['aliases'])
        return cls(**data)

@dataclass
class PairedDevice:
    id: int = 0
    device_id: str = ""
    name: str = ""
    device_type: str = ""
    is_trusted: bool = False
    added_at: str = ""
    last_sync: Optional[str] = None

class DatabaseService:
    """Singleton database service"""
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self, db_path: str = None):
        if self._initialized:
            return
            
        if db_path is None:
            # Store in user's home directory
            home = Path.home()
            vault_dir = home / '.vault_pro'
            vault_dir.mkdir(exist_ok=True)
            db_path = vault_dir / 'vault.db'
        
        self.db_path = str(db_path)
        self._init_database()
        self._initialized = True
    
    def _init_database(self):
        """Initialize database tables"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            
            # Transactions table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS transactions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    raw_text TEXT NOT NULL,
                    amount REAL,
                    balance REAL,
                    fee REAL,
                    date TEXT NOT NULL,
                    sender_alias TEXT,
                    category TEXT,
                    ai_summary TEXT,
                    is_approved INTEGER DEFAULT 0,
                    sent_to_dad INTEGER DEFAULT 0,
                    date_added TEXT DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # People table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS people (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL,
                    aliases TEXT DEFAULT '[]',
                    monthly_fee REAL DEFAULT 0.0,
                    total_transactions INTEGER DEFAULT 0,
                    total_amount REAL DEFAULT 0.0
                )
            ''')
            
            # Devices table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS devices (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    device_id TEXT UNIQUE NOT NULL,
                    name TEXT,
                    device_type TEXT,
                    is_trusted INTEGER DEFAULT 0,
                    added_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    last_sync TEXT
                )
            ''')
            
            # Sync history table
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS sync_history (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    device_id TEXT,
                    transactions_count INTEGER,
                    status TEXT,
                    error_message TEXT,
                    timestamp TEXT DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Create indexes
            cursor.execute('CREATE INDEX IF NOT EXISTS idx_tx_date ON transactions(date)')
            cursor.execute('CREATE INDEX IF NOT EXISTS idx_tx_category ON transactions(category)')
            cursor.execute('CREATE INDEX IF NOT EXISTS idx_tx_approved ON transactions(is_approved)')
            
            conn.commit()
    
    # Transaction operations
    def add_transaction(self, transaction: VaultTransaction) -> int:
        """Add a new transaction, returns the ID"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute('''
                INSERT INTO transactions 
                (raw_text, amount, balance, fee, date, sender_alias, category, 
                 ai_summary, is_approved, sent_to_dad, date_added)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                transaction.raw_text,
                transaction.amount,
                transaction.balance,
                transaction.fee,
                transaction.date,
                transaction.sender_alias,
                transaction.category,
                transaction.ai_summary,
                1 if transaction.is_approved else 0,
                1 if transaction.sent_to_dad else 0,
                transaction.date_added or datetime.now().isoformat()
            ))
            conn.commit()
            return cursor.lastrowid
    
    def get_transaction(self, transaction_id: int) -> Optional[VaultTransaction]:
        """Get a single transaction by ID"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM transactions WHERE id = ?', (transaction_id,))
            row = cursor.fetchone()
            if row:
                return self._row_to_transaction(row)
            return None
    
    def get_all_transactions(self, limit: int = None, offset: int = 0) -> List[VaultTransaction]:
        """Get all transactions with optional pagination"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            query = 'SELECT * FROM transactions ORDER BY date DESC'
            params = ()
            if limit:
                query += ' LIMIT ? OFFSET ?'
                params = (limit, offset)
            cursor.execute(query, params)
            return [self._row_to_transaction(row) for row in cursor.fetchall()]
    
    def get_pending_transactions(self) -> List[VaultTransaction]:
        """Get all unapproved transactions"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM transactions WHERE is_approved = 0 ORDER BY date DESC')
            return [self._row_to_transaction(row) for row in cursor.fetchall()]
    
    def update_transaction(self, transaction: VaultTransaction) -> bool:
        """Update an existing transaction"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute('''
                UPDATE transactions SET
                    raw_text = ?, amount = ?, balance = ?, fee = ?,
                    date = ?, sender_alias = ?, category = ?,
                    ai_summary = ?, is_approved = ?, sent_to_dad = ?
                WHERE id = ?
            ''', (
                transaction.raw_text,
                transaction.amount,
                transaction.balance,
                transaction.fee,
                transaction.date,
                transaction.sender_alias,
                transaction.category,
                transaction.ai_summary,
                1 if transaction.is_approved else 0,
                1 if transaction.sent_to_dad else 0,
                transaction.id
            ))
            conn.commit()
            return cursor.rowcount > 0
    
    def delete_transaction(self, transaction_id: int) -> bool:
        """Delete a transaction"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute('DELETE FROM transactions WHERE id = ?', (transaction_id,))
            conn.commit()
            return cursor.rowcount > 0
    
    def search_transactions(self, query: str) -> List[VaultTransaction]:
        """Search transactions by text"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            search_term = f'%{query}%'
            cursor.execute('''
                SELECT * FROM transactions 
                WHERE raw_text LIKE ? OR sender_alias LIKE ? OR category LIKE ?
                ORDER BY date DESC
            ''', (search_term, search_term, search_term))
            return [self._row_to_transaction(row) for row in cursor.fetchall()]
    
    # People operations
    def add_person(self, person: VaultPerson) -> int:
        """Add a new person"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute('''
                INSERT INTO people (name, aliases, monthly_fee, total_transactions, total_amount)
                VALUES (?, ?, ?, ?, ?)
            ''', (
                person.name,
                json.dumps(person.aliases),
                person.monthly_fee,
                person.total_transactions,
                person.total_amount
            ))
            conn.commit()
            return cursor.lastrowid
    
    def get_all_people(self) -> List[VaultPerson]:
        """Get all people"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM people ORDER BY name')
            return [self._row_to_person(row) for row in cursor.fetchall()]
    
    def find_person_by_alias(self, alias: str) -> Optional[VaultPerson]:
        """Find a person by one of their aliases (case-insensitive)"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM people')
            for row in cursor.fetchall():
                person = self._row_to_person(row)
                if any(a.lower() == alias.lower() for a in person.aliases):
                    return person
            return None
    
    def update_person(self, person: VaultPerson) -> bool:
        """Update a person"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute('''
                UPDATE people SET
                    name = ?, aliases = ?, monthly_fee = ?,
                    total_transactions = ?, total_amount = ?
                WHERE id = ?
            ''', (
                person.name,
                json.dumps(person.aliases),
                person.monthly_fee,
                person.total_transactions,
                person.total_amount,
                person.id
            ))
            conn.commit()
            return cursor.rowcount > 0
    
    def delete_person(self, person_id: int) -> bool:
        """Delete a person"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute('DELETE FROM people WHERE id = ?', (person_id,))
            conn.commit()
            return cursor.rowcount > 0
    
    # Device operations
    def add_device(self, device: PairedDevice) -> int:
        """Add or update a paired device"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute('''
                INSERT OR REPLACE INTO devices 
                (device_id, name, device_type, is_trusted, added_at, last_sync)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (
                device.device_id,
                device.name,
                device.device_type,
                1 if device.is_trusted else 0,
                device.added_at or datetime.now().isoformat(),
                device.last_sync
            ))
            conn.commit()
            return cursor.lastrowid
    
    def get_trusted_devices(self) -> List[PairedDevice]:
        """Get all trusted devices"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM devices WHERE is_trusted = 1')
            return [self._row_to_device(row) for row in cursor.fetchall()]
    
    def get_device(self, device_id: str) -> Optional[PairedDevice]:
        """Get a device by ID"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM devices WHERE device_id = ?', (device_id,))
            row = cursor.fetchone()
            if row:
                return self._row_to_device(row)
            return None
    
    # Statistics
    def get_statistics(self) -> Dict[str, Any]:
        """Get database statistics"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            
            # Total transactions
            cursor.execute('SELECT COUNT(*) FROM transactions')
            total_transactions = cursor.fetchone()[0]
            
            # Total people
            cursor.execute('SELECT COUNT(*) FROM people')
            total_people = cursor.fetchone()[0]
            
            # Pending transactions
            cursor.execute('SELECT COUNT(*) FROM transactions WHERE is_approved = 0')
            pending = cursor.fetchone()[0]
            
            # Total amounts
            cursor.execute('SELECT SUM(amount) FROM transactions WHERE amount > 0')
            total_income = cursor.fetchone()[0] or 0
            
            cursor.execute('SELECT SUM(amount) FROM transactions WHERE amount < 0')
            total_expense = abs(cursor.fetchone()[0] or 0)
            
            # Database size
            db_size = os.path.getsize(self.db_path)
            
            return {
                'total_transactions': total_transactions,
                'total_people': total_people,
                'pending_count': pending,
                'total_income': total_income,
                'total_expense': total_expense,
                'database_size': self._format_size(db_size),
                'db_path': self.db_path
            }
    
    # Helper methods
    def _row_to_transaction(self, row) -> VaultTransaction:
        return VaultTransaction(
            id=row[0],
            raw_text=row[1],
            amount=row[2],
            balance=row[3],
            fee=row[4],
            date=row[5],
            sender_alias=row[6],
            category=row[7],
            ai_summary=row[8],
            is_approved=bool(row[9]),
            sent_to_dad=bool(row[10]),
            date_added=row[11]
        )
    
    def _row_to_person(self, row) -> VaultPerson:
        return VaultPerson(
            id=row[0],
            name=row[1],
            aliases=json.loads(row[2]),
            monthly_fee=row[3],
            total_transactions=row[4],
            total_amount=row[5]
        )
    
    def _row_to_device(self, row) -> PairedDevice:
        return PairedDevice(
            id=row[0],
            device_id=row[1],
            name=row[2],
            device_type=row[3],
            is_trusted=bool(row[4]),
            added_at=row[5],
            last_sync=row[6]
        )
    
    def _format_size(self, size_bytes: int) -> str:
        """Format bytes to human readable size"""
        for unit in ['B', 'KB', 'MB', 'GB']:
            if size_bytes < 1024:
                return f"{size_bytes:.1f} {unit}"
            size_bytes /= 1024
        return f"{size_bytes:.1f} TB"
    
    def export_to_json(self, filepath: str):
        """Export all data to JSON file"""
        data = {
            'transactions': [t.to_dict() for t in self.get_all_transactions()],
            'people': [p.to_dict() for p in self.get_all_people()],
            'exported_at': datetime.now().isoformat()
        }
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
    
    def import_from_json(self, filepath: str):
        """Import data from JSON file"""
        with open(filepath, 'r') as f:
            data = json.load(f)
        
        for tx_data in data.get('transactions', []):
            tx = VaultTransaction.from_dict(tx_data)
            self.add_transaction(tx)
        
        for person_data in data.get('people', []):
            person = VaultPerson.from_dict(person_data)
            self.add_person(person)

# Global instance
db = DatabaseService()
