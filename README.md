# DreamAtlas

A private dream journal and pattern explorer for macOS. You record dreams, tag their emotions and themes, and see what recurs over time.

DreamAtlas is for **personal reflection**. It doesn't interpret, diagnose or predict anything. It only shows you what you've written.

## Build & run

```bash
./build.sh                 # builds build/DreamAtlas.app (Apple Silicon, macOS 14+; needs Xcode installed)
open build/DreamAtlas.app
./make_dmg.sh              # builds a drag-to-install DMG in build/
```

## MVP features
- **Journal:** a three-pane writing view (list, editor, inspector), search across text and tags, month grouping, and a word count.
- **Tags:** 15 colour-coded emotions and 24 starter themes, plus your own. You can rename, merge or delete tags in Settings › Tags.
- **Details:** lucid, recurring, vividness (1–5) and waking mood (Heavy → Bright).
- **Timeline:** a year-long dream calendar heatmap, a streak count, and a month-by-month timeline. You can highlight one emotion or theme.
- **Patterns** (30 days / 90 days / year / all time):
  - stat tiles
  - recurring themes and the emotional palette
  - emotions over time
  - recurring images (nouns found on-device with Apple's NaturalLanguage framework)
  - themes that appear together
  - waking mood trend and weekly rhythm
- **Tag explorer:** click any emotion or theme to see when it shows up, what comes with it, and every dream it appears in.
- **Privacy:**
  - optional Touch ID or Mac-password lock (locks on display sleep, after a timeout, or with ⌃⌘L)
  - no network code at all
  - data stored with owner-only file permissions
- **Quick capture:**
  - press ⌥⌘D from any app to open a small floating panel and jot a dream down half-awake
  - it saves to last night or yesterday, with optional emotions
  - it works while the journal is locked, because it only adds and never shows past dreams
- **Menu bar icon:** quick capture, new dream, open the journal, and your streak. With the icon on, DreamAtlas keeps running after you close its window.
- **Morning reminder:** an optional notification at a time you choose. It's skipped on mornings you've already recorded a dream, and clicking it opens quick capture.
- **Open at login:** a toggle in Settings › Capture, so the shortcut is always ready.
- **Your data:** export to Markdown and back up or restore as JSON. Export always works, even in the free version.

Data lives in `~/Library/Application Support/DreamAtlas/journal.json`.

## Monetization: $14.99 lifetime
- **Free:** up to 15 dreams with every feature, so people can try the patterns. Existing dreams are never locked.
- **Lifetime ($14.99, one-time):** unlimited dreams. The app checks an Ed25519-signed license key offline, so there's no account and no server.
- To sell:
  1. Set `LicenseManager.purchaseURL` in `Sources/License.swift` to your Gumroad, Lemon Squeezy or Paddle checkout.
  2. Issue a key for each buyer:
     ```bash
     swift Tools/license_tool.swift issue "Buyer Name" order-123
     ```
  3. Automate step 2 with your store's webhook.
- `Tools/keys/private.key` signs every license. **Back it up and never publish it.** It's already in `.gitignore`.

## Developer notes
- `DreamAtlas --snapshot <dir> [--dark] [--welcome | --capture]` loads sample dreams and saves a PNG of each screen. Run it with `CFFIXED_USER_HOME=<scratch dir>` so it never touches a real journal. On macOS 26 and later these captures leave the glass sidebar blank, but it shows normally in the app.
- To sell through the Mac App Store instead, wrap these sources in an Xcode project and replace the license key with a StoreKit 2 non-consumable at the same $14.99 price.

See [ROADMAP.md](ROADMAP.md) for expansion ideas.
