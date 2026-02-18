local websocket = require("websocket")
local json = require("json")
local uuid = require("uuid")
local time = require("time")

-- ── Constants ────────────────────────────────────────────

local TRUSTED_CLIENT_TOKEN = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"

local WSS_URL = "wss://speech.platform.bing.com/consumer/speech/synthesize/"
    .. "readaloud/edge/v1?TrustedClientToken=" .. TRUSTED_CLIENT_TOKEN

local VOICE_LIST_URL = "https://speech.platform.bing.com/consumer/speech/synthesize/"
    .. "readaloud/voices/list?trustedclienttoken=" .. TRUSTED_CLIENT_TOKEN

local USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    .. "AppleWebKit/537.36 (KHTML, like Gecko) "
    .. "Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0"

local ORIGIN = "chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold"

local DEFAULT_OUTPUT_FORMAT = "audio-24khz-48kbitrate-mono-mp3"

-- ── Type Definitions ─────────────────────────────────────

type SynthesizeDirectOptions = {
    voice_id: string,
    text: string,
    output_format?: string,
    rate?: string,
    volume?: string,
    pitch?: string,
    timeout?: string | number
}

type AudioResult = {
    data: string,
    size: number,
    format: string,
    output_format: string,
    voice_id: string
}

type VoiceFilter = {
    locale?: string,
    gender?: string
}

type VoiceInfo = {
    short_name: string,
    name: string,
    friendly_name: string,
    locale: string,
    gender: string,
    status: string,
    codec: string,
    categories: {string},
    personalities: {string}
}

-- ── MIME Type Detection ──────────────────────────────────

local function detect_mime_type(output_format: string): string
    if output_format:find("mp3") then
        return "audio/mpeg"
    elseif output_format:find("ogg") then
        return "audio/ogg"
    elseif output_format:find("webm") then
        return "audio/webm"
    elseif output_format:find("riff") or output_format:find("pcm") then
        return "audio/wav"
    elseif output_format:find("flac") then
        return "audio/flac"
    elseif output_format:find("opus") then
        return "audio/opus"
    else
        return "application/octet-stream"
    end
end

local function detect_extension(output_format: string): string
    if output_format:find("mp3") then return ".mp3"
    elseif output_format:find("ogg") then return ".ogg"
    elseif output_format:find("webm") then return ".webm"
    elseif output_format:find("riff") or output_format:find("pcm") then return ".wav"
    elseif output_format:find("flac") then return ".flac"
    else return ".bin"
    end
end

-- ── SSML Builder ─────────────────────────────────────────

local function build_ssml(voice_id: string, text: string, rate: string, volume: string, pitch: string): string
    -- Escape XML special characters
    local escaped = text
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
        :gsub('"', "&quot;")
        :gsub("'", "&apos;")

    -- Extract language from voice_id (e.g., "ru-RU" from "ru-RU-DmitryNeural")
    local lang = voice_id:match("^(%a+%-%a+)%-")
    if not lang then
        lang = "en-US"
    end

    return string.format(
        "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='%s'>"
        .. "<voice name='%s'>"
        .. "<prosody pitch='%s' rate='%s' volume='%s'>"
        .. "%s"
        .. "</prosody>"
        .. "</voice>"
        .. "</speak>",
        lang, voice_id, pitch, rate, volume, escaped
    )
end

-- ── Message Formatting ───────────────────────────────────

local function generate_request_id(): string
    return uuid.v4():gsub("-", "")
end

local function date_to_string(): string
    return os.date("!%a %b %d %Y %H:%M:%S GMT+0000 (Coordinated Universal Time)")
end

local function format_config_message(request_id: string, output_format: string): string
    return string.format(
        "X-Timestamp:%s\r\n"
        .. "Content-Type:application/json; charset=utf-8\r\n"
        .. "Path:speech.config\r\n\r\n"
        .. '{"context":{"synthesis":{"audio":{"metadataoptions":'
        .. '{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"true"},'
        .. '"outputFormat":"%s"}}}}',
        date_to_string(), output_format
    )
end

local function format_ssml_message(request_id: string, ssml: string): string
    return string.format(
        "X-RequestId:%s\r\n"
        .. "Content-Type:application/ssml+xml\r\n"
        .. "X-Timestamp:%s\r\n"
        .. "Path:ssml\r\n\r\n"
        .. "%s",
        request_id, date_to_string(), ssml
    )
end

-- ── Binary Message Parsing ───────────────────────────────

local function extract_audio_from_binary(data: string): string?
    if #data < 4 then
        return nil
    end

    -- First 2 bytes: header length (big-endian uint16)
    local header_len = string.byte(data, 1) * 256 + string.byte(data, 2)

    -- Check if this is an audio path message
    local headers = data:sub(3, 2 + header_len)
    if not headers:find("Path:audio") then
        return nil
    end

    -- Audio data starts after: 2 bytes length + header_len bytes
    local audio_start = 2 + header_len + 1  -- +1 for Lua 1-indexing

    if audio_start > #data then
        return nil
    end

    return data:sub(audio_start)
end

-- ── Core: synthesize_direct ──────────────────────────────

local function synthesize_direct(options: SynthesizeDirectOptions): (AudioResult?, error?)
    -- 1. Validate input
    if not options.voice_id or options.voice_id == "" then
        return nil, errors.new({kind = errors.INVALID, message = "voice_id is required"})
    end
    if not options.text or options.text == "" then
        return nil, errors.new({kind = errors.INVALID, message = "text is required"})
    end
    if #options.text > 5000 then
        return nil, errors.new({kind = errors.INVALID, message = "text too long (max 5000 chars)"})
    end

    local rate = options.rate or "+0%"
    local volume = options.volume or "+0%"
    local pitch = options.pitch or "+0Hz"
    local output_format = options.output_format or DEFAULT_OUTPUT_FORMAT
    local timeout = options.timeout or "30s"

    -- 2. Connect WebSocket
    local client, err = websocket.connect(WSS_URL, {
        headers = {
            ["Origin"] = ORIGIN,
            ["User-Agent"] = USER_AGENT,
            ["Pragma"] = "no-cache",
            ["Cache-Control"] = "no-cache"
        },
        dial_timeout = timeout
    })
    if err then
        return nil, err
    end

    -- 3. Send speech.config
    local request_id = generate_request_id()
    local config_msg = format_config_message(request_id, output_format)
    local ok, send_err = client:send(config_msg)
    if send_err then
        client:close()
        return nil, send_err
    end

    -- 4. Send SSML
    local ssml = build_ssml(options.voice_id, options.text, rate, volume, pitch)
    local ssml_msg = format_ssml_message(request_id, ssml)
    ok, send_err = client:send(ssml_msg)
    if send_err then
        client:close()
        return nil, send_err
    end

    -- 5. Receive audio chunks
    local audio_chunks = {}
    local ch = client:channel()
    local timeout_ch = time.after(timeout)

    while true do
        local r = channel.select {
            ch:case_receive(),
            timeout_ch:case_receive()
        }

        if r.channel == timeout_ch then
            client:close()
            return nil, errors.new({kind = errors.TIMEOUT, message = "TTS synthesis timed out"})
        end

        if not r.ok then
            break -- connection closed
        end

        local msg = r.value
        if msg.type == "binary" then
            local audio_data = extract_audio_from_binary(msg.data)
            if audio_data then
                table.insert(audio_chunks, audio_data)
            end
        elseif msg.type == "text" then
            if string.find(msg.data, "Path:turn.end") then
                break
            end
        end
    end

    client:close()

    -- 6. Assemble result
    if #audio_chunks == 0 then
        return nil, errors.new({kind = errors.INTERNAL, message = "No audio data received"})
    end

    local audio_data = table.concat(audio_chunks)
    return {
        data = audio_data,
        size = #audio_data,
        format = detect_mime_type(output_format),
        output_format = output_format,
        voice_id = options.voice_id
    }
end

-- ── Registry: synthesize ─────────────────────────────────

local function synthesize(voice_ref: string, text: string, options: table?): (AudioResult?, error?)
    options = options or {}

    local registry = require("registry")

    -- 1. Lookup voice entry in registry
    local entry, err = registry.get(voice_ref)
    if err then
        return nil, errors.new({
            kind = errors.NOT_FOUND,
            message = "Voice not found in registry: " .. voice_ref
        })
    end

    -- 2. Validate entry kind
    if entry.kind ~= "edge_tts.voice" then
        return nil, errors.new({
            kind = errors.INVALID,
            message = "Entry is not edge_tts.voice: " .. entry.kind
        })
    end

    -- 3. Validate required meta
    local meta = entry.meta or {}
    if not meta.voice_id or meta.voice_id == "" then
        return nil, errors.new({
            kind = errors.INVALID,
            message = "Voice entry missing voice_id in meta: " .. voice_ref
        })
    end

    -- 4. Merge: per-call options override meta defaults
    local synth_options: SynthesizeDirectOptions = {
        voice_id = meta.voice_id,
        text = text,
        output_format = options.output_format or meta.output_format or DEFAULT_OUTPUT_FORMAT,
        rate = options.rate or meta.rate or "+0%",
        volume = options.volume or meta.volume or "+0%",
        pitch = options.pitch or meta.pitch or "+0Hz",
        timeout = options.timeout or "30s"
    }

    -- 5. Delegate to synthesize_direct
    return synthesize_direct(synth_options)
end

-- ── Voice Discovery ──────────────────────────────────────

local cached_voices = nil
local cache_timestamp = 0
local CACHE_TTL = 3600 -- 1 hour

local function apply_filter(voices: {VoiceInfo}, filter: VoiceFilter?): {VoiceInfo}
    if not filter then
        return voices
    end

    local result = {}
    for _, v in ipairs(voices) do
        local match = true
        if filter.locale and v.locale ~= filter.locale then
            match = false
        end
        if filter.gender and v.gender ~= filter.gender then
            match = false
        end
        if match then
            table.insert(result, v)
        end
    end
    return result
end

local function list_voices(filter: VoiceFilter?): ({VoiceInfo}?, error?)
    -- Check cache
    local now = os.time()
    if cached_voices and (now - cache_timestamp) < CACHE_TTL then
        return apply_filter(cached_voices, filter)
    end

    -- Fetch from API
    local http_client = require("http_client")
    local resp, err = http_client.get(VOICE_LIST_URL, {
        headers = {
            ["User-Agent"] = USER_AGENT,
            ["Accept"] = "*/*"
        },
        timeout = "10s"
    })

    if err then
        -- Return stale cache if available
        if cached_voices then
            return apply_filter(cached_voices, filter)
        end
        return nil, err
    end

    if resp.status_code ~= 200 then
        if cached_voices then
            return apply_filter(cached_voices, filter)
        end
        return nil, errors.new({
            kind = errors.INTERNAL,
            message = "Voice list API returned " .. resp.status_code
        })
    end

    -- Parse response
    local voices_raw = json.decode(resp.body)
    local voices: {VoiceInfo} = {}
    for _, v in ipairs(voices_raw) do
        table.insert(voices, {
            short_name = v.ShortName,
            name = v.Name,
            friendly_name = v.FriendlyName,
            locale = v.Locale,
            gender = v.Gender,
            status = v.Status or "GA",
            codec = v.SuggestedCodec or "",
            categories = (v.VoiceTag and v.VoiceTag.ContentCategories) or {},
            personalities = (v.VoiceTag and v.VoiceTag.VoicePersonalities) or {}
        })
    end

    -- Update cache
    cached_voices = voices
    cache_timestamp = now

    return apply_filter(voices, filter)
end

-- ── Module Export ─────────────────────────────────────────

return {
    synthesize_direct = synthesize_direct,
    synthesize = synthesize,
    list_voices = list_voices,
    detect_mime_type = detect_mime_type,
    detect_extension = detect_extension
}
