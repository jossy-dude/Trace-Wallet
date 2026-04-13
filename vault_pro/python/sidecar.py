"""
Python Sidecar - Main entry point for Electron-Python bridge
Handles all backend operations for the Vault Pro desktop app
"""
import sys
import json
import asyncio
import threading
from pathlib import Path

# Add the python directory to path
sys.path.insert(0, str(Path(__file__).parent))

from database import db, VaultTransaction, VaultPerson
from parser import parser
from server import SyncServer

class Sidecar:
    """Bridge between Electron frontend and Python backend"""
    
    def __init__(self):
        self.server = None
        self.server_thread = None
    
    def start_server(self, host='0.0.0.0', port=8080):
        """Start the sync server in a background thread"""
        def run_server():
            asyncio.set_event_loop(asyncio.new_event_loop())
            self.server = SyncServer(host, port)
            loop = asyncio.get_event_loop()
            loop.run_until_complete(self.server.start())
            loop.run_forever()
        
        self.server_thread = threading.Thread(target=run_server, daemon=True)
        self.server_thread.start()
        return {'status': 'started', 'host': host, 'port': port}
    
    def get_statistics(self):
        """Get database statistics"""
        return db.get_statistics()
    
    def get_transactions(self, limit=None, pending_only=False):
        """Get transactions"""
        if pending_only:
            transactions = db.get_pending_transactions()
        else:
            transactions = db.get_all_transactions(limit=limit)
        return [t.to_dict() for t in transactions]
    
    def add_transaction(self, data):
        """Add a new transaction"""
        transaction = VaultTransaction(
            raw_text=data.get('raw_text', ''),
            amount=data.get('amount'),
            balance=data.get('balance'),
            fee=data.get('fee'),
            date=data.get('date'),
            sender_alias=data.get('sender_alias'),
            category=data.get('category'),
            is_approved=data.get('is_approved', False)
        )
        tx_id = db.add_transaction(transaction)
        return {'id': tx_id, 'status': 'success'}
    
    def update_transaction(self, data):
        """Update an existing transaction"""
        transaction = VaultTransaction(
            id=data.get('id'),
            raw_text=data.get('raw_text', ''),
            amount=data.get('amount'),
            balance=data.get('balance'),
            fee=data.get('fee'),
            date=data.get('date'),
            sender_alias=data.get('sender_alias'),
            category=data.get('category'),
            is_approved=data.get('is_approved', False)
        )
        success = db.update_transaction(transaction)
        return {'success': success}
    
    def delete_transaction(self, transaction_id):
        """Delete a transaction"""
        success = db.delete_transaction(transaction_id)
        return {'success': success}
    
    def search_transactions(self, query):
        """Search transactions"""
        transactions = db.search_transactions(query)
        return [t.to_dict() for t in transactions]
    
    def get_people(self):
        """Get all people"""
        people = db.get_all_people()
        return [p.to_dict() for p in people]
    
    def add_person(self, data):
        """Add a new person"""
        person = VaultPerson(
            name=data.get('name', ''),
            aliases=data.get('aliases', []),
            monthly_fee=data.get('monthly_fee', 0.0)
        )
        person_id = db.add_person(person)
        return {'id': person_id, 'status': 'success'}
    
    def update_person(self, data):
        """Update a person"""
        person = VaultPerson(
            id=data.get('id'),
            name=data.get('name', ''),
            aliases=data.get('aliases', []),
            monthly_fee=data.get('monthly_fee', 0.0)
        )
        success = db.update_person(person)
        return {'success': success}
    
    def delete_person(self, person_id):
        """Delete a person"""
        success = db.delete_person(person_id)
        return {'success': success}
    
    def find_person_by_alias(self, alias):
        """Find person by alias"""
        person = db.find_person_by_alias(alias)
        return person.to_dict() if person else None
    
    def parse_transaction(self, raw_text):
        """Parse a raw transaction message"""
        result = parser.process_raw_transaction(raw_text)
        return {
            'bank': result.bank,
            'amount': result.amount,
            'balance': result.balance,
            'fee': result.fee,
            'entity_name': result.entity_name,
            'is_valid': result.is_valid
        }
    
    def export_data(self, filepath):
        """Export all data to JSON"""
        db.export_to_json(filepath)
        return {'success': True, 'path': filepath}
    
    def import_data(self, filepath):
        """Import data from JSON"""
        db.import_from_json(filepath)
        return {'success': True}


# Global sidecar instance
sidecar = Sidecar()


def handle_command(command, data=None):
    """Handle commands from Electron frontend"""
    commands = {
        'start_server': lambda: sidecar.start_server(**(data or {})),
        'get_statistics': sidecar.get_statistics,
        'get_transactions': lambda: sidecar.get_transactions(**(data or {})),
        'add_transaction': lambda: sidecar.add_transaction(data),
        'update_transaction': lambda: sidecar.update_transaction(data),
        'delete_transaction': lambda: sidecar.delete_transaction(data),
        'search_transactions': lambda: sidecar.search_transactions(data),
        'get_people': sidecar.get_people,
        'add_person': lambda: sidecar.add_person(data),
        'update_person': lambda: sidecar.update_person(data),
        'delete_person': lambda: sidecar.delete_person(data),
        'find_person_by_alias': lambda: sidecar.find_person_by_alias(data),
        'parse_transaction': lambda: sidecar.parse_transaction(data),
        'export_data': lambda: sidecar.export_data(data),
        'import_data': lambda: sidecar.import_data(data),
    }
    
    handler = commands.get(command)
    if handler:
        try:
            result = handler()
            return {'success': True, 'data': result}
        except Exception as e:
            return {'success': False, 'error': str(e)}
    else:
        return {'success': False, 'error': f'Unknown command: {command}'}


def main():
    """Main entry point for command-line interface"""
    # Start server automatically
    sidecar.start_server()
    
    # Listen for commands from stdin (Electron communication)
    print("Python sidecar ready", flush=True)
    
    while True:
        try:
            line = input()
            if not line:
                continue
            
            message = json.loads(line)
            command = message.get('command')
            data = message.get('data')
            
            result = handle_command(command, data)
            print(json.dumps(result), flush=True)
            
        except EOFError:
            break
        except json.JSONDecodeError as e:
            print(json.dumps({'success': False, 'error': f'Invalid JSON: {e}'}), flush=True)
        except Exception as e:
            print(json.dumps({'success': False, 'error': str(e)}), flush=True)


if __name__ == '__main__':
    main()
