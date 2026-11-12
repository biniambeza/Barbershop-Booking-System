# Crown & Blade

Multi-tenant barbershop booking platform for Addis Ababa, built with Flutter and Firebase.

| Role | Can do |
|---|---|
| Admin | Register shops and invite their owners, verify or remove shops, see all users and bookings |
| Shop owner | Manage one shop: profile, hours, services, barbers (invites them by phone), all of the shop's bookings |
| Barber | See and run their own appointment queue, set availability, see earnings |
| Customer | Find shops and barbers, book, cancel, keep favorites |

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

Runs offline on demo data. The sign-in screen shows one-tap demo accounts, and the SMS code is always `123456`. The GitHub Pages build is a demo build. Never ship a production build with `DEMO_MODE`.

### Production (Firebase)

Without the define, the app requires Firebase and shows "Service unavailable" until it is configured.

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

## Tests

```sh
flutter test                         # app tests (run against the local demo data)
cd firestore-tests && npm install && npm test   # security rules tests on the Firestore emulator (needs Java 21+)
```
