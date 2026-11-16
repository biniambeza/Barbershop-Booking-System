# Publishing Crown & Blade on Google Play

Plain-language steps, in order. Everything you paste comes from two files in this folder:

- `store/listing.md`: app name, descriptions, release notes (English and Amharic), category, URLs.
- `store/play-console-answers.md`: content rating, target audience, ads, app access, Data safety.

What is in this folder:

| File | What it is |
|---|---|
| `build/app/outputs/bundle/release/app-release.aab` (not in `store/`) | The app bundle you upload. Version 1.0.0, version code 1. Signed with your upload key (`android/app/upload-keystore.jks`). |
| `store/graphics/icon-512.png` | App icon, 512 x 512 |
| `store/graphics/feature-graphic-en.png`, `feature-graphic-am.png` | Feature graphic, 1024 x 500 (English, Amharic) |
| `store/screenshots/*.png` | Six phone screenshots, 1080 x 1920 (9:16), 24-bit PNG, upload in number order |
| `store/tool/` | Scripts that remake the graphics (see the end of this file) |

---

## 0. Before you start (do these first)

1. **Replace the placeholder email `privacy@example.com`** with a real inbox you read, in all three places:
   - `lib/core/config/legal_links.dart` (`kPrivacyContactEmail`)
   - `web/privacy.html`
   - `web/delete-account.html`

   Then rebuild the bundle (step 0.4), because the app shows this address.
2. **Publish the privacy policy and delete-account pages.** Commit and push to `main`. The GitHub Actions "deploy" workflow copies `web/privacy.html` and `web/delete-account.html` into the website, so they appear at:
   - `https://biniambeza.github.io/Barbershop-Booking-System/privacy.html`
   - `https://biniambeza.github.io/Barbershop-Booking-System/delete-account.html`

   Open both links in a browser and check they load. Google checks them; a 404 means rejection.

   Today (2026-11-16) even the site root `https://biniambeza.github.io/Barbershop-Booking-System/` answers 404. After the workflow has run once, open the GitHub repository > **Settings > Pages** and set **Source: Deploy from a branch**, branch **gh-pages**, folder **/ (root)**. The repository must be public for Pages on a free GitHub account.
3. **Deploy the Firestore rules** (`firebase deploy --only firestore:rules,firestore:indexes`). The Play build talks to the real Firebase project, and maps, portfolio, customer blocks and account deletion need the current rules.
4. **Rebuild the bundle** if you changed anything after the last build:

   ```
   flutter build appbundle --release
   ```

   Every new upload to Play needs a higher version code: change `version: 1.0.0+1` in `pubspec.yaml` to `1.0.0+2`, `1.0.0+3`, ... (or `1.0.1+2` for a visible version change). The number after `+` is the version code.
5. **Keep the upload key safe.** `android/key.properties` and `android/app/upload-keystore.jks` are not in git. Copy both to a safe place (a password manager or an encrypted USB stick). If you lose them, you have to ask Google to reset the upload key, which takes days.

## 1. Create the app in Play Console

1. Go to <https://play.google.com/console> and pay the one-time USD 25 developer registration if you have not yet. New personal accounts must verify identity, and **new personal accounts must run a closed test with at least 12 testers for 14 days before they can publish to production** (see step 8). Organisation accounts (with a D-U-N-S number) skip that rule.
2. **Create app**:
   - App name: `Crown & Blade Barbers` (from `listing.md`)
   - Default language: English (United States) - en-US
   - App or game: App
   - Free or paid: Free (cannot be changed to paid later)
   - Tick the declarations (Developer Program Policies, US export laws).

## 2. Upload to internal testing first

1. **Test and release > Testing > Internal testing > Create new release.**
2. **Play App Signing**: when asked, choose **Use Google-generated key** (the default). Google keeps the key that signs the app on users' phones; your `upload-keystore.jks` only proves uploads come from you.
3. Upload `build/app/outputs/bundle/release/app-release.aab`.
4. Release name: `1.0.0 (1)`. Release notes: paste the English and Amharic release notes from `listing.md` (in the `<en-US>` and `<am>` tags Play shows).
5. **Testers** tab: create an email list with your own Google account (and a few others), save, and copy the opt-in link.
6. **Review release > Start rollout to internal testing.**
7. Open the opt-in link on an Android phone, accept, install from Play, and check sign-in.

## 3. Make Google sign-in work in the Play build (Firebase)

Google sign-in only works when Firebase knows the certificate that signed the installed app. A Play install is signed with Google's **app signing key**, not your upload key, so both must be added.

1. Play Console: **Test and release > Setup > App signing** (also called "App integrity > App signing"). Copy:
   - **App signing key certificate**: SHA-1 and SHA-256
   - **Upload key certificate**: SHA-1 and SHA-256
2. Firebase console > project `barbershop-booking-syste-8a9b8` > **Project settings > Your apps > Android app `et.crownblade.app` > Add fingerprint**. Add all four (two SHA-1, two SHA-256).

   Your upload key (read from the signed bundle, so you can compare):

   ```
   Upload key (CN=Crown and Blade, O=Crown and Blade, L=Addis Ababa, C=ET)
   SHA-1:   76:5D:BC:BC:92:D9:C1:C7:C6:A0:C2:DB:99:12:87:90:74:7C:CE:5E
   SHA-256: A3:56:61:0B:E1:2E:93:EE:A3:48:ED:9E:2C:D6:CB:99:4F:CD:BE:AD:0D:F9:84:A3:99:A5:E1:F7:48:71:A0:7C
   ```

   The upload key's SHA-1 is **already** registered in Firebase for `et.crownblade.app` (the other registered SHA-1, `A7:C9:E6:D4:...:6B:7E`, is most likely your debug key). Still add the upload key's SHA-256, and add **both** app signing key fingerprints from Play Console: those are the ones that matter for people who install from Play.
3. Download the new `google-services.json` from the same page, replace `android/app/google-services.json`, rebuild the bundle with a higher version code and upload it. (Strictly, the file only needs replacing when the OAuth clients change, but replacing it is the safe choice.)
4. Install from the internal testing link again and try **Continue with Google**. Error "10" or "DEVELOPER_ERROR" means a fingerprint is still missing.
5. App Check: in Firebase **App Check > Apps**, register the Android app with **Play Integrity** if not done. Leave enforcement **off** until most requests show as verified (see the readme). In Play Console link the Cloud project under **App integrity > Play Integrity API**.

## 4. Store listing

**Grow users > Store presence > Main store listing**:

1. App name, short description, full description: paste from `listing.md` (English).
2. App icon: `store/graphics/icon-512.png`.
3. Feature graphic: `store/graphics/feature-graphic-en.png`.
4. Phone screenshots: upload the six files in `store/screenshots/` in number order (Play accepts 2 to 8; 4 or more lets Play feature the app in more places):
   `01_customer_home` (shops with landmarks), `02_shop_page` (landmark, map, Directions), `03_booking_flow` (date and free times), `04_barber_dashboard`, `05_owner_reports` (busy hours), `06_portfolio` (haircut photo with "Book this style").
5. Save.
6. **Manage translations > Add your own translations > Amharic – am**: paste the Amharic name, short and full description from `listing.md`, and upload `feature-graphic-am.png` as the Amharic feature graphic (screenshots can stay the English ones).

**Grow users > Store presence > Store settings**:

1. App category: **Beauty** (or Lifestyle). Tags: up to 5 from `listing.md`.
2. Contact details: email (shown publicly: use a real inbox, not the placeholder), optional website `https://biniambeza.github.io/Barbershop-Booking-System/`.

## 5. App content (Policy and programs > App content)

Answer each section with `store/play-console-answers.md`:

1. **Privacy policy**: the privacy URL.
2. **App access**: "All or some functionality is restricted", add the reviewer instructions and accounts (create them first, see step 6).
3. **Ads**: No.
4. **Content rating**: fill the IARC questionnaire (section 4 of the answers). You get the rating by email right away.
5. **Target audience and content**: 18 and over.
6. **Data safety**: section 8 of the answers. Include the delete-account URL.
7. **Government apps, Financial features, Health, News, COVID-19**: No / none.
8. **Advertising ID**: No (the app has no ads). Check with the command in the end of this file that the bundle does not request `AD_ID`.

## 6. Create the reviewer accounts (you, in the real app)

Google's reviewers need working logins. Do this on the production Firebase project (the Play build or the website):

1. Create a **customer** account with an email you own (for example `playreview.customer@<your-domain>` or a Gmail `+alias`), verify the email, set a phone number.
2. Create a test shop "Play Review Barbers" (as admin: register a shop and invite the owner email; or apply as an owner and approve it). Give it a landmark, a map pin, two services, opening hours, and make sure it is **active** (approve a subscription receipt as admin, or extend the subscription).
3. Accept the **owner** invite with a second email; add one **barber** with a third email (Manage barbers), sign in once as the barber and set the final password.
4. Make one booking as the customer so the dashboards are not empty.
5. Put the three emails and passwords in **App access** (template in `play-console-answers.md`). Never change those passwords and never use two-step sign-in on them. Do not give your own admin account.

## 7. Countries

**Test and release > Production > Countries / regions > Add countries**: add **Ethiopia**. Add others only if you want (the app is built for Addis Ababa; prices are in ETB).

## 8. Closed testing (required for new personal developer accounts)

If Play says you must run a closed test before production:

1. **Testing > Closed testing > Create track**, upload the same (or a newer) bundle, add at least **12 testers** by email list or Google Group.
2. The testers must opt in and keep the app installed for **14 days in a row**.
3. Then **Apply for production access** on the Dashboard and answer the questions about the test.

## 9. Production

1. **Test and release > Production > Create new release**: choose the bundle from the library (promote it from testing), paste the release notes.
2. Optional: start with a staged rollout (for example 20%).
3. **Review release > Start rollout to Production.** Review usually takes a few days for a new app. Watch your email and the Play Console inbox for questions.

## 10. After release

- Crashlytics (Firebase console) shows crashes from the Play build.
- Every update: raise the version code in `pubspec.yaml`, `flutter build appbundle --release`, upload to internal testing, then promote.
- Once App Check shows nearly all requests verified, you may turn on enforcement for Firestore and Authentication.

---

## Remaking the graphics and screenshots

```
bash store/tool/fetch_screenshot_assets.sh            # once: fonts, demo photos, 3 map tiles (into build/store_cache)
flutter test --tags screenshots --run-skipped test/store_screenshots_test.dart
python store/tool/make_graphics.py                    # icon + feature graphics (needs Pillow: pip install pillow)
```

The screenshot test is tagged `screenshots` and skipped by `dart_test.yaml`, so plain `flutter test` never runs it. It draws the real screens with the demo data from `assets/seed/addis_seed.json` at 1080 x 1920 into `store/screenshots/`.

## Checking the bundle

```
# who signed it (upload key fingerprints; no password needed)
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
# version code and name
grep -E "versionCode|versionName" build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml
```
