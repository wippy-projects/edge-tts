# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A publishable Wippy Hub package (`butschster/edge-tts`) that provides Text-to-Speech synthesis
using Microsoft Edge Read Aloud service via WebSocket. It is a **library package** — consumers
use the `edge_tts` Lua module in their functions/processes to synthesize speech from text.

## Commands

```bash
# Start the dev server (uses dev/ as the app entry point via wippy.lock)
wippy run

# Lint the module
wippy lint --ns=edge_tts
wippy lint --ns=edge_tts.*
```

## Architecture

### Namespace hierarchy

- `edge_tts` (root) — `ns.definition`, core TTS library

### Key patterns

**Registry-based voice configuration**: Voices are registered as `registry.entry` entries in
the consumer's `_index.yaml` with `meta.type: edge_tts.voice` and fields for `voice_id`,
`language`, `gender`, `output_format`, and prosody settings (`rate`, `volume`, `pitch`).
The `synthesize()` function looks up voices by registry reference and validates
`meta.type == "edge_tts.voice"`.

**Important**: Voice entries must use `kind: registry.entry` (not `kind: edge_tts.voice`),
because the runtime has no built-in handler for the `edge_tts.voice` kind. The type is
identified via `meta.type` instead.

**Per-request WebSocket**: Each `synthesize_direct()` call creates its own WebSocket connection
to Edge TTS, sends SSML, collects audio chunks, and closes. No shared state between calls.

**Two-level API**:

- `edge_tts.synthesize(voice_ref, text, options?)` — uses registry-configured voices
- `edge_tts.synthesize_direct(options)` — direct synthesis without registry
- `edge_tts.list_voices(filter?)` — discover available voices from Microsoft

### Entry kinds used

| Kind             | Purpose                                   |
|------------------|-------------------------------------------|
| `ns.definition`  | Package metadata                          |
| `library.lua`    | Core TTS module (synthesize_direct, etc.) |

### Required modules

The library depends on: `websocket`, `json`, `uuid`, `time`, `hash`, `logger`.
Consumers must include all of these in their process/function `modules` list.

## Audio Format Limitations (Free Edge TTS Endpoint)

The free Edge TTS WebSocket endpoint (`speech.platform.bing.com`) does **NOT** support all
formats listed in the official Azure Speech REST API. Tested results:

| Format                              | Status      | Notes                                    |
|-------------------------------------|-------------|------------------------------------------|
| `audio-24khz-48kbitrate-mono-mp3`   | **Works**   | Default, recommended                     |
| `audio-24khz-96kbitrate-mono-mp3`   | **Works**   | Higher quality MP3                       |
| `webm-24khz-16bit-mono-opus`        | **Works**   | Opus in WebM container                   |
| `ogg-24khz-16bit-mono-opus`         | **Broken**  | Server accepts but sends no audio data   |
| `ogg-16khz-16bit-mono-opus`         | **Broken**  | Same — no audio data                     |

**For Telegram voice messages**: Telegram requires OGG Opus for native voice player (waveform
+ transcription). Since the free endpoint doesn't support OGG, you must either:
- Use MP3 (sent as audio file, no waveform/transcription)
- Convert MP3/WebM to OGG Opus server-side (requires ffmpeg or similar)

## WebSocket Protocol

Edge TTS uses `wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1`
with authentication parameters:

1. **Connect** WebSocket with:
   - URL params: `TrustedClientToken`, `Sec-MS-GEC` (SHA-256 token), `Sec-MS-GEC-Version`, `ConnectionId`
   - Headers: `Origin`, `User-Agent`, `Pragma`, `Cache-Control`, `Accept-Encoding`, `Accept-Language`, `Cookie` (muid)
2. **Send** `speech.config` (output format, metadata options)
3. **Send** SSML with voice, prosody, and text
4. **Receive** text frames: `Path:turn.start`, `Path:response`
5. **Receive** binary frames: audio chunks (header + `Path:audio` + raw audio data)
6. **Receive** text frame: `Path:turn.end`
7. **Close** connection

### Sec-MS-GEC Token

Microsoft requires a `Sec-MS-GEC` token for authentication (added ~Oct 2024).
Algorithm: take current Unix timestamp, add Windows epoch offset (11644473600),
round down to 5-minute intervals, multiply by 10^7, concatenate with TrustedClientToken,
SHA-256 hash, uppercase hex. Must use integer math (`%d` format) to avoid float64 precision
loss on the ~1.3×10^17 tick value.

## Lua conventions

- Core logic in `src/tts.lua` as a library module
- Error handling follows `result, err` two-return pattern
- Type definitions use Luau-style annotations
- Modules declared in `_index.yaml` entry definitions
- Built-in globals (`process`, `channel`) used directly, never `require()`d
- Required modules: `websocket`, `json`, `uuid`, `http_client`, `time`, `hash`, `logger`

## Wippy Documentation

- Docs site: https://wippy.ai/
- LLM-friendly index: https://wippy.ai/llms.txt
