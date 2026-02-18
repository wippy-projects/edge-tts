local edge_tts = require("edge_tts")
local http = require("http")
local json = require("json")

type TTSRequest = {
    voice: string,
    text: string,
    rate?: string,
    pitch?: string,
    volume?: string
}

local function handler()
    local req = http.request()
    local res = http.response()

    local body, err = req:body_json()
    if err then
        return res:set_status(400):write_json({error = "Invalid JSON"})
    end

    local tts_req, val_err = TTSRequest:is(body)
    if not tts_req then
        return res:set_status(400):write_json({
            error = "Validation failed",
            details = tostring(val_err)
        })
    end

    if not tts_req.voice or tts_req.voice == "" then
        return res:set_status(400):write_json({error = "voice is required"})
    end
    if not tts_req.text or tts_req.text == "" then
        return res:set_status(400):write_json({error = "text is required"})
    end

    local audio, synth_err = edge_tts.synthesize(tts_req.voice, tts_req.text, {
        rate = tts_req.rate,
        pitch = tts_req.pitch,
        volume = tts_req.volume
    })

    if synth_err then
        return res:set_status(500):write_json({
            error = "Synthesis failed",
            details = tostring(synth_err)
        })
    end

    res:set_header("Content-Type", audio.format)
    res:set_header("Content-Length", tostring(audio.size))
    res:set_header("X-Voice-Id", audio.voice_id)
    res:set_header("X-Output-Format", audio.output_format)
    res:set_status(200):write(audio.data)
end

return { handler = handler }
