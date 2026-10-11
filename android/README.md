# Offscreen for Android

An offline-first nature companion. This is the Android-native version of the Streamlit prototype. It uses Flutter for the interface and `llama_flutter_android` (llama.cpp) for on-device GGUF model inference.

## What is included

- Mission builder: place, duration, energy, company, and nature interest.
- On-device open-weight model inference, with a safe built-in fallback if no model is loaded.
- Phone-down countdown and a completion action.
- Local nature journal with human-readable timestamps.
- Completed-break count, total recorded minutes, day streak, and a seven-day chart.
- Delete journal cards by swiping left; export the JSON journal using Android's share sheet and import a previous Streamlit `nature_journal.json` file.
- Model picker for a `.gguf` file; the app copies it into private app storage and remembers it.
- No account, no cloud inference, no GPS, and no `INTERNET` permission in the generated Android manifest.

## Important: the model is separate from the APK

The APK contains the app and native inference runtime, not the language model weights. This keeps the APK manageable. Download a small instruction-tuned GGUF model once and select it in **Settings**. After the model is copied and loaded, mission generation works offline. The model file itself takes additional storage (roughly hundreds of MB for a 0.5B Q4 model).

Suggested starting point: [Qwen2.5-0.5B-Instruct-GGUF on Hugging Face](https://huggingface.co/models?search=Qwen2.5-0.5B-Instruct-GGUF). Choose a Q4_K_M GGUF quantization if available. The model's licence and terms are listed on its model card; keep that information with any public release.

## Easiest build path: GitHub Actions (uses GitHub's build machine)

This avoids making your older i3 laptop compile Android native code. You will still need a GitHub account.

1. Create a **new empty public or private GitHub repository** named `Offscreen`.
2. Extract this ZIP on your computer.
3. Open the extracted folder. Upload all its contents (including the hidden `.github` folder) to the repository. The simplest way is GitHub's web upload for small files, or use GitHub Desktop.
4. Commit the files to the `main` branch. The workflow at `.github/workflows/build-apk.yml` starts automatically. You can also open the repository's **Actions** tab and run **Build Offscreen APK** using **Run workflow**.
5. Wait for the workflow to finish. Open its successful run, scroll to **Artifacts**, and download `offscreen-android-arm64-apk`.
6. Extract the artifact ZIP. It contains `app-release.apk`.
7. Transfer the APK to your Android phone, open it, and allow installation from that source if Android asks.
8. Copy the downloaded `.gguf` model onto your phone (Downloads is fine). Open Offscreen → **Settings** → **Choose .gguf model** → select the model → **Load model**.
9. Once the model loads, turn on Airplane mode and generate a mission to verify offline inference.

The build workflow runs `flutter analyze` and `flutter test` before producing the APK. A successful build is not the same as a device test, so install it and try each feature on your phone.

## Build locally on Windows instead

Install Flutter, Git, Android Studio's Android SDK, Android SDK Platform Tools, and Android NDK r27 or newer. Make sure `flutter doctor` reports that Android toolchain is ready. Then double-click `build_apk.bat`. The release APK is written to:

`build\app\outputs\flutter-apk\app-release.apk`

The first build downloads Flutter packages and Android build dependencies. You need internet for that first setup; the installed app itself has no network permission.

## Data storage

The journal JSON is stored in the app's private documents directory. Export it before uninstalling if you want to keep a copy. Android normally removes app-private data when the app is uninstalled. Model weights are stored in private app support storage; selecting a model copies it there.

## Limitations to test honestly

- The model may generate awkward or repetitive ideas. The app validates some unsafe outputs and uses a safe built-in fallback for malformed responses, but this is not a guarantee that every model output is perfect.
- Speed and memory use depend on the phone. Start with a small Q4 model, keep context at 1024, and use two CPU threads.
- The countdown measures elapsed wall-clock time and does not verify that a person physically went outside.
- Exporting uses Android's share sheet; sharing the file is the user's choice.
- This source bundle was generated without a Flutter SDK in the authoring environment, so the APK was not compiled here. Use the provided GitHub Actions build, then send any build error for troubleshooting.

## Tech

- Flutter / Dart
- `llama_flutter_android` (llama.cpp, MIT-licensed binding)
- `file_picker`, `path_provider`, `shared_preferences`, `share_plus`
- Local JSON journal


## Interaction and UI goals

The mobile interface uses a four-destination bottom navigation (Mission, Journal, Progress, Settings), animated page transitions, large touch targets, clear selected states, a circular phone-down timer, and short forms. Quick-focus chips make common mission preferences reachable without opening the dropdown. The mission and journal flow is designed to remain usable offline and to keep the user from spending unnecessary time in the app.

The public `anchildress1/wild-find` project was reviewed as a reference for product principles such as clear safety language, offline-first behavior, accessible controls, and keeping the screen time short. Offscreen has a different purpose and implementation: it creates observation missions and tracks reflections rather than identifying photographed plants. This project does not copy Wild Find's source code or claim its plant-identification capabilities.

Build and device validation are still required before treating this as release-ready. Test the APK on a real Android phone, including low-memory behavior while loading a GGUF model, reduced-motion/accessibility settings, rotation/backgrounding during the timer, and journal persistence after force-closing the app.


## Creator

Built by [@ouuwz on GitHub](https://github.com/ouuwz) · [@ouuwz on Telegram](https://t.me/ouuwz).
