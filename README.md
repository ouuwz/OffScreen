# Offscreen

### A little more outside.

**An open-source project that helps you put your phone down, get
outside, and make the time count.**

[![License:
MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Web-8bcf68)](#platforms)
[![AI](https://img.shields.io/badge/AI-local%20inference-8bcf68)](#how-the-ai-works)

[GitHub](https://github.com/ouuwz) · [Telegram](https://t.me/ouuwz)
:::

------------------------------------------------------------------------

## What is Offscreen?

Offscreen helps you turn screen time into time spent doing something in
the real world. Pick an outdoor mission, set a timer, go do it, and keep
a private record of how you are doing.

The idea is straightforward: your phone can help you decide what to do,
then get out of the way.

Offscreen is an independent, open-source project by
**[@ouuwz](https://github.com/ouuwz)**. It is a work in progress, and
the Android and browser versions have different performance limits.

## Features

-   **Outdoor missions** --- get ideas for short activities that
    encourage you to step away from your screen.
-   **Mission timer** --- set a time for your activity and mark it
    complete when you return.
-   **Private journal** --- record completed missions and personal notes
    on your device.
-   **Progress tracking** --- review completed activities, streaks, and
    your progress over time.
-   **Local AI options** --- run supported models on your own device
    instead of sending prompts to a hosted AI service.
-   **Fallback suggestions** --- use built-in suggestions when local AI
    is unavailable or you have not loaded a model.
-   **Data controls** --- view, export, import, or delete journal data
    where supported by the platform.
-   **Android and web** --- use the native Flutter app or the browser
    version.
-   **No account required** --- the app is designed to work without
    sign-in.

> Offscreen is a tool, not a screen-time police officer. Start with one
> small mission and make it your own.

## Platforms

  ------------------------------------------------------------------------
  Version           Technology        AI runtime        Notes
  ----------------- ----------------- ----------------- ------------------
  Android           Flutter           Local GGUF        You choose and
                                      inference through load a compatible
                                      the app's native  model file.
                                      llama.cpp         Available memory
                                      integration       and model
                                                        compatibility
                                                        affect whether it
                                                        loads.

  Web               Vite, JavaScript, WebLLM with       The model is
                    PWA support       WebGPU on         downloaded by the
                                      supported         browser when
                                      browsers and      needed. First load
                                      devices           can take time and
                                                        use substantial
                                                        memory.

  Streamlit         Python and        Ollama            Kept as a
  prototype         Streamlit                           development
                                                        prototype; it is
                                                        separate from the
                                                        Android and
                                                        browser
                                                        implementations.
  ------------------------------------------------------------------------

Features and behavior can differ between platforms. Check the relevant
folder before assuming a feature works identically everywhere.

## Get started

### Download the app

Look at the repository's **Releases** page for published builds:

-   [Offscreen releases](https://github.com/ouuwz/Offscreen/releases)

If a release is not available yet, use the GitHub Actions build artifact
when one has completed successfully, or build from source using the
instructions below. An Actions artifact is not the same as a published
GitHub Release.

### Android: loading a local model

1.  Download a **GGUF chat/instruct model** from a trusted model
    publisher.
2.  Open Offscreen and go to **Settings**.
3.  Choose the `.gguf` model file.
4.  Tap **Load model** and wait for the load to finish.
5.  Return to the mission screen and try generating a task.

A small instruct model is the best starting point on a phone. For
example, the Qwen2.5 0.5B Instruct family has GGUF releases; choose a
quantized GGUF file that is compatible with the app's native runtime.
See the [official Qwen2.5-0.5B-Instruct-GGUF
repository](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF).

**Do not start with an embedding model.** Embedding models convert text
into vectors; they are not designed to generate mission instructions.
Offscreen's task-generation flow needs a compatible text-generation/chat
model.

The model file is separate from the app, so downloading or changing a
model does not require reinstalling Offscreen. Model compatibility is
not guaranteed for every GGUF file: architecture, quantization, GGUF
format version, context size, and the native runtime version all matter.

### Web: first launch

1.  Open the deployed Offscreen website in a browser that supports
    WebGPU.
2.  Choose the AI task-generation feature.
3.  On the first run, allow time for the selected model to download and
    initialize.
4.  If generation is too slow or the browser becomes unresponsive, try a
    smaller supported model or use the built-in fallback suggestions.

The browser version's model runs on your device. It does not have the
same memory and performance limits as a native Android app, but it still
depends on your browser, GPU, RAM, and device.

## Known limitations and current issues

Offscreen is under active development. These are real limitations, not
guarantees that every device will behave the same way.

### Android: large models may crash the app

Large GGUF models can consume more RAM than an Android device can
provide to the app. Loading a model may fail, the app may close
unexpectedly, or Android may terminate the process. A model can also
fail to load because its architecture or GGUF features are not supported
by the version of the native runtime bundled with the app.

**What to try now:**

-   Start with a small chat/instruct model, such as a compatible 0.5B
    model.
-   Avoid loading a model that is larger than your device can
    comfortably handle.
-   Close other memory-heavy apps before loading the model.
-   Check that the model download completed successfully.
-   If the model fails, try a different supported GGUF file and report
    the model name, file size, phone model, Android version, and error
    message.

**Planned work:** We know model loading needs better compatibility
checks, memory handling, and error reporting. We plan to improve this in
upcoming updates as soon as we can. Until those fixes land, large models
may still crash or fail to load. We cannot promise a specific fix date.

### Web: the browser may freeze during task generation

The browser version can become slow or appear frozen while the model
loads or generates a mission. The impact varies from device to device.
It depends on factors such as available RAM, GPU/WebGPU support, browser
implementation, model size, and whether the model has already been
cached.

**What to try now:**

-   Use a current browser with WebGPU support.
-   Try a smaller supported model.
-   Close heavy tabs and other applications.
-   On the first run, wait a little longer for the model to initialize.
-   If the page stays unresponsive, reload it and try the fallback
    suggestions.

We plan to improve responsiveness and make long-running generation
clearer in future updates. For now, a browser freeze or long pause can
happen on some devices; it does not necessarily mean your journal data
has been lost.

### AI output can be imperfect

Local models can generate repetitive, vague, or unsuitable tasks. Review
a suggestion before following it. Choose activities that fit your
location, physical ability, weather, and personal safety. Do not follow
a task that feels unsafe.

## How the AI works

Offscreen is designed around **on-device inference** where supported:

-   **Android:** the app loads a compatible `.gguf` model through its
    native inference integration.
-   **Web:** the browser version uses WebLLM and WebGPU on supported
    devices. It may download model assets into browser-managed storage.
-   **Streamlit prototype:** the prototype uses Ollama and a locally
    installed model.

Model weights are not bundled into the source repository or APK by
default. This keeps downloads manageable and lets users choose a model
that suits their hardware. You are responsible for checking a model's
licence and usage terms before downloading or redistributing it.

### Choosing a model

  -----------------------------------------------------------------------
  Model type              Suitable for mission    Why
                          generation?             
  ----------------------- ----------------------- -----------------------
  Small chat/instruct     Usually, if supported   Designed to follow
  GGUF model              by the native runtime   prompts and generate
                                                  text.

  Embedding model         No, not for direct text Produces vector
                          generation              representations rather
                                                  than ordinary task
                                                  responses.

  Very large model        Not recommended as a    High memory use can
                          first try on a phone    cause load failures,
                                                  slowdowns, or app
                                                  termination.

  WebLLM-compatible model For the browser build,  WebLLM requires a
                          if its model ID is      compatible converted
                          supported by the app    model and supported
                                                  browser hardware. A
                                                  random GGUF file cannot
                                                  be loaded directly by
                                                  WebLLM.
  -----------------------------------------------------------------------

**Android and web model formats are different.** Android's GGUF loader
and the browser's WebLLM runtime do not share a single interchangeable
model format. Check each platform's supported model list and
documentation.

## Privacy

Offscreen is designed to keep personal activity records on your device.

-   The Android journal is stored in app-private storage.
-   The browser version stores its journal in browser storage on your
    device.
-   Local model inference happens on your device when a supported model
    is loaded.
-   The app is designed to work without an account or cloud AI backend.
-   Model downloads and web hosting still require network access. A
    website host or model provider may receive ordinary connection
    information when you access or download their resources.
-   Clearing app data, uninstalling the Android app, clearing browser
    site data, or losing access to a device may remove locally stored
    records.

Export your journal if you want a separate backup. Treat exported files
as private because they may contain your notes and activity history.
Review the current code and Android permissions if you need to verify
the behavior of a particular build.

## Project structure

``` text
Offscreen/
├── android/                  # Flutter Android app
├── web/                      # Browser app and PWA
├── prototype-streamlit/      # Original Python/Streamlit prototype
├── .github/
│   └── workflows/            # CI, APK build, Pages deploy, release workflows
├── LICENSE
├── CHANGELOG.md
└── README.md
```

The exact files and workflows may change as the project develops.

## Build from source

### Android

You will need Flutter, the Android SDK, and a compatible Java/Gradle
setup.

``` bash
git clone https://github.com/ouuwz/Offscreen.git
cd Offscreen/android
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

The release APK is normally produced under:

``` text
android/build/app/outputs/flutter-apk/app-release.apk
```

If the local build fails, check the Flutter and Android Gradle Plugin
versions in the project, then review the first meaningful error in the
build log.

### Web

You will need a current Node.js LTS release and npm.

``` bash
git clone https://github.com/ouuwz/Offscreen.git
cd Offscreen/web
npm install
npm run dev
```

To make a production build:

``` bash
npm run build
npm run preview
```

The production output is written to `web/dist/`. Browser AI features
require a compatible WebLLM model configuration and WebGPU support.

### Streamlit prototype

The prototype lives in `prototype-streamlit/`. It requires Python, the
packages in `requirements.txt`, and Ollama with a compatible local
model.

On Windows, if the included launcher is present, run:

``` text
start_app.bat
```

Or run the prototype manually from its folder:

``` bash
python -m pip install -r requirements.txt
streamlit run app.py
```

For the Ollama-backed AI features, install and start Ollama separately,
then pull the model configured by the prototype. The prototype is
independent of the Flutter and web model runtimes.

## GitHub Actions and releases

This repository includes workflows intended to automate common tasks:

-   **Tests:** checks the Android code and builds the web app.
-   **Android APK:** builds an ARM64 release APK on supported workflow
    runs.
-   **GitHub Pages:** builds and deploys the web version when Pages is
    configured to use GitHub Actions.
-   **Release:** a version tag such as `v0.1.0` can trigger a release
    workflow that builds release assets.

To publish a release, push a version tag after checking that the
workflows are configured and passing:

``` bash
git tag v0.1.0
git push origin v0.1.0
```

The workflow files are configuration, not proof that a build or
deployment has succeeded. Check the **Actions** tab and **Releases**
page for the actual result. GitHub Pages may also need to be enabled in
repository settings.

## Contributing

Issues, bug reports, and pull requests are welcome.

When reporting a bug, include:

-   Platform: Android, web, or Streamlit.
-   App version or commit, if known.
-   Device, Android version, browser, and available RAM when relevant.
-   Model name, model format, and file size for AI problems.
-   Steps to reproduce the problem.
-   The full error message or a screenshot, after removing personal
    information.

Please do not upload private journal exports, access tokens, or other
sensitive data to an issue.

If you want to contribute code:

1.  Fork the repository.
2.  Create a branch for your change.
3.  Keep changes focused and test the platform you modify.
4.  Open a pull request explaining what changed and how you tested it.

## Roadmap

Work may include:

-   Better Android model compatibility checks and clearer load errors.
-   Safer memory handling for large models.
-   More responsive browser generation and clearer loading states.
-   Better fallbacks when local inference is unavailable.
-   Continued UI, accessibility, and reliability improvements.

This is a direction, not a promise that every item has a release date.

## Troubleshooting

**The Android model will not load.**\
Try a small, compatible chat/instruct GGUF model. Embedding models are
not suitable for ordinary mission generation. If it still fails, report
the device, model, file size, and error.

**The Android app closes while loading.**\
The model may exceed the app's available memory, or the runtime may not
support it. Try a smaller model and report the issue.

**The web app freezes while generating.**\
Wait briefly on the first run, use a smaller supported model, close
heavy tabs, or use fallback suggestions. Performance differs by device
and browser.

**The AI option is unavailable.**\
Check that the correct model is selected and supported by the platform.
Browser AI requires WebGPU and a compatible WebLLM model; Android
requires a supported GGUF model.

**My journal disappeared.**\
Check whether app data or browser site data was cleared, or whether the
app was reinstalled. Local storage is not a cloud backup.

**Where should I report an issue?**\
Open an issue in the [GitHub
repository](https://github.com/ouuwz/Offscreen/issues) and include the
details listed in the Contributing section.

## Credits

Created and maintained by **[@ouuwz](https://github.com/ouuwz)**.

-   GitHub: [@ouuwz](https://github.com/ouuwz)
-   Telegram: [@ouuwz](https://t.me/ouuwz)
-   Local inference: [llama.cpp](https://github.com/ggml-org/llama.cpp)
    and [WebLLM](https://github.com/mlc-ai/web-llm)
-   Example small GGUF model family:
    [Qwen2.5-0.5B-Instruct-GGUF](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF)

Offscreen is independent of the projects and model publishers linked
above. Their names and trademarks belong to their respective owners.

## License

Offscreen is released under the [MIT License](LICENSE). Third-party
dependencies and model weights may have their own separate licences and
terms.
