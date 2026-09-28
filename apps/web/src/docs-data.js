export const DOCS_SECTIONS = [
  {
    id: "getting-started",
    title: "Getting Started",
    icon: "🚀",
    items: [
      {
        id: "intro",
        title: "Introduction & Architecture",
        badge: "Core",
        content: `
# Dossier Kiosk & CRM Documentation

**Dossier** is a high-density, offline-first workstation designed specifically for Cyber Cafes, Common Service Centres (CSCs), and document processing kiosks.

### High-Level Architecture

\`\`\`
+--------------------------------------------------------------------------+
|                            Dossier Monorepo                              |
+--------------------+--------------------------------+--------------------+
|    apps/kiosk      |          apps/web              |    services/api    |
| (Flutter Client)   | (Marketing & Docs Portal)      | (Cloudflare Worker)|
| Web, Desktop, App  | Vanilla CSS + Fast Vite        | D1 SQLite Edge API |
+--------------------+--------------------------------+--------------------+
\`\`\`

### Key Architectural Pillars
- **Two-Tier Authentication**: Master Admin device activation paired with day-to-day desk operator PIN shift unlocks.
- **Web-First with Progressive Local Enhancement**: Fully functional in modern browsers via Flutter WASM + OPFS, with desktop builds unlocking direct ESC/POS byte buffers, native C-FFI SQLite, and background Dart isolates.
- **Bi-Directional Outbox Sync**: Mutations queue in local Drift SQLite and synchronize seamlessly with Cloudflare D1 edge database when network is active.
        `
      },
      {
        id: "installation",
        title: "Installation & System Requirements",
        content: `
## Client Application Setup

Dossier runs cross-platform on Linux, Windows, macOS, Android, and Web browsers.

### Requirements
- **Web (WASM)**: Chrome / Edge 119+, Firefox 120+, Safari 17+ (with SharedArrayBuffer support).
- **Linux**: Ubuntu 22.04+ / Debian 12+ / Arch Linux with \`libgtk-3-dev\`, \`libsqlite3-dev\`.
- **Windows**: Windows 10/11 x64.
- **Hardware POS**: USB/Serial ESC/POS Thermal Receipt Printers (58mm or 80mm).

### Quick Launch via \`mise\`
\`\`\`bash
# Launch Flutter Web Client
mise run run:kiosk:web

# Launch Linux Desktop POS
mise run run:kiosk:linux

# Start Cloudflare Worker Local Backend
mise run dev:api
\`\`\`
        `
      }
    ]
  },
  {
    id: "authentication",
    title: "Two-Tier Authentication",
    icon: "🔐",
    items: [
      {
        id: "activation-gate",
        title: "Tier 1: Software Activation Gate",
        badge: "Admin",
        content: `
## Software Activation Gate

When freshly installed, Dossier begins in a **Locked / Unactivated** state. 

### Activation Steps
1. The **Admin / Business Owner** launches the app.
2. Selects **Register New Kiosk** or **Sign In Existing Admin**.
3. Inputs Admin details (Full Name, Phone, Email, Password, 4-Digit Admin PIN, Kiosk Name, Merchant UPI VPA).
4. The client dispatches \`POST /api/v1/auth/activate\` to Cloudflare Edge.
5. On success, the local kiosk identity is created, the cloud tenant credentials are saved, and full CRM/POS capabilities unlock.

\`\`\`json
// Request Payload: POST /api/v1/auth/activate
{
  "adminName": "Yogesh Raja",
  "phone": "9876543210",
  "email": "admin@dossierkiosk.local",
  "password": "SecurePassword123!",
  "pin": "1234",
  "kioskName": "Main CSC Center",
  "kioskAddress": "123 Market Road, Cyber Hub",
  "merchantUpiVpa": "kiosk@upi",
  "isNewRegistration": true
}
\`\`\`
        `
      },
      {
        id: "operator-shift",
        title: "Tier 2: Desk Operator Shift Login",
        badge: "Daily Flow",
        content: `
## Desk Operator Shift Login

Once the software is activated, day-to-day staff do not need the master Admin password.

### Shift Login Workflow
1. The desk operator clicks on their personal **Avatar Card**.
2. Types their personal **4-digit PIN** on the touch numpad.
3. The app verifies credentials against \`POST /api/v1/auth/operator-login\` (or checks the local Drift SQLite cache during network outages).
4. Operator session is initialized, and transaction receipts attribute the specific operator name.

### Operator Provisioning by Admin
Admins can provision additional operators at any time from the app or Cloudflare backend. Operators are immediately synchronized across all kiosk terminals.
        `
      }
    ]
  },
  {
    id: "api-reference",
    title: "Cloudflare Edge API",
    icon: "⚡",
    items: [
      {
        id: "auth-endpoints",
        title: "Authentication Endpoints",
        badge: "REST",
        content: `
## Authentication REST Endpoints

Hosted on **Cloudflare Workers + D1 SQLite** edge infrastructure.

### 1. \`POST /api/v1/auth/activate\`
Activates a new kiosk installation or authenticates an existing Admin tenant.

**Response (200 OK):**
\`\`\`json
{
  "success": true,
  "token": "jwt_token_payload...",
  "tenantId": "kiosk-001",
  "kioskName": "Main CSC Center",
  "admin": {
    "id": "op-admin-001",
    "name": "Yogesh Raja",
    "role": "admin"
  },
  "operators": [
    { "id": "op-admin-001", "name": "Yogesh Raja", "role": "admin" },
    { "id": "op-002", "name": "Ramesh Staff", "role": "operator" }
  ]
}
\`\`\`

---

### 2. \`POST /api/v1/auth/operators\`
Provision a new counter operator under the authenticated tenant.

**Headers:** \`Authorization: Bearer <ADMIN_JWT>\`

**Request Body:**
\`\`\`json
{
  "name": "Ramesh Kumar",
  "pin": "5678",
  "role": "operator",
  "phone": "9811223344",
  "email": "ramesh@dossierkiosk.local"
}
\`\`\`

---

### 3. \`POST /api/v1/auth/operator-login\`
Verifies an operator PIN during daily counter shift changes.

\`\`\`json
{
  "operatorId": "op-002",
  "pin": "5678"
}
\`\`\`
        `
      },
      {
        id: "sync-endpoints",
        title: "Outbox Sync Endpoints",
        badge: "Sync",
        content: `
## Outbox Sync Protocol

Provides bi-directional synchronization between local Drift SQLite and Cloudflare D1.

### \`POST /api/v1/sync/push\`
Pushes local outbox changelogs (customers, cases, exhibits, transactions) to the cloud.

### \`POST /api/v1/sync/pull\`
Fetches remote mutations since \`lastSyncVersion\` timestamp.
        `
      }
    ]
  },
  {
    id: "hardware",
    title: "Hardware Integration",
    icon: "🖨️",
    items: [
      {
        id: "esc-pos",
        title: "ESC/POS Thermal Printers",
        badge: "Drivers",
        content: `
## ESC/POS Thermal Printer Driver

Dossier features a zero-dependency, pure-Dart ESC/POS byte generator supporting 58mm and 80mm receipt printers.

### Standard Command Sequences
- **Initialize Printer**: \`ESC @\` (\`0x1B, 0x40\`)
- **Text Alignment**: \`ESC a n\` (\`0x1B, 0x61, n\`) (0: Left, 1: Center, 2: Right)
- **Text Bold**: \`ESC E n\` (\`0x1B, 0x45, n\`)
- **Paper Cut**: \`GS V 66 0\` (\`0x1D, 0x56, 0x42, 0x00\`)
- **Cash Drawer Kick Pulse**: \`ESC p 0 25 250\` (\`0x1B, 0x70, 0x00, 0x19, 0xFA\`)

### Column Formatting
Receipts automatically pad two-column rows (Label + Amount) matching exact printer character widths:
- **58mm**: 32 characters per line.
- **80mm**: 48 characters per line.
        `
      }
    ]
  }
];
