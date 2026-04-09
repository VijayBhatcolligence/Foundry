# App Store Review Notes
# Copy the content below into App Store Connect → App Review Information → Notes

---

## READY-TO-PASTE: Notes for Review

```
DEMO ACCOUNT:
Email:    test@foundry.com
Password: test1234

IMPORTANT: Please ensure you are connected to the internet for the initial
login. After login, the app works fully offline — you can test this by
enabling airplane mode after signing in.

---

APP PURPOSE:
Foundry is an enterprise field data collection platform used by quality
inspectors and inventory checkers in manufacturing and warehousing
environments. It is a B2B tool distributed to specific employees by their
organization — not a consumer app.

---

HOW TO TEST (step by step):

1. LAUNCH & LOGIN
   - Open the app — you will see a dark splash screen, then the login page
   - Sign in with: test@foundry.com / test1234
   - The app will check for module updates, then navigate to the Dashboard

2. DASHBOARD (native Flutter screen)
   - Observe the Dashboard: user greeting, online/offline status indicator,
     module count stat, and module cards
   - This is a fully native Flutter UI screen

3. OPEN A MODULE (Quality Inspector)
   - Tap the "Quality Inspector" card
   - The app opens an embedded data collection form
   - This form is served from local device storage (not a remote website)
   - Tap the back arrow (top left) to return to Dashboard

4. BARCODE SCANNING (native feature)
   - Inside the Quality Inspector module, tap the barcode scan button
   - The native camera/scanner will activate (uses MLKit on-device scanning)
   - You can scan any product barcode or press back to cancel

5. PHOTO CAPTURE (native feature)
   - Inside the Quality Inspector module, tap the camera/photo button
   - The native iOS camera picker will appear
   - Capture or select a photo — it will attach to the inspection report

6. TEST OFFLINE MODE
   - Enable airplane mode on the device
   - Notice the Dashboard shows a red "Offline" indicator
   - Navigate into a module — it still loads (content is cached locally)
   - Submit a form — it queues the submission locally
   - Disable airplane mode — the app automatically detects connectivity
     and syncs queued data to the server

7. SETTINGS
   - Tap the three-dot menu (top right of Dashboard) → Settings
   - View: Privacy Policy, Terms of Service, App Version, Support contact
   - The "Delete Account" option is available (do not delete the demo account)

---

ARCHITECTURE NOTE FOR REVIEWER:
The interactive data collection forms (quality inspection, inventory
checking) are rendered as embedded web content served from the device's
own local storage — NOT from a remote website. This design allows
enterprise clients to update form configurations without requiring
an app update from the App Store, similar to how MDM-managed enterprise
tools work.

The Flutter native layer provides all device integrations:
  • Native barcode scanning (MLKit, no WebView involved)
  • Native camera access for photo capture
  • Encrypted credential storage (iOS Keychain via flutter_secure_storage)
  • Offline-first data queue with automatic background sync
  • Real-time connectivity monitoring and status display
  • Native Dashboard, Settings, and Privacy Policy screens

All network communication uses HTTPS. The app does not use advertising,
analytics, or tracking SDKs. Firebase is used solely for authentication.

---

BACKEND STATUS:
The backend at https://foundry-app-rouge.vercel.app is live and will
remain active during the review period.
```

---

## Notes About the Demo Account

- Email: test@foundry.com
- Password: test1234
- This account has access to 2 modules: Quality Inspector + Inventory Checker
- Both modules are pre-bundled with the app and work offline
- Do NOT delete this account during review (account deletion feature is present
  but should only be tested with a personal test account)
