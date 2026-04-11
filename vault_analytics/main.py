import webview
import json
import os
import hashlib
import csv
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta

DATA_FILE = "vault_data.json"

DEFAULT_DATA = {
    "password_hash": None,
    "has_setup_password": False,
    "net_worth": 1284500.00,
    "monthly_income": 14200.00,
    "monthly_burn": 8430.12,
    "theme": "light",
    "privacy_mask": False,
    "biometrics": True,
    "currency": "USD ($)",
    "transactions": [],
    "audit_log": [],
    "goals": [
        {"name": "New Car", "target": 25000, "current": 12400},
        {"name": "Japan Trip", "target": 12000, "current": 4200}
    ]
}

class VaultPro:
    def __init__(self):
        self.window = None
        self.data = {}
        self.load_data()

    def set_window(self, window):
        self.window = window

    def _log_audit(self, event, confidence="HIGH", details=""):
        if "audit_log" not in self.data: self.data["audit_log"] = []
        self.data["audit_log"].insert(0, {
            "timestamp": datetime.now().isoformat(),
            "event": event,
            "confidence": confidence,
            "details": details
        })
        # Keep max 200 entries
        self.data["audit_log"] = self.data["audit_log"][:200]

    def load_data(self):
        if not os.path.exists(DATA_FILE):
            self.data = json.loads(json.dumps(DEFAULT_DATA))
            self._log_audit("Vault Genesis", "HIGH", "Initial vault_data.json created")
            self.save_data()
        else:
            try:
                with open(DATA_FILE, 'r') as f:
                    self.data = json.load(f)
                for key in DEFAULT_DATA:
                    if key not in self.data:
                        self.data[key] = DEFAULT_DATA[key]
            except Exception as e:
                print(f"Error loading data: {e}")
                self.data = json.loads(json.dumps(DEFAULT_DATA))
                self._log_audit("Data Corruption Recovery", "CRITICAL", str(e))

    def save_data(self):
        try:
            with open(DATA_FILE, 'w') as f:
                json.dump(self.data, f, indent=4)
        except Exception as e:
            print(f"Save error: {e}")

    def _calculate_anomaly(self, tx):
        if tx["type"] == "Income": return False
        amt = tx["amount"]
        cat = tx.get("category", "Other")
        past = [t["amount"] for t in self.data.get("transactions", []) if t["type"] == "Expense" and t.get("category") == cat]
        if len(past) < 3:
            if "fee" in tx.get("description", "").lower() and amt > 50.0:
                self._log_audit("Ghost Fee Detected", "MEDIUM", f"Anomalous fee: {tx['description']} (${amt})")
                return True
            return False
        avg = sum(past) / len(past)
        if amt > (avg * 2.5) and amt > 50:
            self._log_audit("Anomaly Threshold Breached", "HIGH", f"{tx['description']} is {amt/avg:.1f}x above {cat} average (${avg:.2f})")
            return True
        return False

    def sync_data(self):
        self.load_data()
        nw = self.data.get("net_worth", 0)
        burn = self.data.get("monthly_burn", 1)
        inc = self.data.get("monthly_income", 1)
        savings_rate = ((inc - burn) / inc * 100) if inc > 0 else 0
        ratio = inc / burn if burn > 0 else 1
        health = 50
        health += min(30, savings_rate)
        health += min(20, ratio * 10)
        self.data["health_score"] = int(max(0, min(100, health)))
        self.data["savings_rate"] = round(savings_rate, 1)
        self.data["ratio"] = round(ratio, 2)
        # 6-month predictions
        preds = []
        pnw = nw
        for i in range(1, 7):
            pnw += (inc - burn)
            preds.append({"month": (datetime.now() + timedelta(days=30*i)).strftime("%b %Y"), "projected_net_worth": round(pnw, 2)})
        self.data["predictions"] = preds
        self._log_audit("Vault Sync", "HIGH", "Full data refresh completed")
        self.save_data()
        return self.data

    def update_setting(self, data):
        key = data.get("key")
        value = data.get("value")
        if key:
            self.data[key] = value
            self._log_audit("Setting Changed", "HIGH", f"{key} = {value}")
            self.save_data()
            return {"status": "success"}
        return {"status": "error"}

    def add_transaction(self, data):
        tx = {
            "id": len(self.data.get("transactions", [])) + 1,
            "date": datetime.now().isoformat(),
            "description": data.get("description", "Manual Entry"),
            "amount": float(data.get("amount", 0.0)),
            "type": data.get("type", "Expense"),
            "category": data.get("category", "Other"),
            "is_anomaly": False
        }
        tx["is_anomaly"] = self._calculate_anomaly(tx)
        if "transactions" not in self.data: self.data["transactions"] = []
        self.data["transactions"].insert(0, tx)
        if tx["type"] == "Income": self.data["net_worth"] += tx["amount"]
        elif tx["type"] == "Expense": self.data["net_worth"] -= tx["amount"]
        self.save_data()
        return {"status": "success", "message": "Transaction secured", "is_anomaly": tx["is_anomaly"]}

    def add_goal(self, data):
        if "goals" not in self.data: self.data["goals"] = []
        self.data["goals"].append({"name": data.get("name","Goal"), "target": float(data.get("target",1000)), "current": float(data.get("current",0))})
        self._log_audit("Goal Created", "MEDIUM", data.get("name","Goal"))
        self.save_data()
        return {"status": "success"}

    def export_data(self):
        if not self.window: return {"status": "error", "message": "No window"}
        result = self.window.create_file_dialog(webview.SAVE_DIALOG, save_filename='vault_export.json')
        if result:
            with open(result[0], 'w') as f: json.dump(self.data, f, indent=4)
            self._log_audit("Data Export", "HIGH", f"To {result[0]}")
            return {"status": "success", "message": "Exported to " + result[0]}
        return {"status": "cancelled", "message": "Export cancelled"}

    def parse_ledger_file(self):
        if not self.window: return {"status": "error", "message": "No window"}
        result = self.window.create_file_dialog(webview.OPEN_DIALOG, file_types=('Ledger (*.csv;*.xml)', 'All (*.*)'))
        if result:
            fp = result[0]
            try:
                cnt = 0
                if fp.endswith('.csv'):
                    with open(fp, 'r', encoding='utf-8') as f:
                        for row in csv.DictReader(f):
                            a = float(row.get('Amount', 0))
                            tx = {"id": len(self.data["transactions"])+1, "date": row.get('Date', datetime.now().isoformat()), "description": row.get('Description','Import'), "amount": abs(a), "type": "Income" if a>0 else "Expense", "category":"Imported","is_anomaly":False}
                            tx["is_anomaly"] = self._calculate_anomaly(tx)
                            self.data["transactions"].insert(0, tx); cnt += 1
                elif fp.endswith('.xml'):
                    try:
                        tree = ET.parse(fp)
                    except ET.ParseError as e:
                        self._log_audit("XML Parse Failure", "LOW", str(e))
                        return {"status": "degraded", "message": str(e), "file": fp}
                    for n in tree.getroot().findall('.//Transaction'):
                        an = n.find('Amount')
                        a = float(an.text) if an is not None else 0
                        tx = {"id": len(self.data["transactions"])+1, "date": datetime.now().isoformat(), "description":"XML Import", "amount":abs(a), "type":"Income" if a>0 else "Expense", "category":"Imported","is_anomaly":False}
                        self.data["transactions"].insert(0, tx); cnt += 1
                self._log_audit("Batch Import", "HIGH", f"{cnt} records imported from {os.path.basename(fp)}")
                self.save_data()
                return {"status": "success", "message": f"{cnt} records imported"}
            except Exception as e:
                self._log_audit("Parser Failure", "FAIL", str(e))
                return {"status": "degraded", "message": str(e), "file": fp}
        return {"status": "cancelled", "message": "Import cancelled"}

    def check_password(self, pwd):
        if not self.data.get("has_setup_password"): return True
        return hashlib.sha256(pwd.encode('utf-8')).hexdigest() == self.data.get("password_hash")

    def setup_password(self, pwd):
        self.data["password_hash"] = hashlib.sha256(pwd.encode('utf-8')).hexdigest()
        self.data["has_setup_password"] = True
        self._log_audit("Password Updated", "HIGH", "Master password hash rotated")
        self.save_data()
        return {"status": "success"}

    def check_auth_status(self):
        return {"has_password": self.data.get("has_setup_password", False)}

    def minimize_window(self):
        if self.window: self.window.minimize()
    def maximize_window(self):
        if self.window: self.window.toggle_fullscreen()
    def close_window(self):
        if self.window: self.window.destroy()



HTML_CONTENT = r'''
<!DOCTYPE html>
<html class="light" lang="en"><head>
<meta charset="utf-8"/>
<meta content="width=device-width, initial-scale=1.0" name="viewport"/>
<title>Vault Analytics — Enterprise Command</title>
<script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
<link href="https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600;700;800&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&display=swap" rel="stylesheet"/>
<script>
tailwind.config = {
    darkMode: "class",
    theme: { extend: {
        colors: {
            "tertiary-fixed-dim":"#88d982","on-primary-fixed-variant":"#2a486e","on-surface-variant":"#434750",
            "surface-container-lowest":"#ffffff","on-error-container":"#93000a","inverse-primary":"#abc8f5",
            "on-primary-fixed":"#001c39","primary-container":"#103257","surface-bright":"#f7f9fc",
            "primary-fixed":"#d3e3ff","on-secondary-container":"#56657b","on-primary-container":"#7e9bc6",
            "error":"#ba1a1a","surface-container-high":"#e6e8eb","primary":"#001d3b",
            "on-tertiary-fixed":"#002204","on-secondary-fixed-variant":"#39485d","on-surface":"#191c1e",
            "surface-variant":"#e0e3e6","error-container":"#ffdad6","surface-dim":"#d8dadd",
            "surface-container-low":"#f2f4f7","secondary-fixed":"#d4e3fe","on-secondary-fixed":"#0c1c2f",
            "outline":"#747781","surface-container":"#eceef1","on-tertiary":"#ffffff","on-error":"#ffffff",
            "surface-tint":"#426087","outline-variant":"#c4c6d2","surface-container-highest":"#e0e3e6",
            "on-tertiary-container":"#5cab5a","tertiary":"#002304","background":"#f7f9fc",
            "tertiary-fixed":"#a3f69c","on-tertiary-fixed-variant":"#005312","secondary-fixed-dim":"#b8c7e1",
            "secondary":"#505f75","inverse-surface":"#2d3133","on-primary":"#ffffff","on-secondary":"#ffffff",
            "surface":"#f7f9fc","inverse-on-surface":"#eff1f4","primary-fixed-dim":"#abc8f5",
            "secondary-container":"#d4e3fe","tertiary-container":"#003b0a","on-background":"#191c1e"
        },
        fontFamily: { headline:["Manrope"], body:["Inter"], label:["Inter"] }
    }}
}
</script>
<style>
    .material-symbols-outlined { font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24; }
    .glass-panel { background: rgba(255,255,255,0.45); backdrop-filter: blur(16px); border: 1px solid rgba(255,255,255,0.3); }
    .glass-primary { background: rgba(0,29,59,0.85); backdrop-filter: blur(16px); border: 1px solid rgba(255,255,255,0.1); box-shadow: 0 10px 30px -5px rgba(0,29,59,0.3); }
    .dark .glass-panel { background: rgba(30,41,59,0.7); border-color: rgba(255,255,255,0.08); }
    .dark .glass-primary { background: rgba(10,20,35,0.95); }
    .vault-gradient { background: linear-gradient(135deg, #001d3b 0%, #103257 100%); }
    .ghost-shadow { box-shadow: 0 8px 24px rgba(25,28,30,0.06); }
    ::-webkit-scrollbar { width: 5px; }
    ::-webkit-scrollbar-track { background: transparent; }
    ::-webkit-scrollbar-thumb { background: rgba(0,0,0,0.08); border-radius: 10px; }
    /* Privacy Mask */
    .privacy-active .priv { filter: blur(8px); transition: filter 0.2s; }
    .privacy-active .priv:hover { filter: blur(0); }
    /* Toast */
    #toast-box { position:fixed; top:3rem; right:1rem; z-index:9999; display:flex; flex-direction:column; gap:0.5rem; pointer-events:none; }
    .toast-item { background:#191c1e; color:#fff; padding:0.75rem 1.25rem; border-radius:0.75rem; box-shadow:0 10px 25px rgba(0,0,0,0.25); font-family:'Inter'; font-size:0.8rem; font-weight:600; opacity:0; transform:translateX(30px); transition:all 0.3s ease; pointer-events:auto; display:flex; align-items:center; gap:0.5rem; }
    .toast-item.show { opacity:1; transform:translateX(0); }
    .dark .toast-item { background:#334155; }
    /* Degraded state */
    .degraded-overlay { position:fixed; inset:0; top:2rem; z-index:150; background:rgba(186,26,26,0.05); backdrop-filter:blur(2px); display:none; align-items:center; justify-content:center; }
    .degraded-overlay.active { display:flex; }
    /* page transitions */
    .app-page { animation: fadeUp 0.25s ease; }
    @keyframes fadeUp { from { opacity:0; transform:translateY(8px); } to { opacity:1; transform:translateY(0); } }
</style>
</head>
<body class="bg-surface dark:bg-slate-950 font-body text-on-surface dark:text-slate-100 antialiased overflow-hidden select-none h-screen flex flex-col pt-8 transition-colors duration-300">

<!-- TITLE BAR -->
<div class="pywebview-drag-region h-8 bg-slate-900 w-full flex items-center justify-between px-4 text-white fixed top-0 left-0 z-[100] border-b border-white/10">
    <div class="flex items-center gap-3">
        <div class="text-[10px] font-bold font-headline tracking-[0.25em] text-slate-400">VAULT INTEGRITY OS</div>
        <div class="w-1.5 h-1.5 rounded-full bg-tertiary-fixed-dim animate-pulse"></div>
    </div>
    <div class="flex gap-4">
        <button onclick="pywebview.api.minimize_window()" class="hover:text-blue-400 material-symbols-outlined text-[16px] leading-none">remove</button>
        <button onclick="pywebview.api.maximize_window()" class="hover:text-blue-400 material-symbols-outlined text-[14px]">crop_square</button>
        <button onclick="pywebview.api.close_window()" class="hover:text-red-400 material-symbols-outlined text-[16px]">close</button>
    </div>
</div>

<div id="toast-box"></div>

<!-- LOCK SCREEN -->
<div id="lock-screen" class="fixed inset-0 top-8 bg-slate-900/95 backdrop-blur-3xl z-[200] flex items-center justify-center hidden">
    <div class="bg-white dark:bg-slate-800 p-10 rounded-3xl border border-white/10 w-[400px] text-center shadow-2xl">
        <span class="material-symbols-outlined text-6xl text-primary dark:text-blue-300 mb-4" style="font-variation-settings:'FILL' 1;">enhanced_encryption</span>
        <h2 class="text-3xl font-headline font-extrabold text-primary dark:text-blue-100 mb-2" id="lock-title">Vault Locked</h2>
        <p class="text-sm text-on-surface-variant mb-8" id="lock-desc">Enter authorization code to proceed</p>
        <input type="password" id="auth-code" class="w-full border border-outline-variant/30 dark:border-slate-600 dark:bg-slate-900 rounded-xl p-4 text-center tracking-widest font-bold mb-6 focus:ring-2 focus:ring-primary focus:outline-none" placeholder="••••••••" onkeypress="if(event.key==='Enter')checkAuth()">
        <button onclick="checkAuth()" class="w-full bg-primary text-white py-4 rounded-xl font-headline font-bold uppercase tracking-widest hover:brightness-110 transition-all">Authenticate</button>
        <p id="lock-error" class="text-error text-xs font-bold mt-4 h-4"></p>
    </div>
</div>

<!-- DEGRADED STATE OVERLAY -->
<div id="degraded-overlay" class="degraded-overlay">
    <div class="bg-white dark:bg-slate-800 p-10 rounded-3xl border border-error/30 w-[500px] text-center shadow-2xl">
        <span class="material-symbols-outlined text-6xl text-error mb-4">emergency</span>
        <h2 class="text-2xl font-headline font-extrabold text-error mb-2">Vault Offline</h2>
        <p class="text-sm text-on-surface-variant mb-4" id="degraded-msg">A critical data integrity issue was detected.</p>
        <div class="bg-error-container dark:bg-red-900/30 p-4 rounded-xl text-left mb-6">
            <p class="text-xs font-bold text-on-error-container uppercase tracking-wider mb-2">Troubleshooting</p>
            <ul class="text-xs text-on-error-container space-y-1 list-disc pl-4">
                <li>Verify vault_data.json is not corrupted</li>
                <li>Ensure the import file is valid CSV or XML</li>
                <li>Restart the application</li>
            </ul>
        </div>
        <button onclick="document.getElementById('degraded-overlay').classList.remove('active')" class="bg-primary text-white px-6 py-3 rounded-xl font-bold text-sm">Dismiss & Continue</button>
    </div>
</div>

<div class="flex h-full overflow-hidden flex-1 relative">

<!-- SIDEBAR -->
<aside class="hidden md:flex flex-col h-full w-[260px] flex-shrink-0 bg-white dark:bg-slate-900 border-r border-slate-200/50 dark:border-white/5 z-40">
    <div class="p-6 flex flex-col h-full">
        <div class="mb-8 flex items-center gap-3">
            <div class="w-10 h-10 bg-primary rounded-xl flex items-center justify-center text-white shadow-lg shadow-primary/20">
                <span class="material-symbols-outlined" style="font-variation-settings:'FILL' 1;">account_balance</span>
            </div>
            <div>
                <h1 class="font-headline font-black text-lg tracking-tight text-primary dark:text-blue-100 leading-none">Vault</h1>
                <p class="text-on-surface-variant text-[9px] uppercase tracking-[0.2em] font-bold mt-0.5">Financial Integrity</p>
            </div>
        </div>
        <nav class="flex flex-col gap-1.5 flex-grow" id="sidebar-nav">
            <a onclick="navigate('command')" id="nav-command" class="nav-btn flex items-center gap-3 px-4 py-3 rounded-xl bg-primary text-white font-bold text-sm cursor-pointer shadow-sm transition-all"><span class="material-symbols-outlined text-[20px]">dashboard</span> Command Center</a>
            <a onclick="navigate('ledger')" id="nav-ledger" class="nav-btn flex items-center gap-3 px-4 py-3 rounded-xl text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 font-semibold text-sm cursor-pointer transition-all"><span class="material-symbols-outlined text-[20px]">receipt_long</span> Deep Ledger</a>
            <a onclick="navigate('intel')" id="nav-intel" class="nav-btn flex items-center gap-3 px-4 py-3 rounded-xl text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 font-semibold text-sm cursor-pointer transition-all"><span class="material-symbols-outlined text-[20px]">analytics</span> Visual Intelligence</a>
            <a onclick="navigate('settings')" id="nav-settings" class="nav-btn flex items-center gap-3 px-4 py-3 rounded-xl text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 font-semibold text-sm cursor-pointer transition-all"><span class="material-symbols-outlined text-[20px]">settings</span> Settings</a>
            <a onclick="navigate('predictions')" id="nav-predictions" class="nav-btn flex items-center gap-3 px-4 py-3 rounded-xl text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 font-semibold text-sm cursor-pointer transition-all"><span class="material-symbols-outlined text-[20px]">trending_up</span> Predictions</a>
            <a onclick="navigate('audit')" id="nav-audit" class="nav-btn flex items-center gap-3 px-4 py-3 rounded-xl text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 font-semibold text-sm cursor-pointer transition-all"><span class="material-symbols-outlined text-[20px]">verified_user</span> Vault Audit</a>
        </nav>
        <div class="pt-4 border-t border-slate-200 dark:border-white/10 space-y-2">
            <button onclick="exportData()" class="w-full flex items-center gap-3 px-4 py-2.5 text-slate-500 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl font-semibold text-sm transition-all"><span class="material-symbols-outlined text-[18px]">download</span> Export JSON</button>
            <button onclick="importLedger()" class="w-full flex items-center gap-3 px-4 py-2.5 text-slate-500 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl font-semibold text-sm transition-all"><span class="material-symbols-outlined text-[18px]">upload_file</span> Import Ledger</button>
            <button onclick="lockVault()" class="w-full mt-3 bg-primary text-white py-3 rounded-xl font-headline font-bold text-sm flex items-center justify-center gap-2 shadow-lg shadow-primary/20 hover:brightness-110 transition-all"><span class="material-symbols-outlined text-[16px]">lock</span> Lock Vault</button>
        </div>
    </div>
</aside>

<!-- MAIN CONTENT -->
<main class="flex-1 overflow-y-auto bg-surface-container-low dark:bg-slate-950 select-text">
    <!-- Global Header -->
    <header class="w-full h-14 sticky top-0 z-30 bg-surface-container-low/80 dark:bg-slate-950/80 backdrop-blur-md flex justify-between items-center px-8 border-b border-outline-variant/10">
        <div class="flex items-center gap-3">
            <div class="px-3 py-1 bg-secondary-container dark:bg-blue-900/40 rounded-full flex items-center gap-2">
                <span class="w-2 h-2 rounded-full bg-on-tertiary-container animate-pulse"></span>
                <span class="text-[9px] font-bold text-on-secondary-fixed dark:text-blue-200 uppercase tracking-wider">Enclave Active</span>
            </div>
            <div id="health-badge" class="px-3 py-1 bg-tertiary-fixed/30 rounded-full items-center gap-1 hidden">
                <span class="material-symbols-outlined text-[14px] text-on-tertiary-container">favorite</span>
                <span class="text-[9px] font-bold text-on-tertiary-container uppercase" id="health-score-header">--</span>
            </div>
        </div>
        <div class="flex items-center gap-3">
            <button onclick="togglePrivacy()" id="privacy-toggle" class="p-2 rounded-lg hover:bg-slate-200/50 dark:hover:bg-slate-800 text-on-surface-variant transition-colors" title="Toggle Privacy Mask"><span class="material-symbols-outlined text-[20px]">visibility</span></button>
            <span id="sync-indicator" class="text-xs font-bold text-primary dark:text-blue-300 opacity-0 transition-opacity flex items-center gap-1"><span class="material-symbols-outlined text-sm animate-spin">refresh</span></span>
            <button onclick="syncData()" class="p-2 rounded-lg hover:bg-slate-200/50 dark:hover:bg-slate-800 text-on-surface-variant transition-colors"><span class="material-symbols-outlined text-[20px]">sync</span></button>
            <button onclick="showToast('No new alerts')" class="p-2 rounded-lg hover:bg-slate-200/50 dark:hover:bg-slate-800 text-on-surface-variant transition-colors"><span class="material-symbols-outlined text-[20px]">notifications</span></button>
            <div class="w-8 h-8 rounded-full bg-primary text-white flex items-center justify-center font-bold text-xs border-2 border-primary-container shadow-sm">VP</div>
        </div>
    </header>

    <!-- ============ PAGE: COMMAND CENTER ============ -->
    <div id="page-command" class="app-page max-w-[1200px] mx-auto p-8 flex flex-col gap-8 pb-24">
        <!-- Hero -->
        <section class="relative vault-gradient rounded-[2.5rem] p-10 overflow-hidden flex flex-col md:flex-row items-center justify-between ghost-shadow min-h-[260px]">
            <div class="absolute top-0 right-0 w-1/2 h-full opacity-10 pointer-events-none"><svg class="w-full h-full" viewBox="0 0 200 200"><path d="M44.7,-76.4C58.1,-69.2,69.5,-57.4,77.3,-43.8C85.1,-30.2,89.2,-15.1,88.4,-0.5C87.5,14.1,81.7,28.2,73.1,40.4C64.5,52.6,53.2,62.9,40.1,70.5C27,78.1,13.5,83,0.3,82.5C-12.9,82,-25.8,76.1,-37.8,68.2C-49.8,60.3,-60.9,50.4,-68.8,38.4C-76.7,26.4,-81.4,12.2,-81.8,-2.2C-82.2,-16.6,-78.3,-31.2,-69.7,-42.9C-61.1,-54.6,-47.8,-63.4,-34.2,-70.5C-20.6,-77.6,-6.6,-83.1,8.3,-84.5C23.2,-85.9,31.3,-83.6,44.7,-76.4Z" fill="#FFFFFF" transform="translate(100 100)"></path></svg></div>
            <div class="relative z-10 flex flex-col gap-2 text-white">
                <p class="text-white/60 font-headline text-[11px] uppercase tracking-[0.25em] font-bold">Total Net Worth</p>
                <h1 class="font-headline text-6xl font-extrabold tracking-tight priv" id="cmd-net-worth">$0.00</h1>
                <div class="flex items-center gap-2 text-tertiary-fixed mt-1">
                    <span class="material-symbols-outlined text-sm">trending_up</span>
                    <span class="text-sm font-bold" id="cmd-health-label">Calculating...</span>
                </div>
            </div>
            <div class="relative z-10 glass-panel p-6 rounded-2xl flex flex-col gap-3 border border-white/10 min-w-[260px] text-white/90 mt-6 md:mt-0">
                <div class="flex justify-between items-center text-white/50">
                    <p class="text-[10px] font-bold uppercase tracking-wider">Vault Insights</p>
                    <span class="material-symbols-outlined text-sm">auto_awesome</span>
                </div>
                <p class="text-sm leading-relaxed" id="cmd-ai-insight">Analyzing your local records...</p>
                <button onclick="navigate('intel')" class="bg-white text-primary text-xs font-bold py-2 rounded-lg hover:bg-slate-100 transition-colors">Full Analytics</button>
            </div>
        </section>

        <!-- KPI Row -->
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <div class="bg-surface-container-lowest dark:bg-slate-900 p-5 rounded-2xl ghost-shadow border border-outline-variant/10 flex flex-col gap-1">
                <div class="flex items-center gap-2 mb-1"><span class="material-symbols-outlined text-primary text-[18px]">account_balance</span><span class="text-[9px] font-bold text-on-surface-variant uppercase tracking-wider">Income</span></div>
                <span class="text-xl font-headline font-extrabold text-primary dark:text-blue-200 priv" id="cmd-income">$0</span>
            </div>
            <div class="bg-surface-container-lowest dark:bg-slate-900 p-5 rounded-2xl ghost-shadow border border-outline-variant/10 flex flex-col gap-1">
                <div class="flex items-center gap-2 mb-1"><span class="material-symbols-outlined text-error text-[18px]">credit_card</span><span class="text-[9px] font-bold text-on-surface-variant uppercase tracking-wider">Burn Rate</span></div>
                <span class="text-xl font-headline font-extrabold text-error priv" id="cmd-burn">$0</span>
            </div>
            <div class="bg-surface-container-lowest dark:bg-slate-900 p-5 rounded-2xl ghost-shadow border border-outline-variant/10 flex flex-col gap-1">
                <div class="flex items-center gap-2 mb-1"><span class="material-symbols-outlined text-on-tertiary-container text-[18px]">savings</span><span class="text-[9px] font-bold text-on-surface-variant uppercase tracking-wider">Savings Rate</span></div>
                <span class="text-xl font-headline font-extrabold text-on-tertiary-container" id="cmd-savings">0%</span>
            </div>
            <div class="bg-surface-container-lowest dark:bg-slate-900 p-5 rounded-2xl ghost-shadow border border-outline-variant/10 flex flex-col gap-1">
                <div class="flex items-center gap-2 mb-1"><span class="material-symbols-outlined text-primary text-[18px]">favorite</span><span class="text-[9px] font-bold text-on-surface-variant uppercase tracking-wider">Health Score</span></div>
                <span class="text-xl font-headline font-extrabold" id="cmd-health">--</span>
            </div>
        </div>

        <!-- Recent Queue -->
        <section class="flex flex-col gap-4">
            <div class="flex justify-between items-end">
                <h2 class="font-headline font-bold text-xl text-primary dark:text-blue-100">Pending Execution</h2>
                <span class="bg-error-container dark:bg-red-900/30 text-on-error-container dark:text-red-300 px-2 py-0.5 rounded text-[10px] font-bold uppercase" id="cmd-tx-count">0 SETTLED</span>
            </div>
            <div id="cmd-recent-list" class="flex flex-col gap-3">
                <div class="p-6 text-center text-on-surface-variant text-sm border border-dashed rounded-xl border-outline-variant/30">Loading...</div>
            </div>
            <button onclick="navigate('ledger')" class="text-xs font-bold text-primary dark:text-blue-300 flex items-center gap-1 self-center hover:underline">View Full Ledger <span class="material-symbols-outlined text-sm">chevron_right</span></button>
        </section>
    </div>

    <!-- ============ PAGE: DEEP LEDGER ============ -->
    <div id="page-ledger" class="app-page max-w-[1200px] mx-auto p-8 flex flex-col gap-6 pb-24 hidden">
        <header class="flex justify-between items-end">
            <div>
                <h2 class="text-3xl font-headline font-extrabold tracking-tight text-primary dark:text-blue-100">Deep Ledger</h2>
                <p class="text-on-surface-variant text-sm mt-1">Full transaction history with anomaly detection.</p>
            </div>
            <div class="flex gap-2">
                <div class="relative">
                    <input type="text" id="ledger-search" oninput="filterLedger()" class="bg-surface-container-lowest dark:bg-slate-900 border border-outline-variant/20 dark:border-slate-700 rounded-xl py-2 pl-9 pr-4 text-sm w-56 focus:outline-none focus:ring-1 focus:ring-primary" placeholder="Search...">
                    <span class="material-symbols-outlined absolute left-2.5 top-1/2 -translate-y-1/2 text-on-surface-variant text-[18px]">search</span>
                </div>
                <select id="ledger-filter" onchange="filterLedger()" class="bg-surface-container-lowest dark:bg-slate-900 border border-outline-variant/20 dark:border-slate-700 rounded-xl py-2 px-3 text-sm focus:outline-none focus:ring-1 focus:ring-primary">
                    <option value="all">All Types</option>
                    <option value="Income">Income</option>
                    <option value="Expense">Expense</option>
                    <option value="anomaly">Anomalies Only</option>
                </select>
            </div>
        </header>

        <!-- Ledger Stats Bar -->
        <div class="grid grid-cols-3 gap-4">
            <div class="bg-surface-container-lowest dark:bg-slate-900 p-4 rounded-xl border border-outline-variant/10 text-center">
                <p class="text-[9px] font-bold text-on-surface-variant uppercase tracking-wider">Total Entries</p>
                <p class="text-lg font-headline font-extrabold text-primary dark:text-blue-200" id="ledger-total">0</p>
            </div>
            <div class="bg-surface-container-lowest dark:bg-slate-900 p-4 rounded-xl border border-outline-variant/10 text-center">
                <p class="text-[9px] font-bold text-on-surface-variant uppercase tracking-wider">Total Volume</p>
                <p class="text-lg font-headline font-extrabold text-primary dark:text-blue-200 priv" id="ledger-volume">$0</p>
            </div>
            <div class="bg-surface-container-lowest dark:bg-slate-900 p-4 rounded-xl border border-outline-variant/10 text-center">
                <p class="text-[9px] font-bold text-on-surface-variant uppercase tracking-wider">Anomalies</p>
                <p class="text-lg font-headline font-extrabold text-error" id="ledger-anomalies">0</p>
            </div>
        </div>

        <!-- Ledger Table -->
        <div class="bg-surface-container-lowest dark:bg-slate-900 rounded-[2rem] ghost-shadow overflow-hidden border border-outline-variant/10">
            <div id="ledger-list" class="divide-y divide-outline-variant/10 dark:divide-slate-800 max-h-[55vh] overflow-y-auto">
                <div class="p-8 text-center text-on-surface-variant text-sm">Loading ledger...</div>
            </div>
        </div>
    </div>

    <!-- ============ PAGE: VISUAL INTELLIGENCE ============ -->
    <div id="page-intel" class="app-page max-w-[1200px] mx-auto p-8 flex flex-col gap-6 pb-24 hidden">
        <header>
            <h2 class="text-3xl font-headline font-extrabold tracking-tight text-primary dark:text-blue-100">Visual Intelligence</h2>
            <p class="text-on-surface-variant text-sm mt-1">Advanced analytics, projections, and spending decomposition.</p>
        </header>
        <section class="grid grid-cols-1 md:grid-cols-12 gap-6">
            <!-- Spending Trajectory -->
            <div class="md:col-span-8 glass-panel dark:bg-slate-900 rounded-[2.5rem] p-8 shadow-sm">
                <div class="flex justify-between items-center mb-6">
                    <div><h3 class="font-headline text-lg font-bold">Spending Trajectory</h3><p class="text-on-surface-variant text-[11px] opacity-70">Daily flow vs projection</p></div>
                    <div class="flex gap-2">
                        <span class="flex items-center gap-1.5 px-3 py-1 rounded-full bg-primary/5 dark:bg-blue-900/30 text-[10px] font-bold uppercase"><div class="w-1.5 h-1.5 rounded-full bg-primary"></div> Income</span>
                        <span class="flex items-center gap-1.5 px-3 py-1 rounded-full bg-on-tertiary-container/5 text-[10px] font-bold uppercase"><div class="w-1.5 h-1.5 rounded-full bg-on-tertiary-container"></div> Projection</span>
                    </div>
                </div>
                <div class="h-60 relative w-full">
                    <svg class="w-full h-full" preserveAspectRatio="none" viewBox="0 0 400 150">
                        <defs><linearGradient id="aG" x1="0%" x2="0%" y1="0%" y2="100%"><stop offset="0%" style="stop-color:#001d3b;stop-opacity:0.15"/><stop offset="100%" style="stop-color:#001d3b;stop-opacity:0"/></linearGradient></defs>
                        <line x1="0" y1="130" x2="400" y2="130" stroke="#e0e3e6" stroke-width="1" stroke-dasharray="4"/>
                        <line x1="0" y1="90" x2="400" y2="90" stroke="#e0e3e6" stroke-width="1" stroke-dasharray="4"/>
                        <line x1="0" y1="50" x2="400" y2="50" stroke="#e0e3e6" stroke-width="1" stroke-dasharray="4"/>
                        <path d="M0,100 C50,110 80,60 120,70 C160,80 200,30 250,50 C300,70 350,40 400,60 L400,150 L0,150 Z" fill="url(#aG)"/>
                        <path d="M0,100 C50,110 80,60 120,70 C160,80 200,30 250,50 C300,70 350,40 400,60" fill="none" stroke="#001d3b" stroke-width="3" stroke-linecap="round"/>
                        <path d="M0,80 C40,90 90,110 140,90 C190,70 240,110 300,100 C360,90 400,70 400,70" fill="none" stroke="#5cab5a" stroke-width="2" stroke-linecap="round" opacity="0.6"/>
                        <circle cx="250" cy="50" r="4" fill="#001d3b"/><circle cx="250" cy="50" r="8" fill="#001d3b" opacity="0.1"/>
                    </svg>
                </div>
                <div class="flex justify-between mt-4 px-2 text-[10px] font-bold text-on-surface-variant/50 uppercase tracking-widest border-t border-slate-200/50 dark:border-slate-700 pt-2"><span>Mon</span><span>Tue</span><span>Wed</span><span>Thu</span><span>Fri</span><span>Sat</span><span>Sun</span></div>
            </div>
            <!-- Donut -->
            <div class="md:col-span-4 glass-primary rounded-[2.5rem] p-8 flex flex-col items-center justify-center relative shadow-xl text-white">
                <div class="absolute top-6 left-6"><h3 class="font-headline text-sm font-bold opacity-80 uppercase tracking-widest">Allocation</h3></div>
                <div class="relative w-40 h-40 mb-6">
                    <svg class="w-full h-full drop-shadow-2xl" viewBox="0 0 36 36">
                        <circle cx="18" cy="18" r="15.9" fill="none" stroke="rgba(255,255,255,0.05)" stroke-width="3.5"/>
                        <circle cx="18" cy="18" r="15.9" fill="none" stroke="#a3f69c" stroke-width="4.5" stroke-dasharray="70, 100" stroke-linecap="round" class="drop-shadow-[0_0_8px_rgba(163,246,156,0.5)]"/>
                    </svg>
                    <div class="absolute inset-0 flex flex-col items-center justify-center bg-white/5 rounded-full m-4 backdrop-blur-md border border-white/10">
                        <span class="text-[10px] uppercase text-white/50 tracking-widest font-bold">Lifestyle</span>
                        <span class="text-3xl font-extrabold" id="intel-alloc">70%</span>
                    </div>
                </div>
                <div class="grid grid-cols-2 gap-4 w-full">
                    <div><div class="flex items-center gap-1.5 text-[10px] uppercase font-bold opacity-60 mb-0.5"><div class="w-1.5 h-1.5 rounded-full bg-tertiary-fixed"></div> Housing</div><span class="text-sm font-bold">42%</span></div>
                    <div class="text-right"><div class="flex items-center justify-end gap-1.5 text-[10px] uppercase font-bold opacity-60 mb-0.5"><div class="w-1.5 h-1.5 rounded-full bg-white/40"></div> Food</div><span class="text-sm font-bold">28%</span></div>
                </div>
            </div>
            <!-- Heatmap -->
            <div class="md:col-span-7 glass-panel dark:bg-slate-900 rounded-[2.5rem] p-8 shadow-sm">
                <div class="flex justify-between items-end mb-6">
                    <div><h3 class="font-headline text-lg font-bold">Activity Heat Map</h3><p class="text-on-surface-variant text-[11px] opacity-70">Contribution to net growth</p></div>
                    <div class="flex items-center gap-2 text-[9px] uppercase font-bold text-on-surface-variant/50"><span>Low</span><div class="flex gap-1"><div class="w-3 h-3 bg-surface-container rounded-sm"></div><div class="w-3 h-3 bg-tertiary-fixed-dim/50 rounded-sm"></div><div class="w-3 h-3 bg-tertiary-fixed rounded-sm"></div><div class="w-3 h-3 bg-primary rounded-sm"></div></div><span>High</span></div>
                </div>
                <div class="grid grid-cols-7 gap-1.5" id="intel-heatmap"></div>
            </div>
            <!-- Ratio -->
            <div class="md:col-span-5 glass-panel dark:bg-slate-900 rounded-[2.5rem] p-8 shadow-sm">
                <h3 class="font-headline text-lg font-bold mb-6">Refined Ratio</h3>
                <div class="flex items-center justify-between gap-4 mb-6">
                    <div class="text-center flex-1"><p class="text-[10px] font-bold text-on-surface-variant uppercase opacity-60">Income</p><p class="text-2xl font-extrabold text-on-tertiary-container priv" id="intel-income">$0</p></div>
                    <div class="h-10 w-[1px] bg-outline-variant/30"></div>
                    <div class="text-center flex-1"><p class="text-[10px] font-bold text-on-surface-variant uppercase opacity-60">Expenses</p><p class="text-2xl font-extrabold text-error/80 priv" id="intel-burn">$0</p></div>
                </div>
                <div class="w-full h-4 bg-surface-container-highest dark:bg-slate-800 rounded-full overflow-hidden flex border border-white/40 dark:border-slate-700">
                    <div id="ratio-income" class="h-full bg-gradient-to-r from-on-tertiary-container to-tertiary-fixed shadow-inner transition-all" style="width:50%"></div>
                    <div id="ratio-expense" class="h-full bg-error/40 transition-all" style="width:50%"></div>
                </div>
                <p class="mt-4 text-[11px] text-on-surface-variant text-center">Ratio: <span class="font-extrabold text-on-tertiary-container" id="intel-ratio">--</span></p>
            </div>
        </section>
    </div>

    <!-- ============ PAGE: SECURITY & SETTINGS ============ -->
    <div id="page-settings" class="app-page max-w-[1000px] mx-auto p-8 flex flex-col gap-8 pb-24 hidden">
        <header>
            <h2 class="text-3xl font-headline font-extrabold tracking-tight text-primary dark:text-blue-100">Advanced Settings</h2>
            <p class="text-on-surface-variant text-sm mt-1">Configure your editorial vault and security protocols.</p>
        </header>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <!-- Appearance -->
            <section class="bg-surface-container-lowest dark:bg-slate-900 border border-outline-variant/10 dark:border-slate-800 rounded-3xl p-8 shadow-sm">
                <div class="flex items-center gap-3 mb-6 border-b border-slate-100 dark:border-slate-800 pb-4">
                    <span class="material-symbols-outlined text-primary dark:text-blue-300">palette</span><h3 class="font-headline font-bold text-lg">Appearance</h3>
                </div>
                <div class="space-y-5">
                    <div><p class="text-[10px] font-bold uppercase tracking-widest text-on-surface-variant mb-3">Theme Mode</p>
                        <div class="grid grid-cols-2 gap-3">
                            <button onclick="setTheme('light')" id="theme-light" class="py-3 rounded-xl border border-outline-variant/30 dark:border-slate-700 font-bold text-sm flex items-center justify-center gap-2 bg-white dark:bg-slate-950 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors"><span class="material-symbols-outlined text-sm">light_mode</span> Light</button>
                            <button onclick="setTheme('dark')" id="theme-dark" class="py-3 rounded-xl border border-outline-variant/30 dark:border-slate-700 font-bold text-sm flex items-center justify-center gap-2 bg-white dark:bg-slate-950 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors"><span class="material-symbols-outlined text-sm">dark_mode</span> Dark</button>
                        </div>
                    </div>
                    <div class="flex justify-between items-center bg-surface dark:bg-slate-950 p-4 rounded-xl border border-outline-variant/20 dark:border-slate-700">
                        <div><p class="font-bold text-sm">Privacy Mask</p><p class="text-[10px] text-on-surface-variant">Blur all dollar amounts</p></div>
                        <button onclick="togglePrivacy()" id="privacy-switch" class="w-10 h-5 bg-outline-variant dark:bg-slate-600 rounded-full relative cursor-pointer transition-colors"><div class="absolute w-4 h-4 rounded-full bg-white left-0.5 top-0.5 transition-transform shadow-sm" id="privacy-dot"></div></button>
                    </div>
                </div>
            </section>
            <!-- Security -->
            <section class="bg-primary text-white rounded-3xl p-8 shadow-xl relative overflow-hidden">
                <div class="absolute -right-8 -top-8 opacity-10 pointer-events-none"><span class="material-symbols-outlined text-[150px]" style="font-variation-settings:'FILL' 1">security</span></div>
                <div class="relative z-10">
                    <div class="flex items-center gap-3 mb-6"><span class="material-symbols-outlined">security</span><h3 class="font-headline font-bold text-lg">Security Protocol</h3></div>
                    <div class="space-y-4">
                        <div class="bg-white/10 p-4 rounded-xl backdrop-blur flex justify-between items-center">
                            <div class="flex items-center gap-3"><span class="material-symbols-outlined">fingerprint</span><div><p class="font-bold text-sm">Biometrics</p><p class="text-[9px] uppercase tracking-widest opacity-70">Touch/FaceID</p></div></div>
                            <button onclick="toggleBio(this)" id="bio-switch" class="w-10 h-5 bg-tertiary-fixed-dim rounded-full relative cursor-pointer"><div class="absolute w-4 h-4 rounded-full bg-white right-0.5 top-0.5 transition-transform shadow-sm"></div></button>
                        </div>
                        <div class="bg-white/10 p-4 rounded-xl backdrop-blur flex justify-between items-center">
                            <div class="flex items-center gap-3"><span class="material-symbols-outlined">key</span><div><p class="font-bold text-sm">Master Password</p><p class="text-[9px] uppercase tracking-widest opacity-70">SHA-256 Encrypted</p></div></div>
                            <button onclick="promptNewPassword()" class="text-[10px] font-bold bg-white text-primary px-3 py-1.5 rounded-full hover:bg-slate-100">Reset</button>
                        </div>
                    </div>
                </div>
            </section>
            <!-- Goals -->
            <section class="md:col-span-2 bg-surface-container-lowest dark:bg-slate-900 border border-outline-variant/10 dark:border-slate-800 rounded-3xl p-8 shadow-sm">
                <div class="flex justify-between items-center mb-6 border-b border-slate-100 dark:border-slate-800 pb-4">
                    <div class="flex items-center gap-3"><span class="material-symbols-outlined text-primary dark:text-blue-300">stars</span><h3 class="font-headline font-bold text-lg">Saving Goals</h3></div>
                    <button onclick="addGoal()" class="text-xs font-bold bg-primary/10 dark:bg-blue-900/40 text-primary dark:text-blue-300 px-3 py-1.5 rounded-full flex items-center gap-1 hover:brightness-110"><span class="material-symbols-outlined text-sm">add</span> New Goal</button>
                </div>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-6" id="goals-list"></div>
            </section>
            <!-- Local Engine Info -->
            <section class="md:col-span-2 bg-surface-container-lowest dark:bg-slate-900 border border-outline-variant/10 dark:border-slate-800 rounded-3xl p-8 shadow-sm">
                <div class="flex items-center gap-3 mb-6"><span class="material-symbols-outlined text-primary dark:text-blue-300">dns</span><h3 class="font-headline font-bold text-lg">Local Engine</h3></div>
                <div class="space-y-4">
                    <div class="flex justify-between items-center py-3 border-b border-surface-container-highest dark:border-slate-800"><span class="text-sm font-semibold text-slate-600 dark:text-slate-400">Database</span><span class="text-xs font-mono bg-surface-container-high dark:bg-slate-800 px-2 py-1 rounded text-primary dark:text-blue-200">./vault_data.json</span></div>
                    <div class="flex justify-between items-center py-3 border-b border-surface-container-highest dark:border-slate-800"><span class="text-sm font-semibold text-slate-600 dark:text-slate-400">Renderer</span><span class="text-xs font-bold text-primary dark:text-blue-200">pywebview (EdgeChromium)</span></div>
                    <div class="flex justify-between items-center py-3"><span class="text-sm font-semibold text-slate-600 dark:text-slate-400">Status</span><span class="text-xs font-bold text-tertiary-fixed-dim bg-tertiary-fixed-dim/10 border border-tertiary-fixed-dim/20 px-2 py-1 rounded">V3.0 Enterprise</span></div>
                </div>
            </section>
        </div>
    </div>

    <!-- ============ PAGE: PREDICTIONS ============ -->
    <div id="page-predictions" class="app-page max-w-[1200px] mx-auto p-8 flex flex-col gap-8 pb-24 hidden">
        <header>
            <h2 class="text-3xl font-headline font-extrabold tracking-tight text-primary dark:text-blue-100">Financial Predictions</h2>
            <p class="text-on-surface-variant text-sm mt-1">6-month forward projection based on current income/burn trajectory.</p>
        </header>
        <!-- Projection Chart -->
        <section class="glass-panel dark:bg-slate-900 rounded-[2.5rem] p-8 shadow-sm">
            <div class="flex justify-between items-center mb-6">
                <h3 class="font-headline text-lg font-bold">Net Worth Projection</h3>
                <div class="flex items-center gap-1.5 px-3 py-1 rounded-full bg-tertiary-fixed/20 text-[10px] font-bold uppercase text-on-tertiary-container"><span class="material-symbols-outlined text-sm">auto_graph</span> Linear Model</div>
            </div>
            <div class="h-64 relative w-full" id="pred-chart-area">
                <svg class="w-full h-full" preserveAspectRatio="none" viewBox="0 0 600 200" id="pred-svg">
                    <defs><linearGradient id="predGrad" x1="0%" x2="0%" y1="0%" y2="100%"><stop offset="0%" style="stop-color:#001d3b;stop-opacity:0.12"/><stop offset="100%" style="stop-color:#001d3b;stop-opacity:0"/></linearGradient></defs>
                    <line x1="0" y1="160" x2="600" y2="160" stroke="#e0e3e6" stroke-width="1" stroke-dasharray="4"/>
                    <line x1="0" y1="100" x2="600" y2="100" stroke="#e0e3e6" stroke-width="1" stroke-dasharray="4"/>
                    <line x1="0" y1="40" x2="600" y2="40" stroke="#e0e3e6" stroke-width="1" stroke-dasharray="4"/>
                    <path id="pred-area" d="" fill="url(#predGrad)"/>
                    <path id="pred-line" d="" fill="none" stroke="#001d3b" stroke-width="3" stroke-linecap="round"/>
                </svg>
            </div>
            <div class="flex justify-between mt-2 px-2 text-[10px] font-bold text-on-surface-variant/50 uppercase tracking-widest" id="pred-labels"></div>
        </section>
        <!-- Projection Table -->
        <section class="bg-surface-container-lowest dark:bg-slate-900 rounded-3xl p-8 ghost-shadow border border-outline-variant/10">
            <h3 class="font-headline font-bold text-lg mb-6">Monthly Breakdown</h3>
            <div class="space-y-4" id="pred-table">
                <div class="p-4 text-center text-on-surface-variant text-sm">Calculating projections...</div>
            </div>
        </section>
        <!-- Runway -->
        <section class="vault-gradient rounded-3xl p-8 text-white relative overflow-hidden">
            <div class="absolute top-0 right-0 w-64 h-64 bg-white/5 rounded-full -translate-y-1/2 translate-x-1/2 blur-3xl"></div>
            <div class="relative z-10 flex items-center justify-between">
                <div>
                    <p class="text-white/60 text-[10px] font-bold uppercase tracking-widest mb-1">Financial Runway</p>
                    <h3 class="text-4xl font-headline font-extrabold" id="pred-runway">-- months</h3>
                    <p class="text-white/70 text-sm mt-2">How long your current net worth lasts at current burn rate.</p>
                </div>
                <div class="w-20 h-20 rounded-full border-4 border-tertiary-fixed flex items-center justify-center">
                    <span class="material-symbols-outlined text-tertiary-fixed text-3xl">rocket_launch</span>
                </div>
            </div>
        </section>
    </div>

    <!-- ============ PAGE: VAULT AUDIT ============ -->
    <div id="page-audit" class="app-page max-w-[1200px] mx-auto p-8 flex flex-col gap-6 pb-24 hidden">
        <header class="flex justify-between items-end">
            <div>
                <h2 class="text-3xl font-headline font-extrabold tracking-tight text-primary dark:text-blue-100">Vault Audit</h2>
                <p class="text-on-surface-variant text-sm mt-1">System integrity log and confidence monitoring.</p>
            </div>
            <div class="flex items-center gap-4">
                <div class="flex items-center gap-2 px-3 py-1.5 bg-tertiary-fixed/20 dark:bg-green-900/30 rounded-full">
                    <span class="w-2 h-2 rounded-full bg-on-tertiary-container animate-pulse"></span>
                    <span class="text-[10px] font-bold text-on-tertiary-container uppercase tracking-wider">System Integrity: High</span>
                </div>
            </div>
        </header>
        <!-- Audit Stats -->
        <div class="grid grid-cols-4 gap-4">
            <div class="bg-surface-container-lowest dark:bg-slate-900 p-5 rounded-2xl border border-outline-variant/10 text-center">
                <p class="text-[9px] font-bold text-on-surface-variant uppercase tracking-wider">Total Events</p>
                <p class="text-2xl font-headline font-extrabold text-primary dark:text-blue-200" id="audit-total">0</p>
            </div>
            <div class="bg-surface-container-lowest dark:bg-slate-900 p-5 rounded-2xl border border-outline-variant/10 text-center">
                <p class="text-[9px] font-bold text-on-surface-variant uppercase tracking-wider">High Confidence</p>
                <p class="text-2xl font-headline font-extrabold text-on-tertiary-container" id="audit-high">0</p>
            </div>
            <div class="bg-surface-container-lowest dark:bg-slate-900 p-5 rounded-2xl border border-outline-variant/10 text-center">
                <p class="text-[9px] font-bold text-on-surface-variant uppercase tracking-wider">Low / Fail</p>
                <p class="text-2xl font-headline font-extrabold text-error" id="audit-low">0</p>
            </div>
            <div class="bg-surface-container-lowest dark:bg-slate-900 p-5 rounded-2xl border border-outline-variant/10 text-center">
                <p class="text-[9px] font-bold text-on-surface-variant uppercase tracking-wider">Last Sync</p>
                <p class="text-sm font-headline font-extrabold text-primary dark:text-blue-200" id="audit-last-sync">Never</p>
            </div>
        </div>
        <!-- Audit Timeline -->
        <div class="bg-surface-container-lowest dark:bg-slate-900 rounded-[2rem] ghost-shadow border border-outline-variant/10 overflow-hidden">
            <div id="audit-timeline" class="divide-y divide-outline-variant/10 dark:divide-slate-800 max-h-[55vh] overflow-y-auto">
                <div class="p-8 text-center text-on-surface-variant text-sm">Loading audit log...</div>
            </div>
        </div>
    </div>

    <!-- Mobile Bottom Nav -->
    <nav class="md:hidden fixed bottom-4 left-1/2 -translate-x-1/2 w-[92%] max-w-md rounded-3xl border border-white/20 z-50 bg-white/70 dark:bg-slate-900/80 backdrop-blur-2xl shadow-2xl flex justify-around items-center p-2">
        <a onclick="navigate('command')" class="flex flex-col items-center text-on-surface-variant px-2 py-1.5 cursor-pointer"><span class="material-symbols-outlined text-[22px]">home</span><span class="text-[8px] font-bold uppercase tracking-widest mt-0.5">Home</span></a>
        <a onclick="navigate('intel')" class="flex flex-col items-center text-on-surface-variant px-2 py-1.5 cursor-pointer"><span class="material-symbols-outlined text-[22px]">analytics</span><span class="text-[8px] font-bold uppercase tracking-widest mt-0.5">Intel</span></a>
        <a onclick="navigate('ledger')" class="flex flex-col items-center text-on-surface-variant px-2 py-1.5 cursor-pointer"><span class="material-symbols-outlined text-[22px]">receipt_long</span><span class="text-[8px] font-bold uppercase tracking-widest mt-0.5">Ledger</span></a>
        <a onclick="navigate('predictions')" class="flex flex-col items-center bg-primary text-white rounded-2xl px-4 py-1.5 cursor-pointer shadow-lg"><span class="material-symbols-outlined text-[22px]">trending_up</span></a>
        <a onclick="navigate('settings')" class="flex flex-col items-center text-on-surface-variant px-2 py-1.5 cursor-pointer"><span class="material-symbols-outlined text-[22px]">settings</span><span class="text-[8px] font-bold uppercase tracking-widest mt-0.5">Gear</span></a>
    </nav>

</main>
</div>

<script>
// ===== VAULT STATE HANDLER =====
const VS = { data: null, privacyOn: false, currentPage: 'command' };

function showToast(msg, icon='info') {
    const c = document.getElementById('toast-box');
    const el = document.createElement('div');
    el.className = 'toast-item';
    el.innerHTML = '<span class="material-symbols-outlined text-[16px]">' + icon + '</span>' + msg;
    c.appendChild(el);
    setTimeout(() => el.classList.add('show'), 10);
    setTimeout(() => { el.classList.remove('show'); setTimeout(() => el.remove(), 300); }, 3000);
}

function showDegradedState(msg) {
    document.getElementById('degraded-msg').innerText = msg || 'A critical data integrity issue was detected.';
    document.getElementById('degraded-overlay').classList.add('active');
}

function fmt(v) { return new Intl.NumberFormat('en-US', {style:'currency',currency:'USD'}).format(v); }

// ===== AUTH =====
window.addEventListener('pywebviewready', function() {
    pywebview.api.check_auth_status().then(s => {
        const ls = document.getElementById('lock-screen');
        if (!s.has_password) {
            ls.classList.remove('hidden');
            document.getElementById('lock-title').innerText = "Initialize Vault";
            document.getElementById('lock-desc').innerText = "Create a master password for local encryption.";
            window.checkAuth = function() {
                const p = document.getElementById('auth-code').value;
                if (p.length < 4) { document.getElementById('lock-error').innerText = "Min 4 characters."; return; }
                pywebview.api.setup_password(p).then(() => { ls.classList.add('hidden'); boot(); window.checkAuth = normalUnlock; });
            }
        } else { ls.classList.remove('hidden'); window.checkAuth = normalUnlock; }
    });
});

function normalUnlock() {
    const p = document.getElementById('auth-code').value;
    pywebview.api.check_password(p).then(ok => {
        if (ok) { document.getElementById('lock-screen').classList.add('hidden'); document.getElementById('auth-code').value=''; boot(); }
        else { document.getElementById('lock-error').innerText = "Invalid authorization code."; }
    });
}

function lockVault() { document.getElementById('lock-screen').classList.remove('hidden'); document.getElementById('auth-code').value=''; }

function boot() { syncData(); navigate('command'); }

// ===== NAVIGATION =====
function navigate(id) {
    VS.currentPage = id;
    document.querySelectorAll('.app-page').forEach(e => { e.classList.add('hidden'); e.classList.remove('block'); });
    const pg = document.getElementById('page-' + id);
    if (pg) { pg.classList.remove('hidden'); pg.classList.add('block'); }
    document.querySelectorAll('.nav-btn').forEach(e => {
        e.classList.remove('bg-primary','text-white','shadow-sm');
        e.classList.add('text-slate-500','dark:text-slate-400');
        if (e.id === 'nav-' + id) { e.classList.remove('text-slate-500','dark:text-slate-400'); e.classList.add('bg-primary','text-white','shadow-sm'); }
    });
}

// ===== SYNC =====
function syncData() {
    const si = document.getElementById('sync-indicator');
    si.classList.remove('opacity-0');
    pywebview.api.sync_data().then(d => {
        VS.data = d;
        if (d.theme === 'dark') document.documentElement.classList.add('dark');
        else document.documentElement.classList.remove('dark');
        if (d.privacy_mask) { VS.privacyOn = true; document.body.classList.add('privacy-active'); updatePrivacyUI(); }
        renderAll(d);
        setTimeout(() => si.classList.add('opacity-0'), 1000);
    });
}

function renderAll(d) { renderCommand(d); renderLedger(d); renderIntel(d); renderSettings(d); renderPredictions(d); renderAudit(d); }

// ===== COMMAND CENTER =====
function renderCommand(d) {
    document.getElementById('cmd-net-worth').innerText = fmt(d.net_worth);
    document.getElementById('cmd-income').innerText = fmt(d.monthly_income);
    document.getElementById('cmd-burn').innerText = fmt(d.monthly_burn);
    document.getElementById('cmd-savings').innerText = (d.savings_rate||0) + '%';
    const hs = d.health_score || 0;
    const hEl = document.getElementById('cmd-health');
    hEl.innerText = hs + '/100';
    hEl.className = 'text-xl font-headline font-extrabold ' + (hs >= 70 ? 'text-on-tertiary-container' : hs >= 40 ? 'text-yellow-600' : 'text-error');
    document.getElementById('cmd-health-label').innerText = hs >= 70 ? 'Healthy Growth Detected' : hs >= 40 ? 'Moderate — Review Spending' : 'Warning — High Burn Rate';
    document.getElementById('health-badge').classList.remove('hidden');
    document.getElementById('health-badge').classList.add('flex');
    document.getElementById('health-score-header').innerText = 'Health: ' + hs;
    // AI insight
    const sr = d.savings_rate || 0;
    document.getElementById('cmd-ai-insight').innerText = sr > 20 ? 'Strong savings at ' + sr + '%. On track to exceed monthly targets.' : 'Savings below optimal. Consider reducing discretionary spend.';
    // Recent list
    const txs = d.transactions || [];
    document.getElementById('cmd-tx-count').innerText = txs.length + ' SETTLED';
    const list = document.getElementById('cmd-recent-list');
    list.innerHTML = '';
    txs.slice(0, 4).forEach(tx => {
        const isI = tx.type === 'Income';
        const anom = tx.is_anomaly ? ' border-l-4 border-error' : '';
        list.innerHTML += '<div class="bg-surface-container dark:bg-slate-800 rounded-2xl p-5 flex justify-between items-start' + anom + '"><div><p class="font-bold text-sm">' + tx.description + '</p><p class="text-xs text-on-surface-variant mt-1">' + tx.category + (tx.is_anomaly ? ' <span class=\'text-error font-bold\'>⚠ ANOMALY</span>' : '') + '</p></div><p class="font-headline font-extrabold ' + (isI ? 'text-on-tertiary-container' : 'text-error') + ' priv">' + (isI?'+':'-') + fmt(tx.amount) + '</p></div>';
    });
    if (txs.length === 0) list.innerHTML = '<div class="p-6 text-center text-on-surface-variant text-sm border border-dashed rounded-xl">No transactions yet</div>';
}

// ===== LEDGER =====
function renderLedger(d) {
    const txs = d.transactions || [];
    document.getElementById('ledger-total').innerText = txs.length;
    const vol = txs.reduce((s,t) => s + t.amount, 0);
    document.getElementById('ledger-volume').innerText = fmt(vol);
    document.getElementById('ledger-anomalies').innerText = txs.filter(t => t.is_anomaly).length;
    buildLedgerRows(txs);
}

function buildLedgerRows(txs) {
    const list = document.getElementById('ledger-list');
    list.innerHTML = '';
    if (txs.length === 0) { list.innerHTML = '<div class="p-8 text-center text-on-surface-variant text-sm">No transactions found.</div>'; return; }
    txs.forEach(tx => {
        const isI = tx.type === 'Income';
        const ic = isI ? 'text-tertiary-fixed-dim bg-tertiary-fixed-dim/20' : 'text-on-surface-variant bg-surface-container-high dark:bg-slate-800';
        const iS = isI ? 'call_received' : 'shopping_bag';
        const aC = isI ? 'text-on-tertiary-container' : 'text-on-surface dark:text-slate-100';
        const dt = new Date(tx.date).toLocaleDateString();
        const anomBadge = tx.is_anomaly ? '<span class="ml-2 px-1.5 py-0.5 bg-error/10 text-error text-[9px] font-bold rounded uppercase">Anomaly</span>' : '';
        list.innerHTML += '<div class="flex items-center gap-4 p-5 hover:bg-surface-container-low dark:hover:bg-slate-800 transition-colors' + (tx.is_anomaly ? ' border-l-4 border-error' : '') + '"><div class="size-10 rounded-full ' + ic + ' flex items-center justify-center shrink-0"><span class="material-symbols-outlined text-xl">' + iS + '</span></div><div class="flex-1"><p class="font-bold text-sm">' + tx.description + anomBadge + '</p><p class="text-xs text-on-surface-variant">' + tx.category + ' • ' + dt + '</p></div><div class="text-right"><p class="font-headline font-bold ' + aC + ' priv">' + (isI?'+':'-') + fmt(tx.amount) + '</p><p class="text-[10px] text-on-surface-variant uppercase font-bold tracking-tighter">Settled</p></div></div>';
    });
}

function filterLedger() {
    if (!VS.data) return;
    const q = (document.getElementById('ledger-search').value || '').toLowerCase();
    const f = document.getElementById('ledger-filter').value;
    let txs = VS.data.transactions || [];
    if (f === 'anomaly') txs = txs.filter(t => t.is_anomaly);
    else if (f !== 'all') txs = txs.filter(t => t.type === f);
    if (q) txs = txs.filter(t => t.description.toLowerCase().includes(q) || t.category.toLowerCase().includes(q));
    buildLedgerRows(txs);
}

// ===== VISUAL INTELLIGENCE =====
function renderIntel(d) {
    document.getElementById('intel-income').innerText = fmt(d.monthly_income);
    document.getElementById('intel-burn').innerText = fmt(d.monthly_burn);
    document.getElementById('intel-ratio').innerText = (d.ratio || 0) + ':1';
    const total = d.monthly_income + d.monthly_burn;
    if (total > 0) { const p = (d.monthly_income/total)*100; document.getElementById('ratio-income').style.width = p+'%'; document.getElementById('ratio-expense').style.width = (100-p)+'%'; }
    // Heatmap
    const hm = document.getElementById('intel-heatmap');
    hm.innerHTML = '';
    const levels = ['bg-surface-container dark:bg-slate-800','bg-tertiary-fixed-dim/30','bg-tertiary-fixed-dim/50','bg-tertiary-fixed/60','bg-tertiary-fixed','bg-primary/70','bg-primary','bg-error/20'];
    for (let i = 0; i < 28; i++) { const l = levels[Math.floor(Math.random()*levels.length)]; hm.innerHTML += '<div class="aspect-square '+l+' rounded-[4px] border border-white/30 dark:border-slate-700"></div>'; }
}

// ===== SETTINGS =====
function renderSettings(d) {
    const gl = document.getElementById('goals-list');
    gl.innerHTML = '';
    (d.goals || []).forEach(g => {
        const p = g.target > 0 ? Math.min((g.current/g.target)*100,100).toFixed(1) : 0;
        gl.innerHTML += '<div class="bg-surface dark:bg-slate-950 p-5 rounded-2xl border border-outline-variant/20 dark:border-slate-700"><div class="flex justify-between items-start mb-4"><div><p class="font-bold">' + g.name + '</p><p class="text-xs text-on-surface-variant">Target: ' + fmt(g.target) + '</p></div><span class="text-lg font-black text-primary dark:text-blue-200 priv">' + fmt(g.current) + '</span></div><div class="w-full bg-surface-container-highest dark:bg-slate-800 rounded-full h-2 mb-2"><div class="bg-primary dark:bg-blue-400 h-2 rounded-full" style="width:'+p+'%"></div></div><p class="text-[10px] text-on-surface-variant font-bold uppercase tracking-tighter">' + p + '% Achieved</p></div>';
    });
}

// ===== PREDICTIONS =====
function renderPredictions(d) {
    const preds = d.predictions || [];
    if (preds.length === 0) return;
    const vals = preds.map(p => p.projected_net_worth);
    const minV = Math.min(...vals) * 0.95;
    const maxV = Math.max(...vals) * 1.05;
    const range = maxV - minV || 1;
    // Build SVG path
    const w = 600, h = 180, pad = 10;
    let pts = [];
    preds.forEach((p, i) => {
        const x = pad + (i / (preds.length-1)) * (w - 2*pad);
        const y = h - pad - ((p.projected_net_worth - minV) / range) * (h - 2*pad);
        pts.push({x, y});
    });
    let lineD = 'M' + pts.map(p => p.x+','+p.y).join(' L');
    let areaD = lineD + ' L' + (w-pad) + ',190 L' + pad + ',190 Z';
    document.getElementById('pred-line').setAttribute('d', lineD);
    document.getElementById('pred-area').setAttribute('d', areaD);
    // Labels
    document.getElementById('pred-labels').innerHTML = preds.map(p => '<span>' + p.month + '</span>').join('');
    // Table
    const tbl = document.getElementById('pred-table');
    tbl.innerHTML = '';
    preds.forEach((p, i) => {
        const delta = i === 0 ? p.projected_net_worth - d.net_worth : p.projected_net_worth - preds[i-1].projected_net_worth;
        tbl.innerHTML += '<div class="flex justify-between items-center py-3 border-b border-outline-variant/10 dark:border-slate-800 last:border-0"><div class="flex items-center gap-3"><span class="material-symbols-outlined text-primary dark:text-blue-300 text-[18px]">calendar_month</span><span class="font-bold text-sm">' + p.month + '</span></div><div class="text-right"><p class="font-headline font-bold text-primary dark:text-blue-200 priv">' + fmt(p.projected_net_worth) + '</p><p class="text-[10px] text-on-tertiary-container font-bold">+' + fmt(delta) + '</p></div></div>';
    });
    // Runway
    const burn = d.monthly_burn || 1;
    const runway = Math.floor(d.net_worth / burn);
    document.getElementById('pred-runway').innerText = runway + ' months';
}

// ===== VAULT AUDIT =====
function renderAudit(d) {
    const log = d.audit_log || [];
    document.getElementById('audit-total').innerText = log.length;
    document.getElementById('audit-high').innerText = log.filter(e => e.confidence === 'HIGH').length;
    document.getElementById('audit-low').innerText = log.filter(e => e.confidence === 'LOW' || e.confidence === 'FAIL' || e.confidence === 'CRITICAL').length;
    const syncs = log.filter(e => e.event.includes('Sync'));
    document.getElementById('audit-last-sync').innerText = syncs.length > 0 ? new Date(syncs[0].timestamp).toLocaleTimeString() : 'Never';
    const tl = document.getElementById('audit-timeline');
    tl.innerHTML = '';
    if (log.length === 0) { tl.innerHTML = '<div class="p-8 text-center text-on-surface-variant text-sm">No audit events recorded.</div>'; return; }
    log.slice(0, 50).forEach(e => {
        const confC = e.confidence === 'HIGH' ? 'bg-tertiary-fixed/20 text-on-tertiary-container' : e.confidence === 'MEDIUM' ? 'bg-yellow-100 dark:bg-yellow-900/30 text-yellow-700 dark:text-yellow-300' : 'bg-error-container dark:bg-red-900/30 text-error';
        const iconC = e.confidence === 'HIGH' ? 'text-on-tertiary-container bg-tertiary-fixed/30' : e.confidence === 'MEDIUM' ? 'text-yellow-600 bg-yellow-100 dark:bg-yellow-900/30' : 'text-error bg-error-container dark:bg-red-900/30';
        const icon = e.confidence === 'HIGH' ? 'check_circle' : e.confidence === 'MEDIUM' ? 'warning' : 'error';
        const dt = new Date(e.timestamp);
        tl.innerHTML += '<div class="flex items-start gap-4 p-5 hover:bg-surface-container-low dark:hover:bg-slate-800 transition-colors"><div class="size-10 rounded-full ' + iconC + ' flex items-center justify-center shrink-0"><span class="material-symbols-outlined text-xl">' + icon + '</span></div><div class="flex-1 min-w-0"><p class="font-bold text-sm">' + e.event + '</p><p class="text-xs text-on-surface-variant mt-0.5 truncate">' + (e.details || 'No details') + '</p><p class="text-[10px] text-on-surface-variant mt-1">' + dt.toLocaleDateString() + ' ' + dt.toLocaleTimeString() + '</p></div><span class="px-2 py-0.5 rounded text-[9px] font-bold uppercase shrink-0 ' + confC + '">' + e.confidence + '</span></div>';
    });
}

// ===== ACTIONS =====
function setTheme(mode) {
    if (mode === 'dark') document.documentElement.classList.add('dark');
    else document.documentElement.classList.remove('dark');
    pywebview.api.update_setting({key:'theme', value:mode});
    showToast('Theme: ' + mode, 'palette');
}

function togglePrivacy() {
    VS.privacyOn = !VS.privacyOn;
    document.body.classList.toggle('privacy-active', VS.privacyOn);
    pywebview.api.update_setting({key:'privacy_mask', value:VS.privacyOn});
    updatePrivacyUI();
    showToast(VS.privacyOn ? 'Privacy Mask ON' : 'Privacy Mask OFF', 'visibility');
}

function updatePrivacyUI() {
    const dot = document.getElementById('privacy-dot');
    const sw = document.getElementById('privacy-switch');
    const tog = document.getElementById('privacy-toggle');
    if (VS.privacyOn) { dot.classList.add('translate-x-5'); sw.classList.remove('bg-outline-variant','dark:bg-slate-600'); sw.classList.add('bg-tertiary-fixed-dim'); tog.innerHTML = '<span class="material-symbols-outlined text-[20px]">visibility_off</span>'; }
    else { dot.classList.remove('translate-x-5'); sw.classList.add('bg-outline-variant','dark:bg-slate-600'); sw.classList.remove('bg-tertiary-fixed-dim'); tog.innerHTML = '<span class="material-symbols-outlined text-[20px]">visibility</span>'; }
}

function toggleBio(el) {
    const thumb = el.querySelector('div');
    const isOn = thumb.classList.contains('translate-x-[-20px]') === false;
    pywebview.api.update_setting({key:'biometrics', value:!isOn});
    showToast('Biometrics ' + (!isOn ? 'enabled' : 'disabled'), 'fingerprint');
}

function promptNewPassword() { let p = prompt("New Master Password (min 4):"); if (p && p.length >= 4) { pywebview.api.setup_password(p).then(() => showToast('Password rotated','key')); } else if (p) { showToast('Too short','error'); } }

function addGoal() { let n = prompt("Goal Name:","New Goal"); if (n) { let t = prompt("Target Amount:","1000"); pywebview.api.add_goal({name:n,target:t,current:0}).then(() => syncData()); } }

function exportData() { pywebview.api.export_data().then(r => showToast(r.message || 'Done', 'download')); }

function importLedger() {
    pywebview.api.parse_ledger_file().then(r => {
        if (r.status === 'degraded') { showDegradedState(r.message); }
        else { showToast(r.message || 'Import complete', 'upload_file'); }
        syncData();
    });
}
</script>
</body></html>

'''


if __name__ == '__main__':
    api = VaultPro()
    window = webview.create_window(
        'Vault Analytics',
        html=HTML_CONTENT,
        js_api=api,
        width=1440, height=900,
        min_size=(1280, 800),
        frameless=True, easy_drag=False
    )
    api.set_window(window)
    webview.start()
