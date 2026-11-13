# Seed data

`assets/seed/addis_seed.json` is the single demo dataset: 6 Addis Ababa shops (Bole, Kirkos/Kazanchis, Arada/Piassa, Kolfe Keranio/Sarbet, Yeka/CMC, Yeka/Megenagna), their services (ETB), barbers, 13 users, 8 bookings and the 3 subscription plans.

- **Demo mode** (`flutter run --dart-define=DEMO_MODE=true`) loads it as a Flutter asset (`lib/data/seed_dataset.dart`).
- **Firestore**: `seed.js` writes the same data with `firebase-admin`.

Times in the JSON are relative (`createdDaysAgo`, `subscriptionEndsInDays`, and for bookings `dayOffset` + `startTime` in Addis local time), so the demo always has bookings today and tomorrow. Both loaders resolve them the same way (Addis Ababa is UTC+3).

## Running the seed script

```sh
cd tool/seed
npm install
node seed.js --dry-run                     # show what would be written
```

Against the emulators (the script reads `FIRESTORE_EMULATOR_HOST` / `FIREBASE_AUTH_EMULATOR_HOST`):

```sh
firebase emulators:exec --only firestore,auth --project demo-crownblade "node tool/seed/seed.js"
```

Against a real project (asks for `--yes` because it writes production data):

```sh
GOOGLE_APPLICATION_CREDENTIALS=service-account.json node seed.js --invites --project <project-id> --yes
```

## Users or invites

| Mode | Writes | Use for |
|---|---|---|
| default (users) | `users/{uid}` with fixed uids (`user_admin_1`, `owner_1`, `barber_user_1`, `user_cust_1`, ...), each with an `email` and a contact `phone`, plus bookings, shops, services, barbers, plans. With the Auth emulator running or `--with-auth`, also Firebase Auth users with the same uids and verified emails. | Emulator, staging |
| `--invites` | `invites/{email}` (doc id = the lowercased email) for the admin, owners and barbers (no customers), shops with `ownerId: ''`, services, barbers, plans. No users or bookings. | A real project |

Sign-in is with Google, so people are identified by their (lowercased) Google email. In invites mode each person gets their role the first time they sign in with Google using the invited address, as with any invite (owners then claim their shop). The dataset's emails are `@example.com` placeholders: before running `--invites` on a real project, replace them in `assets/seed/addis_seed.json` (or a copy) with the real people's Google addresses, otherwise nobody can accept the invites. The script lowercases emails and refuses users without one.

Demo emails: admin `admin@example.com`, owner of `shop_1` `owner.shop1@example.com` (shops 2-6: `owner.shop2@example.com` ...), barbers `barber1.shop1@example.com` and `barber2.shop1@example.com`, customer `liya@example.com`. Phones (`+251911000001`, ...) are contact numbers on the profile, not sign-in identities.

`npm test` checks the script resolves the data like the app does.

## Report stats and client history

The seed writes no `barbershops/{shop}/stats/{yyyy-MM}` or `barbershops/{shop}/clients/{customerId}` docs: they are derived data, and the seeded booking dates are relative, so fixed stats would go stale. They come from the `functions/insights` codebase instead:

- With the Functions emulator running while you seed (`firebase emulators:exec --only firestore,auth,functions ...`), `aggregateBookingStats` builds them from each seeded booking.
- Otherwise, after seeding, sign in as the admin and call the `rebuildShopStats` callable once per shop (`{ "shopId": "shop_1" }`, then `shop_2`, ...). It rebuilds stats, clients and the `insightsApplied` markers from the shop's bookings.

In demo mode the owner Reports screen computes the same figures from the local bookings, so nothing extra is needed.

## Reviews

Users mode writes `barbershops/{shop}/reviews/{bookingId}` for each entry of the dataset's `reviews` list (13 reviews of completed bookings, English and Amharic, some with an owner reply). Shop, barber and customer come from the booking; `createdAt` and `replyAt` are counted from the booking's start (`hoursAfterVisit`, `replyHoursAfterVisit`). The shops' and barbers' `rating` / `reviewCount` in the dataset already match these reviews, which is what `aggregateReviewRatings` (functions/insights) would write; `reviews.test.js` checks it. Booking `book_5` (Liya, the demo customer) is left unreviewed so the demo has a visit to rate.
