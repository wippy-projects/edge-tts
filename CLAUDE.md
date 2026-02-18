# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A publishable Wippy Hub package (`butschster/edge_tts`) that provides Text-to-Speech synthesis
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
- `edge_tts.voice` — Entry kind for voice configurations

### Key patterns

**Registry-based voice configuration**: Voices are registered as `edge_tts.voice` entries in
`_index.yaml` with `meta` fields for `voice_id`, `language`, `gender`, `output_format`, and
prosody settings (`rate`, `volume`, `pitch`). The `synthesize()` function looks up voices by
registry reference.

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
| `edge_tts.voice` | Voice configuration with meta fields      |

## Lua conventions

- Core logic in `src/tts.lua` as a library module
- Error handling follows `result, err` two-return pattern
- Type definitions use Luau-style annotations
- Modules declared in `_index.yaml` entry definitions
- Built-in globals (`process`, `channel`) used directly, never `require()`d
- Required modules (`websocket`, `json`, `uuid`, `http_client`, `time`) declared in registry

## WebSocket Protocol

Edge TTS uses `wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1`
with a `TrustedClientToken` parameter. The protocol flow is:

1. Connect WebSocket with browser-like headers
2. Send `speech.config` (output format)
3. Send SSML with voice, prosody, and text
4. Receive binary audio chunks until `turn.end`
5. Close connection

## Wippy Documentation

- Docs site: https://home.wj.wippy.ai/
- LLM-friendly index: https://home.wj.wippy.ai/llms.txt
