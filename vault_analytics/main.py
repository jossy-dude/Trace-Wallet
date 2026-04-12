import threading
import webview
import logging

from vault.ui.api import VaultPro
from vault.pipeline.sms_server import create_sms_server

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

if __name__ == '__main__':
    # Initialize Core Application Logic
    api = VaultPro()
    
    # Extract config port safely
    port = getattr(api, 'settings', {}).get('sms_port', 8765)
    
    # Start SMS Fast API listener in background thread
    server = create_sms_server(api)
    def run_server():
        import uvicorn
        uvicorn.run(server, host="0.0.0.0", port=port, log_level="error")
        
    threading.Thread(target=run_server, daemon=True).start()
    logging.info(f"SMS Sync Listener active on port {port}")
    
    # Boot the UI
    window = webview.create_window(
        title='Vault Analytics v4.0', 
        url='index.html',
        js_api=api,
        width=1400, 
        height=900,
        frameless=True,
        transparent=True,
        easy_drag=False
    )
    
    api.set_window(window)
    webview.start()
