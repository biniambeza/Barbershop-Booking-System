# iPhone (iOS) setup

The iPhone version of Crown & Blade is ready in the code. What is missing is Apple's side: an Apple developer account, signing, and a push key. You need a Mac (or the GitHub Actions Mac runner, see step 7) to build it. A Windows PC cannot build iOS apps.

## Already done in the code

| What | Where |
|---|---|
| Bundle id `et.crownblade.app` (same as Android) | `ios/Runner.xcodeproj/project.pbxproj` |
| Name under the icon: **Crown & Blade** | `CFBundleDisplayName` in `ios/Runner/Info.plist` |
| Google sign-in return address (URL schemes: `REVERSED_CLIENT_ID` and the encoded app id), plus `GIDClientID` | `ios/Runner/Info.plist` |
| Camera and photo library permission texts (receipt photos) | `ios/Runner/Info.plist` |
| Background push (`UIBackgroundModes` = `remote-notification`) | `ios/Runner/Info.plist` |
| "No special encryption" answer, so TestFlight does not ask about export compliance on every build | `ITSAppUsesNonExemptEncryption` = false in `ios/Runner/Info.plist` |
| English and Amharic declared as app languages | `CFBundleLocalizations` in `ios/Runner/Info.plist` |
| Push entitlement (`aps-environment`) and App Attest entitlement (for App Check) | `ios/Runner/Runner.entitlements`, wired in with `CODE_SIGN_ENTITLEMENTS` for Debug, Release and Profile |
| `GoogleService-Info.plist` included in the app | added to the Runner target's resources |
| Minimum iOS version 15.0 (the Firebase iOS SDK requires it) | `IPHONEOS_DEPLOYMENT_TARGET` |
| Push notifications hooked up for the UIScene lifecycle | `ios/Runner/AppDelegate.swift` calls `FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()` |
| The app waits for Apple's push token before asking Firebase for its own | `FcmPushRegistrar` in `lib/services/notification_service.dart` |
| A Mac build on GitHub Actions, with an optional TestFlight upload | `.github/workflows/ios.yml` |

**No Podfile.** Flutter 3.44 uses Swift Package Manager for iOS plugins by default, and every native plugin this app uses supports it. `path_provider_foundation` is pure Dart. The Xcode project already references `FlutterGeneratedPluginSwiftPackage`. If you ever turn Swift Package Manager off (`flutter config --no-enable-swift-package-manager`), Flutter writes a Podfile on the first Mac build. Then change its first line to `platform :ios, '15.0'`.

**Push only works on the Blaze plan.** The push messages are sent by the `notifications` Cloud Functions. On the free Spark plan, iPhone users (like everyone else) get the in-app notifications inbox but no push messages. The steps below still make sense on Spark: once you move to Blaze, iPhone push works without another app update.

## 1. Join the Apple Developer Program (USD 99 per year)

1. Go to <https://developer.apple.com/programs/enroll/> and sign in with the Apple ID that should own the app.
2. Enrol as an **Individual** or as an **Organization**. An organization needs a D-U-N-S number. The App Store then shows the company name as the seller, which is usually better for a business.
3. Pay the USD 99 yearly fee. Approval takes from a few hours to a few days.
4. Write down your **Team ID**: developer.apple.com > Account > Membership details. It is 10 characters, like `AB12CD34EF`.

## 2. Register the app id

developer.apple.com > Certificates, Identifiers & Profiles > Identifiers > **+** > App IDs > App.

- Description: `Crown and Blade`
- Bundle ID: **Explicit**, `et.crownblade.app`
- Capabilities: tick **Push Notifications** and **App Attest**.
- Tick **Sign In with Apple** only if you build it (see step 9). The app does not have it yet.

If you sign with Xcode's automatic signing (step 4), Xcode can also create this for you. Doing it by hand first avoids surprises.

## 3. Create the push key (APNs .p8) and give it to Firebase

1. developer.apple.com > Certificates, Identifiers & Profiles > **Keys** > **+**.
2. Name it, for example `Crown and Blade push`, and tick **Apple Push Notifications service (APNs)**. Choose the environment **Sandbox & Production**. Continue and Register.
3. **Download** the `AuthKey_XXXXXXXXXX.p8` file. Apple lets you download it only once, so keep it somewhere safe and never put it in the repository. Write down the **Key ID**.
4. Firebase console > project `barbershop-booking-syste-8a9b8` > Project settings (gear icon) > **Cloud Messaging** > Apple app configuration > the iOS app `et.crownblade.app` > **APNs Authentication Key** > Upload. Pick the .p8 file, then enter the Key ID and your Team ID.

One key works for both development and App Store builds, and for all your apps. You do not need the older .p12 push certificates.

## 4. Signing in Xcode (on a Mac)

1. Install Xcode from the Mac App Store, then run `flutter doctor` and fix what it reports.
2. Run `flutter pub get`, then open `ios/Runner.xcworkspace` in Xcode.
3. Select **Runner** (the blue project icon) > target **Runner** > **Signing & Capabilities**:
   - Tick **Automatically manage signing**.
   - Team: your team from step 1. Xcode then stores `DEVELOPMENT_TEAM` in the project, so commit that change.
   - You should see **Push Notifications**, **Background Modes > Remote notifications** and **App Attest** listed. They come from `Runner.entitlements` and `Info.plist`. If Xcode offers to "fix" them, accept.
4. Plug in an iPhone and run `flutter run --release`, or press Run in Xcode. The first time, trust the developer on the phone: Settings > General > VPN & Device Management.
5. Check that Google sign-in opens and comes back to the app, that receipt photos can be taken, and that a push arrives (push needs the Blaze plan and step 3).

`aps-environment` is `development` in the file. When you archive for TestFlight or the App Store, Xcode switches it to `production` by itself. You don't need to edit it.

## 5. Create the app in App Store Connect

<https://appstoreconnect.apple.com> > Apps > **+** > New App:

- Platform iOS, name **Crown & Blade** (if the name is taken, try for example "Crown & Blade Barbers"), primary language English, bundle id `et.crownblade.app`, SKU for example `crownblade-ios`.
- Fill in the privacy policy URL, the age rating questionnaire and **App Privacy**. The app collects name, email, phone number, booking history, payment receipt photos, the push token and crash data (Crashlytics, off by default).

## 6. TestFlight

**From a Mac:** run `flutter build ipa --release`, then open `build/ios/archive/Runner.xcarchive` in Xcode (Window > Organizer) > **Distribute App** > App Store Connect > Upload. You can also drag `build/ios/ipa/*.ipa` into Apple's **Transporter** app.

**Without a Mac:** use the GitHub workflow (step 7).

After the upload, Apple processes the build (about 15 minutes). Then App Store Connect > your app > **TestFlight**:

- Internal testers (up to 100 people in your App Store Connect team) can install it right away with the TestFlight app.
- External testers (up to 10,000, by email or a public link) need a short Beta App Review first, usually within a day.

Each upload needs a higher build number. `pubspec.yaml` has `version: 1.0.0+1`, and the `+1` is the build number. The workflow uses its run number unless you type one.

## 7. Build on GitHub Actions (no Mac needed)

`.github/workflows/ios.yml` runs only when started by hand: GitHub > **Actions** > **iOS build** > **Run workflow**.

- **Always:** it builds the app on a Mac runner without signing (`flutter build ios --release --no-codesign`). This proves the iPhone build compiles.
- **When all signing secrets exist:** it also signs the app, archives it and uploads it to TestFlight. If any secret is missing, those steps are skipped with a notice and the run still passes.

Add these under GitHub > repository **Settings** > **Secrets and variables** > **Actions** > New repository secret:

| Secret | How to get it |
|---|---|
| `APPLE_TEAM_ID` | Step 1, Membership details. |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect > Users and Access > **Integrations** > App Store Connect API > Team Keys > **+**. Use the role **App Manager**, or **Admin** if you want Xcode to create the distribution certificate for you. Copy the Key ID. |
| `APP_STORE_CONNECT_API_ISSUER_ID` | Shown above the keys list on the same page. |
| `APP_STORE_CONNECT_API_KEY_P8` | Download the key's `.p8` (only possible once) and paste its **whole text**, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines. This is a different key from the push key in step 3. |
| `IOS_DIST_CERT_P12_BASE64` | An **Apple Distribution** certificate with its private key. On a Mac: Xcode > Settings > Accounts > your team > Manage Certificates > **+** > Apple Distribution. Then in Keychain Access, right-click the certificate > Export as `.p12` with a password. Encode it with `base64 -i dist.p12 \| pbcopy` on a Mac, or `certutil -encode dist.p12 dist.b64` on Windows (remove the BEGIN/END lines). Without a Mac, create a CSR with `openssl`, upload it at developer.apple.com > Certificates > **+** > Apple Distribution, then combine the downloaded `.cer` and your key into a `.p12` with `openssl pkcs12 -export -legacy`. |
| `IOS_DIST_CERT_PASSWORD` | The password you chose for the `.p12`. |
| `IOS_PROVISIONING_PROFILE_BASE64` (optional) | Not needed normally. Automatic signing with the API key downloads or creates the App Store profile itself. Add one only if automatic signing fails: developer.apple.com > Profiles > **+** > App Store Connect > `et.crownblade.app`, then base64-encode it the same way. |

Never commit any of these files (`.p8`, `.p12`, `.mobileprovision`) to the repository.

## 8. App Store review: things that will be checked

1. **Account deletion (guideline 5.1.1(v)).** Apps that let people create an account must let them delete it **inside the app**, not only by email or on a website. The app does **not have this yet** for customers, barbers or owners. It must be added before submitting (see the follow-ups below).
2. **Sign in with Apple, or an equivalent (guideline 4.8, "Login Services").** The current rule, checked against Apple's guidelines page in November 2026: an app that uses a third-party login such as **Google Sign-In** for the user's main account must also offer another login service that collects only name and email, lets users **keep their email private**, and does not track them for ads without consent. The exception "the app uses only its own account system" does not apply, because the app offers Google sign-in. The app's own email sign-up does not meet the "keep email private" condition either. So in practice the app needs **Sign in with Apple**, which is the standard way to meet this rule, before App Store review. The other option is to hide Google sign-in on iPhone. Sign in with Apple is **not built yet**. To build it: add the Sign In with Apple capability (step 2 and Xcode), turn on the **Apple** provider in Firebase console > Authentication, and call `FirebaseAuth.signInWithProvider(AppleAuthProvider())` the same way as Google. The free Spark plan is enough for this.
3. **Demo account for the reviewer.** In App Store Connect > App Review Information, give a working customer login (email and password) and, if possible, an owner login. Explain that payments in Ethiopia go through Chapa or telebirr/CBE receipts. Apple's reviewers usually cannot pay. Booking services that are paid for outside the app (haircuts) are allowed without Apple in-app purchase under guideline 3.1.3(e), for goods and services used outside the app.
4. **Shop subscriptions.** Owners pay the platform a subscription by receipt or Chapa. Apple can treat a digital subscription unlocked in the app as needing in-app purchase (guideline 3.1.1). An owner's business tools for a physical barbershop are usually accepted as a business service (3.1.3), but be ready to explain it in the review notes. Safest: on iPhone, do not show subscription prices or a pay button, only "manage your plan on the website".
5. **Permission texts** (camera, photos, notifications) must say why the app needs them. They are in `Info.plist`, in English. Apple accepts English even for an Amharic app.
6. **Screenshots:** 6.9-inch iPhone (1320 x 2868) is required. 13-inch iPad screenshots are also needed because the app runs on iPad (`TARGETED_DEVICE_FAMILY = "1,2"`). To avoid iPad screenshots, make the app iPhone-only in Xcode (Runner > General > Supported Destinations).

## Optional extras

- **Crashlytics symbols:** iOS crash reports show readable stack traces only if the dSYM files are uploaded. The workflow's export sets `uploadSymbols` for Apple. For Firebase, add the Crashlytics "upload-symbols" run script in Xcode (see the Firebase Crashlytics iOS docs) or run `flutterfire configure` on a Mac, which adds it.
- **App Check:** once the App Store build is live, check Firebase console > App Check > Apps to see that the iOS app's App Attest requests are verified, before you ever turn on enforcement.
