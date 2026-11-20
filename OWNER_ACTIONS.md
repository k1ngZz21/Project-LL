# Owner actions

These steps change live accounts or need your credentials, inbox or phone, so
they were prepared but not performed. Each lists exactly what to do and how
to check it worked. Status is tracked in [PHASE_PROGRESS.md](PHASE_PROGRESS.md).

## 1. Back up the release key (do this first)

The upload keystore was created on 2026-11-20 by
`mobile/tool/create_release_keystore.ps1`:

```
%USERPROFILE%\.learnlite-signing\learnlite-upload.jks
%USERPROFILE%\.learnlite-signing\key.properties   (contains the password)
```

- Copy **both files** to a safe offline place (encrypted USB drive, or a
  password manager's file attachment). If they are lost, a published app can
  never be updated under the same signature.
- Never commit them, email them or put them in OneDrive.
- Certificate fingerprints (public, safe to share):
  - SHA-1: `16:98:E5:0A:3D:83:52:5E:11:10:A0:D4:EF:D3:26:18:2B:15:71:70`
  - SHA-256: `9B:32:46:5D:FC:5F:06:F4:F5:D0:18:3F:B1:BF:55:90:95:92:BC:12:F5:0F:A1:C0:75:0E:3B:F0:0E:2C:C4:DC`

Release builds now use this key automatically. **An APK signed with it cannot
be installed over a debug-signed LearnLite** (Android refuses a signature
change). Uninstalling the old app first deletes its local progress, so move
a device to the release build only when that is acceptable.

## 2. Choose and register the production application ID

Current ID: `com.example.learnlite` (the Flutter template default; Google Play
rejects `com.example.*`). Firebase has exactly one Android app registered
(`1:593696228310:android:1538c1fb05efbd67f8da77`, checked read-only on
2026-11-20).

1. Choose an ID you control, in reverse-domain form, e.g.
   `ph.<your-school-or-name>.learnlite`. It can never change after
   publishing. Check that Google Play shows no app with it.
2. Register it in Firebase (Console → Project settings → Your apps → Add app
   → Android), or:
   ```powershell
   firebase apps:create android "LearnLite" --package-name <new.id> --project learnlite-f1dd5
   firebase apps:android:sha:create <new-app-id> 16:98:E5:0A:3D:83:52:5E:11:10:A0:D4:EF:D3:26:18:2B:15:71:70 --project learnlite-f1dd5
   firebase apps:sdkconfig android <new-app-id> --project learnlite-f1dd5 > mobile\android\app\google-services.json
   ```
3. In `mobile/android/app/build.gradle.kts` set `applicationId = "<new.id>"`
   (keep `namespace` or change it together with the Kotlin package folder of
   `MainActivity`).
4. Run `mobile\tool\verify.ps1 -Build`, install, register and sign in.

Local progress is stored per application ID, so phones that had
`com.example.learnlite` start fresh under the new ID (accounts are kept in
Firebase).

## 3. Restrict the Firebase API key

The Android key in `google-services.json` is public by design, but it should
only work for LearnLite. In Google Cloud Console → APIs & Services →
Credentials → the "Android key (auto created by Firebase)":

1. **Application restrictions:** Android apps → add the package name (current
   or new ID) with SHA-1 `16:98:E5:…:71:70` (release) **and** your debug SHA-1
   (`keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android`)
   so test builds keep working.
2. **API restrictions:** restrict to *Identity Toolkit API* and *Token Service
   API* (all LearnLite uses).
3. Check: sign in on a debug build and on a release build. If sign-in fails
   with "API key not valid", a fingerprint or package name is missing.

Also in Firebase Console → Authentication → Settings: keep only the
Email/Password provider enabled, and turn on email enumeration protection.

## 4. Real-account checks (Phase 2)

Automated checks against the Firebase Auth emulator cover register,
duplicate email, invalid email, weak password, wrong password, logout,
account isolation, quiz with an account, a deleted account and no network
(`mobile/integration_test/auth_flow_test.dart`). What remains needs your
inbox and the live project:

1. On a phone or emulator, register account B with an email you can open;
   click the verification link; sign in.
2. Take one lesson quiz as B; confirm the result shows e.g. "3 / 5 · 60%".
3. Sign out, sign in as account A; confirm A's XP and lessons are unchanged
   and B's quiz is not shown.
4. Firebase Console → Authentication → Users: both accounts are listed.

## 5. Physical phone pass (Phase 8)

Install `release/LearnLite-1.0.0-arm64-v8a.apk` on the TECNO Spark Go 2 (use
the universal APK if Android says the app is not compatible). Android will
refuse it over the old debug build because the signature differs; uninstalling
that build first deletes the phone's local progress. Then: register or sign
in, open a lesson, take a quiz, use flashcards, open Offline downloads →
"Subanen word list (PDF)" → download → Open, switch to airplane mode and
repeat, restart the phone and confirm progress is still there. For the
Tutor, run the bridge on the PC (README) and allow TCP 8000 in Windows
Firewall.

## 6. Source materials still needed

No licensed Subanen pronunciation audio or published dictionary exists in
the project, and none could be found that may be redistributed. LearnLite
will not invent either. To add them:

- **Audio:** recordings by a fluent speaker who agrees to their use (written
  permission), one file per workbook entry, named by its workbook row. Admins
  can attach audio per entry in the Dictionary admin screen today.
- **Review:** a fluent speaker marks entries verified in the admin screen;
  the word-list PDF and dictionary then show "Verified".
