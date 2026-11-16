# Play Console answers: Crown & Blade (et.crownblade.app)

Answers for **Play Console > Policy and programs > App content**. They match `web/privacy.html` (2026-11-16) and what the app does today on the free Firebase Spark plan. If you move to Blaze and turn on push, SMS (AfroMessage) or Chapa payments, read the "Blaze" notes again: the answers stay the same (those providers process data for you), but the privacy policy already names them.

---

## 1. Privacy policy

`https://biniambeza.github.io/Barbershop-Booking-System/privacy.html`

It only works after `web/privacy.html` is committed and pushed to `main` (today it returns 404). Replace `privacy@example.com` first (see RELEASE_STEPS.md).

## 2. Ads

**Does your app contain ads?** No.

## 3. App access

**All or some functionality is restricted** (you have to sign in). Give Google reviewers working accounts. You have to create them yourself (see RELEASE_STEPS.md, step 6). Paste this into the instructions field and fill in the passwords:

```
Crown & Blade needs an account. Use "Log in" with email and password (not Google).

Customer: playreview.customer@YOUR-DOMAIN / PASSWORD
  Home lists barbershops in Addis Ababa. Open a shop, tap a barber and a
  service, pick a day and a free time and confirm. "My bookings" shows it;
  it can be rescheduled or cancelled there.

Shop owner: playreview.owner@YOUR-DOMAIN / PASSWORD
  Owner dashboard of the test shop "Play Review Barbers": bookings, walk-in
  queue, Manage barbers, Reports. The monthly subscription screen only records
  a bank or telebirr transfer reference; no money is taken in the app.

Barber: playreview.barber@YOUR-DOMAIN / PASSWORD
  Barber dashboard: today's bookings, accept or decline requests, time off.

Account deletion: menu (three dots) > Delete account.
No location permission is needed; "Near me" asks for it only when tapped.
```

Rules for these accounts: email verified, no two-step login, the password never changes, the test shop is active (not suspended). Don't use your own admin account.

## 4. Content rating (IARC questionnaire)

**Category:** "All other app types" (Utility, productivity, communication or other). Not a game.

| Question | Answer |
|---|---|
| Violence, blood, gore | No |
| Sexual content or nudity | No |
| Bad language | No |
| Drugs, alcohol, tobacco | No |
| Crude humour | No |
| Gambling, simulated gambling, loot boxes | No |
| Horror or fear themes | No |
| **Can users interact or exchange content with each other?** | **Yes.** Customers write public reviews (stars and a comment) of a completed visit, and the shop owner replies publicly. Barbers and owners post haircut photos (portfolio) that everyone can see. There is no chat between users. |
| Does the app share the user's current location with other users? | No. A customer's location stays on the phone ("Near me"). Only the shop's address and map pin, set by the owner, are public. |
| Can users buy digital goods? | No digital goods for customers. Haircuts are paid at the shop (and, on Blaze, online through Chapa for the physical service). Shop owners pay a monthly listing fee by telebirr or bank transfer outside Google Play (see "Payments policy risk" below). |
| Unrestricted internet access (a web browser)? | No. Links open in the phone's browser or maps app. |
| Promotes digital currencies or NFTs? | No |

Expected result: Everyone / PEGI 3 / ESRB Everyone, with the "Users Interact" descriptor.

**Honest note on user-generated content.** Reviews are written only by customers with a completed booking, a customer can edit or delete their own review, the owner can reply, and the admin can disable an abusive account (that blocks new reviews). **There is no "Report" button on a review or photo and no admin screen to hide one review.** Google's User Generated Content policy expects an in-app way to report objectionable content and users. Recommended before production: add a "Report" action on reviews and portfolio photos plus an admin list to hide reported items. Until then, answer the UGC questions honestly (as above) and expect a reviewer to possibly ask for it.

## 5. Target audience and content

- **Target age groups: 18 and over** (recommended). The app handles bookings, phone numbers and payments, and the privacy policy already says it is not for children under 13. Choosing only 18+ keeps the app out of the Families policy and teen-specific checks. (16-17 can be added later if you want teenagers as customers; never tick under 13.)
- **Could the app unintentionally appeal to children?** No.
- Store listing "Appeals to children": No.

## 6. News app

No.

## 7. COVID-19 contact tracing and status apps

No.

## 8. Data safety

### Overview

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (Firebase and all providers use HTTPS/TLS) |
| Which ways can users ask for their data to be deleted? | **"Users can request that data be deleted"**: in the app (menu > Delete account) and on the web |
| Delete account URL | `https://biniambeza.github.io/Barbershop-Booking-System/delete-account.html` |
| Account creation methods | Username (email) and password; OAuth (Sign in with Google) |
| Independent security review (MASA) | No |
| Is any data shared with third parties? | **No.** Google Firebase (and, on Blaze, Chapa and AfroMessage) are service providers that process data for us, which Play does not count as sharing. Showing a customer's name and phone to the shop they booked is a user-initiated transfer, which Play also does not count as sharing. |

### Data types

For every type below: **Shared: No. Processed ephemerally: No.**

| Play data type | Collected | Required or optional | Purposes | What it is |
|---|---|---|---|---|
| Personal info > **Name** | Yes | Required | App functionality, Account management | Profile name; shown to the shop you book; first name on reviews |
| Personal info > **Email address** | Yes | Required | App functionality, Account management | Login; Google sign-in email |
| Personal info > **Phone number** | Yes | Required | App functionality, Account management | Contact phone on the profile and bookings; queue entries |
| Personal info > **User IDs** | Yes | Required | App functionality, Account management | Firebase user id |
| Financial info > **Purchase history** | Yes | Required | App functionality | Bookings with service, price, payment status, refunds |
| Financial info > **Other financial info** | Yes | Optional | App functionality | Shop owners only: telebirr/CBE transaction numbers for the subscription; on Blaze, Chapa payment references. No card or wallet PIN |
| Location > **Approximate location** and **Precise location** | Yes | Optional | App functionality | Only when an owner taps "Use my current location" to place the shop's map pin (saved as the shop's public location). A customer's "Near me" location stays on the phone and is not sent |
| Photos and videos > **Photos** | Yes | Optional | App functionality | Haircut portfolio photos (barbers and owners) and subscription receipt photos (owners) |
| App activity > **Other user-generated content** | Yes | Optional | App functionality | Review comments and stars, owner replies, cancellation and decline reasons |
| App activity > **Other actions** | Yes | Required | App functionality | Bookings made, rescheduled and cancelled, queue joins |
| App info and performance > **Crash logs** | Yes | Required | Analytics (fixing crashes) | Firebase Crashlytics (release builds) |
| App info and performance > **Diagnostics** | Yes | Required | Analytics | Device model, OS and app version with a crash |
| Device or other IDs | Yes | Required | App functionality, Fraud prevention and security | Notification (FCM) token, Firebase installation id, App Check (Play Integrity) |

Not collected: contacts, calendar, messages (SMS/email content), health, fitness, audio, files, web browsing, installed apps, race/religion/political views, advertising ID, payment card numbers.

"Favourites" are stored only on the phone, so they are not "collected".

### Advertising ID

Answer **"No, my app does not use advertising ID"** unless the merged manifest of the release build contains `com.google.android.gms.permission.AD_ID` (see RELEASE_STEPS.md, the build check prints it). The app has no ads and no Firebase Analytics.

## 9. Government app

No.

## 10. Financial features

"My app doesn't provide any financial features." (It records payments for haircuts and listing fees; it is not a bank, wallet, loan or crypto app.)

## 11. Health

"My app does not have any health features."

## 12. Payments policy risk (read before production)

Shop owners pay Crown & Blade a monthly fee by telebirr or CBE transfer and submit the reference in the app. Google requires Google Play Billing for in-app purchases of **digital** services and subscriptions. Payments for **physical** services (the haircut itself) are exempt. A business listing or SaaS subscription bought inside the app is a grey area that some reviewers reject. Options if Google objects:

1. Explain in the review notes that the fee is a merchant listing fee for a physical-service marketplace, billed offline by bank transfer.
2. Hide the subscription payment screen in the Play build and invoice owners outside the app (by phone or email), without a link or button that sends them to pay elsewhere.
3. Sell the owner subscription through Google Play Billing.
