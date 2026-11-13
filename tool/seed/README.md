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
| default (users) | `users/{uid}` with fixed uids (`user_admin_1`, `owner_1`, `barber_user_1`, `user_cust_1`, ...), bookings, shops, services, barbers, plans. With the Auth emulator running or `--with-auth`, also Firebase Auth phone users with the same uids. | Emulator, staging |
| `--invites` | `invites/{phone}` for the admin, owners and barbers (no customers), shops with `ownerId: ''`, services, barbers, plans. No users or bookings. | A real project |

In invites mode each person gets their role on first sign-in with their number, as with any invite (owners then claim their shop).

Demo numbers: admin `+251911000001`, owner of `shop_1` `+251911000101`, barber `barber_1` `+251911000201`, customer `+251911000301`. To sign in with them on a real project without SMS, add them under **Authentication > Phone numbers for testing**.

`npm test` checks the script resolves the data like the app does.
