-- Telemetria, file di ricerca sensori
-- Maurizio 2026-09
----------------------------------------------------------
-- LTD DASH - Telemetry Engine v0.7
-- Maurizio 2026-09
----------------------------------------------------------

local M = {}

M.data = {
    alt   = 0,
    vario = 0,
    speed = 0,
    bat   = 0,
    rssi  = 0,
    lq    = 0,
    sats    = 0,
    tpwr    = nil,
    gpsdist = 0,
    gpsalt  = 0,
    gpsvv   = 0,
    heading = nil,
    gpsspeed = nil,
    rqly    = nil,
    trss    = nil,
    rtmp    = nil,
    lat     = nil,
    lon     = nil,
    powerBat = nil,
    current  = nil,
    consumed = nil,
    cells    = nil
}

local function readSensor(names)
    for i = 1, #names do
        local name = names[i]
        local info = getFieldInfo(name)

        if info ~= nil then
            local value = getValue(info.id)

            if type(value) == "number" then
                return value
            end
        end
    end

    return 0
end

local function readOptionalSensor(names)
    for i = 1, #names do
        local name = names[i]
        local info = getFieldInfo(name)

        if info ~= nil then
            local value = getValue(info.id)

            if type(value) == "number" then
                return value
            end
        end
    end

    return nil
end


local function readTableSensor(names)
    for i = 1, #names do
        local name = names[i]
        local info = getFieldInfo(name)

        if info ~= nil then
            local value = getValue(info.id)

            if type(value) == "table" then
                return value
            end
        end
    end

    return nil
end

function M.update()

    M.data.alt = readSensor({
        "Alt", "VAlt", "Valt", "gpal"
    })

    M.data.vario = readSensor({
        "Vvv", "vvv", "gpvv", "VSpd"
    })

    M.data.speed = readSensor({
        "GPsp", "GSpd"
    })

    M.data.bat = readSensor({
        "rbt", "Rbtm", "RxBt", "VFAS"
    })

    M.data.rssi = readSensor({
        "1RSS", "Rssi"
    })

    M.data.lq = readSensor({
        "Rqly", "RQly", "tqly", "TQly"
        
    })

    M.data.sats = readSensor({
        "gpns", "GPns", "Sats"
    })

    -- ExpressLRS transmit power.
    -- Different telemetry setups may expose the name with different case.
    M.data.tpwr = readOptionalSensor({
        "TPWR", "Tpwr", "tpwr"
    })

    -- Dati opzionali RADIO / LINK.
    -- Se non presenti con il protocollo/ricevente in uso restano nil.
    M.data.rqly = readOptionalSensor({
        "RQly", "Rqly", "rqly"
    })

    M.data.trss = readOptionalSensor({
        "TRSS", "Tssi", "TSSI", "tssi"
    })

    M.data.rtmp = readOptionalSensor({
        "RTmp", "Rtmp", "rtmp"
    })


    ------------------------------------------------------
    -- GPS / NAV - Pagina 2
    ------------------------------------------------------

    M.data.gpsdist = readOptionalSensor({
        "GPdi", "GPdi"
    })

    M.data.gpsalt = readOptionalSensor({
        "GAlt", "GPal"
    })

    M.data.gpsvv = readOptionalSensor({
        "GPvv", "GPVv"
    })

    M.data.heading = readOptionalSensor({
        "GPhd", "GPHd", "Vhdg", "VHdg"
    })

    M.data.gpsspeed = readOptionalSensor({
        "GPsp", "GSpd"
    })

    local gps = readTableSensor({
        "GPS"
    })

    if gps ~= nil then
        M.data.lat = gps.lat
        M.data.lon = gps.lon
    else
        M.data.lat = nil
        M.data.lon = nil
    end


    ------------------------------------------------------
    -- POWER - Pagina 5
    ------------------------------------------------------
    -- Tensione batteria di trazione. VFAS e' il nome piu' comune;
    -- altri nomi vengono provati per compatibilita' con diversi sensori.
    M.data.powerBat = readOptionalSensor({
        "VFAS", "BatV", "Batt", "RxBt"
    })

    -- Corrente motore / ESC in ampere.
    M.data.current = readOptionalSensor({
        "Curr", "Current", "Amps"
    })

    -- Capacita' consumata in mAh.
    M.data.consumed = readOptionalSensor({
        "Capa", "Fuel", "mAh"
    })

    -- Sensore celle EdgeTX: normalmente restituisce una tabella.
    M.data.cells = readTableSensor({
        "Cels", "Cells", "Cel"
    })

end

return M
