# Crown & Blade

Multi-tenant barbershop booking platform for Addis Ababa, built with Flutter and Firebase.

| Role | Can do |
|---|---|
| Admin | Register shops and invite their owners, verify or remove shops, see all users and bookings, resolve payments flagged for review |
| Shop owner | Manage one shop: profile, hours, services, barbers (invites them by phone), all of the shop's bookings. Set the booking policy (cancellation cutoff, reschedule limit), mark no-shows, add or remove any of the shop's barbers' time off, run the walk-in queue, reply to reviews, see monthly reports and the client list |
| Barber | See and run their own appointment queue, set availability, add or remove their own time off, mark no-shows, run the walk-in queue, see earnings and their own reviews |
| Customer | Find shops and barbers, book, reschedule and cancel (within the shop's policy), keep favorites, join a shop's walk-in queue from the app, rate completed visits |

## Architecture

| Layer | Where | What it does |
|---|---|---|
| Flutter app | `lib/` | One app for all four roles. Screens read synchronous getters on `AppRepository` inside `ListenableBuilder`s. |
| Repository | `lib/services/app_repository.dart` | `ChangeNotifier` singleton. Reads come from an in-memory `DataCache`; writes go through a `DataStore`. |
| Data stores | `lib/services/data_store.dart`, `firestore_data_store.dart` | `FirestoreDataStore` (production) opens role-scoped snapshot listeners after sign-in and writes to Firestore. `LocalDataStore` (demo mode and tests) keeps everything in memory. Customer, owner and barber booking listeners load every upcoming booking plus the last 90 days of history (newest 200 for customers, 1000 for staff). |
| Time slots | `lib/services/availability_service.dart` | Builds bookable slots on a 15-minute grid in Addis time (UTC+3) from shop and barber hours, service length and existing bookings. A booking is written in one transaction together with a slot lock per 15-minute block (`barbershops/{shop}/barbers/{barber}/slotLocks/{yyyyMMdd-HHmm}`), so two customers can never take the same block. Each lock holds only `bookingId`, `startAt` and `expiresAt` (booking end + 1 day), no customer data. The rules check the first four locks and the last one; `verifyBookingLocks` checks all of them. Services are limited to 120 minutes (8 locks) to stay inside Firestore's per-request rule limits. Barber time off (`barbers/{b}/timeOff/{id}`) is written in one batch with a lock per block shaped `{timeOffId, startAt, expiresAt}`, so availability, bookings and the lock checks all treat it as taken. |
| Booking policy | `lib/services/booking_policy.dart`, `time_off_service.dart` | Cutoff, reschedule limit, no-show timing and time-off validation as pure functions shared by the screens, the repository and the tests. See [Booking policies](#booking-policies). |
| Walk-in queue | `lib/services/queue_service.dart`, `lib/features/queue/`, `functions/queue` | Staff add walk-ins and call the next person; signed-in customers can join from the shop page. `onQueueEntryWritten` keeps the public `queueSummary/current` (waiting count, estimated wait, each waiting entry's place) up to date and tells a remote customer when they are next. The wait formula (`queue_wait.dart` / `estimate.ts`) is the same in Dart and TypeScript. |
| Reviews | `lib/services/reviews_service.dart`, `lib/features/reviews/` | Customers rate a completed booking once (1-5 stars, optional comment); the owner can reply. Ratings on shops and barbers are recalculated by `functions/insights`. |
| Reports | `lib/services/reports_service.dart`, `lib/features/reports/`, `functions/insights` | Owner reports: monthly totals, revenue in Birr, top services, barber performance and a client list, read from the `stats` and `clients` documents that `functions/insights` maintains. |
| Notifications | `lib/services/notification_service.dart`, `functions/notifications` | Cloud Functions send push (FCM), an in-app inbox entry (`users/{uid}/notifications`) and SMS (AfroMessage) on booking changes, payment results (paid, refunded, failed, subscription paid or failed) and slots lost to a conflict, plus 24h and 2h reminders. The app registers FCM tokens and shows the inbox. |
| Payments | `lib/services/payment_service.dart`, `functions/payments` | Chapa checkout for bookings and monthly shop subscriptions (trial, Basic, Pro). Callables create the checkout; a signed webhook and `verifyPayment` confirm it; a daily job moves overdue shops to past due and then suspended. Payments that need a person (paid for a cancelled booking, paid twice) are flagged `needsReview` and listed on the admin's **Payments to review** screen, where the admin records a Chapa refund or "no action needed" (`resolvePaymentReview`). |
| Localization | `lib/l10n/` | English and Amharic (`app_en.arb`, `app_am.arb`). Prices in Birr, phones in +251 form, dates and times in Addis time. |
| Security | `firestore.rules` | Roles, shop ownership, booking validity (price, duration, slot locks), and payment and subscription fields that only functions may write. Tested in `firestore-tests/`. |

Collections: `users`, `invites`, `barbershops` (with `services`, `barbers`, `barbers/*/slotLocks`, `barbers/*/timeOff`, `queue`, `queueSummary` (functions only), `reviews`, and `stats` and `clients` (functions only; owner and admin read) subcollections), `bookings`, `plans`, `payments`, `notificationLog` and `insightsApplied` (functions only), `users/{uid}/devices` and `users/{uid}/notifications`. All dates are stored as ISO-8601 UTC strings.

In demo mode and in tests every feature runs on a local store (`LocalDataStore`, `LocalQueueStore`, `LocalReviewStore`, and `ReportsService` computing the figures from the cached bookings), so nothing needs Firebase.

## Booking policies

- **Cancellation cutoff** (`barbershops/{s}.cancellationCutoffHours`, 0-72, default 2): customers cannot cancel or reschedule within this many hours of the start. Owners, the assigned barber and admins can still cancel.
- **Reschedule limit** (`maxReschedules`, 0-5, default 2): a customer can move a booking to another time with the same barber and service this many times. A reschedule is one transaction that updates the booking (`startAt`, `endAt`, `date`, `timeSlot`, `rescheduleCount`, `rescheduledAt`), deletes the locks of blocks it leaves and creates the locks of blocks it takes. `rescheduleCount` is absent until the first move.
- The owner sets both in **Customize Shop > Booking policy**. The rules enforce them too.
- **No-show:** once the start time has passed, the assigned barber, the owner or an admin can mark a pending or confirmed booking `noShow`. It is final and keeps its slot locks. The customer gets an inbox and push notification.
- **Time off:** the owner (for any barber of the shop) or the barber (their own) adds time off for a whole working day or an hour range on one Addis day. It cannot overlap a booking or other time off.

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

Besides shops, users and bookings, the seed has booking policies on every shop, one time-off entry, a walk-in queue for `shop_1` with its summary, and 13 reviews whose averages match the shops' and barbers' `rating` fields. Report stats are not seeded: the `insights` trigger builds them when the Functions emulator runs during seeding, or the admin calls `rebuildShopStats` afterwards.

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

There are five codebases (TypeScript, Node 20, region `europe-west1`), all listed in [firebase.json](firebase.json) and built and tested in CI:

| Codebase | Functions |
|---|---|
| `functions/notifications` | `onBookingWritten` (push, inbox and SMS on booking and booking-payment changes; `rescheduled` goes to customer, barber and owner with an SMS to the customer and clears reminders already sent so the new time gets its own; `noShow` goes to the customer only, without SMS), `onPaymentWritten` (failed booking payments, subscription paid or failed), `sendBookingReminders` (every 15 minutes) |
| `functions/payments` | Callables `createBookingPayment`, `createSubscriptionPayment`, `verifyPayment`, `setShopSubscription`, `seedDefaultPlans`, `resolvePaymentReview` (admin only); HTTPS `chapaWebhook`; scheduled `dailySubscriptionCheck` (03:00 Addis time) |
| `functions/bookings` | `verifyBookingLocks` (on booking create: checks a slot lock exists for every 15-minute block and cancels the booking with `cancelledBy: 'system'`, `cancelReason: 'slot_conflict'` if one is missing or taken), `verifyRescheduledBookingLocks` (on booking update when the time changed: the same check for the new interval; time-off locks count as taken), `cleanupExpiredSlotLocks` (daily 04:00 Addis: deletes slot locks whose `expiresAt` has passed, booking and time-off locks alike) |
| `functions/queue` | `onQueueEntryWritten` (recomputes `barbershops/{s}/queueSummary/current` in a transaction, sets a customer's duplicate remote entries to `left`, and sends a `queueNext` inbox entry and push, once, to a remote customer who reaches the front) |
| `functions/insights` | `aggregateBookingStats` (on every booking write: keeps `barbershops/{s}/stats/{yyyy-MM}` and `clients/{customerId}` up to date, idempotently through `insightsApplied/{bookingId}` markers; system slot-conflict cancellations are not counted), `aggregateReviewRatings` (on review writes: recalculates `rating` and `reviewCount` on the shop and its barbers), callable `rebuildShopStats` (admin only: rebuilds one shop's stats and clients from all its bookings) |

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
   firebase deploy --only functions              # all five codebases
   firebase deploy --only functions:payments     # or just one
   firebase deploy --only functions:bookings
   firebase deploy --only functions:queue
   firebase deploy --only functions:insights
   ```

   Deploy `firestore:indexes` first: the bounded booking listeners need the bookings `startAt` composite indexes, the lock cleanup needs the collection-group index on `slotLocks.expiresAt`, the queue needs `queue (status, createdAt)` and `queue (addedBy, createdAt desc)`, barber review lists need `reviews (barberId, createdAt desc)` and `reviews (barberId, rating)`, and `aggregateBookingStats` needs `bookings (shopId, customerId, status, startAt desc)`. Index builds can take a few minutes; queries fail until they finish.

   If the project already has bookings when `insights` is first deployed, sign in as the admin and call `rebuildShopStats` once per shop (`{ "shopId": "..." }`) so the reports include the older bookings.

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
- After deploying the rules, try a 120-minute booking (the longest allowed service), a 120-minute reschedule to a non-overlapping time and a whole-day time off (up to 96 locks in one batch) on the real project. The rules stay within Firestore's expression and read limits on the emulator, but the emulator does not show how production counts repeated `get`/`getAfter` calls on the same document. If production counts them separately, the app must split time off into smaller batches.
- Deep links back from Chapa on Android and iOS. For now the app verifies the payment when it comes back to the foreground, or when the user taps "I've paid".
- Refunds are made by hand in the Chapa dashboard; the admin then marks the payment as refunded on the Payments to review screen. There is no automatic refund through the Chapa API.

## Known limitations

- Booking listeners only cover upcoming bookings and the last 90 days (newest 200 for customers, 1000 for staff), so barber earnings and owner totals are for that window, not all time. Admins load the newest bookings by creation time.
- A booking that loses a slot race on the client side is rejected at once; one that slips past the rules (they check only the first four locks and the last one) is cancelled by `verifyBookingLocks` within seconds, and the customer gets a "that time was just taken" notification.
- Slot locks written before `expiresAt` existed are never cleaned up by `cleanupExpiredSlotLocks`. There is no production data yet; if there ever is, backfill `expiresAt` or delete them once.
- A booking that was already paid and is then cancelled is not flagged for review automatically (only payments that succeed after the cancellation are). The owner or admin handles that refund by hand.
- Time off covers one Addis day per entry ("whole day" means the barber's working hours that day). A longer absence is added day by day, or by turning the barber's availability off. Admins cannot add, remove or read time off, though they can still clear any lock.
- A reschedule keeps the existing locks of blocks that are in both the old and the new interval; they keep the old `expiresAt`, which is always after the block.
- `noShow` is final: nobody can change the status afterwards (the admin can still correct `paymentStatus`).
- Customers cannot edit or delete a review once posted. Only the shop owner can reply (not the admin). Owners are not notified of new reviews.
- Reports and review lists load once (with a refresh) rather than live, and the figures change a few seconds after a booking or review does, once the `insights` trigger has run. Ratings on shops and barbers are live.
- The queue summary is recomputed only when a queue entry changes, so a barber going unavailable or a service changing length shows up at the next queue change. In demo mode a remote customer gets no "you're next" inbox entry (the card on the shop page still says so). One active queue entry per customer is checked by the app and repaired by the function; the rules cannot enforce it.
- Queue and review errors use their own `QueueException` / `ReviewException` codes rather than the shared `AppErrorCode` enum. All of them are translated.

## Tests

```sh
flutter test                         # app tests (run against the local demo data)
cd firestore-tests && npm install && npm test   # security rules tests on the Firestore emulator (needs Java 21+)
cd functions/notifications && npm install && npm run build && npm test
cd functions/payments && npm install && npm run build && npm test
cd functions/bookings && npm install && npm run build && npm test
cd functions/queue && npm install && npm run build && npm test
cd functions/insights && npm install && npm run build && npm test
cd tool/seed && npm install && npm test          # seed script
```
