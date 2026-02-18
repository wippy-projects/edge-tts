local edge_tts = require("edge_tts")
local logger = require("logger")

local function main()
    logger:info("=== Edge TTS Basic Tests ===")

    -- Test 1: Basic Russian synthesis (synthesize_direct)
    logger:info("Test 1: Basic Russian synthesis (direct)")
    local audio, err = edge_tts.synthesize_direct({
        voice_id = "ru-RU-DmitryNeural",
        text = "Привет! Это тестовое сообщение."
    })
    if err then
        logger:error("Test 1 FAILED", {error = tostring(err)})
    else
        logger:info("Test 1 PASSED", {
            size = audio.size,
            format = audio.format,
            output_format = audio.output_format,
            voice_id = audio.voice_id
        })
    end

    -- Test 2: English synthesis (direct)
    logger:info("Test 2: English synthesis (direct)")
    audio, err = edge_tts.synthesize_direct({
        voice_id = "en-US-GuyNeural",
        text = "Hello, this is a test message."
    })
    if err then
        logger:error("Test 2 FAILED", {error = tostring(err)})
    else
        logger:info("Test 2 PASSED", {size = audio.size, format = audio.format})
    end

    -- Test 3: Prosody options
    logger:info("Test 3: Prosody options")
    audio, err = edge_tts.synthesize_direct({
        voice_id = "ru-RU-SvetlanaNeural",
        text = "Быстрая речь!",
        rate = "+50%",
        pitch = "+10Hz"
    })
    if err then
        logger:error("Test 3 FAILED", {error = tostring(err)})
    else
        logger:info("Test 3 PASSED", {size = audio.size})
    end

    -- Test 4: OGG Opus format (for Telegram)
    logger:info("Test 4: OGG Opus format")
    audio, err = edge_tts.synthesize_direct({
        voice_id = "ru-RU-DmitryNeural",
        text = "Голосовое сообщение для Telegram",
        output_format = "ogg-24khz-16bit-mono-opus"
    })
    if err then
        logger:error("Test 4 FAILED", {error = tostring(err)})
    else
        logger:info("Test 4 PASSED", {
            size = audio.size,
            format = audio.format,
            output_format = audio.output_format
        })
    end

    -- Test 5: Error handling — empty text
    logger:info("Test 5: Empty text error")
    audio, err = edge_tts.synthesize_direct({
        voice_id = "ru-RU-DmitryNeural",
        text = ""
    })
    if err then
        logger:info("Test 5 PASSED", {error = tostring(err)})
    else
        logger:error("Test 5 FAILED: expected error for empty text")
    end

    -- Test 6: Error handling — missing voice_id
    logger:info("Test 6: Missing voice_id error")
    audio, err = edge_tts.synthesize_direct({
        text = "Hello"
    })
    if err then
        logger:info("Test 6 PASSED", {error = tostring(err)})
    else
        logger:error("Test 6 FAILED: expected error for missing voice_id")
    end

    -- Test 7: Synthesize via registry name
    logger:info("Test 7: Registry synthesis")
    audio, err = edge_tts.synthesize("app:voice.ru.male", "Тест через реестр")
    if err then
        logger:error("Test 7 FAILED", {error = tostring(err)})
    else
        logger:info("Test 7 PASSED", {
            size = audio.size,
            voice_id = audio.voice_id
        })
    end

    -- Test 8: Registry synthesis with OGG Opus (Telegram voice)
    logger:info("Test 8: Registry Telegram voice")
    audio, err = edge_tts.synthesize("app:voice.ru.male.tg", "Голосовое для Telegram через реестр")
    if err then
        logger:error("Test 8 FAILED", {error = tostring(err)})
    else
        logger:info("Test 8 PASSED", {
            size = audio.size,
            format = audio.format,
            output_format = audio.output_format
        })
    end

    -- Test 9: Per-call options override meta
    logger:info("Test 9: Per-call options override")
    audio, err = edge_tts.synthesize("app:voice.ru.fast", "Очень быстро!", {
        rate = "+80%"
    })
    if err then
        logger:error("Test 9 FAILED", {error = tostring(err)})
    else
        logger:info("Test 9 PASSED", {size = audio.size})
    end

    -- Test 10: NOT_FOUND for missing voice
    logger:info("Test 10: NOT_FOUND for missing voice")
    audio, err = edge_tts.synthesize("app:nonexistent.voice", "text")
    if err then
        logger:info("Test 10 PASSED", {error = tostring(err)})
    else
        logger:error("Test 10 FAILED: expected NOT_FOUND error")
    end

    logger:info("=== All tests completed ===")
    return 0
end

return { main = main }
