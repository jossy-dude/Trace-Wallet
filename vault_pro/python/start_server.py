#!/usr/bin/env python3
"""
Vault Pro - Server Launcher
Standalone script to start the FastAPI backend
"""
import subprocess
import sys
import os
from pathlib import Path

def main():
    print("=" * 60)
    print("Vault Pro Backend Server")
    print("=" * 60)
    
    # Get the directory where this script is located
    script_dir = Path(__file__).parent.absolute()
    
    # Check if requirements are installed
    try:
        import fastapi
        import uvicorn
    except ImportError:
        print("Installing dependencies...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", str(script_dir / "requirements.txt")])
    
    # Change to script directory
    os.chdir(script_dir)
    
    # Import and run the main app
    from main import app
    
    print(f"Database location: {Path.home() / '.vault_pro' / 'vault.db'}")
    print("Starting server on http://0.0.0.0:8080")
    print("Press Ctrl+C to stop")
    print("=" * 60)
    
    try:
        import uvicorn
        uvicorn.run(app, host="0.0.0.0", port=8080, log_level="info")
    except KeyboardInterrupt:
        print("\nShutting down gracefully...")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
