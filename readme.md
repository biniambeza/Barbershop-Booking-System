# Crown & Blade

Multi-tenant barbershop booking platform for Addis Ababa, built with Flutter and Firebase.

| Role | Can do |
|---|---|
| Admin | Manage shops (search and filter, edit profile, verification and subscription, suspend with a reason, reactivate, delete), register shops and invite their owners, review shop applications (approve creates the shop and the owner invite, reject with a reason), manage users (search, change a role, disable or enable an account), approve or reject subscription receipts and set subscription prices, resolve payments flagged for review. The admin does not see customers' bookings. Opening hours (`openingHour`, `closingHour`, `workingDays`) are owner-only: the admin sees them read-only, new shops start at 09:00-20:00 every day, and the rules refuse an admin update that changes them |
| Shop owner | Manage one shop: profile (address, nearby landmark, map pin), hours, services, barbers (creates a login with a temporary password, or invites them by email), all of the shop's bookings, pay the subscription by telebirr or CBE transfer and submit the receipt. Set the booking policy (cancellation cutoff, reschedule limit, whether barbers must accept each booking), answer booking requests for any barber, mark no-shows, add or remove any of the shop's barbers' time off, run the walk-in queue, reply to reviews, see monthly reports, earnings totals for any period, the client list, busiest hours and each customer's no-show rate, block or unblock a customer (optionally automatically after N no-shows), set each barber's commission and record payouts (unpaid shares carry over), see refunds due and mark them refunded |
| Barber | See and run their own appointment queue, accept or decline booking requests, finish a booking early (the next customers are told they can come in), set availability, add or remove their own time off (one day or a vacation from one date to another), mark no-shows, run the walk-in queue, see earnings for any period, their share, payouts and balance owed, and their own reviews |
| Customer | Find shops and barbers (landmark, map pin and Directions on the shop page, "Near me" sorts by distance), book, reschedule and cancel (within the shop's policy), keep favorite shops and barbers, book again with a past or favorite barber in one tap, join a shop's walk-in queue from the app, rate completed visits and edit or delete their review, call their barber from a confirmed booking, get a refund flagged when a paid booking is cancelled, get "your barber is free now" notices, apply to list their own barbershop |

## Architecture

| Layer | Where | What it does |
|---|---|---|
| Flutter app | `lib/` | One app for all four roles. Screens read synchronous getters on `AppRepository` inside `ListenableBuilder`s. |
| Repository | `lib/services/app_repository.dart` | `ChangeNotifier` singleton. Reads come from an in-memory `DataCache`; writes go through a `DataStore`. |
| Data stores | `lib/services/data_store.dart`, `firestore_data_store.dart` | `FirestoreDataStore` (production) opens role-scoped snapshot listeners after sign-in and writes to Firestore. `LocalDataStore` (demo mode and tests) keeps everything in memory. Customer, owner and barber booking listeners load every upcoming booking plus the last 90 days of history (newest 200 for customers, 1000 for staff). |
| Time slots | `lib/services/availability_service.dart` | Builds bookable slots on a 15-minute grid in Addis time (UTC+3) from shop and barber hours, service length and existing bookings. A booking is written in one transaction together with a slot lock per 15-minute block (`barbershops/{shop}/barbers/{barber}/slotLocks/{yyyyMMdd-HHmm}`), so two customers can never take the same block. Each lock holds only `bookingId`, `startAt` and `expiresAt` (booking end + 1 day), no customer data. The rules check the first four locks and the last one; `verifyBookingLocks` checks all of them. Services are limited to 120 minutes (8 locks) to stay inside Firestore's per-request rule limits. Barber time off (`barbers/{b}/timeOff/{id}`) is written in one batch with a lock per block shaped `{timeOffId, startAt, expiresAt}`, so availability, bookings and the lock checks all treat it as taken. |
| Booking policy | `lib/services/booking_policy.dart`, `time_off_service.dart` | Cutoff, reschedule limit, no-show timing and time-off validation as pure functions shared by the screens, the repository and the tests. See [Booking policies](#booking-policies). |
| Walk-in queue | `lib/services/queue_service.dart`, `lib/features/queue/`, `functions/queue` | Staff add walk-ins and call the next person; signed-in customers can join from the shop page. `onQueueEntryWritten` keeps the public `queueSummary/current` (waiting count, estimated wait, each waiting entry's place) up to date and tells a remote customer when they are next. The wait formula (`queue_wait.dart` / `estimate.ts`) is the same in Dart and TypeScript. |
| Reviews | `lib/services/reviews_service.dart`, `lib/features/reviews/` | Customers rate a completed booking once (1-5 stars, optional comment); the owner can reply. The review and the barber's `ratingSum`/`reviewCount` are written in one batch by the customer's app (the rules check the increment), so ratings work on the free plan. A barber's rating is `ratingSum / reviewCount`; a shop's rating is the average of its rated barbers' averages ("New" when none), computed in the app (`lib/services/rating_service.dart`). A customer can edit (stars, comment; marked "edited") or delete their own review: one transaction re-reads the stored review and changes the barber's `ratingSum` by new minus old stars (edit) or takes its stars and 1 off `reviewCount` (delete), so the counters stay exact; after a delete the visit can be rated again. The customer's app also writes the owner's "new review" inbox entry in the review's transaction. |
| Reports | `lib/services/reports_service.dart`, `lib/features/reports/`, `functions/insights` | Owner reports: monthly totals, revenue in Birr, top services, barber performance and a client list, read from the `stats` and `clients` documents that `functions/insights` maintains. |
| Notifications | `lib/services/notification_service.dart`, `functions/notifications` | Cloud Functions send push (FCM), an in-app inbox entry (`users/{uid}/notifications`) and SMS (AfroMessage) on booking changes, payment results (paid, refunded, failed, subscription paid or failed) and slots lost to a conflict, plus 24h and 2h reminders. The app registers FCM tokens and shows the inbox. |
| Payments | `lib/services/payment_service.dart`, `functions/payments` | Chapa checkout for bookings and monthly shop subscriptions (trial, Basic, Pro). Callables create the checkout; a signed webhook and `verifyPayment` confirm it; a daily job moves overdue shops to past due and then suspended. Payments that need a person (paid for a cancelled booking, paid twice) are flagged `needsReview` and listed on the admin's **Payments to review** screen, where the admin records a Chapa refund or "no action needed" (`resolvePaymentReview`). |
| Shop applications | `lib/features/applications/`, `lib/models/shop_application.dart`, `functions/notifications/src/applications.ts` | A customer applies to list their barbershop (`shopApplications/{uid}`), can edit or withdraw it while pending and apply again after a rejection. The admin's **Shop applications** screen approves it (one batch: the shop, two starter services, a lead barber, the owner invite and the application update) or rejects it with a reason. The applicant becomes the owner without signing out (`applyPendingInviteForCurrentUser`). `onShopApplicationWritten` sends them an inbox entry and push in their language. |
| Barber acceptance | `lib/services/booking_acceptance.dart`, `lib/features/barber/widgets/booking_requests_section.dart`, `functions/bookings` | When a shop sets `requireBarberAcceptance`, new bookings start `pending` and appear under **New requests** for the barber and the owner. See [Booking policies](#booking-policies). |
| Commission and payouts | `lib/services/payout_service.dart`, `lib/models/payout.dart`, `lib/features/payouts/` | Each barber has a commission (`commissionPercent`, 0-100, default 50). The barber's share of a completed booking is its price times the commission, rounded to whole Birr. The owner's **Payouts** screen shows each barber's monthly share, what was paid and the balance owed, and records payouts (cash, telebirr, bank or other). A payout can be deleted within 24 hours. The barber dashboard shows the barber's share, payouts and balance. Balances are per calendar month in Addis time, and what is left unpaid carries over: each month shows "carried over" (shares of completed bookings from November 2026 up to that month, minus payouts for that time) and a balance that becomes next month's carried-over amount. Nothing is stored for this; it is computed from bookings and payouts (`lib/services/payout_carryover.dart`). |
| Earnings for any period | `lib/services/earnings_period.dart`, `lib/features/payouts/earnings_cards.dart` | Barbers (**Your earnings** card) and owners (**Totals** tab of the reports) pick this month, last month, any of the last 24 months, this year or all time. With Firebase the figures come from Firestore aggregate queries (`count()` and `sum('price')` over completed bookings by shop, barber and `startAt`), so they are not limited to the 90 days of bookings the app keeps; in demo mode and tests they are computed from the cached bookings. Works on Spark. |
| Owner analytics and customer blocks | `lib/services/busy_hours.dart`, `customer_insights.dart`, `customer_blocks.dart`, `owner_insights_service.dart`, `lib/features/reports/widgets/` | Two more tabs in the owner reports. **Busy hours**: a weekday x hour heatmap (Addis time) of the shop's bookings for the last 30 or 90 days or a chosen month, with busiest day, busiest time and quietest hour (within opening hours). A booking counts in the hour it starts; cancelled ones are left out. The last 30/90 days come from the loaded bookings; a month older than 90 days is read with one `bookings where shopId, startAt in month` query (at most 3000 docs). **No-shows**: the shop's customers with bookings, completed, cancelled, no-shows and no-show rate (no-shows / (completed + no-shows)), highest rate first, searchable by name, with only the name and phone the owner already sees on bookings. On Spark the counts cover the last 90 days; on Blaze they are merged with the all-time `clients` docs. **Blocking**: the owner blocks or unblocks a customer with an optional note (`barbershops/{shop}/blockedCustomers/{customerUid}`: `customerId`, `customerName`, `source` owner/auto, `blockedBy`, `blockedAt`, optional `reason`, `noShowCount`). A blocked customer cannot book or join the queue there and sees "This shop can't take your booking right now. Please contact the shop." Their upcoming bookings stay unless the owner ticks "Also cancel" (normal owner cancel, so paid ones are flagged for a refund). Optional auto-block (`barbershops/{shop}/settings/customerBlocks.autoBlockNoShows`, off by default, 3 when switched on, 1-10): the app that marks a no-show blocks the customer once they reach N no-shows at the shop (the owner's app counts all the shop's bookings with an aggregate query; a barber's app counts the bookings it can see). Unblocking deletes the block; only a new no-show can block again. Works on Spark once the rules are deployed. |
| Admin payments dashboard | `lib/features/admin/screens/admin_payments_tab.dart`, `lib/services/admin_payments_summary.dart` | The **Payments** tab shows this month's subscription income (verified receipts, Addis calendar month), receipts waiting for review, verified and rejected counts, shops by subscription status (active, trial, past due, suspended), shops whose subscription ends within 7 days, the subscription types on sale (lengths and prices, with a warning while the telebirr/CBE receivers are placeholders) and the latest payments. Its cards open the existing screens: receipt review (approve/reject), subscription types and prices (add, remove or change tiers and where owners pay), each shop's plan and end date, and online (Chapa) payments to resolve. |
| Admin shop management | `lib/features/admin/screens/admin_shops_screen.dart`, `admin_shop_edit_screen.dart`, `lib/services/admin_shops_logic.dart` | The admin dashboard has three tabs, **Shops**, **Payments** and **Users**; there is no admin bookings list and the admin's app loads no bookings. The Shops tab has totals (all, bookable, suspended, barbers), search by name, sub-city or address, and filters (active, suspended, verified, unverified). The edit screen changes the profile, verification and the subscription plan, status and end date (one Firestore update). **Suspend** needs a reason (1-300 characters) and sets `adminSuspended`, `adminSuspendedReason`, `adminSuspendedAt` and `adminSuspendedBy`, separate from `subscriptionStatus`; **reactivate** sets `adminSuspended: false` and deletes the other three. A suspended shop is hidden from customer lists, search, favourites and the barber finder, its page says "Temporarily unavailable", and booking, reschedule and remote queue joins are refused (by the app and the rules). Existing bookings stay, and the owner sees a red banner with the reason. **Delete** needs the shop's exact name typed in, shows what will happen (counts of upcoming bookings, staff, barbers, services and invites) and then runs the clean-up in five steps (see [Security](#security)); past bookings are kept as history. |
| Admin user management | `lib/features/admin/screens/admin_users_tab.dart`, `admin_user_edit_screen.dart`, `lib/services/admin_users.dart`, `admin_user_writes.dart` | The **Users** tab searches by name, email or phone (any spelling), filters by role or disabled, and masks phones and emails in the list. **Edit user** changes the role (customer, owner of a shop, barber of a shop linked to a free or new barber profile, admin) in one batch with every side effect listed first (shop `ownerId`, other owners, pending invites). **Disable** sets `disabled`, `disabledAt`, `disabledBy` and an optional reason: the app signs that person out at once and refuses sign-in, the rules refuse their new bookings, reviews, queue joins and applications, and the admin can cancel a disabled barber's upcoming bookings (`cancelReason: 'account_disabled'`, customers notified, paid ones refund-flagged). On Blaze `onUserDisabledChanged` (`functions/auth`) also disables the Firebase Auth login. |
| Barber accounts | `lib/services/staff_account_service.dart`, `lib/features/shop_owner/widgets/add_barber_sheet.dart`, `lib/features/auth/screens/force_password_change_screen.dart` | See [How sign-in and roles work](#how-sign-in-and-roles-work). Works on the free plan: the owner's app creates the barber's Firebase Auth login in a second Firebase app instance, so the owner stays signed in. |
| Favorite barbers and rebook | `lib/services/rebook_service.dart`, `favorite_barbers_store.dart`, `lib/features/customer/widgets/rebook_widgets.dart` | Customers heart a barber on the shop page, in the booking flow, in Find Barbers or on a completed booking. Favorites are kept on the device per account (shared_preferences key `favoriteBarbers.<uid>`, no Firestore, so no rules and it works on Spark). The customer home shows **Your barbers**: favorites first, then the barbers of completed bookings from the last 180 days (at most 8), each with **Book again with &lt;first name&gt;**; completed booking cards have **Book again**. One tap opens the booking flow with that shop, barber and the last service, scrolled to date and time, with the barber's next free slot (from the availability service, searching day by day through the 30-day window) already selected. If the shop is gone or suspended, the barber left or is not taking bookings, or the service is gone, a dialog explains it and offers the shop page, another service or removing the favorite. |
| Early finish | `lib/services/early_finish_service.dart`, `lib/features/customer/widgets/early_finish_banner.dart`, `functions/notifications/src/earlyFinish.ts` | Completing a booking stores `completedAt`. If the barber (or the owner) finishes before the booking's scheduled end, the barber's next confirmed customers later that Addis day (at most 5, soonest first) get an inbox entry: the first `barberFreeEarly` ("Your barber is free now"), the rest `runningEarly`, with the minutes early (rounded down to 5, at most 240). The staff app writes these entries itself in one batch (`users/{uid}/notifications/{bookingId}_early_{sourceBookingId}`), so it works on the free plan; a failed write never fails the finish. The next customer's booking card shows a green banner for 60 minutes with Call shop and Directions. On Blaze, `onBookingCompletedEarly` writes the same entries (or refreshes their text in the customer's language) and sends one push each. |
| Subscription receipts | `lib/features/payments/receipts/`, `lib/services/subscription_pricing.dart`, `lib/models/subscription_payment.dart`, `functions/payments/src/receipts/` | Owners pay by telebirr or CBE transfer (or "other") and submit the transaction number, the amount and optionally a photo of the receipt (compressed to a JPEG stored as base64 in the document, at most 350,000 characters; on Blaze the admin can switch photos to Cloud Storage, see [Security](#security)). The receipt is `subscriptionPayments/{method}_{transactionId}`, so a transaction number can be used only once on the whole platform. Prices are tiers in `platformConfig/subscriptionPricing` (default 500 ETB = 30 days, 1,400 = 90, 2,700 = 180, 5,000 = 365); a payment buys the longest tier its amount covers. The admin edits the tiers, the telebirr number and CBE account owners pay to, and the receipt link templates. **Free plan:** the admin's **Subscription receipts** screen lists open receipts with the photo and the official receipt link, and approves (one batch: receipt `verified`, shop `active` with `subscriptionEndsAt` extended from the later of now and the current end, `subscriptionReceiptId`, and an inbox entry for the owner) or rejects with a reason. An admin suspension is not lifted by a payment. **Blaze:** `verifyReceipt` checks each new receipt against the official telebirr page or CBE PDF and approves it automatically when the reference, receiver, amount and date match; anything it cannot confirm goes to `needs_review` for the admin. |
| Refunds | `lib/services/refunds.dart`, `refund_writes.dart`, `lib/models/refund_model.dart`, `lib/features/refunds/`, `functions/bookings/src/logic/refund.ts` | Every cancel of a paid booking (customer, barber, owner, admin, declined or expired request, vacation, shop deletion, disabled account) calls `flagRefundIfPaid` in the same write: the booking gets `refundStatus: 'due'`, `refundAmount`, `refundReason`, `refundFlaggedAt`, and the customer a `{bookingId}_refundDue` inbox entry. Full price when the shop's side cancels or the customer cancels before the cutoff, 50% for a customer cancel after the cutoff (only through staff or a server path), nothing for a no-show. The owner (own shop) and the admin (all shops) see **Refunds due** and **Mark refunded** (method, optional reference), which sets `refundStatus: 'refunded'`, `paymentStatus: 'refunded'` and notifies the customer. The money itself is sent by hand. Works on Spark; on Blaze `flagRefundOnCancel` flags any paid cancel the app missed. |
| Vacation (time off ranges) | `lib/services/vacation_service.dart`, `lib/features/barber/screens/barber_schedule_screen.dart` | Barbers and owners block time off from one date to another (inclusive, at most 90 days, starting today or later; optional later start on the first day and earlier end on the last). Each working day is saved as an ordinary time-off record with its own slot locks, in its own batch, sharing `groupId`, `groupFrom` and `groupTo`. Upcoming bookings in the range are listed first (paid ones marked) and can be cancelled with a notice to each customer. Works on Spark. |
| Shop maps | `lib/services/shop_maps.dart`, `device_location.dart`, `lib/features/shared/widgets/shop_map.dart`, `lib/features/customer/widgets/shop_location_block.dart` | A shop has an optional **map pin** (`latitude`, `longitude`: numbers, both or neither) next to its address, sub-city and **nearby landmark** (e.g. "Near Edna Mall"). The owner (Customize shop) and the admin (register / edit shop) set it by tapping the map or with **Use my current location** (geolocator; asked only when tapped; a denied or blocked permission shows a message and the map still works). Customers see the landmark first and big on the shop page, then the address, a small map with the pin and **Directions**, which opens `https://www.google.com/maps/dir/?api=1&destination=lat,lng` (the Google Maps app when installed), falls back to a `geo:` link for the default maps app, and without a pin searches for landmark + address. Shop cards show the landmark too, and **Near me** sorts the list by distance when location is allowed. Maps are OpenStreetMap tiles through `flutter_map`: no API key and no billing; the tile requests send `et.crownblade.app` as User-Agent and every map shows "© OpenStreetMap contributors", as the OSM tile policy asks. Works on Spark and on the web. |
| Barber portfolio | `lib/models/portfolio_photo.dart`, `lib/features/portfolio/` | Each barber shows up to 12 haircut photos with an optional style name (up to 40 characters, e.g. "Low fade"). The barber (their own) and the shop owner (any of the shop's barbers) add them from the camera or the gallery (**My portfolio** on the barber dashboard, **Portfolio photos** under each barber in Manage Barbers), rename and delete them. Photos are compressed to a JPEG of at most ~150 KB and 1280 px (the receipt-photo pipeline) and stored one per document at `barbershops/{shop}/barbers/{barber}/portfolio/{p01..p12}` (`caption?`, `image` base64 or `imagePath`, `createdAt`; no personal data, public read). The slot ids cap the count at 12. When the admin's Storage switch (`platformConfig/subscriptionPricing.storageReceipts`) is on and the upload works, the JPEG goes to `portfolio/{shop}/{barber}/{photoId}.jpg` in Cloud Storage and only `imagePath` is saved; otherwise it stays inline (works on Spark). Customers see **See their work** on the shop page (only a `count()` per barber is fetched there, no images) and **See (barber)'s work** in the booking flow; the gallery (3-column grid) loads that barber's photos once per session, and the full-screen viewer (swipe, pinch to zoom) has **Book this style with (barber)**, which starts the booking with that barber. |
| iOS | `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements`, [docs/ios-setup.md](docs/ios-setup.md), `.github/workflows/ios.yml` | Display name "Crown & Blade", English and Amharic, Google sign-in URL schemes, camera and photo-library texts, background push, push and App Attest entitlements. Not built yet (needs a Mac); see docs/ios-setup.md for signing, the APNs key and App Store review (Sign in with Apple is still missing). |
| Privacy policy and account deletion | `lib/features/legal/`, `lib/core/config/legal_links.dart`, `web/privacy.html`, `web/delete-account.html`, `lib/features/account/delete_account_screen.dart`, `lib/services/account_deletion.dart`, `account_deletion_writes.dart`, `account_auth_service.dart`, `lib/features/admin/screens/admin_removal_requests_screen.dart` | **Privacy policy** in the app menu and under the sign-in buttons: it opens `privacy.html` on the GitHub Pages site (English and Amharic), or the copy bundled in the app when no browser can open it. `web/privacy.html` and `web/delete-account.html` are copied into the web build, so the Pages deploy publishes them (Google Play's privacy policy and "delete account" URLs). The contact address `privacy@example.com` is a placeholder in `legal_links.dart` and both pages. **Delete account** (app menu): shows what will happen, the person types DELETE and signs in again (password or Google), then the app cancels their upcoming bookings (normal customer cancels, paid ones refund-flagged), sets their reviews to "Former customer" without the comment (stars and the owner's reply stay), sets their bookings to "Former customer" with no phone (except bookings with a refund still due or a paid booking still open), a barber's customer bookings are cancelled and their portfolio photos and barber profile removed, then their invite, application, inbox and device tokens, `users/{uid}` and the Firebase Auth login are deleted. A failed step can be retried from where it stopped. A shop owner cannot delete the account while the shop exists: they send a **shop removal request** (`shopRemovalRequests/{uid}`), the admin sees it under **Shop removal requests**, deletes the shop and marks it done; the last enabled admin cannot delete themselves. Works on Spark once the rules are deployed. On Spark, bookings inside the shop's cancellation cutoff stay with the shop (anonymised; a paid one keeps the phone for the refund). On Blaze, `functions/auth` `onUserProfileDeleted` (on `users/{uid}` delete) cancels them (`cancelReason: 'account_deleted'`, paid ones refund-flagged like a customer cancel), repeats the anonymising, and removes a deleted barber's time off, slot locks, portfolio photos and Storage copies. |
| Localization | `lib/l10n/` | English and Amharic (`app_en.arb`, `app_am.arb`). Prices in Birr, phones in +251 form, dates and times in Addis time. |
| Light and dark themes | `lib/core/theme/app_palette.dart`, `app_theme.dart`, `theme_controller.dart`, `lib/features/shared/widgets/theme_mode_toggle.dart` | Two palettes: **light** is white and green (`#16A34A` buttons, green hero cards), **dark** is black and green (`#0A0A0A` pages, `#151515` cards, `#22C55E` accents). `AppTheme.xxx` colours return the value for the current mode. The mode is **System default** (follows the phone's light / dark setting; the default), **Light** or **Dark**. Switch it with the sun / moon button on the sign-in, profile setup and forced password change screens (tap toggles light / dark, long-press offers System default) or **Dark mode** in every dashboard's app-bar menu. The choice is kept on the device (shared_preferences key `app_theme_mode`) and restored at start-up. `ThemeRebuilder` (under `MaterialApp.builder`) repaints every screen, including those deeper in the navigation stack, the moment the mode changes, keeps the navigation state, and sets readable status and navigation bar icons for the mode. Eye-check renders: `flutter test --tags screenshots --run-skipped test/theme_renders_test.dart` (writes `build/theme_renders/<screen>_<light\|dark>.png`). |
| Security | `firestore.rules`, `storage.rules` | Roles, shop ownership, booking validity (price, duration, slot locks), private barber phones, refunds, shop deletion, disabled accounts, and payment and subscription fields that only functions may write. Tested in `firestore-tests/`. See [Security](#security). |

Collections: `users`, `invites`, `shopApplications` (doc id = applicant uid), `shopRemovalRequests` (doc id = owner uid), `subscriptionPayments` (doc id = `{method}_{transactionId}`), `platformConfig/subscriptionPricing`, `barbershops` (with `services`, `barbers`, `barbers/*/slotLocks`, `barbers/*/timeOff`, `barbers/*/portfolio` (public haircut photos, slots p01-p12), `queue`, `queueSummary` (functions only), `reviews`, `blockedCustomers` (owner writes; a barber only creates auto-blocks; the customer gets their own), `settings/customerBlocks` (owner writes, staff read), `payouts` (owner writes; owner and admin read all, a barber reads their own), and `stats` and `clients` (functions only; owner and admin read) subcollections), `bookings`, `plans`, `payments`, `notificationLog`, `insightsApplied`, `emailCodes`, `authRateLimits` and `inviteEmails` (functions only), `users/{uid}/devices` and `users/{uid}/notifications`. All dates are stored as ISO-8601 UTC strings.

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
- **Time off:** the owner (for any barber of the shop) or the barber (their own) adds time off for a whole working day or an hour range on one Addis day. It cannot overlap a booking or other time off. A **vacation** (date range, up to 90 days) is saved as one such record per working day; bookings inside it can be cancelled in the same step (see Vacation above).
- **Refunds:** cancelling a paid booking flags a refund in the same write (see Refunds above). A no-show is not refunded.

## How sign-in and roles work

- People sign in with their Google account, or with an email address and password (Firebase Authentication, Google and Email/Password providers). An email account is only created after a 6-digit code sent to that address is entered, so its email is verified too (see [Email registration codes](#email-registration-codes)). There are no SMS codes. A person is identified by their verified sign-in email, lowercased, so invites work the same for both kinds of account.
- On first sign-in the person enters their name and a contact phone number (Ethiopian mobile, `+2519...` or `+2517...`) and gets a profile at `users/{uid}` holding `email` (taken from the Google account, cannot be changed later), `name` and `phone`. The phone is not verified; it is used for bookings, SMS reminders and Chapa, and the person can change it (and their name and language) in their profile.
- The role on that profile is enforced by [firestore.rules](firestore.rules). Nobody can choose their own role:
  - Without an invite, a new account is a **customer**.
  - The admin registers a shop with the owner's Google email. That creates an invite at `invites/{email}` (the lowercased address), and the owner gets the **shop owner** role when they sign in with that Google account.
  - A customer can also apply to list their own shop (customer home, or "I own a barbershop" on the profile setup screen). When the admin approves the application, the same owner invite is created for the applicant's email and applied at once, without signing out.
  - A shop owner adds a barber in one of two ways, both creating a **barber** invite for their own shop:
    - **Create a login (temporary password).** The owner enters the barber's name, email and phone, and the app generates a readable 10-character temporary password (it can be regenerated or copied). The app creates the Firebase Auth email/password account in a second Firebase app instance (the owner stays signed in), then saves the barber profile and `invites/{email}` with `authUid` (the new login's uid) and `mustChangePassword: true` in one batch; if that batch fails, the new login is deleted again. The final sheet shows the email and temporary password once, with copy buttons, for the owner to hand over. If the email already has an account, the app offers to send a normal invitation instead.
    - **Invite by email.** The barber registers or signs in with that email themselves.
  - Manage Barbers shows each barber as "Waiting for first login", "Invitation sent" or "Active".
  - An invite works for a verified email that matches it, or (owner-created logins only) for the unverified login whose uid is the invite's `authUid`. It upgrades an existing customer once and never changes an existing barber, owner or admin.
- **First login with a temporary password:** the barber signs in with the email and temporary password (the email does not need to be verified), confirms name and phone (prefilled from the barber profile), and the profile gets `mustChangePassword: true` from the invite. Before any dashboard the app shows **Choose your new password** (temporary password, new password, confirm; the new one must differ). Saving changes the Firebase Auth password and sets `mustChangePassword: false`; the rules let the user only clear that flag, never set it. A barber who loses the temporary password uses "Forgot password?" on the login screen: on the free plan the owner cannot reset another person's password.
- Removing a barber profile removes that barber's access (their Firebase Auth login remains; adding the same email again offers an invitation instead).

**Free plan fallback.** On the free Spark plan the `functions/auth` callables are not deployed. The first time `requestEmailCode` fails the way a missing function does (`not-found`, `unimplemented`, `internal` without a server code, or `unavailable` / a network-level failure while Firebase Auth itself answers), the app switches that flow to Firebase Authentication's own emails for the rest of the session (the 6-digit codes come back on the next app start once the functions are deployed). Register then asks for the email, then a password, creates the account with `createUserWithEmailAndPassword`, sends Firebase's verification link and signs out again: the person opens the link and then logs in (unverified addresses still cannot sign in, and the log in form offers "Resend verification link"). Forgot password sends Firebase's reset link (`sendPasswordResetEmail`, in English or Amharic) and never says whether the account exists. Both emails use the templates under **Authentication > Templates** in the Firebase console. Demo builds and tests keep the code flow unless `LocalEmailAuthService(functionsAvailable: false)` is used.

## Running the app

### Demo mode (no Firebase)

```sh
flutter run --dart-define=DEMO_MODE=true
```

Runs offline on the Addis Ababa demo dataset in [assets/seed/addis_seed.json](assets/seed/addis_seed.json). The sign-in screen shows one-tap demo accounts (no Google sign-in needed). Chapa payments are simulated, and booking notifications appear only in the in-app inbox (no push or SMS). The GitHub Pages website is the real app; a demo website is built only on request (see [Website and APK (GitHub Actions)](#website-and-apk-github-actions)). Never ship a production build with `DEMO_MODE`.

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

Besides shops, users and bookings, the seed has booking policies on every shop, one time-off entry, a walk-in queue for `shop_1` with its summary, and 13 reviews whose averages match the shops' and barbers' `rating` fields. `shop_2` requires barber acceptance and has a pending request (`book_21`); `shop_1`'s barbers have commissions (60, 50, 40) and two payouts this month; and `user_cust_2` has a pending shop application. `shop_4` (Sarbet Fade Studio) is suspended by the admin with a reason. `platformConfig/subscriptionPricing` holds the default tiers with placeholder receivers, and there are two subscription receipts: a verified CBE one for `shop_2` and a pending telebirr one for `shop_5`. Payouts, receipts and the application are written in users mode only. Report stats are not seeded: the `insights` trigger builds them when the Functions emulator runs during seeding, or the admin calls `rebuildShopStats` afterwards.

On a real project use `--invites`: it writes no fake accounts or bookings. Invites are keyed by email (`invites/{email}`), and the dataset's emails are `@example.com` placeholders, so put the real people's Google addresses in the JSON first. The plans can also be created from the admin app (Subscriptions > Plans > Create default plans), which calls the `seedDefaultPlans` function.

### Translations

Edit `lib/l10n/app_en.arb` and `lib/l10n/app_am.arb` (they have the same keys), then run `flutter gen-l10n`. The generated code goes to `lib/l10n/gen`.

### Brand assets

The Crown & Blade logo (a green crown with a jewel on each tip, standing on a brushed-steel straight-razor blade, with a faceted gem) is drawn in code in `lib/core/brand/crown_blade_logo.dart`. It has four colour variants (`CrownBladeVariant`): `onLight` (white pages), `onDark` (black pages), `onBrand` (white mark for the green app icon and green hero cards) and `monochrome`; `CrownBladeLogo.adaptive()` follows the theme. The start-up intro in `lib/features/splash/animated_splash.dart` plays once on a cold start, over the app as it builds: its first frame is exactly the native splash, then the logo breathes, the jewels twinkle, a glint runs along the blade and the wordmark is revealed, and the logo lifts away as the app fades in. Every image is generated from that code. After changing the logo, regenerate them in this order:

```bash
# 1. Logo PNGs: assets/brand/*.png, web/icons/logo-mark*.png and store/graphics/icon-512.png (previews go to build/brand_preview/)
flutter test --tags brand --run-skipped test/brand/generate_brand_assets_test.dart
# 2. Launcher icons: Android (adaptive + Android 13 themed), iOS and web/icons (flutter_launcher_icons.yaml)
dart run flutter_launcher_icons
# 3. Native launch screen, light and dark: Android (also Android 12+) and iOS (flutter_native_splash.yaml)
dart run flutter_native_splash:create
# 4. Optional: Play Store feature graphics, and frames of the intro (light and dark) for review (build/splash_frames/)
python store/tool/make_graphics.py
flutter test --tags brand --run-skipped test/animated_splash_test.dart
```

After steps 2 and 3, revert `ios/Runner.xcodeproj/project.pbxproj` (flutter_launcher_icons rewrites `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` by mistake) and `ios/Runner/Info.plist` (flutter_native_splash reindents it and adds `UIStatusBarHidden`): `git checkout -- ios/Runner.xcodeproj/project.pbxproj ios/Runner/Info.plist`. The app icon is the white mark on the brand green gradient (`#22C55E` to `#15803D`). The splash is the green mark on white (`#FFFFFF`), or on near-black (`#0A0A0A`) when the device is in dark mode. The native splash, the Android window background (`@color/splash_background` in `android/app/src/main/res/values/splash_colors.xml` and `values-night/`), the web loader in `web/index.html` (by `prefers-color-scheme`) and the intro all use these colours, so there is no flash at start-up. The `brand` tag is skipped in normal `flutter test` runs (`dart_test.yaml`).

## Firebase setup (one time)

1. Install the tools and sign in:

   ```sh
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   firebase login
   ```

2. Create a Firebase project at <https://console.firebase.google.com>, then connect the app. This replaces the placeholder `lib/firebase_options.dart` and adds the Android config. The app id is `et.crownblade.app` on both Android (`applicationId` and `namespace` in `android/app/build.gradle.kts`) and iOS (bundle id); it is the permanent Play Store id, so do not change it after the first release:

   ```sh
   flutterfire configure --project=<your-project-id> --platforms=android,ios,web \
     --android-package-name=et.crownblade.app --ios-bundle-id=et.crownblade.app --no-web-messaging-sw
   ```

   `--no-web-messaging-sw` keeps our own `web/firebase-messaging-sw.js`. On Windows FlutterFire does not write the iOS `GoogleService-Info.plist`; fetch it with `firebase apps:sdkconfig IOS <ios-app-id> --out ios/Runner/GoogleService-Info.plist` (it is already part of the Runner target). The full iPhone setup (Apple account, signing, push key, TestFlight, App Store review) is in [docs/ios-setup.md](docs/ios-setup.md).

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

## Website and APK (GitHub Actions)

`.github/workflows/deploy.yml` runs on every push to `main`. After the rules, functions and seed tests pass, it:

- **Website:** runs `flutter analyze` and `flutter test`, builds the **real app** (production Firebase project from `lib/firebase_options.dart`, no `DEMO_MODE`) with `--base-href "/<repo>/"`, and publishes it to the `gh-pages` branch: <https://biniambeza.github.io/Barbershop-Booking-System/>. Works on the free Spark plan (the Spark fallbacks above apply).
- **Android APK:** builds the production release APK and uploads it as a workflow artifact (Actions > the run > Artifacts). It is named `CrownAndBlade-production-release-signed` when the keystore secrets below are set, and `CrownAndBlade-production-UNSIGNED-debug-signed` otherwise. The debug-signed APK uses a throwaway CI key: fine for a quick install, not for Google Play, and Google sign-in fails on it because its SHA-1 is not registered in Firebase.

**Demo build:** Actions > *Build & Deploy Crown & Blade* > **Run workflow**, tick **demo**. That run builds the website and APK with `DEMO_MODE=true` (offline data, one-tap demo logins, OTP `123456`) and the demo **replaces** the website until the next push or normal run. Locally: `flutter build web --release --dart-define=DEMO_MODE=true`.

**Repository secrets** (GitHub > Settings > Secrets and variables > Actions; all optional):

| Secret | Used for |
| --- | --- |
| `RECAPTCHA_SITE_KEY` | The reCAPTCHA site key registered for the web app under Firebase console > App Check (passed as `--dart-define=RECAPTCHA_SITE_KEY`). Empty: web App Check is skipped. |
| `ANDROID_KEYSTORE_BASE64` | The release keystore (`android/app/upload-keystore.jks`) as base64: `base64 -w0 android/app/upload-keystore.jks` (macOS: `base64 -i ...`; PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("android\app\upload-keystore.jks"))`). |
| `ANDROID_KEY_ALIAS` | `keyAlias` from `android/key.properties` |
| `ANDROID_KEY_PASSWORD` | `keyPassword` from `android/key.properties` |
| `ANDROID_STORE_PASSWORD` | `storePassword` from `android/key.properties` |

The four Android secrets are used only when all four are set: the job then writes `android/key.properties` and the `.jks` for the build and deletes them afterwards. Without `key.properties`, `android/app/build.gradle.kts` signs the release with the debug key.

**Turn on GitHub Pages once:** GitHub > Settings > Pages > Source **Deploy from a branch**, branch `gh-pages`, folder `/ (root)`. The workflow only pushes to `gh-pages`; until Pages is on, the site answers 404.

**Google sign-in on the website** needs the Pages domain `biniambeza.github.io` under Firebase console > **Authentication > Settings > Authorized domains** (otherwise `auth/unauthorized-domain`); it has been added for this project. If the browser API key in `lib/firebase_options.dart` gets HTTP-referrer restrictions in Google Cloud console > APIs & Services > Credentials, include `https://biniambeza.github.io/*` there too. On Android it needs the release key's SHA-1 and SHA-256 added to the Firebase Android app (step 4 of the setup above), and the Play app signing key's too once the app is on Google Play.

Not on the website yet: web push. GitHub Pages serves the app under `/Barbershop-Booking-System/`, while the Firebase Messaging web SDK registers `/firebase-messaging-sw.js` at the domain root, so the workflow does not pass `FCM_VAPID_KEY` and web users get the in-app inbox only. Push also needs the `notifications` functions (Blaze). Hosting on Firebase Hosting (served at the root) would allow it.

## Free plan (Spark)

The Firebase project can run on the free **Spark** plan, where Cloud Functions do not run. Deploy only the rules (`firebase deploy --only firestore:rules,firestore:indexes`); no new indexes are needed for the fallbacks below. The functions stay in the repo unchanged and take over once the project is on Blaze. Each client fallback is idempotent and gives way to the matching function, so nothing has to be switched off when you upgrade.

**Works without Blaze (client fallbacks, secured by the rules):**

- **Subscription expiry.** The app works out a shop's status the same way `dailySubscriptionCheck` does: `past_due` at `subscriptionEndsAt`, `suspended` 7 days later, and suspended stays suspended ([lib/services/subscription_state.dart](lib/services/subscription_state.dart)). The owner's app (own shop) and the admin's app (every shop) write the downgrade once as `{subscriptionStatus, subscriptionStatusChangedAt}`. The rules allow the owner only these downgrades, checked against the server clock. Customers never see a lapsed shop, and the rules refuse bookings and remote queue joins once the 7-day grace period is over, even while the stored status is out of date. The owner banner counts the days left and opens the receipt payment screen.
- **Subscription receipts.** Owners pay by telebirr or CBE transfer and the admin approves in the app. The admin's **Set up where shop owners pay you** card stays on the dashboard until a real telebirr number or CBE account is saved; until then owners see "Payments aren't open yet".
- **Owner reports.** When the `stats/{yyyy-MM}` documents are missing or older than the bookings show (by more than 15 minutes), the report is computed from the bookings the owner's app already loads. That covers the last 90 days, and the screen says so.
- **Walk-in queue summary.** The staff app (the owner or a barber of the shop) recomputes `queueSummary/current` with the function's formula and writes it with the same shape. It does this after each staff action and whenever the live queue list changes, and skips the write when nothing but `updatedAt` would change.
- **Unanswered booking requests.** While a barber or owner dashboard is open, it closes `pending` requests that start within 45 minutes, using the existing decline write (`declineReason: 'not_accepted'`) and freeing their slot locks. On Blaze, `expirePendingBookings` (60 minutes, every 15 minutes) always goes first. Customers see "No answer" on a request that has run out of time.
- **Shop maps.** Pins, the shop page map, Directions and Near me need no Cloud Functions, Storage or API key (OpenStreetMap tiles). Deploy the rules once so owners and admins may write `latitude` / `longitude`; until then a save with a pin is refused (saves without a pin keep working).
- **Early finish notices**, admin shop management and barber accounts (see [Before the first deploy](#before-the-first-deploy)).

**Still needs Blaze:**

- **Push notifications** to phones, booking reminders and the queue "you're next" message. The in-app inbox entries the app writes itself still appear.
- **SMS** through AfroMessage.
- **Emails:** the 6-digit codes for email sign-up and password reset, and invitation emails (`functions/auth`). Google sign-in works on Spark.
- **Automatic receipt checks** (`verifyReceipt`, `recheckReceipt`). On Spark the admin approves or rejects each receipt by hand.
- **The booking-lock safety net** (`verifyBookingLocks`, `verifyRescheduledBookingLocks`, `cleanupExpiredSlotLocks`). The rules still check slot locks when a booking is made, but a rare race they miss is not cancelled afterwards, and expired locks are not deleted.
- **Chapa online payments** (the `payments` callables and webhook) and the monthly report stats (`functions/insights`; on Spark the reports fall back to the bookings, as above). Ratings are updated by the customer's app and work on both plans.

Free-plan gaps: the queue summary and expired requests are only updated while a staff device has the app open, and a lapsed owner whose phone clock runs fast may have the downgrade refused once; the admin's app or the next session writes it.

## Security

- **Private barber phones.** A barber's phone is never on the public profile (`barbershops/{s}/barbers/{b}`, readable by anyone). It lives in `barbershops/{s}/barbers/{b}/private/contact` `{phone}`, which only admins, the shop's owner and that barber can read or write. A customer sees it only on their own confirmed or in-progress booking: the staff app copies it to `bookings/{id}.barberPhone` when a request is accepted (and to upcoming confirmed bookings missing it), and the rules accept it only when it equals the private number. Old public docs that still carry a phone or email are moved once, automatically, when the owner (own shop) or an admin opens the app. Works on Spark.
- **Shop deletion clean-up** (admin app, works on Spark): the app records `shopDeletions/{shopId}` and suspends the shop, cancels its upcoming bookings (`cancelReason: 'shop_deleted'`, customers notified, paid ones refund-flagged), turns the owner and barbers into customers and deletes the shop's invites, deletes every subcollection (barbers with their private contact, slot locks and time off, services, queue, reviews, stats, clients, payouts) in batches of 100, then the shop document. Each step can be run again; the rules allow the clean-up writes only while the `shopDeletions` record exists. On Blaze `onShopDeleted` also deletes the barber logins the owner created.
- **Receipt photos in Storage** (Blaze only): the admin switch **Store receipt photos in Firebase Storage** (`platformConfig/subscriptionPricing.storageReceipts`, off by default) makes the owner's app upload the photo to `receipts/{shopId}/{paymentId}.jpg` and save only `imagePath`. `storage.rules` lets the shop's owner create it once (an image under 2 MB, never overwritten or deleted) and only that owner and admins read it. Any upload failure falls back to the inline photo, so leave the switch off on Spark. Deploy `storage.rules` with `firebase deploy --only storage` after enabling Storage.
- **App Check** ([lib/services/app_check_setup.dart](lib/services/app_check_setup.dart), free on Spark) is activated right after `Firebase.initializeApp`: Play Integrity on Android release builds, App Attest with DeviceCheck fallback on iOS/macOS release builds, the debug provider in debug builds, and reCAPTCHA v3 on the web when built with `--dart-define=RECAPTCHA_SITE_KEY=<site key>` (without it the web build skips App Check and logs that once). It is skipped in demo mode and tests. **Enforcement is off for every service and must stay off** while the APK is sideloaded: Play Integrity only passes for apps installed from Google Play, so enforcing would lock out the sideloaded app. Turn on enforcement per service (Firestore, Authentication) in the console only after the Play Store release and once the App Check metrics show nearly all requests verified. To use a debug build against an enforced project, register the debug token it prints in the device log under **App Check > Apps > Manage debug tokens**.
- **Crashlytics** ([lib/services/crash_reporting.dart](lib/services/crash_reporting.dart), free on Spark) records uncaught Flutter errors (`FlutterError.onError`) and uncaught async/platform errors (`PlatformDispatcher.instance.onError`) as fatal crashes. It is off on the web, in demo mode, in tests and in debug builds; native collection also defaults to off in `AndroidManifest.xml` and `Info.plist` and is turned on by the app in release builds.
- **Backups (Blaze only).** Scheduled Firestore backups and point-in-time recovery are billed features, so they are not set up on Spark. After upgrading to Blaze run [tool/backups/enable_daily_backups.sh](tool/backups/enable_daily_backups.sh) once (needs `gcloud` signed in as a project owner): a daily backup of the `(default)` database kept for 7 days, and with `--pitr` also point-in-time recovery for the last 7 days. A backup is restored into a new database (`gcloud firestore databases restore`, see the script). On Spark there are no automatic backups (managed exports need billing too).

## Cloud Functions

There are six codebases (TypeScript, Node 20, region `europe-west1`), all listed in [firebase.json](firebase.json) and built and tested in CI:

| Codebase | Functions |
|---|---|
| `functions/notifications` | `onBookingWritten` (push, inbox and SMS on booking and booking-payment changes; `rescheduled` goes to customer, barber and owner with an SMS to the customer and clears reminders already sent so the new time gets its own; `noShow` goes to the customer only, without SMS; barber acceptance sends `accepted`, `requestDeclined` and `requestExpired` to the customer, and staff also hear about expiries), `onShopApplicationWritten` (inbox entry and push to the applicant when their shop application is approved or rejected), `onBookingCompletedEarly` (when a booking is completed before its scheduled end: the same `barberFreeEarly` / `runningEarly` inbox entries the staff app writes, in each customer's language, plus one push each, guarded by `notificationLog`; skipped when `completedAt` is more than 30 minutes old), `onPaymentWritten` (failed booking payments, subscription paid or failed), `sendBookingReminders` (every 15 minutes) |
| `functions/payments` | Callables `createBookingPayment`, `createSubscriptionPayment`, `verifyPayment`, `setShopSubscription`, `seedDefaultPlans`, `resolvePaymentReview` (admin only); HTTPS `chapaWebhook`; scheduled `dailySubscriptionCheck` (03:00 Addis time); `verifyReceipt` (on `subscriptionPayments` create: fetches the official telebirr receipt page or CBE receipt PDF and, in one transaction, verifies and extends the shop, rejects a duplicate or an amount below the cheapest tier, or leaves it `needs_review` with a reason; an admin's earlier decision always stands); callable `recheckReceipt` (admin only, runs the check again) |
| `functions/bookings` | `verifyBookingLocks` (on booking create: checks a slot lock exists for every 15-minute block and cancels the booking with `cancelledBy: 'system'`, `cancelReason: 'slot_conflict'` if one is missing or taken), `verifyRescheduledBookingLocks` (on booking update when the time changed: the same check for the new interval; time-off locks count as taken), `cleanupExpiredSlotLocks` (daily 04:00 Addis: deletes slot locks whose `expiresAt` has passed, booking and time-off locks alike), `expirePendingBookings` (every 15 minutes: cancels booking requests still `pending` within 60 minutes of their start with `cancelledBy: 'system'`, `cancelReason: 'not_accepted'`, and deletes their slot locks in the same transaction; uses the `bookings (status, startAt)` index) |
| `functions/queue` | `onQueueEntryWritten` (recomputes `barbershops/{s}/queueSummary/current` in a transaction, sets a customer's duplicate remote entries to `left`, and sends a `queueNext` inbox entry and push, once, to a remote customer who reaches the front) |
| `functions/auth` | Callables `requestEmailCode`, `verifyEmailCode`, `completeEmailRegistration`, `resetPasswordWithCode` (email + password accounts verified by an emailed 6-digit code, see [Email registration codes](#email-registration-codes)); scheduled `cleanupEmailCodes` (daily 04:30 Addis: deletes expired codes and send counters); Firestore trigger `onInviteCreated` (emails a new invite its sign-up steps, see [Invitation emails](#invitation-emails)); Firestore trigger `onShopDeleted` (Blaze: repeats the admin app's shop-deletion cascade and deletes the logins the owner created for barbers); Firestore trigger `onUserDisabledChanged` (mirrors an admin's disable to Firebase Auth); Firestore trigger `onUserProfileDeleted` (Blaze: finishes an in-app account deletion, see the privacy and account deletion row above) |
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

   **Admin shop management, barber accounts, early finish and subscription receipts** need only `firestore:rules` to work on the free Spark plan: the rules add the `adminSuspended*` and `subscriptionReceiptId` shop fields (admin only), block bookings, reschedules and remote queue joins at an admin-suspended shop, drop the admin's bookings list access, allow the `authUid` / `mustChangePassword` invite and profile path for owner-created logins, the `{status, completedAt}` completion and the staff-written early-finish inbox entries, and open `subscriptionPayments` and `platformConfig/subscriptionPricing`. No new indexes are needed. Then, as admin, open **Subscription prices** (admin menu) and enter the real telebirr number, CBE account and receiver names exactly as they appear on receipts (the seed has `XXXX` placeholders). Once on Blaze, also deploy `functions:notifications` (`onBookingCompletedEarly`) and `functions:payments` (`verifyReceipt`, `recheckReceipt`); the app does not depend on them. The official receipt sites may block or time out requests from `europe-west1`; receipts then land in `needs_review` (`fetch_failed`) for the admin, or point `receiptUrls` at an https relay hosted in Ethiopia (with an `{id}` placeholder).

   **Receipt photos in Firebase Storage (Blaze only).** On Spark, receipt photos stay inline in the receipt document (`receiptImage`, base64). On Blaze, open Storage in the Firebase console once to create the default bucket, run `firebase deploy --only storage` (`storage.rules`: the shop's owner may create `receipts/{shopId}/{paymentId}.jpg`, an image under 2 MB, never overwrite or delete it; the owner reads their shop's photos, admins read all), then turn on **Store receipt photos in Firebase Storage** in **Subscription prices**. New receipts then save only `imagePath`; any failed upload (no bucket, permission, network) falls back to inline automatically, and both kinds keep showing in the owner and admin views. `functions:payments` reads Storage photos for its automatic check (`autoCheck.image`). Storage rules tests: `firebase emulators:exec --only firestore,storage --project demo-crownblade "node --test storage.test.js"` in `firestore-tests`.

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
- **iOS:** upload an APNs key (.p8) under Firebase console > Project settings > Cloud Messaging. The push entitlement, background mode and AppDelegate hook are already in `ios/`; see [docs/ios-setup.md](docs/ios-setup.md).
- **Web:** fill in the `firebaseConfig` placeholders in `web/firebase-messaging-sw.js`, and build with `--dart-define=FCM_VAPID_KEY=<key>` (Firebase console > Cloud Messaging > Web Push certificates). Without the key, web users still get the in-app inbox.

## What still needs real-world setup

- SMTP credentials for the email codes (Gmail app password, Brevo or Resend) and the Email/Password provider turned on (see [Email registration codes](#email-registration-codes)).
- A Firebase project (`flutterfire configure`), the Google sign-in provider enabled (with the Android SHA-1 fingerprints and the web domains authorized), and the first admin invite (see above).
- A Chapa merchant account. Test with Chapa test keys first: the webhook signature check and the verify response were written from Chapa's docs and have not run against live Chapa.
- An AfroMessage account with an approved sender name. Until then, set `AFROMESSAGE_TOKEN` to `none`.
- The platform's real telebirr number, CBE account and receiver names for subscription receipts (admin menu > Subscription prices), and the final receipt price tiers.
- A real privacy contact address in place of `privacy@example.com` (`lib/core/config/legal_links.dart`, `web/privacy.html`, `web/delete-account.html`), then the privacy policy and delete-account URLs entered in the Google Play Console.
- Final plan prices. Edit them in the admin app; the defaults live in `functions/payments/src/config.ts` and `assets/seed/addis_seed.json`.
- After deploying the rules, try a 120-minute booking (the longest allowed service), a 120-minute reschedule to a non-overlapping time and a whole-day time off (up to 96 locks in one batch) on the real project. The rules stay within Firestore's expression and read limits on the emulator, but the emulator does not show how production counts repeated `get`/`getAfter` calls on the same document. If production counts them separately, the app must split time off into smaller batches.
- Deep links back from Chapa on Android and iOS. For now the app verifies the payment when it comes back to the foreground, or when the user taps "I've paid".
- Refunds are made by hand in the Chapa dashboard; the admin then marks the payment as refunded on the Payments to review screen. There is no automatic refund through the Chapa API.

## Known limitations

- Booking listeners only cover upcoming bookings and the last 90 days (newest 200 for customers, 1000 for staff), so the 90-day dashboard tiles and the report fallback cover that window; the earnings cards (any month, this year, all time) use aggregate queries instead. Admins load no bookings (platform revenue is not shown; it would come from payments and subscription receipts).
- Deleting a shop (admin app) cancels its upcoming bookings (`cancelReason: 'shop_deleted'`, customers notified), turns the owner and barbers into customers (notice "Your barbershop was removed"), revokes its invites and deletes its subcollections before the shop document; past bookings stay. A failed step can be retried from the dialog. On the free plan the staff keep their Firebase Auth logins (as customers); on Blaze `onShopDeleted` in `functions/auth` deletes the logins the owner created for barbers (password-only, never verified).
- Barber accounts: the owner cannot reset a barber's password on the free plan (the barber uses "Forgot password?"), and removing a barber does not delete their Firebase Auth login.
- Early finish: the staff app cannot read customers' language, so the stored text of a free-plan notice is Amharic; the customer app shows it in the viewer's language from their booking, and `onBookingCompletedEarly` rewrites it on Blaze.
- Subscription receipts: the telebirr and CBE parsers follow public open-source verifiers and have not been tested against a live receipt from this project's accounts; anything they cannot read goes to `needs_review`, never `verified`. The CBE PDF reader handles plain FlateDecode text only. There is no button for `recheckReceipt` in the app yet.
- A booking that loses a slot race on the client side is rejected at once; one that slips past the rules (they check only the first four locks and the last one) is cancelled by `verifyBookingLocks` within seconds, and the customer gets a "that time was just taken" notification.
- Slot locks written before `expiresAt` existed are never cleaned up by `cleanupExpiredSlotLocks`. There is no production data yet; if there ever is, backfill `expiresAt` or delete them once.
- Refunds are flagged automatically but paid out by hand (telebirr, bank, cash or the Chapa dashboard); "Mark refunded" only records it. There is no automatic refund through the Chapa API.
- Time off is stored as one Addis day per entry ("whole day" means the barber's working hours that day); a vacation is a group of such entries. Admins cannot add, remove or read time off, though they can still clear any lock.
- A reschedule keeps the existing locks of blocks that are in both the old and the new interval; they keep the old `expiresAt`, which is always after the block.
- `noShow` is final: nobody can change the status afterwards (the admin can still correct `paymentStatus`).
- Only the shop owner can reply to a review (not the admin). Owners get an inbox entry for a new review; the barber's entry and the pushes need Blaze (`onReviewCreated`).
- Reports and review lists load once (with a refresh) rather than live, and the figures change a few seconds after a booking or review does, once the `insights` trigger has run. Ratings on shops and barbers are live.
- The queue summary is recomputed only when a queue entry changes (on the free plan: when a staff device sees the change, see [Free plan](#free-plan-spark)), so a barber going unavailable or a service changing length shows up at the next queue change. In demo mode a remote customer gets no "you're next" inbox entry (the card on the shop page still says so). One active queue entry per customer is checked by the app and repaired by the function; the rules cannot enforce it.
- Booking acceptance: any `pending` booking is treated as an open request, whatever the shop's current setting (the older seed booking `book_6` included). Accepting is allowed by the rules until the start time; the 60-minute cut-off is enforced by the app and by `expirePendingBookings`. In demo mode there is no auto-expiry (expired requests just stop being listed), and the local notification copy for an accept or decline uses the plain confirmed/cancelled texts.
- Payouts: payout `createdAt` comes from the client clock (the rules cap it at one hour in the future). Balances carry over from November 2026 on (earlier months are not counted), and owner reports do not include payout totals (the Payouts screen has them).
- Shop applications: approving creates the shop with an empty `ownerId` and a starter set of two services and a lead barber, which the new owner then edits.
- Queue and review errors use their own `QueueException` / `ReviewException` codes rather than the shared `AppErrorCode` enum. All of them are translated.

## Tests

```sh
flutter test                         # app tests (run against the local demo data)
cd firestore-tests && npm install && npm test   # security rules tests on the Firestore emulator (needs Java 21+)
cd firestore-tests && npx firebase emulators:exec --only firestore,storage --project demo-crownblade "node --test storage.test.js"   # storage.rules (skipped by npm test; run on its own, rules.test.js clears the shared emulator)
cd functions/notifications && npm install && npm run build && npm test
cd functions/payments && npm install && npm run build && npm test
cd functions/bookings && npm install && npm run build && npm test
cd functions/queue && npm install && npm run build && npm test
cd functions/insights && npm install && npm run build && npm test
cd functions/auth && npm install && npm run build && npm test
cd tool/seed && npm install && npm test          # seed script
```
