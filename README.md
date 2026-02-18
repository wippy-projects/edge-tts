# Edge TTS Module for Wippy

Text-to-Speech module using Microsoft Edge Read Aloud service. Supports 400+ voices
in 100+ languages, free, no API key required.

## Installation

Add to your project's dependencies:

```yaml
  - name: dep.edge-tts
    kind: ns.dependency
    component: butschster/edge-tts
```

## Quick Start

### 1. Configure voices in `_index.yaml`

```yaml
entries:
  - name: voice.ru.male
    kind: edge_tts.voice
    meta:
      voice_id: "ru-RU-DmitryNeural"
      language: "ru-RU"
      gender: "male"

  - name: voice.en.female
    kind: edge_tts.voice
    meta:
      voice_id: "en-US-JennyNeural"
      language: "en-US"
      gender: "female"
```

### 2. Use in your handler

```yaml
  - name: my_handler
    kind: function.lua
    source: file://handler.lua
    method: main
    modules: [ edge_tts, json ]
```

```lua
local edge_tts = require("edge_tts")

local function main()
    -- Synthesize via registry name
    local audio, err = edge_tts.synthesize("app:voice.ru.male", "Привет, мир!")
    if err then
        return nil, err
    end

    -- audio.data   — raw audio bytes (MP3 by default)
    -- audio.size   — byte count
    -- audio.format — MIME type ("audio/mpeg")
end
```

## API

### `edge_tts.synthesize(voice_ref, text, options?)`

Synthesize speech using a registry-configured voice.

| Parameter   | Type   | Description                                          |
|-------------|--------|------------------------------------------------------|
| `voice_ref` | string | Registry reference (`namespace:name`)                |
| `text`      | string | Text to synthesize (1-5000 chars)                    |
| `options`   | table? | Override rate, volume, pitch, output_format, timeout |

Returns: `AudioResult, error`

### `edge_tts.synthesize_direct(options)`

Direct synthesis without registry lookup.

```lua
local audio, err = edge_tts.synthesize_direct({
    voice_id = "ru-RU-DmitryNeural",
    text = "Привет!",
    output_format = "ogg-24khz-16bit-mono-opus",  -- for Telegram
    rate = "+20%",
    volume = "+0%",
    pitch = "+0Hz",
    timeout = "30s"
})
```

### `edge_tts.list_voices(filter?)`

Get available voices from Microsoft Edge TTS.

```lua
-- All voices
local voices, err = edge_tts.list_voices()

-- Filter by locale
local ru_voices, err = edge_tts.list_voices({locale = "ru-RU"})

-- Filter by locale and gender
local voices, err = edge_tts.list_voices({locale = "en-US", gender = "Female"})
```

### AudioResult

| Field           | Type   | Description            |
|-----------------|--------|------------------------|
| `data`          | string | Raw audio bytes        |
| `size`          | number | Byte count             |
| `format`        | string | MIME type              |
| `output_format` | string | Edge TTS format string |
| `voice_id`      | string | Voice ID used          |

## Voice Configuration

### Basic voice

```yaml
- name: voice.ru.male
  kind: edge_tts.voice
  meta:
    voice_id: "ru-RU-DmitryNeural"
    language: "ru-RU"
    gender: "male"
```

### Voice for Telegram (OGG Opus)

```yaml
- name: voice.ru.male.tg
  kind: edge_tts.voice
  meta:
    voice_id: "ru-RU-DmitryNeural"
    language: "ru-RU"
    gender: "male"
    output_format: "ogg-24khz-16bit-mono-opus"
```

### Voice with prosody presets

```yaml
- name: voice.ru.fast
  kind: edge_tts.voice
  meta:
    voice_id: "ru-RU-DmitryNeural"
    language: "ru-RU"
    rate: "+30%"
    volume: "+10%"
    pitch: "+5Hz"
```

## Supported Audio Formats

| Format        | output_format string              | Use case                |
|---------------|-----------------------------------|-------------------------|
| MP3 (default) | `audio-24khz-48kbitrate-mono-mp3` | Universal               |
| OGG Opus      | `ogg-24khz-16bit-mono-opus`       | Telegram voice messages |
| WebM Opus     | `webm-24khz-16bit-mono-opus`      | Web players             |
| WAV           | `riff-24khz-16bit-mono-pcm`       | Lossless                |
| FLAC          | `audio-24khz-16bit-mono-flac`     | Lossless compressed     |

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
