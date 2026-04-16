# App Store Review Notes
# Copy the content below into App Store Connect → App Review Information → Notes

---

## READY-TO-PASTE: Notes for Review

```
DEMO ACCOUNT:
Email:    test@foundry.com
Password: test1234

IMPORTANT: An active internet connection is required for the initial login.
After first login, all modules work fully offline.

---

APP PURPOSE:
Foundry is a B2B enterprise field data collection platform used by quality
inspectors and inventory checkers in manufacturing and warehousing environments.
It is distributed to specific company employees by their organization — it is
not a consumer app and is not publicly advertised.

---

HOW TO TEST (step by step):

1. LAUNCH & LOGIN
   - Open the app — you will see a branded splash screen, then the login screen
   - Tap "Privacy Policy" at the bottom to view the full policy (native screen)
   - Sign in with: test@foundry.com / test1234

2. DASHBOARD (fully native Flutter screen)
   - The Dashboard is a 100% native Flutter screen
   - It shows: user greeting, real-time online/offline status, module count,
     sync status, and module cards
   - No WebView is involved on this screen

3. BARCODE SCANNING — native feature, NOT in WebView
   - Tap "Quality Inspector" on the Dashboard
   - Inside the module, tap the barcode/scan button
   - The native iOS camera activates for on-device barcode scanning (MLKit)
   - Scan any barcode or tap Cancel — result is returned to the form
   NOTE: This is a NATIVE capability, not a web feature

4. PHOTO CAPTURE — native feature, NOT in WebView
   - Inside the Quality Inspector module, tap the camera/photo button
   - The native iOS camera picker (UIImagePickerController) appears
   - Capture or choose a photo — it attaches to the inspection report
   NOTE: This is a NATIVE capability, not a web feature

5. OFFLINE MODE
   - Enable airplane mode after logging in
   - The Dashboard immediately shows an Offline indicator (native UI)
   - Modules continue to load from local device storage
   - Disable airplane mode — the app detects connectivity and syncs automatically

6. SETTINGS (fully native Flutter screen)
   - Tap the three-dot menu (top right) → Settings
   - Account: view email, Delete Account, Log Out
   - Legal: Privacy Policy (native screen), Terms of Service (native dialog)
   - About: app version 1.0.0, support email
   - Data: Clear Local Cache

7. DELETE ACCOUNT (do not delete the demo account)
   - Settings → Delete Account
   - Requires email + password re-confirmation (Firebase requirement)
   - Permanently deletes Firebase account, backend data, and all local files

---

GUIDELINE 4.2 — MINIMUM FUNCTIONALITY:
This app is NOT a web wrapper or browser. It is a native enterprise platform
with significant device-level capabilities that cannot be replicated in a
pure web app:

  • Firebase authentication with encrypted Keychain token storage (iOS Keychain)
  • Native barcode scanning (MLKit, ZXing — camera-based, fully offline)
  • Native camera access via UIImagePickerController / AVFoundation
  • Native offline-first data queue with automatic sync on reconnect
  • Native real-time connectivity monitoring (displayed in Dashboard and modules)
  • Native account management, deletion, and privacy controls
  • SHA-256 integrity verification of all locally stored content
  • ECDSA P-256 cryptographic signature verification of every downloaded module
    bundle — only content signed by the organization's private key executes;
    tampered or unsigned content is rejected before writing to disk

The data collection forms (quality inspection, inventory check) run inside
WKWebView as a rendering surface. This is the same pattern used by enterprise
apps like Salesforce Mobile, SAP Fiori, and ServiceNow — a native shell
providing device APIs to a structured data collection UI layer.

---

GUIDELINE 2.5.2 — CODE EXECUTION:
This app does NOT download or execute native/binary code. No Objective-C,
Swift, machine code, or executable binaries are downloaded at runtime.

What actually happens:
  - At startup, the app authenticates and verifies the device's locally
    stored HTML/CSS/JavaScript content against the enterprise server
  - If locally cached content is outdated (version mismatch), the new
    version is downloaded, SHA-256 verified, and ECDSA P-256 signature
    verified against a public key hardcoded in the binary before replacing
    the local copy — unsigned or tampered content is never written to disk
  - This content is then served from LOCAL DEVICE STORAGE to WKWebView

WKWebView executing JavaScript is explicitly sanctioned by Apple. This is
not "dynamic code execution" — it is a native browser engine rendering
structured web content, the same mechanism Safari uses. The JavaScript
has no access to device APIs except through our explicitly declared native
bridge (camera, barcode, auth token, network state).

No content can be pushed that adds new native capabilities, modifies
IAP logic, bypasses the App Store, or changes the app's declared purpose.
The native bridge interface is fixed — it only exposes the specific
capabilities submitted for review.

---

ARCHITECTURE NOTE:
All interactive forms are served from LOCAL device storage
(file:// equivalent via localhost), NOT from a remote web server.
The WKWebView never loads a URL from the internet directly — it
loads from an on-device HTTP server (loopback only) that serves
pre-verified, locally cached content.

---

BACKEND STATUS:
Backend API at https://foundry-app-rouge.vercel.app is live and will
remain active throughout the entire review period.

Demo account (test@foundry.com / test1234) has access to:
  - Quality Inspector module
  - Inventory Checker module
Both modules are pre-cached on device and work fully offline.
```

---

## Notes About the Demo Account

- Email: test@foundry.com / Password: test1234
- Account has 2 modules: Quality Inspector + Inventory Checker
- Both modules are pre-bundled and work offline
- Do NOT delete this account during review
- If login fails, the backend at https://foundry-app-rouge.vercel.app may need
  a moment to wake from idle (Vercel free tier cold start ~3-5 seconds)

## Key Talking Points if Apple Requests Clarification

1. **Not a web wrapper**: Dashboard, Settings, Login, Privacy Policy, Barcode Scanner
   are all 100% native Flutter screens — no WebView on any of them.

2. **2.5.2 defense**: JavaScript runs inside Apple's own WKWebView engine (same as
   Safari). The JS cannot install code, cannot modify native binaries, and cannot
   access device APIs beyond our declared bridge (camera, barcode, network state).

3. **Why local HTTP server**: WKWebView needs an HTTP origin for module-to-module
   JavaScript fetches and cache headers to work correctly. Content is served
   from localhost — it never leaves the device.

4. **Enterprise use case**: This is a B2B tool. Modules are controlled by the
   organization's IT/backend team — not end users or third parties.

5. **ECDSA bundle signing (Phase 12)**: Every module bundle is signed with an
   ECDSA P-256 private key held only by the organization's administrator. The
   app verifies this signature before executing any downloaded content. This is
   a stronger trust model than most native apps — equivalent to Apple's own
   code signing, applied to the JavaScript layer.
