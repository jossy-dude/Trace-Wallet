# Vault Pro v1.2.0

**Financial Transaction Management System with P2P Mobile Sync**

A lightweight, privacy-focused financial tracking application designed for Ethiopian users. Automatically parse bank SMS messages from CBE, Telebirr, and BOA, and sync them to your desktop via local WiFi.

## Features

### Core Features
- **Transaction Management**: Track income, expenses, and transfers
- **Bank SMS Parsing**: Automatic parsing of Ethiopian bank SMS (CBE, Telebirr, BOA)
- **P2P Mobile Sync**: Syncthing-style local WiFi synchronization
- **UDP Discovery**: Auto-discover devices on your network
- **SQLite Database**: Fast, reliable local storage
- **CSV Export**: Export your data for backup or analysis
- **People Management**: Organize contacts for faster transactions
- **Dashboard Analytics**: Real-time financial insights

### Privacy & Security
- **Zero Cloud**: All data stays on your devices
- **Local Network Only**: No internet required for sync
- **Token Authentication**: Secure device pairing
- **No Third-Party Services**: Complete ownership of your data

## Architecture

```
┌─────────────────┐         ┌─────────────────┐
│   Mobile App    │  HTTP   │  Desktop App    │
│  (React +       │ ──────► │  (Electron +    │
│   Capacitor)    │  UDP    │   React)        │
│                 │ ◄────── │                 │
│ - SMS Reader    │  Discover│ - FastAPI      │
│ - P2P Client    │         │ - SQLite DB     │
└─────────────────┘         └─────────────────┘
```

## Tech Stack

### Desktop
- **Frontend**: React 18, Tailwind CSS, React Router
- **Desktop Shell**: Electron
- **Backend**: FastAPI (Python)
- **Database**: SQLite

### Mobile (Coming Soon)
- **Framework**: React + Capacitor
- **SMS**: Capacitor SMS plugin
- **P2P**: HTTP client + UDP discovery

## Installation

### Prerequisites
- Node.js 18+
- Python 3.11+
- npm or yarn

### Desktop Setup

1. **Install Python dependencies**:
```bash
cd vault_pro/python
pip install -r requirements.txt
```

2. **Start the backend server**:
```bash
python python/start_server.py
```

3. **Install Node dependencies** (in another terminal):
```bash
cd vault_pro
npm install
```

4. **Run the development server**:
```bash
npm run dev
```

5. **Build for production**:
```bash
npm run dist
```

### Mobile Setup (Coming Soon)

```bash
cd vault_pro
npm install @capacitor/core @capacitor/cli
npx cap init
npx cap add android
npm run build
npx cap sync
```

## Usage

### Starting the Application

1. **Start Backend**: 
```bash
python python/start_server.py
```
Server will start on `http://localhost:8080`

2. **Start Frontend**:
```bash
npm run dev
```
App will open on `http://localhost:5173`

### P2P Sync Setup

1. **Enable Discovery** on desktop (Settings → P2P Sync)
2. **Open mobile app** and scan QR code
3. **Approve pairing** on desktop
4. **Send SMS** on mobile → automatically synced to desktop

### API Endpoints

- `GET /api/health` - Health check
- `GET /api/transactions` - Get transactions
- `POST /api/transactions` - Create transaction
- `POST /api/sms` - Receive SMS from mobile
- `GET /api/dashboard/stats` - Dashboard statistics
- `GET /api/discovery/devices` - Get discovered devices
- `GET /api/export/csv` - Export transactions to CSV

## Configuration

### Data Storage
- **Windows**: `%APPDATA%/VaultPro/`
- **macOS**: `~/Library/Application Support/VaultPro/`
- **Linux**: `~/.vault_pro/`

Files:
- `vault.db` - SQLite database
- `config.json` - Application settings

### Environment Variables

Create `.env` file in root:
```
VITE_API_URL=http://localhost:8080
DEBUG=false
```

## Development

### Project Structure
```
vault_pro/
├── electron/          # Electron main process
├── python/            # FastAPI backend
│   ├── main.py       # Main API server
│   └── requirements.txt
├── src/              # React frontend
│   ├── components/   # UI components
│   ├── hooks/        # Custom React hooks
│   ├── utils/        # Utilities (API client)
│   └── App.jsx       # Main app component
├── package.json
└── README.md
```

### Running Tests
```bash
# Backend tests
pytest python/tests/

# Frontend tests
npm test
```

## Troubleshooting

### Backend won't start
- Check if port 8080 is available
- Ensure Python 3.11+ is installed
- Install dependencies: `pip install -r requirements.txt`

### Can't connect to server
- Verify backend is running on `http://localhost:8080`
- Check firewall settings
- Try `http://127.0.0.1:8080`

### P2P Discovery not working
- Ensure both devices are on same WiFi network
- Check if UDP port 5333 is blocked
- Restart discovery service

## Roadmap

### v1.3.0 (Next Release)
- [ ] Mobile app (React + Capacitor)
- [ ] QR code pairing
- [ ] Budget tracking
- [ ] Recurring transactions
- [ ] Dark/Light theme toggle

### v1.4.0
- [ ] Multi-currency support
- [ ] Amharic/Oromo localization
- [ ] Data encryption
- [ ] Backup/Restore functionality

## License

MIT License - See LICENSE file for details

## Support

For issues and feature requests, please open a GitHub issue.

---

**Built with ❤️ for Ethiopia**
