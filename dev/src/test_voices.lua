local edge_tts = require("edge_tts")
local logger = require("logger")

local function main()
    logger:info("=== Edge TTS Voice Discovery Tests ===")

    -- Test 1: List all voices
    logger:info("Test 1: List all voices")
    local voices, err = edge_tts.list_voices()
    if err then
        logger:error("Test 1 FAILED", {error = tostring(err)})
    else
        logger:info("Test 1 PASSED", {total_voices = #voices})
    end

    -- Test 2: Filter by locale (Russian)
    logger:info("Test 2: Filter by locale ru-RU")
    local ru_voices, err = edge_tts.list_voices({locale = "ru-RU"})
    if err then
        logger:error("Test 2 FAILED", {error = tostring(err)})
    else
        logger:info("Test 2 PASSED", {count = #ru_voices})
        for _, v in ipairs(ru_voices) do
            logger:info("  Voice", {
                short_name = v.short_name,
                gender = v.gender,
                friendly_name = v.friendly_name
            })
        end
    end

    -- Test 3: Filter by gender
    logger:info("Test 3: Filter by gender Female")
    local female, err = edge_tts.list_voices({gender = "Female"})
    if err then
        logger:error("Test 3 FAILED", {error = tostring(err)})
    else
        logger:info("Test 3 PASSED", {count = #female})
    end

    -- Test 4: Combined filter
    logger:info("Test 4: Combined filter en-US Female")
    local en_female, err = edge_tts.list_voices({locale = "en-US", gender = "Female"})
    if err then
        logger:error("Test 4 FAILED", {error = tostring(err)})
    else
        logger:info("Test 4 PASSED", {count = #en_female})
        for _, v in ipairs(en_female) do
            logger:info("  Voice", {short_name = v.short_name, friendly_name = v.friendly_name})
        end
    end

    -- Test 5: Voice info structure
    logger:info("Test 5: Voice info structure")
    local ru_male, err = edge_tts.list_voices({locale = "ru-RU", gender = "Male"})
    if err then
        logger:error("Test 5 FAILED", {error = tostring(err)})
    elseif #ru_male == 0 then
        logger:error("Test 5 FAILED: no ru-RU Male voices found")
    else
        local v = ru_male[1]
        logger:info("Test 5 PASSED", {
            short_name = v.short_name,
            locale = v.locale,
            gender = v.gender,
            friendly_name = v.friendly_name,
            status = v.status,
            codec = v.codec
        })
    end

    -- Test 6: Caching (second call should be instant)
    logger:info("Test 6: Caching verification")
    local t1 = os.clock()
    local v1, err = edge_tts.list_voices()
    local elapsed1 = os.clock() - t1

    local t2 = os.clock()
    local v2, err = edge_tts.list_voices()
    local elapsed2 = os.clock() - t2

    if v1 and v2 and #v1 == #v2 then
        logger:info("Test 6 PASSED", {
            first_call_ms = string.format("%.1f", elapsed1 * 1000),
            second_call_ms = string.format("%.1f", elapsed2 * 1000),
            voices_count = #v1
        })
    else
        logger:error("Test 6 FAILED: cache inconsistency")
    end

    logger:info("=== Voice discovery tests completed ===")
    return 0
end

return { main = main }
