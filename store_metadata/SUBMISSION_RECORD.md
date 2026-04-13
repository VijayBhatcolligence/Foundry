# Foundry — App Store Submission Record

> This file records exactly what was submitted. If Apple rejects, update the "Rejection" section and note what to change next time.

---

## Submission Date
2026-04-13

## Build Version
1.0.0+3

## Bundle ID
in.colligence.foundry.position

---

## App Store Listing Fields

| Field | Value |
|-------|-------|
| App Name | Foundry |
| Subtitle | (blank) |
| Primary Category | Business |
| Secondary Category | Productivity |
| Age Rating | 4+ |
| Privacy Policy URL | https://colligence.in/privacy |
| Support URL | https://colligence.in |
| Marketing URL | (blank) |
| Copyright | 2025 Colligence |

---

## Description Fields

**Promotional Text (170 chars max):**
> Your organization's field tools, always in your pocket. Offline-ready, role-based, and synced automatically when you're back online.

**Keywords:**
> enterprise,field ops,quality inspection,inventory,barcode scanner,offline,forms

**Long Description:** see STORE_LISTING.md

---

## App Review Information

| Field | Value |
|-------|-------|
| Sign-in required | Yes |
| Test username | test@foundry.com |
| Test password | test1234 |
| Contact email | support@colligence.in |

**Review Notes submitted:**
```
Foundry is an internal enterprise application. Access requires organization-issued credentials — use the test account above to sign in.

After signing in, you will see the Dashboard with 2 modules: Quality Inspector and Inventory Checker. Tap either module to open it.

The app downloads HTML and JavaScript web content at runtime to render operational workflows inside a native WKWebView. No native executable code is downloaded. This is equivalent to a browser loading a web page, with a native bridge for camera, barcode scanning, and device secure storage.

If the modules show a loading error during review, it is because the CDN requires a valid auth token — the test account above has full access.
```

---

## Content Rights
- Contains third-party content: **No**

---

## Encryption
- ITSAppUsesNonExemptEncryption = false (set in Info.plist)
- Uses only standard HTTPS/TLS, Firebase Auth (TLS), and OS keychain

---

## Screenshots Submitted

| Slot | File | Size |
|------|------|------|
| iPhone 6.5" | sc1_dashboard.png | 1242×2688 |
| iPhone 6.5" | sc2_settings.png | 1242×2688 |
| iPhone 6.5" | sc3_login.png | 1242×2688 |
| iPhone 6.5" | sc4_quality_inspector.png | 1242×2688 |
| iPhone 6.5" | sc5_inventory_checker.png | 1242×2688 |
| iPad 13" | ipad_sc1_dashboard.png | 2064×2732 |
| iPad 13" | ipad_sc2_settings.png | 2064×2732 |
| iPad 13" | ipad_sc3_quality.png | 2064×2732 |

---

## App Store Version Release
- Setting: **Automatically release this version**

---

## Blockers Fixed Before Submission

| Blocker | Fix |
|---------|-----|
| Missing iPad screenshots | Generated from phone screenshots, padded to 2064×2732 |
| Primary category not set | Set to Business |
| Privacy Policy URL missing | https://colligence.in/privacy |
| Content Rights not set | Answered No (no third-party content) |
| Age Rating not answered | All questions answered None/No → 4+ |
| Encryption compliance | ITSAppUsesNonExemptEncryption=false in Info.plist |

---

## Rejection History

### Attempt 1 — 2026-04-13
**Status:** Submitted — awaiting review

**If rejected, record here:**
- Rejection reason:
- Guideline number:
- What to change:
- Resubmit date:
