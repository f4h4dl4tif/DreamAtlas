# DreamAtlas expansion roadmap

Guiding rule: every feature helps people **reflect on their own words**. Nothing interprets symbols, diagnoses or predicts.

## Planned expansions
1. **Mobile voice journal (iPhone and Apple Watch)**
   - Record a dream half-awake, by voice, and have it transcribed on-device.
   - Lock Screen and Action Button widgets so you can start recording in one tap.
   - The Watch app saves a voice note and the time; you finish the entry later.
   - Syncs with the Mac through end-to-end encrypted iCloud (CloudKit private database), and only if the user opts in.
2. **Optional AI categorization**
   - Suggests emotion and theme tags from the text. The user accepts or rejects every suggestion.
   - Runs on-device first (Apple Foundation Models), with a cloud model only as an explicit opt-in.
   - Labelled "suggested tags", never "meaning".

## More ideas, grouped by value

### Capture: remember more of the dream
- ~~**Morning prompt:** a gentle notification at your usual wake time, plus a menu bar quick-capture window (⌥⌘D) that opens instantly.~~ (shipped)
- **Guided recall questions:** where were you, who was there, what colours, what did you want. They help when you remember only fragments.
- **Sketch or photo attachments:** draw a place or a creature from the dream (Apple Pencil on iPad).
- **Dream fragments:** save a half-remembered scrap and merge it into a full entry later.
- **Sleep context (optional, from HealthKit):** bedtime, sleep duration and naps shown next to each dream, as context rather than conclusions.

### Reflection: make sense of it yourself
- **Waking-life notes:** a separate field for "what was going on in my life", so users can notice their own links.
- **Personal dictionary:** users write what a recurring symbol means *to them*. The app shows their own definition when that symbol comes up again. This is the respectful alternative to a "dream dictionary".
- **Reflection prompts:** neutral questions such as "This theme has appeared 4 times this month. Anything you'd like to note about it?"
- **"On this day":** dreams from a year ago, for continuity.
- **Monthly and yearly recap:** a shareable, privacy-safe summary card (counts and top themes only, never dream text).

### Exploration: richer pattern views
- **Dream map:** an interactive graph linking themes, people and places across dreams (a real "atlas").
- **People and places as tag types:** see who and where shows up most.
- **Saved filters / smart collections:** for example "lucid + flying" or "recurring with anxiety".
- **Series:** link dreams that continue a story or a recurring setting.
- **Compare periods:** this season against last, before and after a life change the user marks.

### Lucid dreaming toolkit (a popular niche with enthusiasts)
- Reality-check reminders, dream-sign tracking (from your own recurring themes), and a lucidity streak and log.

### Trust & data
- **Encrypted journal file:** AES-GCM with the key in the Keychain, plus an optional separate passphrase.
- **Encrypted backups,** plus import from Day One, Obsidian/Markdown and CSV.
- **Print and PDF "book" export:** a typeset yearly dream book. This could be a paid add-on or a reason to keep buying.

## Monetization fit
- Keep the **$14.99 lifetime** Mac app as the core.
- Possible extras:
  - **iPhone/Watch companion:** included in a universal lifetime purchase, or $4.99 extra.
  - **AI suggestions:** free when on-device. A cloud option, if ever added, could be a small optional add-on so the core price never needs a subscription.
  - **Dream Book print export:** a one-time unlock.

## Suggested order
1. ~~Menu bar quick-capture and morning reminder~~ (shipped)
2. Personal dictionary and waking-life notes (the core of "reflection")
3. Encrypted journal file
4. iPhone voice journal and iCloud sync
5. On-device AI tag suggestions
6. Dream map graph and yearly recap
