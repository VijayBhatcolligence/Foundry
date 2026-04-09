# App Store Connect — Metadata Checklist
# Complete every item below before submitting for review.
# Items marked [DONE] are already implemented. Items marked [TODO] need manual action.

---

## App Information

- [DONE] App Name: `Foundry` (or `Foundry - Field Inspector`)
  - Max 30 characters. Unique. No trademarked terms.
- [TODO] Subtitle: `Offline Field Data Collection`
  - Max 30 characters. Set in App Store Connect → App Information.
- [DONE] Bundle ID: `in.colligence.foundry.position`
- [TODO] Primary Category: `Business`
- [TODO] Secondary Category: `Productivity`
- [TODO] Age Rating: `4+` (no objectionable content — answer all rating questions as None/No)

---

## App Description

Copy into App Store Connect → Description field (max 4000 chars):

```
Foundry is a powerful offline-first field data collection platform designed
for quality inspectors, inventory checkers, and field workers in manufacturing
and warehousing environments.

KEY FEATURES:
• Barcode Scanning — Instantly scan 1D and 2D barcodes using your device camera
• Photo Capture — Attach photos to inspection reports and inventory counts
• Offline-First — Work without internet. Data syncs automatically when you reconnect
• Real-Time Dashboard — See your sync status, module access, and connectivity at a glance
• Secure — Enterprise-grade encryption for credentials and data transmission
• Multiple Modules — Access quality inspection, inventory checking, and more

DESIGNED FOR THE FIELD:
Foundry is built for workers who operate in environments with unreliable
connectivity. Warehouses, factories, and field sites often lack stable
internet — Foundry ensures your work is never lost.

Collect data offline. Sync when ready. Simple.
```

---

## Keywords

Copy into App Store Connect → Keywords field (max 100 chars):

```
inspection,inventory,barcode,scanner,field,data,collection,offline,sync,quality
```

---

## URLs

- [TODO] Privacy Policy URL: `https://[your-domain]/privacy-policy`
  - REQUIRED — will be rejected without this. Host the privacy-policy.html from assets/legal/.
- [TODO] Support URL: `https://[your-domain]/support` (or use mailto:support@colligence.in)
- [TODO] Marketing URL: `https://[your-domain]` (optional)

---

## Screenshots

Minimum required device sizes:

- [TODO] 6.7" iPhone (iPhone 15 Pro Max) — minimum 3 screenshots
- [TODO] 6.5" iPhone (iPhone 14 Plus / iPhone 11 Pro Max) — minimum 3 screenshots
- [TODO] 12.9" iPad Pro (6th gen) — minimum 3 screenshots (since app supports iPad)

Recommended screenshot order:
1. Dashboard screen — showing modules, connectivity status, user greeting
2. Quality Inspector module open — showing the data collection form
3. Barcode scanner active — showing native camera scanner UI
4. Offline mode — Dashboard showing offline indicator + pending sync
5. Settings screen — showing privacy policy, version, support info

> Tips: Take screenshots on iOS Simulator. Use Simulator → File → Take Screenshot.
> Do NOT use placeholder or mockup screenshots — Apple requires real app UI.

---

## App Review Information

- [DONE] Demo Account Email: test@foundry.com
- [DONE] Demo Account Password: test1234
- [TODO] Notes for Review: Copy from `app-store-review-notes.md`
- [TODO] Contact First Name: [Your name]
- [TODO] Contact Last Name: [Your name]
- [TODO] Contact Phone: [Your phone number]
- [TODO] Contact Email: support@colligence.in

---

## Privacy — App Privacy Nutrition Labels

Set in App Store Connect → App Privacy:

### Data Linked to User
- [TODO] Contact Info → Email Address
  - Purpose: App Functionality
  - Linked to identity: YES

### Data Not Linked to User
- [TODO] Photos or Videos → Photos
  - Purpose: App Functionality
  - Linked to identity: NO

### Usage Data
- [TODO] Usage Data → Product Interaction
  - Purpose: App Functionality
  - Linked to identity: YES

### Data NOT collected (answer No to all others):
- Location: NO
- Health & Fitness: NO
- Financial Info: NO
- Contacts: NO
- Browsing History: NO
- Search History: NO
- Identifiers: NO
- Diagnostics: NO
- Sensitive Info: NO

### Tracking:
- [TODO] "Does this app use data to track users?" → NO

---

## Content Rights

- [TODO] "Does your app contain, show, or access third-party content?" → YES
  - Firebase (authentication), Supabase (data storage), Vercel (API)
- [TODO] "Do you have all necessary rights to that content?" → YES

---

## Export Compliance

- [TODO] "Does your app use encryption?" → YES
  - "Is it exempt from encryption regulations?" → YES
  - Reason: Uses only standard HTTPS/TLS (exempt under EAR 740.17)

---

## Build Requirements (before uploading)

- [DONE] Privacy manifest included (`ios/Runner/PrivacyInfo.xcprivacy`)
- [DONE] Camera permission string in Info.plist (`NSCameraUsageDescription`)
- [DONE] Photo library permission in Info.plist (`NSPhotoLibraryUsageDescription`)
- [TODO] Build with release script: `./scripts/build_ios_release.sh`
  - Enables Dart obfuscation and tree shaking
- [TODO] Built with Xcode 16+ (iOS 18 SDK) — required by Apple as of 2025
- [TODO] Valid distribution certificate and provisioning profile
- [TODO] Increment version/build number in pubspec.yaml before each upload

---

## Final Submission Checklist

- [ ] All TODO items above completed
- [ ] Screenshots uploaded for all required device sizes
- [ ] Privacy Policy URL is publicly accessible (not behind a login)
- [ ] Backend is live and responding at https://foundry-app-rouge.vercel.app
- [ ] Demo account test@foundry.com / test1234 works end-to-end
- [ ] App tested on a physical iPhone (not just simulator) before submission
- [ ] Review notes copied from app-store-review-notes.md
- [ ] Build uploaded to TestFlight and tested before App Store submission
