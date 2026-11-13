# Crown & Blade

Multi-tenant barbershop booking platform for Addis Ababa, built with Flutter and Firebase.

| Role | Can do |
|---|---|
| Admin | Register shops and invite their owners, verify or remove shops, see all users and bookings |
| Shop owner | Manage one shop: profile, hours, services, barbers (invites them by phone), all of the shop's bookings |
| Barber | See and run their own appointment queue, set availability, see earnings |
| Customer | Find shops and barbers, book, cancel, keep favorites |

## Architecture

| Layer | Where | What it does |
|---|---|---|
| Flutter app | `lib/` | One app for all four roles. Screens read synchronous getters on `AppRepository` inside `ListenableBuilder`s. |
| Repository | `lib/services/app_repository.dart` | `ChangeNotifier` singleton. Reads come from an in-memory `DataCache`; writes go through a `DataStore`. |
| Data stores | `lib/services/data_store.dart`, `firestore_data_store.dart` | `FirestoreDataStore` (production) opens role-scoped snapshot listeners after sign-in and writes to Firestore. `LocalDataStore` (demo mode and tests) keeps everything in memory. |
| Time slots | `lib/services/availability_service.dart` | Builds bookable slots on a 15-minute grid in Addis time (UTC+3) from shop and barber hours, service length and existing bookings. A booking is written in one transaction together with a slot lock per 15-minute block (`barbershops/{shop}/barbers/{barber}/slotLocks/{yyyyMMdd-HHmm}`), so two customers can never take the same block. |
| Notifications | `lib/services/notification_service.dart`, `functions/notifications` | Cloud Functions send push (FCM), an in-app inbox entry (`users/{uid}/notifications`) and SMS (AfroMessage) on booking changes, plus 24h and 2h reminders. The app registers FCM tokens and shows the inbox. |
| Payments | `lib/services/payment_service.dart`, `functions/payments` | Chapa checkout for bookings and monthly shop subscriptions (trial, Basic, Pro). Callables create the checkout; a signed webhook and `verifyPayment` confirm it; a daily job moves overdue shops to past due and then suspended. |
| Localization | `lib/l10n/` | English and Amharic (`app_en.arb`, `app_am.arb`). Prices in Birr, phones in +251 form, dates and times in Addis time. |
| Security | `firestore.rules` | Roles, shop ownership, booking validity (price, duration, slot locks), and payment and subscription fields that only functions may write. Tested in `firestore-tests/`. |

Collections: `users`, `invites`, `barbershops` (with `services`, `barbers` and `barbers/*/slotLocks` subcollections), `bookings`, `plans`, `payments`, `notificationLog` (functions only), `users/{uid}/devices` and `users/{uid}/notifications`. All dates are stored as ISO-8601 UTC strings.

## How sign-in and roles work

- Everyone signs in with an Ethiopian mobile number and a 6-digit SMS code (Firebase phone auth). There are no passwords.
- On first sign-in the person enters their name and gets a profile at `users/{uid}`.
- The role on that profile is enforced by [firestore.rules](firestore.rules). Nobody can choose their own role:
  - Without an invite, a new account is a **customer**.
  - The admin registers a shop with the owner's phone number. That creates an invite at `invites/{phone}`, and the owner gets the **shop owner** role when they sign in with that number.
  - A shop owner adds a barber with a phone number, which creates a **barber** invite for their own shop.
  - An invite upgrades an existing customer once. It never changes an existing barber, owner or admin.
- Removing a barber profile removes that barber's access.

## Running the app

### Demo mode (no Firebase)

```sh
flutter run --dart-define=DEMO_MODE=true
```

Runs offline on the Addis Ababa demo dataset in [assets/seed/addis_seed.json](assets/seed/addis_seed.json). The sign-in screen shows one-tap demo accounts, and the SMS code is always `123456`. Chapa payments are simulated, and booking notifications appear only in the in-app inbox (no push or SMS). The GitHub Pages build is a demo build. Never ship a production build with `DEMO_MODE`.

### Production (Firebase)

Without the define, the app requires Firebase and shows "Service unavailable" until it is configured.

With Firebase, Firestore is the source of truth: after sign-in the app keeps live listeners on the data your role can see.

### Seeding Firestore

The seed script loads the demo dataset into the emulator or a real project. All options are in [tool/seed/README.md](tool/seed/README.md).

```sh
cd tool/seed && npm install
node seed.js --dry-run     # preview what would be written

# emulator (run from the repo root)
firebase emulators:exec --only firestore,auth --project demo-crownblade "node tool/seed/seed.js"

# real project: shops, services, barbers, plans and invites only
GOOGLE_APPLICATION_CREDENTIALS=service-account.json node seed.js --invites --project <project-id> --yes
```

On a real project use `--invites`: it writes no fake accounts or bookings. The plans can also be created from the admin app (Subscriptions > Plans > Create default plans), which calls the `seedDefaultPlans` function.

### Translations

Edit `lib/l10n/app_en.arb` and `lib/l10n/app_am.arb` (they have the same keys), then run `flutter gen-l10n`. The generated code goes to `lib/l10n/gen`.

## Firebase setup (one time)

1. Install the tools and sign in:

   ```sh
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   firebase login
   ```

2. Create a Firebase project at <https://console.firebase.google.com>, then connect the app. This replaces the placeholder `lib/firebase_options.dart` and adds the Android config:

   ```sh
   flutterfire configure --project=<your-project-id> --platforms=android,ios,web
   ```

3. In the Firebase console:
   - **Authentication > Sign-in method:** enable **Phone**.
   - **Authentication > Settings > SMS region policy:** allow Ethiopia (+251).
   - **Authentication > Settings > Authorized domains:** add your web domain (for example `<user>.github.io`).
   - **Firestore Database:** create the database (choose a region near Ethiopia, such as `europe-west`).
   - For testing without real SMS, add test numbers under **Phone numbers for testing**.

4. Android phone auth needs your app's signing fingerprints. Get them with `cd android && ./gradlew signingReport` and add the SHA-1 and SHA-256 under **Project settings > Your apps > Android**.

5. Deploy the security rules:

   ```sh
   firebase use <your-project-id>
   firebase deploy --only firestore:rules
   ```

6. Create the first admin. In the Firestore console, add a document to the `invites` collection:
   - Document ID: the admin's phone number in `+2519XXXXXXXX` form
   - Fields: `phone` (same number), `role` = `admin`, `name`, `createdBy` = `console`, `createdAt` = an ISO date string such as `2026-11-13T00:00:00Z`

   Then sign in with that number in the app. From there the admin registers shops and invites owners.

## Cloud Functions

There are two codebases (TypeScript, Node 20, region `europe-west1`), both listed in [firebase.json](firebase.json):

| Codebase | Functions |
|---|---|
| `functions/notifications` | `onBookingWritten` (push, inbox and SMS on booking changes), `sendBookingReminders` (every 15 minutes) |
| `functions/payments` | Callables `createBookingPayment`, `createSubscriptionPayment`, `verifyPayment`, `setShopSubscription`, `seedDefaultPlans`; HTTPS `chapaWebhook`; scheduled `dailySubscriptionCheck` (03:00 Addis time) |

### Before the first deploy

1. Upgrade the Firebase project to the **Blaze** (pay as you go) plan. Cloud Functions, Cloud Scheduler and outbound calls to Chapa and AfroMessage need it.
2. Create the Firestore database in a location that works with `europe-west1` triggers, for example `eur3` or `europe-west1`.
3. Set the secrets. Each command prompts for the value:

   ```sh
   firebase functions:secrets:set CHAPA_SECRET_KEY           # Chapa dashboard > Settings > API keys
   firebase functions:secrets:set CHAPA_WEBHOOK_SECRET       # the secret you give Chapa for the webhook
   firebase functions:secrets:set AFROMESSAGE_TOKEN          # AfroMessage API token; "none" logs SMS instead of sending
   firebase functions:secrets:set AFROMESSAGE_IDENTIFIER_ID  # AfroMessage sender identifier id
   firebase functions:secrets:set AFROMESSAGE_SENDER         # AfroMessage sender name
   ```

4. Deploy. The first deploy of `payments` asks for `PAYMENT_RETURN_URL`, the page Chapa sends the customer back to. Use the web app's root URL, for example `https://<host>/`: the app reads `?paymentId=` from it and verifies the payment. `CHAPA_CALLBACK_URL` is optional and defaults to the `chapaWebhook` URL.

   ```sh
   firebase deploy --only firestore:rules,firestore:indexes
   firebase deploy --only functions              # both codebases
   firebase deploy --only functions:payments     # or just one
   ```

5. In the Chapa dashboard, set the webhook URL to `https://europe-west1-<project-id>.cloudfunctions.net/chapaWebhook`, with the same secret as `CHAPA_WEBHOOK_SECRET`.
6. Create the subscription plans: as admin, open Subscriptions > Plans > Create default plans, or run the seed script. The defaults are Basic at 500 ETB a month for up to 3 barbers, Pro at 1,200 ETB a month with unlimited barbers, and a 30-day free trial for every new shop.

### Push notifications

- **Android:** works after `flutterfire configure`. The app creates the `bookings` notification channel.
- **iOS:** upload an APNs key under Firebase console > Project settings > Cloud Messaging, and turn on the Push Notifications and Background Modes (remote notifications) capabilities in Xcode.
- **Web:** fill in the `firebaseConfig` placeholders in `web/firebase-messaging-sw.js`, and build with `--dart-define=FCM_VAPID_KEY=<key>` (Firebase console > Cloud Messaging > Web Push certificates). Without the key, web users still get the in-app inbox.

## What still needs real-world setup

- A Firebase project (`flutterfire configure`), phone sign-in with +251 allowed in the SMS region policy, and the first admin invite (see above).
- A Chapa merchant account. Test with Chapa test keys first: the webhook signature check and the verify response were written from Chapa's docs and have not run against live Chapa.
- An AfroMessage account with an approved sender name. Until then, set `AFROMESSAGE_TOKEN` to `none`.
- Final plan prices. Edit them in the admin app; the defaults live in `functions/payments/src/config.ts` and `assets/seed/addis_seed.json`.
- After deploying the rules, try a 90-minute booking on the real project. Production may count rule expressions differently from the emulator; if long bookings are rejected, cap service durations.
- Deep links back from Chapa on Android and iOS. For now the app verifies the payment when it comes back to the foreground, or when the user taps "I've paid".
- An admin screen for payments flagged `needsReview` (for example, paid and then cancelled). Refunds are made in the Chapa dashboard.

## Tests

```sh
flutter test                         # app tests (run against the local demo data)
cd firestore-tests && npm install && npm test   # security rules tests on the Firestore emulator (needs Java 21+)
cd functions/notifications && npm install && npm run build && npm test
cd functions/payments && npm install && npm run build && npm test
cd tool/seed && npm install && npm test          # seed script
```
