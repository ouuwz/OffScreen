# Offscreen Web

Vite PWA using WebLLM for browser-local inference. Requires a compatible browser with WebGPU for model inference. Built-in offline missions work if WebGPU or the model is unavailable.

```bash
npm install
npm run dev
```

Production output: `npm run build` → `dist/`.

The model is downloaded separately on first use. The site does not upload journal entries or call a hosted inference API. Offline support depends on the browser retaining the site shell and model cache; verify on the actual device.
