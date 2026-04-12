# Trace Wallet

A secure, LocalSend-style P2P financial tracking system with cross-platform support. Track transactions, analyze spending patterns, and sync SMS-based bank alerts from your mobile device to your desktop vault.

## Features

### Core Features
- **Transaction Management** - Track income, expenses, and transfers with intelligent categorization
- **Financial Analytics** - Net worth tracking, spending velocity, runway calculation, and 6-month predictions
- **Bank SMS Parsing** - Automatic parsing of Ethiopian bank SMS (CBE, Telebirr, BOA, Dashen)
- **Goal Tracking** - Set and monitor savings goals with progress tracking
- **Budget Limits** - Category-based budget enforcement with hard-stop options
- **AI Insights** - Local Ollama integration for transaction categorization

### P2P Mobile Sync (LocalSend-Style)
- **UDP Discovery** - Auto-discover your desktop vault on local WiFi
- **QR Code Pairing** - Scan to instantly pair mobile and desktop
- **Secure Token Authentication** - UUID-based token verification
- **Device Management** - Track and manage paired devices
- **Batch SMS Sync** - Send multiple bank SMS messages in one batch
- **HTTPS Support** - Optional SSL/TLS encryption for local network

## Architecture

```
Trace Wallet/
├── lib/                    # Flutter mobile app (work in progress)
├── vault_analytics/        # Python desktop application
│   ├── vault/
│   │   ├── pipeline/       # SMS processing, P2P server, discovery
│   │   ├── ui/            # API layer for pywebview
│   │   ├── core/          # Data transformer
│   │   ├── ai/            # Ollama integration
│   │   └── config.py      # Configuration defaults
│   ├── index.html         # Web UI (glassmorphism design)
│   └── main.py            # Application entry point
└── README.md
```

## Quick Start

### Desktop Vault (Windows/Linux/Mac)

```bash
cd vault_analytics

# Create virtual environment
python -m venv venv

# Activate (Windows)
venv\Scripts\activate
# OR Activate (Linux/Mac)
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run the application
python main.py
```

### Building Desktop Executable

```bash
# Install PyInstaller
pip install pyinstaller

# Build executable
pyinstaller --onefile --windowed --add-data "index.html;." --name "VaultAnalytics" main.py
```

## P2P Mobile Sync Setup

### Desktop Setup
1. Open Vault Settings → P2P Mobile Sync
2. Click "Open Config" to view QR code and connection details
3. Enable P2P Server (toggle on)
4. Note your local IP and port (default: 8765)

### Mobile App Integration
Your Flutter app should implement:

```dart
// 1. UDP Discovery - Listen on port 5333
RawDatagramSocket.bind(InternetAddress.anyIPv4, 5333)
  .then((socket) {
    socket.listen((event) {
      final datagram = socket.receive();
      if (datagram != null) {
        final message = utf8.decode(datagram.data);
        final config = jsonDecode(message);
        // config contains: ip, port, token, protocol
      }
    });
  });

// 2. QR Scanning - Use mobile_scanner package
// Scan QR to get: {"ip": "192.168.x.x", "port": 8765, "token": "..."}

// 3. Send SMS to Vault
final response = await http.post(
  Uri.parse('http://192.168.x.x:8765/api/sms'),
  headers: {'X-Vault-Token': 'your-token'},
  body: jsonEncode({
    'body': 'Your bank SMS text here',
    'sender': 'CBE',
    'metadata': {'timestamp': DateTime.now().toIso8601String()}
  }),
);
```

## API Endpoints

### Health Check
```
GET /api/health
Response: {"status": "ok", "version": "4.0", "secure": false}
```

### Pair Verification
```
GET /api/pair
Headers: X-Vault-Token: <token>
Response: {"status": "paired", "device_id": "vault-desktop", ...}
```

### Send SMS
```
POST /api/sms
Headers: X-Vault-Token: <token>
Body: {"body": "...", "sender": "...", "metadata": {...}}
```

### Batch SMS
```
POST /api/sms/batch
Headers: X-Vault-Token: <token>
Body: {"messages": [{...}, {...}]}
```

## Configuration

### Default Settings (vault_config.json)
```json
{
  "sms_port": 8765,
  "sms_use_https": false,
  "ssl_cert_path": "",
  "ssl_key_path": "",
  "sms_debounce_seconds": 60,
  "sms_instant_mode": false
}
```

### Enabling HTTPS
1. Generate SSL certificates:
   ```bash
   openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes
   ```
2. Update settings with certificate paths
3. Set `sms_use_https: true`

## Security

- **Local Network Only** - P2P server binds to `0.0.0.0` but intended for LAN use
- **Token Authentication** - UUID-based tokens for device pairing
- **Optional HTTPS** - SSL/TLS support for encrypted local communication
- **No Cloud** - All data stays on your devices
- **SHA-256 Passwords** - Master password hashing

## Screenshots

*Coming soon*

## Tech Stack

- **Desktop**: Python, FastAPI, PyWebView, TailwindCSS
- **Mobile**: Flutter (in development)
- **AI**: Ollama (local LLM)
- **Communication**: UDP broadcast, HTTP/HTTPS

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Inspired by LocalSend for P2P architecture
- Ethiopian bank SMS parsing patterns from community contributions
- Glassmorphism UI design trends
