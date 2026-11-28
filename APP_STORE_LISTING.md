# Jero: App Store listing (copy and paste)

Everything App Store Connect asks for, in the order it asks. Character limits are checked.

## 0. Before you start
- App Store Connect > Apps > Jero (bundle ID `com.ralphgeb.jero`) > the new version "1.0" under iOS App.
- Business > Agreements: the Paid Apps Agreement, banking and tax must be "Active", or the subscription cannot sell.
- GitHub Pages must be on for this repo (Settings > Pages > Deploy from branch > main > /docs). Then open the two links in step 3 in a browser. Both must load.

## 1. App Information (left menu: General > App Information)
| Field | Enter |
|---|---|
| Name (max 30) | `Jero: Wine Course & Journal` (27) |
| Subtitle (max 30) | `Learn, taste and scan wine` (26) |
| Primary category | Education |
| Secondary category | Food & Drink |
| Content rights | Yes, you have the rights (photos and map data are public domain or Creative Commons and are credited inside the app) |
| Age rating | Answer the questionnaire truthfully. For alcohol references a wine app will probably come out 17+/18+. Accept it. |

If the name is taken: `Jero: Learn Wine` or `Jero - Wine School`.
Do not put WSET or any wine school's name in the name, subtitle or keywords (trademark rule 2.3.7).

## 2. Pricing and Availability
- Price: Free (the subscription is the only purchase).
- Availability: all countries (or start with your own).

## 3. Version page (1.0 Prepare for Submission)

**Promotional text (max 170, can change any time):**
```
Short daily wine lessons, an atlas of grapes and regions on real maps, and a journal that identifies the bottle in your hand. Start free.
```

**Keywords (max 100, no spaces after commas):**
```
sommelier,grape,vineyard,tasting,cellar,quiz,study,label,scanner,atlas,viticulture,winery,vintage
```

**Description (max 4000):**
```
Learn wine in minutes a day. Jero is a short-lesson wine course, an atlas of the wine world and a journal for the bottles you drink, all in one app.

LEARN
• Five levels, from Foundations to Expert, with 250 short lessons
• Quick questions after every card, daily streaks and practice mixes
• Mock exams for every level, always a fresh mix of 30 questions
• A placement quiz that starts you at the right level

EXPLORE THE ATLAS
• 66 grapes with flavors, taste profiles and what to serve
• Detailed zoomable maps of wine countries, regions and appellations
• Aroma wheel, color chart, tasting guide, glossary and food pairings
• 76 wines of the world and 25 great wines to try

KEEP A WINE JOURNAL
• Scan a label to see the wine, its grapes, region, aromas and an average price
• Build a cellar: see what it is worth, what you paid, and graphs of colors, countries and prices
• Blind tasting mode: look, smell and taste, guess the grape and country, and get a score out of 100
• Save your tasting notes and see your palate grow

WIDGETS
• A wine fun fact and a wine to try on your home screen, in light, dark or automatic

MADE FOR YOUR PHONE
• Works on iPhone and is laid out for foldable iPhones too

JERO PLUS (OPTIONAL)
Jero is free to start. Jero Plus unlocks every level, every country and the journal for $0.99 a month. Payment is charged to your Apple ID at confirmation of purchase. The subscription renews automatically unless it is canceled at least 24 hours before the end of the current period. Manage or cancel it any time in your Apple ID account settings.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://ralphgeb.github.io/Jeroboam/privacy.html

Wine lookups are estimates. Please drink responsibly. Jero is for adults of legal drinking age.
```

**Support URL:** `https://ralphgeb.github.io/Jeroboam/support.html`
**Marketing URL:** leave empty
**Privacy Policy URL (in App Information too):** `https://ralphgeb.github.io/Jeroboam/privacy.html`
**What's New:** `First release.`
**Copyright:** `2026 Ralph Gebara`
**Version:** 1.0. **Build:** choose the newest TestFlight build.
**Release:** "Manually release this version" is safest for a first launch.

## 4. Screenshots
- Required: the 6.9" iPhone set (1320 x 2868). iPad is not needed (iPhone only).
- 6 to 8 pictures, in this order, with one short caption each:
  1. Learn: "Learn wine in minutes a day"
  2. A lesson card: "Short lessons, quick questions"
  3. Atlas map: "Explore regions on real maps"
  4. A grape page: "66 grapes, flavors and food"
  5. Journal scan result: "Scan a label, know the wine"
  6. Cellar with a graph open: "See what your cellar is worth"
  7. Blind tasting score: "Taste blind, score out of 100"
  8. Widgets: "A wine fact on your home screen"

## 5. App Privacy (left menu: Trust & Safety > App Privacy)
- "Do you or your third-party partners collect data?" Yes.
- Tracking: No. (No ad networks, no tracking.)
- Data types to tick (every one: **not linked to the user**, **not used for tracking**, purpose **App Functionality**):
  1. Photos or Videos (a label photo is sent for identification when the text is unclear; a numeric fingerprint of each
     scanned label's look is kept in Jero's wine table for faster recognition, not the photo)
  2. Other User Content (the text read from a label)
  3. Product Interaction under Usage Data (the anonymous wine count: which wines are looked up)
  4. Device ID under Identifiers (a random number made by the app on first use, sent with wine lookups so Jero's server can
     keep each phone to its small daily allowance, and with each scan so it can count phones per day; purposes: App
     Functionality + Analytics; not the advertising ID, not linked to the person)
- Everything else: not collected (no name, email, contact, location, purchases, diagnostics).
- Privacy Policy URL: step 3 link.

## 6. Subscription (left menu: Monetization > Subscriptions)
The build workflow already made the group, the product `com.ralphgeb.jero.plus.monthly` and its text. Open it and fill the rest:
1. Subscription group display name: `Jero Plus`
2. Product reference name: `Jero Plus monthly`. Display name: `Jero Plus`. Description (max 45): `Every level, every country, your journal`
3. Price: $0.99 per month (check the other countries' prices it fills in)
4. Review screenshot: a picture of the Jero Plus offer screen (open it from Settings > Get Jero Plus)
5. Review notes (optional): `Subscription unlocks levels 2-5, all countries and the Journal.`
6. Status must change from "Missing Metadata" to "Ready to Submit".
7. On the version page, scroll to **In-App Purchases and Subscriptions** and add `Jero Plus`. Without this the first review fails.

## 7. App Review Information (bottom of the version page)
- Sign-in required: No.
- Contact: your name, phone and email (Apple only, not shown to users).
- Notes (paste):
```
Jero is a wine-learning app: short lessons, an atlas of grapes and regions, and a journal.
No account is needed and there is no sign-in. Progress, tastings and cellar sync through the user's own iCloud (Settings > Sync with iCloud), and Settings > Erase all my data deletes everything from the phone and iCloud.
To try it: finish onboarding, open the Journal tab and tap "Scan a wine" (camera) or type a wine. The label text is read on the device, and the wine details come from the Claude API (Anthropic) and our wine database. Photos are not kept.
Jero Plus is an auto-renewing monthly subscription (com.ralphgeb.jero.plus.monthly). Levels 2-5, all countries and the Journal are in Plus; France and Level 1 are free. Please test it with the sandbox account.
All photos, map data and wine facts are original, public domain or Creative Commons and credited in the app (Settings > Regions & maps). The app is not affiliated with any wine school or brand.
```

## 8. Export compliance
Already answered in the build (`ITSAppUsesNonExemptEncryption = false`). If asked: "No" to encryption beyond standard HTTPS.

## 9. Press "Add for Review", then "Submit"
Last checks:
- Open both policy links on your phone.
- Add an email address to the support page (the page now only says "open an issue on GitHub", and App Review prefers a contact email).
- If the review comes back with 4.3(a) (spam, as happened to Ahead): reply in the Resolution Center. Jero's content (250 lessons, 66 grapes, zoomable regional maps, wine journal with scanning) is not shared with any of your other apps.
