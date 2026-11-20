# LearnLite emulator test report

- **Date:** 2026-11-20
- **Build under test:** release APK, version 1.0.0 (1), signed with the LearnLite release key (SHA-256 `9b32465d…0e2cc4dc`), Tutor address `http://10.0.2.2:8000` with the LAN opt-in. Branch `learnlite-roadmap`.
- **Host:** Windows 11, 6 logical cores, 7.6 GB RAM, Android Emulator with software rendering (`swiftshader_indirect`), headless.

Everything below was executed. Nothing here is a physical-device result;
the physical-phone pass is still open (see [OWNER_ACTIONS.md](../OWNER_ACTIONS.md) §5).

## Device profiles

| AVD | Profile | Android | Screen | RAM / cores | Used for |
|---|---|---|---|---|---|
| `LL_Phone_API36` | Pixel 5 | 16 (API 36) | 1080×2340, 440 dpi | 2 GB / 2 | Account integration test, clean install, offline walkthrough, screenshots |
| `LL_Tablet_API36` | Pixel Tablet | 16 (API 36) | 2560×1600, 320 dpi | 2 GB / 2 | Large-screen layout |
| `Flutter_Emulator` | existing | 16 (API 36) | 1080×2400 | existing | Owner's device with account A; release ↔ debug data check and live Tutor (earlier today) |
| Low-end, minimum Android (API 24) | planned | 7.0 | — | 1.5 GB / 2 | **Blocked:** the system image download from `dl.google.com` failed three times (stalled at 766 MB, then network errors). |

## Results

| Area | Result | Evidence |
|---|---|---|
| Clean install and first launch | PASS | Uninstalled, installed the release APK, launched: login screen in 16.3 s (first run includes the one-time workbook import). Memory after launch: 90 MB PSS. |
| Registration, duplicates, invalid email, weak password | PASS | `integration_test/auth_flow_test.dart` against the Firebase Auth emulator (project `demo-learnlite`), 7/7. |
| Wrong password, unknown account, username instead of email | PASS | Same test. Message: "Email or password is incorrect." |
| Email verification gate | PASS | Unverified account cannot use the Tutor; after the emulator's verification link, sign-in succeeds. |
| Quiz with an authenticated account | PASS | Same test: verified account A takes a workbook lesson quiz; XP and attempt saved. |
| Logout keeps data; A/B isolation | PASS | Same test: A's XP unchanged after sign-out; B starts at 0 with no module progress; A unchanged after B. |
| Deleted account | PASS | Same test: the session ends and the app returns to sign-in. |
| No network at sign-in | PASS after fix | Found **F15**: the SDK reported `unknown`, so learners saw a vague error. Fixed; now "Could not reach Firebase…". |
| Guest (offline) learning | PASS after fixes | Airplane mode on (ping: network unreachable). Lessons list, lesson word cards, lesson quiz (submitted: "2 / 5 correct · 40%", +17 XP), flashcards, practice filters, progress. Found and fixed **F16–F18** (below). |
| Word-list PDF | PASS | Downloaded (65.9 KB), opened in airplane mode in Android's print preview: 13 pages, 251 entries, every one with its workbook status. Share/save and remove available. |
| Restart persistence | PASS | Force-stop and relaunch offline: XP 17, 1 lesson, 1-day streak kept. Relaunch 7.0 s. |
| Upgrade install | PASS | `adb install -r` of a newer release build kept progress and the saved PDF. Earlier: release ↔ debug installs on `Flutter_Emulator` left the database identical (all table counts, XP, 0 duplicates). |
| AI Tutor | PASS (earlier run) | `Flutter_Emulator`, release build, signed in as account A: `qwen2.5:3b` answered with workbook entries labelled pending review. Guest sees "Sign in with a verified LearnLite account…". Bridge tests 9/9 including stopped Ollama and timeout. |
| Large screen | PASS | Tablet: login card centred at reading width; Home uses two columns (Continue learning / Daily Word). |
| Network interruption | PASS | Airplane on → learning continued; airplane off → host reachable (`10.0.2.2`). |
| Background/foreground resume | NOT RUN | Only force-stop/relaunch was exercised. |
| Battery usage | NOT MEASURED | Emulators do not give meaningful battery data; measure on the phone. |
| Android 7.0 (minimum) and low-end profile | BLOCKED | Image download failed; see profiles. |

## Bugs found during emulator testing

| ID | Bug | Fix |
|---|---|---|
| F15 | Sign-in without a reachable server showed "Firebase sign-in could not be completed" instead of the offline guidance (SDK code `unknown`). | `normalizedAuthErrorCode` maps network-type `unknown`/`internal-error` to `network-request-failed`; unit and device tests. |
| F16 | Guests always saw 0 XP, Level 0 on Home/Progress, whatever they had learned. | `fetchProfile()` returns the offline-guest profile; the shell loads and refreshes it. Unit test. |
| F17 | "Welcome," with no name for profiles without a name. | Falls back to the next non-blank name, then "learner". |
| F18 | Start Quiz kept the lesson's scroll offset, opening at the last question. | Each lesson view gets its own scroll position. Widget test. |
| F19 | Offline downloads said only verified entries can be downloaded (no longer true). | Text corrected. |

## Environment limitations

- The emulators share 7.6 GB with the IDE, Gradle, the Auth emulator and Ollama. Android's own processes (System UI, launcher, Digital Wellbeing) repeatedly showed "isn't responding" during first boot and builds; LearnLite's threads were idle at those times (trace checked on `Flutter_Emulator`). These are host limits, not app defects (F14).
- Software rendering makes startup slower than on real hardware; the timings above are upper bounds, not phone figures.
- The Tutor on an emulator reaches Ollama on the PC through `10.0.2.2`. That is local-network AI, not on-device AI (D6).

## How to repeat

```powershell
# 1. Account flows (repo root, then mobile/ copy)
firebase emulators:start --only auth --project demo-learnlite
flutter test integration_test/auth_flow_test.dart -d <test-avd> --dart-define=LEARNLITE_AUTH_EMULATOR=10.0.2.2:9099
# 2. Release build for an emulator with the Tutor bridge on the PC
flutter build apk --release --dart-define=LEARNLITE_API_BASE_URL=http://10.0.2.2:8000 --dart-define=LEARNLITE_ALLOW_LAN_HTTP=true
```

Use a dedicated test AVD: the integration test installs LearnLite and may
uninstall it afterwards, which deletes that device's local progress.

Screenshots from these runs: [docs/screenshots](screenshots/).
