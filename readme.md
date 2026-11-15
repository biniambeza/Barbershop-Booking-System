# Crown & Blade

Multi-tenant barbershop booking platform for Addis Ababa, built with Flutter and Firebase.

| Role | Can do |
|---|---|
| Admin | Register shops and invite their owners, review shop applications (approve creates the shop and the owner invite, reject with a reason), verify or remove shops, see all users and bookings, resolve payments flagged for review |
| Shop owner | Manage one shop: profile, hours, services, barbers (invites them by Google email), all of the shop's bookings. Set the booking policy (cancellation cutoff, reschedule limit, whether barbers must accept each booking), answer booking requests for any barber, mark no-shows, add or remove any of the shop's barbers' time off, run the walk-in queue, reply to reviews, see monthly reports and the client list, set each barber's commission and record payouts |
| Barber | See and run their own appointment queue, accept or decline booking requests, set availability, add or remove their own time off, mark no-shows, run the walk-in queue, see earnings, their share, payouts and balance owed, and their own reviews |
| Customer | Find shops and barbers, book, reschedule and cancel (within the shop's policy), keep favorites, join a shop's walk-in queue from the app, rate completed visits, apply to list their own barbershop |

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
| Shop applications | `lib/features/applications/`, `lib/models/shop_application.dart`, `functions/notifications/src/applications.ts` | A customer applies to list their barbershop (`shopApplications/{uid}`), can edit or withdraw it while pending and apply again after a rejection. The admin's **Shop applications** screen approves it (one batch: the shop, two starter services, a lead barber, the owner invite and the application update) or rejects it with a reason. The applicant becomes the owner without signing out (`applyPendingInviteForCurrentUser`). `onShopApplicationWritten` sends them an inbox entry and push in their language. |
| Barber acceptance | `lib/services/booking_acceptance.dart`, `lib/features/barber/widgets/booking_requests_section.dart`, `functions/bookings` | When a shop sets `requireBarberAcceptance`, new bookings start `pending` and appear under **New requests** for the barber and the owner. See [Booking policies](#booking-policies). |
| Commission and payouts | `lib/services/payout_service.dart`, `lib/models/payout.dart`, `lib/features/payouts/` | Each barber has a commission (`commissionPercent`, 0-100, default 50). The barber's share of a completed booking is its price times the commission, rounded to whole Birr. The owner's **Payouts** screen shows each barber's monthly share, what was paid and the balance owed, and records payouts (cash, telebirr, bank or other). A payout can be deleted within 24 hours. The barber dashboard shows the barber's share, payouts and balance. Balances are per calendar month in Addis time. |
| Localization | `lib/l10n/` | English and Amharic (`app_en.arb`, `app_am.arb`). Prices in Birr, phones in +251 form, dates and times in Addis time. |
| Security | `firestore.rules` | Roles, shop ownership, booking validity (price, duration, slot locks), and payment and subscription fields that only functions may write. Tested in `firestore-tests/`. |

Collections: `users`, `invites`, `shopApplications` (doc id = applicant uid), `barbershops` (with `services`, `barbers`, `barbers/*/slotLocks`, `barbers/*/timeOff`, `queue`, `queueSummary` (functions only), `reviews`, `payouts` (owner writes; owner and admin read all, a barber reads their own), and `stats` and `clients` (functions only; owner and admin read) subcollections), `bookings`, `plans`, `payments`, `notificationLog`, `insightsApplied`, `emailCodes`, `authRateLimits` and `inviteEmails` (functions only), `users/{uid}/devices` and `users/{uid}/notifications`. All dates are stored as ISO-8601 UTC strings.

In demo mode and in tests every feature runs on a local store (`LocalDataStore`, `LocalQueueStore`, `LocalReviewStore`, `LocalShopApplicationStore`, `LocalPayoutStore`, and `ReportsService` computing the figures from the cached bookings), so nothing needs Firebase.

## Booking policies

- **Cancellation cutoff** (`barbershops/{s}.cancellationCutoffHours`, 0-72, default 2): customers cannot cancel or reschedule within this many hours of the start. Owners, the assigned barber and admins can still cancel.
- **Barber cancel:** the assigned barber can cancel their own `pending` or `confirmed` booking up to its start time (not after it, and never another barber's booking). The app writes, in one transaction, `{status: 'cancelled', cancelledBy: <the barber's uid>, cancelReasonNote?: string (1-200 characters, only when a reason is given)}` and deletes the booking's slot locks, so the time is bookable again at once. No other field may change. `cancelReasonNote` can only be written on this staff cancel (the owner may add one too when cancelling with their own uid in `cancelledBy`); customers cannot write it, and nobody can edit it afterwards. The customer gets the usual cancelled notification ("cancelled by the barber"). Once the appointment has started, only the owner or an admin can cancel it.
- **Reschedule limit** (`maxReschedules`, 0-5, default 2): a customer can move a booking to another time with the same barber and service this many times. A reschedule is one transaction that updates the booking (`startAt`, `endAt`, `date`, `timeSlot`, `rescheduleCount`, `rescheduledAt`), deletes the locks of blocks it leaves and creates the locks of blocks it takes. `rescheduleCount` is absent until the first move.
- **Barbers accept each booking** (`requireBarberAcceptance`, bool, absent = off): when on, a new booking is created `pending` (it still holds its slot locks) and shows under **New requests** for that barber and the shop owner. Either can:
  - **accept**: status `confirmed` plus `acceptedAt`; the customer is told the booking is confirmed.
  - **decline**, with an optional reason up to 200 characters: status `cancelled`, `cancelledBy: 'barber'`, `declineReason`; the slot locks are released in the same transaction.
  - A request that is not answered by 60 minutes before its start is cancelled by the scheduled `expirePendingBookings` function (`cancelledBy: 'system'`, `cancelReason: 'not_accepted'`), which also frees its locks. The app stops offering Accept at that point.
  - A pending booking cannot be paid online until it is accepted. The customer sees "Waiting for barber" and, after a decline or expiry, is asked to pick another time.
  - The rules require the status the shop's setting implies (`pending` when on, `confirmed` when off), so a customer whose app has a stale copy of the setting gets a booking error and can retry.
- The owner sets all three in **Customize Shop > Booking policy**. The rules enforce them too.
- **No-show:** once the start time has passed, the assigned barber, the owner or an admin can mark a pending or confirmed booking `noShow`. It is final and keeps its slot locks. The customer gets an inbox and push notification.
- **Time off:** the owner (for any barber of the shop) or the barber (their own) adds time off for a whole working day or an hour range on one Addis day. It cannot overlap a booking or other time off.

## How sign-in and roles work

- People sign in with their Google account, or with an email address and password (Firebase Authentication, Google and Email/Password providers). An email account is only created after a 6-digit code sent to that address is entered, so its email is verified too (see [Email registration codes](#email-registration-codes)). There are no SMS codes. A person is identified by their verified sign-in email, lowercased, so invites work the same for both kinds of account.
- On first sign-in the person enters their name and a contact phone number (Ethiopian mobile, `+2519...` or `+2517...`) and gets a profile at `users/{uid}` holding `email` (taken from the Google account, cannot be changed later), `name` and `phone`. The phone is not verified; it is used for bookings, SMS reminders and Chapa, and the person can change it (and their name and language) in their profile.
- The role on that profile is enforced by [firestore.rules](firestore.rules). Nobody can choose their own role:
  - Without an invite, a new account is a **customer**.
  - The admin registers a shop with the owner's Google email. That creates an invite at `invites/{email}` (the lowercased address), and the owner gets the **shop owner** role when they sign in with that Google account.
  - A customer can also apply to list their own shop (customer home, or "I own a barbershop" on the profile setup screen). When the admin approves the application, the same owner invite is created for the applicant's email and applied at once, without signing out.
  - A shop owner adds a barber with the barber's Google email, which creates a **barber** invite for their own shop.
  - An invite only works for a verified Google email that matches it, and it upgrades an existing customer once. It never changes an existing barber, owner or admin.
- Removing a barber profile removes that barber's access.

## Running the app

### Demo mode (no Firebase)

```sh
flutter run --dart-define=DEMO_MODE=true
```

Runs offline on the Addis Ababa demo dataset in [assets/seed/addis_seed.json](assets/seed/addis_seed.json). The sign-in screen shows one-tap demo accounts (no Google sign-in needed). Chapa payments are simulated, and booking notifications appear only in the in-app inbox (no push or SMS). The GitHub Pages build is a demo build. Never ship a production build with `DEMO_MODE`.

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

Besides shops, users and bookings, the seed has booking policies on every shop, one time-off entry, a walk-in queue for `shop_1` with its summary, and 13 reviews whose averages match the shops' and barbers' `rating` fields. `shop_2` requires barber acceptance and has a pending request (`book_21`); `shop_1`'s barbers have commissions (60, 50, 40) and two payouts this month; and `user_cust_2` has a pending shop application. Payouts and the application are written in users mode only. Report stats are not seeded: the `insights` trigger builds them when the Functions emulator runs during seeding, or the admin calls `rebuildShopStats` afterwards.

On a real project use `--invites`: it writes no fake accounts or bookings. Invites are keyed by email (`invites/{email}`), and the dataset's emails are `@example.com` placeholders, so put the real people's Google addresses in the JSON first. The plans can also be created from the admin app (Subscriptions > Plans > Create default plans), which calls the `seedDefaultPlans` function.

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
   - **Authentication > Get started** (first time only), then **Sign-in method > Add new provider > Google**: turn it on, choose the project support email, and save.
   - **Authentication > Settings > Authorized domains:** `localhost` and the project's `<project>.firebaseapp.com` / `<project>.web.app` domains are there by default. Add any other domain the web app is served from (for example `<user>.github.io` or your Firebase Hosting custom domain), or Google sign-in fails there with `auth/unauthorized-domain`.
   - **Firestore Database:** create the database (choose a region near Ethiopia, such as `europe-west`).

4. Android Google sign-in needs your app's signing fingerprints (debug, release and, if you publish through Google Play, the Play app signing key). Get them with `cd android && ./gradlew signingReport`, then add each SHA-1 (and SHA-256) either in the console under **Project settings > Your apps > Android > Add fingerprint**, or with the CLI:

   ```sh
   firebase apps:list ANDROID                                   # find the Android app id
   firebase apps:android:sha:create <android-app-id> <SHA-1>
   ```

   Then download the updated `google-services.json` again (or rerun `flutterfire configure`) so it contains the OAuth client.

5. Deploy the security rules:

   ```sh
   firebase use <your-project-id>
   firebase deploy --only firestore:rules
   ```

6. Create the first admin. In the Firestore console, add a document to the `invites` collection:
   - Document ID: the admin's Google email in lowercase, for example `someone@gmail.com`
   - Fields: `email` (the same lowercased address), `role` = `admin`, `name`, `createdBy` = `console`, `createdAt` = an ISO date string such as `2026-11-13T00:00:00Z`

   Then sign in with that Google account in the app (it asks for a contact phone on first sign-in). From there the admin registers shops and invites owners by their Google email, and owners invite their barbers the same way.

## Cloud Functions

There are six codebases (TypeScript, Node 20, region `europe-west1`), all listed in [firebase.json](firebase.json) and built and tested in CI:

| Codebase | Functions |
|---|---|
| `functions/notifications` | `onBookingWritten` (push, inbox and SMS on booking and booking-payment changes; `rescheduled` goes to customer, barber and owner with an SMS to the customer and clears reminders already sent so the new time gets its own; `noShow` goes to the customer only, without SMS; barber acceptance sends `accepted`, `requestDeclined` and `requestExpired` to the customer, and staff also hear about expiries), `onShopApplicationWritten` (inbox entry and push to the applicant when their shop application is approved or rejected), `onPaymentWritten` (failed booking payments, subscription paid or failed), `sendBookingReminders` (every 15 minutes) |
| `functions/payments` | Callables `createBookingPayment`, `createSubscriptionPayment`, `verifyPayment`, `setShopSubscription`, `seedDefaultPlans`, `resolvePaymentReview` (admin only); HTTPS `chapaWebhook`; scheduled `dailySubscriptionCheck` (03:00 Addis time) |
| `functions/bookings` | `verifyBookingLocks` (on booking create: checks a slot lock exists for every 15-minute block and cancels the booking with `cancelledBy: 'system'`, `cancelReason: 'slot_conflict'` if one is missing or taken), `verifyRescheduledBookingLocks` (on booking update when the time changed: the same check for the new interval; time-off locks count as taken), `cleanupExpiredSlotLocks` (daily 04:00 Addis: deletes slot locks whose `expiresAt` has passed, booking and time-off locks alike), `expirePendingBookings` (every 15 minutes: cancels booking requests still `pending` within 60 minutes of their start with `cancelledBy: 'system'`, `cancelReason: 'not_accepted'`, and deletes their slot locks in the same transaction; uses the `bookings (status, startAt)` index) |
| `functions/queue` | `onQueueEntryWritten` (recomputes `barbershops/{s}/queueSummary/current` in a transaction, sets a customer's duplicate remote entries to `left`, and sends a `queueNext` inbox entry and push, once, to a remote customer who reaches the front) |
| `functions/auth` | Callables `requestEmailCode`, `verifyEmailCode`, `completeEmailRegistration`, `resetPasswordWithCode` (email + password accounts verified by an emailed 6-digit code, see [Email registration codes](#email-registration-codes)); scheduled `cleanupEmailCodes` (daily 04:30 Addis: deletes expired codes and send counters); Firestore trigger `onInviteCreated` (emails a new invite its sign-up steps, see [Invitation emails](#invitation-emails)) |
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

   The `auth` codebase needs the SMTP secrets too; see [Email registration codes](#email-registration-codes).

4. Deploy. The first deploy of `payments` asks for `PAYMENT_RETURN_URL`, the page Chapa sends the customer back to. Use the web app's root URL, for example `https://<host>/`: the app reads `?paymentId=` from it and verifies the payment. `CHAPA_CALLBACK_URL` is optional and defaults to the `chapaWebhook` URL.

   ```sh
   firebase deploy --only firestore:rules,firestore:indexes
   firebase deploy --only functions              # all six codebases
   firebase deploy --only functions:payments     # or just one
   firebase deploy --only functions:bookings
   firebase deploy --only functions:queue
   firebase deploy --only functions:insights
   firebase deploy --only functions:auth
   ```

   Deploy `firestore:indexes` first: the bounded booking listeners need the bookings `startAt` composite indexes, the lock cleanup needs the collection-group index on `slotLocks.expiresAt`, the queue needs `queue (status, createdAt)` and `queue (addedBy, createdAt desc)`, barber review lists need `reviews (barberId, createdAt desc)` and `reviews (barberId, rating)`, and `aggregateBookingStats` needs `bookings (shopId, customerId, status, startAt desc)`. Index builds can take a few minutes; queries fail until they finish.

   When updating an existing project for shop applications, barber acceptance and payouts, deploy `firestore:rules` (new `shopApplications` and `payouts` rules, the booking accept/decline branches, `requireBarberAcceptance` and `commissionPercent`) together with `functions:notifications` (`onShopApplicationWritten` and the new booking events) and `functions:bookings` (`expirePendingBookings`, which needs Cloud Scheduler) and `functions:payments` (refuses online payment of a pending booking). No new indexes are needed.

   If the project already has bookings when `insights` is first deployed, sign in as the admin and call `rebuildShopStats` once per shop (`{ "shopId": "..." }`) so the reports include the older bookings.

5. In the Chapa dashboard, set the webhook URL to `https://europe-west1-<project-id>.cloudfunctions.net/chapaWebhook`, with the same secret as `CHAPA_WEBHOOK_SECRET`.
6. Create the subscription plans: as admin, open Subscriptions > Plans > Create default plans, or run the seed script. The defaults are Basic at 500 ETB a month for up to 3 barbers, Pro at 1,200 ETB a month with unlimited barbers, and a 30-day free trial for every new shop.

### Email registration codes

Besides Google, people can create an account with an email address and a password. The address is confirmed with a 6-digit code sent by email, and the same kind of code resets a forgotten password. `functions/auth` does the server side; the app calls its four callables.

**Setup (once per project):**

1. Firebase console > **Authentication > Sign-in method > Add new provider > Email/Password**: turn on **Email/Password** (leave "Email link" off) and save.
2. Get SMTP credentials from one of:
   - **Gmail:** turn on 2-Step Verification for the sending Google account, then create an app password at <https://myaccount.google.com/apppasswords>. Host `smtp.gmail.com`, port `465`, user = the Gmail address, password = the 16-character app password. Gmail allows about 500 messages a day.
   - **Brevo:** Settings > SMTP & API > SMTP: host `smtp-relay.brevo.com`, port `587`, user = the SMTP login shown there, password = an SMTP key. Verify the sender address or domain first.
   - **Resend:** host `smtp.resend.com`, port `465`, user `resend`, password = an API key, with a verified domain.
3. Set the secrets (each command prompts for the value):

   ```sh
   firebase functions:secrets:set SMTP_HOST    # e.g. smtp.gmail.com
   firebase functions:secrets:set SMTP_PORT    # 465 (TLS) or 587 (STARTTLS)
   firebase functions:secrets:set SMTP_USER
   firebase functions:secrets:set SMTP_PASS    # app password / SMTP key
   firebase functions:secrets:set MAIL_FROM    # e.g. "Crown & Blade <you@gmail.com>"
   ```

4. Deploy (the project must be on the **Blaze** plan): `firebase deploy --only functions:auth`, and `firebase deploy --only firestore:rules` if the rules changed.

If a secret is empty, `requestEmailCode` fails with `email-not-configured` and logs which secrets are missing. To change a secret later, set it again and redeploy `functions:auth`.

**Flow:**

The app asks for the email, then the code, and only asks for a password once the code has been accepted:

1. `requestEmailCode({email, purpose: 'register' | 'reset', language})` → `{ok, resendAfterSeconds: 60, expiresInSeconds: 600}` emails the code.
2. `verifyEmailCode({email, code, purpose})` → `{ok, verificationToken, expiresInSeconds: 900}` checks the code without using it up. A wrong code counts as a try, exactly as before. For `register` it also refuses an email that already has an account (`email-already-registered`). If the person goes back and enters the same code again within the window, they get a new token, the previous token stops working and the 15 minutes start again.
3. The password step sends the token instead of the code:
   - **Register:** `completeEmailRegistration({email, verificationToken, password, name?})` creates the Firebase Auth user with a verified email. The app then signs in with `signInWithEmailAndPassword` and runs the usual first sign-in profile setup (name, contact phone, invite), which creates `users/{uid}`; the function never writes `users/*`.
   - **Forgot password:** `resetPasswordWithCode({email, verificationToken, newPassword})` sets the password and signs the account out everywhere else (refresh tokens revoked).

   A token works once, for that email and purpose, within 15 minutes of verifying. A missing, wrong, used or expired token gives `verification-expired`: the app goes back to the email step. The password is checked first (`weak-password`) and a weak one does not use up the token.

The original one-step calls, `completeEmailRegistration({email, code, password, name?})` and `resetPasswordWithCode({email, code, newPassword})`, still work. Send either `code` or `verificationToken`, not both (`invalid-input`).

- A reset gets the same answers whether or not the account exists, up to the last step: the request succeeds, and a correct code is verified and returns a token. A code is only emailed to accounts that have a password (a Google-only account gets nothing and keeps signing in with Google). Only `resetPasswordWithCode` fails for an unknown account (`verification-expired`, or `invalid-code` on the code path).
- The email is in the language the app is set to, followed by the other one (English and Amharic).
- Errors come back as `HttpsError` with `details.code`: `invalid-email`, `invalid-input`, `email-already-registered`, `too-soon` (with `details.retryAfterSeconds`), `rate-limited`, `invalid-code` (with `details.attemptsLeft`), `code-expired`, `verification-expired` (status `deadline-exceeded`: start again), `weak-password`, `email-not-configured`, `email-send-failed`, `internal`.

**Limits:**

- A code is 6 random digits, valid for 10 minutes and usable once. Only a salted SHA-256 hash is stored, in `emailCodes/{purpose}_{sha256(email)}`; a new code replaces the previous one. Register and reset codes are separate.
- Verifying keeps that document and adds `verifiedAt`, the SHA-256 of the verification token (32 random bytes, base64url) and a new `expiresAt` 15 minutes later. Finishing the flow deletes the document, so neither the code nor the token can be used again.
- 5 wrong tries and the code is deleted (`code-expired`); the person asks for a new one.
- One code per email and purpose every 60 seconds, at most 5 codes per email per day and 20 per IP address per hour (counters in `authRateLimits`, keyed by hashes).
- Passwords: 8 to 128 characters with at least one letter and one digit.
- `emailCodes` and `authRateLimits` are closed to clients in the rules; `cleanupEmailCodes` deletes expired documents daily.
- App Check is not enforced on these callables yet.

### Invitation emails

When an invite is created (`invites/{email}`: the owner adds a barber, or the admin invites an owner or admin), `onInviteCreated` in `functions/auth` emails the invited address how to sign up. It uses the same SMTP secrets as the codes, so no extra setup is needed.

- **Barber:** "{inviter's name, or the shop name} added you as a barber at {shop name} on Crown & Blade. Install or open the app, tap Register, enter this email ({email}), type the 6-digit code we send you and create your password. Then you'll see your bookings."
- **Shop owner:** the same steps, as "the owner of {shop name}", ending with managing the shop, barbers and bookings.
- **Admin:** a short version of the same steps.
- The shop name comes from `barbershops/{shopId}.name` (a generic "a barbershop" when it is missing), the inviter's name and language from `users/{createdBy}`. The email has both languages: Amharic first, unless the inviter's app language is English.
- The email holds no codes, links or tokens; the 6-digit code comes later from `requestEmailCode` when the person taps Register.
- One email per invite: before sending, the function creates `inviteEmails/{email}_{createdAt}` (status `sending`, then `sent`). A retried or duplicate event finds it and sends nothing; if sending fails, the marker is deleted so a retry can send it. `inviteEmails` is closed to clients in the rules.
- Replacing an existing invite (an update) sends nothing; deleting it and inviting again does.
- If the SMTP secrets are not set, the trigger logs which ones are missing and sends nothing.

### Push notifications

- **Android:** works after `flutterfire configure`. The app creates the `bookings` notification channel.
- **iOS:** upload an APNs key under Firebase console > Project settings > Cloud Messaging, and turn on the Push Notifications and Background Modes (remote notifications) capabilities in Xcode.
- **Web:** fill in the `firebaseConfig` placeholders in `web/firebase-messaging-sw.js`, and build with `--dart-define=FCM_VAPID_KEY=<key>` (Firebase console > Cloud Messaging > Web Push certificates). Without the key, web users still get the in-app inbox.

## What still needs real-world setup

- SMTP credentials for the email codes (Gmail app password, Brevo or Resend) and the Email/Password provider turned on (see [Email registration codes](#email-registration-codes)).
- A Firebase project (`flutterfire configure`), the Google sign-in provider enabled (with the Android SHA-1 fingerprints and the web domains authorized), and the first admin invite (see above).
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
- Booking acceptance: any `pending` booking is treated as an open request, whatever the shop's current setting (the older seed booking `book_6` included). Accepting is allowed by the rules until the start time; the 60-minute cut-off is enforced by the app and by `expirePendingBookings`. In demo mode there is no auto-expiry (expired requests just stop being listed), and the local notification copy for an accept or decline uses the plain confirmed/cancelled texts.
- Payouts: payout `createdAt` comes from the client clock (the rules cap it at one hour in the future). Balances do not carry over between months, and owner reports do not include payout totals (the Payouts screen has them).
- Shop applications: approving creates the shop with an empty `ownerId` and a starter set of two services and a lead barber, which the new owner then edits.
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
cd functions/auth && npm install && npm run build && npm test
cd tool/seed && npm install && npm test          # seed script
```
