# Edge TTS Module for Wippy

Text-to-Speech module using Microsoft Edge Read Aloud service. Supports 400+ voices
in 100+ languages, free, no API key required.

## Installation

Add to your project's dependencies in `_index.yaml`:

```yaml
- name: dep.edge-tts
  kind: ns.dependency
  component: butschster/edge-tts
```

## Quick Start

### 1. Register voices in `_index.yaml`

Voice entries must use `kind: registry.entry` with `meta.type: edge_tts.voice`:

```yaml
entries:
  - name: voice.ru.male
    kind: registry.entry
    meta:
      type: edge_tts.voice
      voice_id: "ru-RU-DmitryNeural"
      language: "ru-RU"
      gender: "male"
      output_format: "audio-24khz-48kbitrate-mono-mp3"
      description: "Dmitry - Russian male voice"

  - name: voice.en.female
    kind: registry.entry
    meta:
      type: edge_tts.voice
      voice_id: "en-US-JennyNeural"
      language: "en-US"
      gender: "female"
      output_format: "audio-24khz-48kbitrate-mono-mp3"
      description: "Jenny - English female voice"
```

### 2. Import in your process/function

The `edge_tts` library requires several modules available in the runtime.
List them in your process/function entry:

```yaml
- name: my_process
  kind: process.lua
  source: file://my_process.lua
  method: main
  modules:
    - logger
    - time
    - json
    - websocket
    - uuid
    - http_client
    - hash
  imports:
    edge_tts: edge_tts:tts
```

### 3. Use in Lua code

```lua
local edge_tts = require("edge_tts")

local function main()
    -- Synthesize via registry voice reference
    local audio, err = edge_tts.synthesize("app:voice.ru.male", "Привет, мир!")
    if err then
        print("Error: " .. tostring(err))
        return
    end

    -- audio.data          — raw audio bytes
    -- audio.size          — byte count
    -- audio.format        — MIME type (e.g. "audio/mpeg")
    -- audio.output_format — Edge TTS format string
    -- audio.voice_id      — voice ID used
end
```

## API

### `edge_tts.synthesize(voice_ref, text, options?)`

Synthesize speech using a registry-configured voice.

| Parameter   | Type   | Description                                          |
|-------------|--------|------------------------------------------------------|
| `voice_ref` | string | Registry reference (e.g. `app:voice.ru.male`)        |
| `text`      | string | Text to synthesize (1-5000 chars)                    |
| `options`   | table? | Override rate, volume, pitch, output_format, timeout |

Returns: `AudioResult?, error?`

```lua
-- Basic usage
local audio, err = edge_tts.synthesize("app:voice.ru.male", "Привет!")

-- With options override
local audio, err = edge_tts.synthesize("app:voice.en.female", "Hello!", {
    rate = "+20%",
    volume = "+10%",
})
```

### `edge_tts.synthesize_direct(options)`

Direct synthesis without registry lookup. Useful for one-off calls or testing.

```lua
local audio, err = edge_tts.synthesize_direct({
    voice_id = "ru-RU-DmitryNeural",
    text = "Привет!",
    output_format = "audio-24khz-96kbitrate-mono-mp3",
    rate = "+20%",      -- speech rate (default: "+0%")
    volume = "+0%",     -- volume (default: "+0%")
    pitch = "+0Hz",     -- pitch (default: "+0Hz")
    timeout = "30s"     -- connection timeout (default: "30s")
})
```

### `edge_tts.list_voices(filter?)`

Get available voices from Microsoft Edge TTS.

```lua
-- All voices
local voices, err = edge_tts.list_voices()

-- Filter by locale
local ru_voices, err = edge_tts.list_voices({ locale = "ru-RU" })

-- Filter by locale and gender
local voices, err = edge_tts.list_voices({ locale = "en-US", gender = "Female" })
```

Returns a list of `VoiceInfo` tables:

```lua
{
    short_name = "ru-RU-DmitryNeural",
    name = "Microsoft Server Speech Text to Speech Voice (ru-RU, DmitryNeural)",
    friendly_name = "Dmitry",
    locale = "ru-RU",
    gender = "Male",
    status = "GA",
    codec = "audio-24khz-48kbitrate-mono-mp3",
    categories = { ... },
    personalities = { ... }
}
```

### AudioResult

| Field           | Type   | Description                           |
|-----------------|--------|---------------------------------------|
| `data`          | string | Raw audio bytes                       |
| `size`          | number | Byte count                            |
| `format`        | string | MIME type (auto-detected from format) |
| `output_format` | string | Edge TTS format string used           |
| `voice_id`      | string | Voice ID used                         |

## Voice Configuration

### Voice meta fields

| Field           | Required | Default                             | Description              |
|-----------------|----------|-------------------------------------|--------------------------|
| `voice_id`      | yes      | —                                   | Microsoft voice ID       |
| `language`      | no       | —                                   | Language tag (e.g. ru-RU)|
| `gender`        | no       | —                                   | male / female            |
| `output_format` | no       | `audio-24khz-48kbitrate-mono-mp3`   | Audio format string      |
| `rate`          | no       | `+0%`                               | Speech rate              |
| `volume`        | no       | `+0%`                               | Volume                   |
| `pitch`         | no       | `+0Hz`                              | Pitch                    |
| `description`   | no       | —                                   | Human-readable label     |

### Voice with prosody presets

```yaml
- name: voice.ru.fast
  kind: registry.entry
  meta:
    type: edge_tts.voice
    voice_id: "ru-RU-DmitryNeural"
    language: "ru-RU"
    rate: "+30%"
    volume: "+10%"
    pitch: "+5Hz"
    output_format: "audio-24khz-48kbitrate-mono-mp3"
```

### Full example with Telegram bot

```yaml
# _index.yaml
entries:
  # 1. Add dependency
  - name: dep.edge-tts
    kind: ns.dependency
    component: butschster/edge-tts

  # 2. Register voices
  - name: voice.ru.male
    kind: registry.entry
    meta:
      type: edge_tts.voice
      voice_id: "ru-RU-DmitryNeural"
      language: "ru-RU"
      gender: "male"
      output_format: "audio-24khz-48kbitrate-mono-mp3"

  - name: voice.en.female
    kind: registry.entry
    meta:
      type: edge_tts.voice
      voice_id: "en-US-JennyNeural"
      language: "en-US"
      gender: "female"
      output_format: "audio-24khz-48kbitrate-mono-mp3"

  # 3. Use in a process (include all required modules)
  - name: my_session
    kind: process.lua
    source: file://session.lua
    method: main
    modules:
      - funcs
      - logger
      - time
      - json
      - websocket
      - uuid
      - http_client
      - hash
    imports:
      edge_tts: edge_tts:tts
```

```lua
-- session.lua
local edge_tts = require("edge_tts")
local funcs = require("funcs")

local VOICE_MAP = {
    ru = "app:voice.ru.male",
    en = "app:voice.en.female",
}

local function send_voice(chat_id, text, lang)
    local voice_ref = VOICE_MAP[lang] or VOICE_MAP["en"]

    local audio, err = edge_tts.synthesize(voice_ref, text)
    if err then
        return nil, err
    end

    -- Send as Telegram voice/audio message
    return funcs.call("telegram.sdk:send_voice", {
        chat_id = chat_id,
        voice_bytes = audio.data,
        filename = "voice.mp3",
        content_type = audio.format,  -- "audio/mpeg" for MP3
    })
end
```

## Supported Audio Formats

The free Edge TTS WebSocket endpoint does **not** support all formats from the
official Azure Speech REST API. Only these have been verified to work:

| Format string                        | MIME type    | Status      |
|--------------------------------------|-------------|-------------|
| `audio-24khz-48kbitrate-mono-mp3`    | audio/mpeg  | Works       |
| `audio-24khz-96kbitrate-mono-mp3`    | audio/mpeg  | Works       |
| `audio-48khz-192kbitrate-mono-mp3`   | audio/mpeg  | Works       |
| `webm-24khz-16bit-mono-opus`         | audio/webm  | Works       |
| `ogg-24khz-16bit-mono-opus`          | audio/ogg   | Not working |
| `ogg-16khz-16bit-mono-opus`          | audio/ogg   | Not working |

**Recommendation**: Use `audio-24khz-48kbitrate-mono-mp3` as the default.
OGG Opus formats are accepted by the server (no connection error) but produce
no audio data — the server sends `turn.start` and `response` messages but
never sends binary audio frames.

### Telegram voice messages

Telegram's native voice player (waveform + transcription) requires OGG Opus format.
Since the free Edge TTS endpoint doesn't support OGG output, voice messages sent
as MP3 will appear as regular audio files without the voice player UI. To get
the native voice experience, you need server-side conversion (e.g. ffmpeg).

## Popular Voices

| Voice ID               | Language     | Gender |
|------------------------|--------------|--------|
| `ru-RU-DmitryNeural`   | Russian      | Male   |
| `ru-RU-SvetlanaNeural` | Russian      | Female |
| `en-US-GuyNeural`      | English (US) | Male   |
| `en-US-JennyNeural`    | English (US) | Female |
| `en-US-AriaNeural`     | English (US) | Female |
| `en-GB-SoniaNeural`    | English (UK) | Female |
| `de-DE-ConradNeural`   | German       | Male   |
| `uk-UA-OstapNeural`    | Ukrainian    | Male   |

Use `edge_tts.list_voices()` to discover all 400+ available voices.

## License

MIT
