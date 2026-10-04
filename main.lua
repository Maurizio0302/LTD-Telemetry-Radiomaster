-- LTD DASH v1.7b - 7 pagine di telemetria con grafici vario e link
-- EdgeTX 2.12.x / TX16S MK3 by Maurizzio 2026-09


local NAME = "LTD DASH"
local telemetry = assert(
    loadScript("/WIDGETS/LTDDASH/telemetry.lua")
)()

----------------------------------------------------------
-- COLORI LTD DASH
----------------------------------------------------------
local COLOR_BG     = lcd.RGB(5, 12, 20)
local COLOR_TITLE  = lcd.RGB(145, 200, 255)
local COLOR_VALUE  = lcd.RGB(255, 220, 0)
local COLOR_UNIT   = LIGHTGREY
local COLOR_STATUS = lcd.RGB(190, 215, 235)
local COLOR_ARROW  = lcd.RGB(255, 220, 0)
local COLOR_LINE   = lcd.RGB(45, 95, 135)
local COLOR_WARNING = lcd.RGB(255, 55, 55)
local COLOR_GRAPH_ALT = lcd.RGB(70, 180, 255)
local COLOR_GRAPH_VARIO = lcd.RGB(255, 170, 40)
local COLOR_GRAPH_GRID = lcd.RGB(35, 65, 85)
local COLOR_GRAPH_LQ = lcd.RGB(70, 220, 120)
local COLOR_GRAPH_RSSI = lcd.RGB(255, 170, 40)
local COLOR_GRAPH_TPWR = lcd.RGB(210, 110, 255)

-- Soglia allarme cella LiPo (volt)
local CELL_WARNING = 3.30

----------------------------------------------------------
-- LTD DASH v1.7 LINK GRAPH MULTI-DISPLAY
-- Pagina 1: FLIGHT
-- Pagina 2: NAV
-- Pagina 3: RADIO / LINK
-- Pagina 4: GLIDER
-- Pagina 5: POWER
-- Pagina 6: GRAPH (quota + vario, ultimi 5 minuti)
-- Pagina 7: LINK GRAPH (LQ + RSSI + TPWR, ultimi 5 minuti)
-- TX16S MK3 + TX15 480x320 + TX16S MK2 480x372 / EdgeTX
----------------------------------------------------------

----------------------------------------------------------
-- ADATTAMENTO MULTI-DISPLAY
-- Layout di riferimento: 800 x 480 (TX16S MK3)
-- I display 480 x 320 e 480 x 372 mantengono la stessa
-- disposizione logica, con coordinate adattate allo schermo.
----------------------------------------------------------
local function sx(z, x)
    return z.x + math.floor((x * z.w / 800) + 0.5)
end

local function sy(z, y)
    return z.y + math.floor((y * z.h / 480) + 0.5)
end

local function compactDisplay(z)
    return z.w <= 500
end

local function valueSize(z)
    if compactDisplay(z) then return DBLSIZE end
    return XXLSIZE
end

local function mediumValueSize(z)
    if compactDisplay(z) then return MIDSIZE end
    return DBLSIZE
end

local function titleSize(z)
    -- MIDSIZE resta leggibile anche sui display 480 px
    return MIDSIZE
end

local function create(zone, options)
    return {
        zone = zone,
        options = options,
        page = 1,
        varioSamples = {},
        varioSum = 0,
        lastVarioSample = 0,
        varioAvg = 0,
        cellCache = nil,
        cellCacheTime = nil,
        graphAlt = {},
        graphVario = {},
        lastGraphSample = 0,
        graphLQ = {},
        graphRSSI = {},
        graphTPWR = {},
        lastLinkGraphSample = 0
    }
end

local function update(widget, options)
    widget.options = options
end


----------------------------------------------------------
-- TEMPO DI VOLO - TIMER 1 EdgeTX
----------------------------------------------------------
local function getFlightTimeText()
    local timer = model.getTimer(0) -- Timer 1
    local seconds = 0

    if timer ~= nil and timer.value ~= nil then
        seconds = math.floor(math.abs(timer.value))
    end

    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local sec = seconds % 60

    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, sec)
    end

    return string.format("%02d:%02d", m, sec)
end

local function drawFlightTime(z)
    lcd.drawText(
        z.x + z.w - (compactDisplay(z) and 8 or 20),
        sy(z, 5),
        getFlightTimeText(),
        titleSize(z) + RIGHT + COLOR_TITLE
    )
end


----------------------------------------------------------
-- NOME MODELLO EdgeTX
----------------------------------------------------------
local function getModelName()
    local info = model.getInfo()
    if info ~= nil and info.name ~= nil and info.name ~= "" then
        return info.name
    end
    return "--"
end

local function drawPageTitle(z, title)
    -- Sui 480 px il titolo parte da sinistra: lascia libero il timer a destra.
    if compactDisplay(z) then
        lcd.drawText(
            sx(z, 12), sy(z, 5),
            (title == "LTD DASH" and "LTD FLIGHT" or title) .. "  " .. getModelName(),
            titleSize(z) + COLOR_TITLE
        )
    else
        lcd.drawText(
            z.x + z.w / 2, sy(z, 5),
            title .. "  " .. getModelName(),
            titleSize(z) + CENTER + COLOR_TITLE
        )
    end
end

local function drawPageIndicator(z, page)
    local y = z.y + z.h - (compactDisplay(z) and 18 or 28)
    lcd.drawText(
        z.x + z.w - (compactDisplay(z) and 28 or 35),
        y,
        tostring(page) .. "/7",
        SMLSIZE + COLOR_STATUS
    )
    -- Firma discreta vicino al numero pagina
    lcd.drawText(
        z.x + z.w - (compactDisplay(z) and 62 or 82),
        y,
        "ms",
        SMLSIZE + COLOR_STATUS
    )
end

----------------------------------------------------------
-- PAGINA 1 - FLIGHT
----------------------------------------------------------
local function drawFlight(widget)

    local z = widget.zone
    local d = telemetry.data

    lcd.drawFilledRectangle(z.x, z.y, z.w, z.h, COLOR_BG)

    drawPageTitle(z, "LTD DASH")

    drawFlightTime(z)

    -- ALT
    lcd.drawText(sx(z, 20), sy(z, 60), "ALT", MIDSIZE + COLOR_TITLE)
    lcd.drawNumber(sx(z, 20), sy(z, 85), d.alt, valueSize(z) + COLOR_VALUE)
    lcd.drawText(sx(z, 150), sy(z, 105), "m", MIDSIZE + COLOR_UNIT)

    -- VARIO
    lcd.drawText(sx(z, 400), sy(z, 60), "VARIO", MIDSIZE + COLOR_TITLE)

    local arrowX = sx(z, 350)
    local arrowY = sy(z, 103)

    if d.vario > 0.1 then
        lcd.drawLine(arrowX, arrowY + 20, arrowX, arrowY - 15, SOLID, COLOR_ARROW)
        lcd.drawLine(arrowX, arrowY - 15, arrowX - 8, arrowY - 5, SOLID, COLOR_ARROW)
        lcd.drawLine(arrowX, arrowY - 15, arrowX + 8, arrowY - 5, SOLID, COLOR_ARROW)
    elseif d.vario < -0.1 then
        lcd.drawLine(arrowX, arrowY - 15, arrowX, arrowY + 20, SOLID, COLOR_ARROW)
        lcd.drawLine(arrowX, arrowY + 20, arrowX - 8, arrowY + 10, SOLID, COLOR_ARROW)
        lcd.drawLine(arrowX, arrowY + 20, arrowX + 8, arrowY + 10, SOLID, COLOR_ARROW)
    end

    lcd.drawNumber(
        sx(z, 400),
        sy(z, 85),
        d.vario * 10,
        valueSize(z) + PREC1 + COLOR_VALUE
    )

    lcd.drawText(sx(z, 565), sy(z, 115), "m/s", MIDSIZE + COLOR_UNIT)

    -- SPD
    lcd.drawText(sx(z, 20), sy(z, 230), "SPD", MIDSIZE + COLOR_TITLE)
    lcd.drawNumber(sx(z, 20), sy(z, 255), d.speed, valueSize(z) + COLOR_VALUE)
    lcd.drawText(sx(z, 150), sy(z, 275), "km/h", MIDSIZE + COLOR_UNIT)

    -- BAT
    lcd.drawText(sx(z, 400), sy(z, 230), "BAT", MIDSIZE + COLOR_TITLE)
    lcd.drawNumber(
        sx(z, 400),
        sy(z, 255),
        d.bat * 10,
        valueSize(z) + PREC1 + COLOR_VALUE
    )
    lcd.drawText(sx(z, 565), sy(z, 275), "V", MIDSIZE + COLOR_UNIT)

    -- Barra telemetria inferiore
    lcd.drawText(sx(z, 20), sy(z, 385), "LQ " .. d.lq, MIDSIZE + COLOR_STATUS)
    lcd.drawText(sx(z, 180), sy(z, 385), "RSSI " .. d.rssi, MIDSIZE + COLOR_STATUS)
    lcd.drawText(sx(z, 390), sy(z, 385), "SAT " .. d.sats, MIDSIZE + COLOR_STATUS)

    local tpwrText = "--"
    if d.tpwr ~= nil and d.tpwr > 0 then
        tpwrText = tostring(d.tpwr) .. " mW"
    end

    lcd.drawText(
        sx(z, 555),
        sy(z, 385),
        "TPWR " .. tpwrText,
        MIDSIZE + COLOR_STATUS
    )

    drawPageIndicator(z, 1)
end

----------------------------------------------------------
-- NAV: "--" indica sensore non disponibile
----------------------------------------------------------
local function drawNavNumber(x, y, value, flags)
    if value == nil then
        lcd.drawText(x, y, "--", flags)
    else
        lcd.drawNumber(x, y, value, flags)
    end
end

local function navText(value, decimals)
    if value == nil then return "--" end
    if decimals == 1 then return string.format("%.1f", value) end
    return tostring(value)
end

----------------------------------------------------------
-- PAGINA 2 - NAV / GPS
----------------------------------------------------------
local function drawNav(widget)

    local z = widget.zone
    local d = telemetry.data

    lcd.drawFilledRectangle(z.x, z.y, z.w, z.h, COLOR_BG)

    drawPageTitle(z, "LTD NAV")

    drawFlightTime(z)

    -- Riga superiore: quota GPS e prua GPS
    lcd.drawText(sx(z, 20), sy(z, 55), "GPS ALT", MIDSIZE + COLOR_TITLE)
    drawNavNumber(sx(z, 20), sy(z, 82), d.gpsalt, valueSize(z) + COLOR_VALUE)
    lcd.drawText(sx(z, 170), sy(z, 105), "m", MIDSIZE + COLOR_UNIT)

    -- HDG leggermente spostato a destra
    lcd.drawText(sx(z, 440), sy(z, 55), "HDG", MIDSIZE + COLOR_TITLE)
    drawNavNumber(sx(z, 440), sy(z, 82), d.heading, valueSize(z) + COLOR_VALUE)
    lcd.drawText(sx(z, 595), sy(z, 105), "deg", MIDSIZE + COLOR_UNIT)

    lcd.drawLine(
        sx(z, 20), sy(z, 175),
        z.x + z.w - 20, sy(z, 175),
        SOLID, COLOR_LINE
    )

    -- Riga centrale: distanza da home e velocita' GPS
    lcd.drawText(sx(z, 20), sy(z, 205), "DIST HOME", MIDSIZE + COLOR_TITLE)
    drawNavNumber(sx(z, 20), sy(z, 232), d.gpsdist, valueSize(z) + COLOR_VALUE)
    lcd.drawText(sx(z, 170), sy(z, 255), "m", MIDSIZE + COLOR_UNIT)

    -- GPS SPD leggermente spostato a destra
    lcd.drawText(sx(z, 440), sy(z, 205), "GPS SPD", MIDSIZE + COLOR_TITLE)
    drawNavNumber(sx(z, 440), sy(z, 232), d.gpsspeed, valueSize(z) + COLOR_VALUE)
    lcd.drawText(sx(z, 595), sy(z, 255), "km/h", MIDSIZE + COLOR_UNIT)

    lcd.drawLine(
        sx(z, 20), sy(z, 330),
        z.x + z.w - 20, sy(z, 330),
        SOLID, COLOR_LINE
    )

    -- Coordinate GPS
    local latText = "--"
    local lonText = "--"

    if d.lat ~= nil then
        latText = string.format("%.5f", d.lat)
    end

    if d.lon ~= nil then
        lonText = string.format("%.5f", d.lon)
    end

    lcd.drawText(sx(z, 20), sy(z, 350), "LAT " .. latText, MIDSIZE + COLOR_STATUS)
    lcd.drawText(sx(z, 400), sy(z, 350), "LON " .. lonText, MIDSIZE + COLOR_STATUS)

    lcd.drawText(
        sx(z, 20),
        sy(z, 395),
        "SAT " .. d.sats .. "    GPS VV " .. navText(d.gpsvv, 1) .. " m/s",
        MIDSIZE + COLOR_STATUS
    )

    drawPageIndicator(z, 2)
end

----------------------------------------------------------
-- MEDIA VARIO 5 s
----------------------------------------------------------
local function updateVarioAverage(widget, vario)
    local now = getTime()

    -- getTime() usa tick da 10 ms: 50 tick = 0.5 s
    if widget.lastVarioSample == 0 or (now - widget.lastVarioSample) >= 50 then
        widget.lastVarioSample = now

        table.insert(widget.varioSamples, vario)
        widget.varioSum = widget.varioSum + vario

        if #widget.varioSamples > 10 then
            widget.varioSum = widget.varioSum - table.remove(widget.varioSamples, 1)
        end

        if #widget.varioSamples > 0 then
            widget.varioAvg = widget.varioSum / #widget.varioSamples
        end
    end
end

----------------------------------------------------------
-- PAGINA 3 - RADIO / LINK
----------------------------------------------------------
local function drawRadio(widget)

    local z = widget.zone
    local d = telemetry.data

    lcd.drawFilledRectangle(z.x, z.y, z.w, z.h, COLOR_BG)

    drawPageTitle(z, "LTD RADIO / LINK")

    drawFlightTime(z)

    -- LQ
    lcd.drawText(sx(z, 20), sy(z, 55), "LQ", MIDSIZE + COLOR_TITLE)
    lcd.drawNumber(sx(z, 20), sy(z, 82), d.lq, valueSize(z) + COLOR_VALUE)
    lcd.drawText(sx(z, 170), sy(z, 105), "%", MIDSIZE + COLOR_UNIT)

    -- RSSI
    lcd.drawText(sx(z, 440), sy(z, 55), "RSSI", MIDSIZE + COLOR_TITLE)
    lcd.drawNumber(sx(z, 440), sy(z, 82), d.rssi, valueSize(z) + COLOR_VALUE)
    lcd.drawText(sx(z, 610), sy(z, 105), "dBm", MIDSIZE + COLOR_UNIT)

    lcd.drawLine(
        sx(z, 20), sy(z, 175),
        z.x + z.w - 20, sy(z, 175),
        SOLID, COLOR_LINE
    )

    -- RX BAT
    lcd.drawText(sx(z, 20), sy(z, 205), "RX BAT", MIDSIZE + COLOR_TITLE)
    lcd.drawNumber(
        sx(z, 20),
        sy(z, 232),
        d.bat * 10,
        valueSize(z) + PREC1 + COLOR_VALUE
    )
    lcd.drawText(sx(z, 170), sy(z, 255), "V", MIDSIZE + COLOR_UNIT)

    -- TPWR
    lcd.drawText(sx(z, 440), sy(z, 205), "TPWR", MIDSIZE + COLOR_TITLE)
    if d.tpwr ~= nil and d.tpwr > 0 then
        lcd.drawNumber(sx(z, 440), sy(z, 232), d.tpwr, valueSize(z) + COLOR_VALUE)
        lcd.drawText(sx(z, 610), sy(z, 255), "mW", MIDSIZE + COLOR_UNIT)
    else
        lcd.drawText(sx(z, 440), sy(z, 232), "--", valueSize(z) + COLOR_VALUE)
    end

    lcd.drawLine(
        sx(z, 20), sy(z, 330),
        z.x + z.w - 20, sy(z, 330),
        SOLID, COLOR_LINE
    )

    -- Dati diagnostici opzionali
    local rqlyText = "--"
    if d.rqly ~= nil then rqlyText = tostring(d.rqly) end

    local trssText = "--"
    if d.trss ~= nil then trssText = tostring(d.trss) end

    local rtmpText = "--"
    if d.rtmp ~= nil then rtmpText = tostring(d.rtmp) end

    lcd.drawText(
        sx(z, 20),
        sy(z, 365),
        "RQly " .. rqlyText .. "     TRSS " .. trssText .. "     RTmp " .. rtmpText,
        MIDSIZE + COLOR_STATUS
    )

    lcd.drawText(
        sx(z, 20),
        sy(z, 405),
        "LINK STATUS",
        SMLSIZE + COLOR_TITLE
    )

    local status = "OK"
    if d.lq <= 0 and d.rssi == 0 then
        status = "--"
    elseif d.lq < 50 then
        status = "LOW"
    end

    lcd.drawText(
        sx(z, 150),
        sy(z, 405),
        status,
        MIDSIZE + COLOR_STATUS
    )

    drawPageIndicator(z, 3)
end

----------------------------------------------------------
-- PAGINA 4 - GLIDER
----------------------------------------------------------
local function drawGlider(widget)

    local z = widget.zone
    local d = telemetry.data
    local avg = widget.varioAvg or 0

    lcd.drawFilledRectangle(z.x, z.y, z.w, z.h, COLOR_BG)

    drawPageTitle(z, "LTD GLIDER")

    drawFlightTime(z)

    -- Quota e velocita' in alto
    lcd.drawText(sx(z, 20), sy(z, 52), "ALT", MIDSIZE + COLOR_TITLE)
    lcd.drawNumber(sx(z, 20), sy(z, 77), d.alt, mediumValueSize(z) + COLOR_VALUE)
    lcd.drawText(sx(z, 135), sy(z, 88), "m", MIDSIZE + COLOR_UNIT)

    lcd.drawText(sx(z, 570), sy(z, 52), "SPD", MIDSIZE + COLOR_TITLE)
    lcd.drawNumber(sx(z, 570), sy(z, 77), d.speed, mediumValueSize(z) + COLOR_VALUE)
    lcd.drawText(sx(z, 680), sy(z, 88), "km/h", MIDSIZE + COLOR_UNIT)

    lcd.drawLine(
        sx(z, 20), sy(z, 130),
        z.x + z.w - 20, sy(z, 130),
        SOLID, COLOR_LINE
    )

    -- Variometro centrale molto grande
    lcd.drawText(
        sx(z, 515),
        sy(z, 145),
        "VARIO",
        MIDSIZE + CENTER + COLOR_TITLE
    )

    local arrowX = sx(z, 305)
    local arrowY = sy(z, 235)

    -- Freccia VARIO piu' spessa: tre linee parallele per ogni tratto.
    -- Lo spessore viene adattato automaticamente alla larghezza del display.
    local arrowThickness = compactDisplay(z) and 1 or 2
    local function thickLine(x1, y1, x2, y2)
        for o = -arrowThickness, arrowThickness do
            lcd.drawLine(x1 + o, y1, x2 + o, y2, SOLID, COLOR_ARROW)
        end
    end

    if d.vario > 0.1 then
        thickLine(arrowX, arrowY + 60, arrowX, arrowY - 60)
        thickLine(arrowX, arrowY - 60, arrowX - 28, arrowY - 28)
        thickLine(arrowX, arrowY - 60, arrowX + 28, arrowY - 28)
    elseif d.vario < -0.1 then
        thickLine(arrowX, arrowY - 60, arrowX, arrowY + 60)
        thickLine(arrowX, arrowY + 60, arrowX - 28, arrowY + 28)
        thickLine(arrowX, arrowY + 60, arrowX + 28, arrowY + 28)
    end

    lcd.drawNumber(
        sx(z, 420),
        sy(z, 190),
        d.vario * 10,
        valueSize(z) + PREC1 + COLOR_VALUE
    )
    lcd.drawText(sx(z, 605), sy(z, 225), "m/s", MIDSIZE + COLOR_UNIT)

    lcd.drawLine(
        sx(z, 20), sy(z, 315),
        z.x + z.w - 20, sy(z, 315),
        SOLID, COLOR_LINE
    )

    -- Media vario 5 secondi
    lcd.drawText(sx(z, 20), sy(z, 340), "AVG 5s", MIDSIZE + COLOR_TITLE)
    lcd.drawNumber(
        sx(z, 20),
        sy(z, 368),
        avg * 10,
        mediumValueSize(z) + PREC1 + COLOR_VALUE
    )
    lcd.drawText(sx(z, 145), sy(z, 380), "m/s", MIDSIZE + COLOR_UNIT)

    -- Efficienza istantanea: solo in planata, con vario negativo significativo
    lcd.drawText(sx(z, 430), sy(z, 340), "L/D", MIDSIZE + COLOR_TITLE)

    if d.vario < -0.2 and d.speed > 0 then
        local ld = (d.speed / 3.6) / (-d.vario)
        if ld > 99 then ld = 99 end
        lcd.drawNumber(sx(z, 430), sy(z, 368), ld * 10, mediumValueSize(z) + PREC1 + COLOR_VALUE)
    else
        lcd.drawText(sx(z, 430), sy(z, 368), "--", mediumValueSize(z) + COLOR_VALUE)
    end

    lcd.drawText(
        sx(z, 20),
        sy(z, 425),
        "LQ " .. d.lq .. "    RSSI " .. d.rssi .. "    TPWR " .. (d.tpwr ~= nil and tostring(d.tpwr) or "--"),
        SMLSIZE + COLOR_STATUS
    )

    drawPageIndicator(z, 4)
end

----------------------------------------------------------
-- MEMORIA DATI CELLE
-- Mantiene l'ultimo pacchetto valido per 5 secondi.
----------------------------------------------------------
local CELL_HOLD_TICKS = 500 -- getTime(): 100 tick = 1 secondo

local function updateCellCache(widget, cells)
    local valid = {}
    if type(cells) == "table" then
        local maxCells = math.min(#cells, 7)
        for i = 1, maxCells do
            local v = cells[i]
            if type(v) == "number" and v > 0 then
                valid[#valid + 1] = v
            end
        end
    end

    if #valid > 0 then
        widget.cellCache = valid
        widget.cellCacheTime = getTime()
    end
end

local function getDisplayCells(widget)
    if widget.cellCache == nil or widget.cellCacheTime == nil then
        return nil
    end
    if (getTime() - widget.cellCacheTime) <= CELL_HOLD_TICKS then
        return widget.cellCache
    end
    return nil
end

----------------------------------------------------------
-- PAGINA 5 - POWER / MOTORE ELETTRICO
----------------------------------------------------------
local function drawPower(widget)
    local z = widget.zone
    local d = telemetry.data

    lcd.drawFilledRectangle(z.x, z.y, z.w, z.h, COLOR_BG)
    drawPageTitle(z, "LTD POWER")
    drawFlightTime(z)

    -- Batteria trazione
    lcd.drawText(sx(z, 20), sy(z, 58), "BAT V", MIDSIZE + COLOR_TITLE)
    if d.powerBat ~= nil then
        lcd.drawNumber(sx(z, 20), sy(z, 86), d.powerBat * 10, valueSize(z) + PREC1 + COLOR_VALUE)
        lcd.drawText(sx(z, 205), sy(z, 108), "V", MIDSIZE + COLOR_UNIT)
    else
        lcd.drawText(sx(z, 20), sy(z, 86), "--", valueSize(z) + COLOR_VALUE)
    end

    -- Corrente motore
    lcd.drawText(sx(z, 430), sy(z, 58), "CURRENT", MIDSIZE + COLOR_TITLE)
    if d.current ~= nil then
        lcd.drawNumber(sx(z, 430), sy(z, 86), d.current * 10, valueSize(z) + PREC1 + COLOR_VALUE)
        lcd.drawText(sx(z, 605), sy(z, 108), "A", MIDSIZE + COLOR_UNIT)
    else
        lcd.drawText(sx(z, 430), sy(z, 86), "--", valueSize(z) + COLOR_VALUE)
    end

    lcd.drawLine(sx(z, 20), sy(z, 165), z.x + z.w - 20, sy(z, 165), SOLID, COLOR_LINE)

    -- Capacita' consumata
    lcd.drawText(sx(z, 20), sy(z, 188), "CONSUMED", MIDSIZE + COLOR_TITLE)
    if d.consumed ~= nil then
        lcd.drawNumber(sx(z, 20), sy(z, 216), d.consumed, mediumValueSize(z) + COLOR_VALUE)
        lcd.drawText(sx(z, 185), sy(z, 230), "mAh", MIDSIZE + COLOR_UNIT)
    else
        lcd.drawText(sx(z, 20), sy(z, 216), "--", mediumValueSize(z) + COLOR_VALUE)
    end

    -- Celle individuali + minima
    lcd.drawText(sx(z, 390), sy(z, 188), "CELLS", MIDSIZE + COLOR_TITLE)

    local cells = getDisplayCells(widget)
    local minCell = nil
    if type(cells) == "table" and #cells > 0 then
        local maxCells = math.min(#cells, 7)
        for i = 1, maxCells do
            local v = cells[i]
            if type(v) == "number" and v > 0 then
                -- I valori 0 delle celle non presenti vengono ignorati.
                if minCell == nil or v < minCell then minCell = v end
                local col = (v < CELL_WARNING) and COLOR_WARNING or COLOR_VALUE
                local colNum = (i - 1) % 2
                local row = math.floor((i - 1) / 2)
                local cx = (colNum == 0) and 390 or 590
                local cy = 220 + row * 42
                lcd.drawText(sx(z, cx), sy(z, cy), "C" .. i, SMLSIZE + COLOR_STATUS)
                lcd.drawNumber(sx(z, cx + 42), sy(z, cy - 4), v * 100, MIDSIZE + PREC2 + col)
            end
        end
    else
        lcd.drawText(sx(z, 390), sy(z, 220), "--", mediumValueSize(z) + COLOR_VALUE)
    end

    -- Cella minima: diventa rossa sotto 3.30 V
    lcd.drawText(sx(z, 20), sy(z, 330), "MIN CELL", MIDSIZE + COLOR_TITLE)
    if minCell ~= nil then
        local col = (minCell < CELL_WARNING) and COLOR_WARNING or COLOR_VALUE
        lcd.drawNumber(sx(z, 20), sy(z, 358), minCell * 100, mediumValueSize(z) + PREC2 + col)
        lcd.drawText(sx(z, 155), sy(z, 370), "V", MIDSIZE + COLOR_UNIT)
    else
        lcd.drawText(sx(z, 20), sy(z, 358), "--", mediumValueSize(z) + COLOR_VALUE)
    end

    lcd.drawText(sx(z, 20), sy(z, 425), "LQ " .. d.lq .. "    RSSI " .. d.rssi .. "    TPWR " .. (d.tpwr ~= nil and tostring(d.tpwr) or "--"), SMLSIZE + COLOR_STATUS)
    drawPageIndicator(z, 5)
end

----------------------------------------------------------
-- PAGINA 6 - GRAPH / QUOTA + VARIO
-- Un campione al secondo, ultimi 5 minuti (300 campioni).
----------------------------------------------------------
local GRAPH_MAX_SAMPLES = 300
local GRAPH_SAMPLE_TICKS = 100 -- getTime(): 100 tick = 1 secondo
local GRAPH_DRAW_STEP = 5    -- disegna circa 60 punti su 300: riduce il carico CPU

local function updateGraphSamples(widget, alt, vario)
    local now = getTime()

    if widget.lastGraphSample == 0 or (now - widget.lastGraphSample) >= GRAPH_SAMPLE_TICKS then
        widget.lastGraphSample = now

        table.insert(widget.graphAlt, alt or 0)
        table.insert(widget.graphVario, vario or 0)

        if #widget.graphAlt > GRAPH_MAX_SAMPLES then
            table.remove(widget.graphAlt, 1)
        end
        if #widget.graphVario > GRAPH_MAX_SAMPLES then
            table.remove(widget.graphVario, 1)
        end
    end
end

local function graphMinMax(values)
    if #values == 0 then return 0, 1 end

    local mn = values[1]
    local mx = values[1]
    for i = 2, #values do
        local v = values[i]
        if v < mn then mn = v end
        if v > mx then mx = v end
    end

    if mx - mn < 1 then
        local c = (mx + mn) / 2
        mn = c - 0.5
        mx = c + 0.5
    end
    return mn, mx
end

local function drawGraph(widget)
    local z = widget.zone
    local d = telemetry.data

    lcd.drawFilledRectangle(z.x, z.y, z.w, z.h, COLOR_BG)
    drawPageTitle(z, "LTD GRAPH")
    drawFlightTime(z)

    -- Valori istantanei in alto
    lcd.drawText(sx(z, 20), sy(z, 48), "ALT", MIDSIZE + COLOR_TITLE)
    lcd.drawNumber(sx(z, 105), sy(z, 45), d.alt, mediumValueSize(z) + COLOR_GRAPH_ALT)
    lcd.drawText(sx(z, 245), sy(z, 60), "m", SMLSIZE + COLOR_UNIT)

    lcd.drawText(sx(z, 420), sy(z, 48), "VARIO", MIDSIZE + COLOR_TITLE)
    lcd.drawNumber(sx(z, 555), sy(z, 45), d.vario * 10, mediumValueSize(z) + PREC1 + COLOR_GRAPH_VARIO)
    lcd.drawText(sx(z, 720), sy(z, 60), "m/s", SMLSIZE + COLOR_UNIT)

    local gx1 = sx(z, 55)
    local gx2 = sx(z, 745)
    local gy1 = sy(z, 125)
    local gy2 = sy(z, 405)
    local gw = gx2 - gx1
    local gh = gy2 - gy1

    -- Cornice e griglia
    lcd.drawRectangle(gx1, gy1, gw, gh, COLOR_LINE)
    for i = 1, 3 do
        local yy = gy1 + math.floor(gh * i / 4)
        lcd.drawLine(gx1, yy, gx2, yy, DOTTED, COLOR_GRAPH_GRID)
    end
    for i = 1, 4 do
        local xx = gx1 + math.floor(gw * i / 5)
        lcd.drawLine(xx, gy1, xx, gy2, DOTTED, COLOR_GRAPH_GRID)
    end

    local n = #widget.graphAlt
    if n >= 2 then
        local altMin, altMax = graphMinMax(widget.graphAlt)
        local varMin, varMax = graphMinMax(widget.graphVario)

        -- Un piccolo margine evita che le curve tocchino il bordo.
        local altPad = math.max(1, (altMax - altMin) * 0.08)
        altMin = altMin - altPad
        altMax = altMax + altPad

        local varAbs = math.max(math.abs(varMin), math.abs(varMax), 0.5)
        varMin = -varAbs
        varMax = varAbs

        local prevX, prevAltY, prevVarY = nil, nil, nil
        local i = 1
        while i <= n do
            -- Manteniamo 300 campioni in memoria, ma ne disegniamo circa 60.
            -- La forma del grafico resta leggibile e il carico CPU cala molto.
            local x = gx1 + math.floor((i - 1) * gw / math.max(1, GRAPH_MAX_SAMPLES - 1))
            local ay = gy2 - math.floor((widget.graphAlt[i] - altMin) * gh / (altMax - altMin))
            local vy = gy2 - math.floor((widget.graphVario[i] - varMin) * gh / (varMax - varMin))

            if prevX ~= nil then
                lcd.drawLine(prevX, prevAltY, x, ay, SOLID, COLOR_GRAPH_ALT)
                lcd.drawLine(prevX, prevVarY, x, vy, SOLID, COLOR_GRAPH_VARIO)
            end
            prevX, prevAltY, prevVarY = x, ay, vy
            i = i + GRAPH_DRAW_STEP
        end

        -- Disegna sempre anche il campione piu' recente.
        if ((n - 1) % GRAPH_DRAW_STEP) ~= 0 then
            local x = gx1 + math.floor((n - 1) * gw / math.max(1, GRAPH_MAX_SAMPLES - 1))
            local ay = gy2 - math.floor((widget.graphAlt[n] - altMin) * gh / (altMax - altMin))
            local vy = gy2 - math.floor((widget.graphVario[n] - varMin) * gh / (varMax - varMin))
            lcd.drawLine(prevX, prevAltY, x, ay, SOLID, COLOR_GRAPH_ALT)
            lcd.drawLine(prevX, prevVarY, x, vy, SOLID, COLOR_GRAPH_VARIO)
        end

        -- Scale compatte ai bordi del grafico
        lcd.drawText(gx1 + 3, gy1 + 2, string.format("%.0fm", altMax), SMLSIZE + COLOR_GRAPH_ALT)
        lcd.drawText(gx1 + 3, gy2 - 17, string.format("%.0fm", altMin), SMLSIZE + COLOR_GRAPH_ALT)
        lcd.drawText(gx2 - 3, gy1 + 2, string.format("+%.1f", varAbs), SMLSIZE + RIGHT + COLOR_GRAPH_VARIO)
        lcd.drawText(gx2 - 3, gy2 - 17, string.format("-%.1f", varAbs), SMLSIZE + RIGHT + COLOR_GRAPH_VARIO)
    else
        lcd.drawText((gx1 + gx2) / 2, (gy1 + gy2) / 2 - 10, "RACCOLTA DATI...", MIDSIZE + CENTER + COLOR_STATUS)
    end

    lcd.drawText(gx1, sy(z, 414), "5 MIN", SMLSIZE + COLOR_STATUS)
    lcd.drawText(gx2, sy(z, 414), "ORA", SMLSIZE + RIGHT + COLOR_STATUS)

    drawPageIndicator(z, 6)
end


----------------------------------------------------------
-- PAGINA 7 - LINK GRAPH / LQ + RSSI + TPWR
-- Un campione al secondo, ultimi 5 minuti (300 campioni).
----------------------------------------------------------
local function updateLinkGraphSamples(widget, lq, rssi, tpwr)
    local now = getTime()
    if widget.lastLinkGraphSample == 0 or (now - widget.lastLinkGraphSample) >= GRAPH_SAMPLE_TICKS then
        widget.lastLinkGraphSample = now
        table.insert(widget.graphLQ, lq or 0)
        table.insert(widget.graphRSSI, rssi or 0)
        table.insert(widget.graphTPWR, tpwr or 0)
        if #widget.graphLQ > GRAPH_MAX_SAMPLES then table.remove(widget.graphLQ, 1) end
        if #widget.graphRSSI > GRAPH_MAX_SAMPLES then table.remove(widget.graphRSSI, 1) end
        if #widget.graphTPWR > GRAPH_MAX_SAMPLES then table.remove(widget.graphTPWR, 1) end
    end
end

local function drawLinkGraph(widget)
    local z = widget.zone
    local d = telemetry.data
    lcd.drawFilledRectangle(z.x, z.y, z.w, z.h, COLOR_BG)
    drawPageTitle(z, "LTD LINK GRAPH")
    drawFlightTime(z)

    lcd.drawText(sx(z, 20), sy(z, 48), "LQ", MIDSIZE + COLOR_TITLE)
    lcd.drawNumber(sx(z, 80), sy(z, 45), d.lq or 0, mediumValueSize(z) + COLOR_GRAPH_LQ)
    lcd.drawText(sx(z, 175), sy(z, 60), "%", SMLSIZE + COLOR_UNIT)

    lcd.drawText(sx(z, 275), sy(z, 48), "RSSI", MIDSIZE + COLOR_TITLE)
    lcd.drawNumber(sx(z, 380), sy(z, 45), d.rssi or 0, mediumValueSize(z) + COLOR_GRAPH_RSSI)
    lcd.drawText(sx(z, 470), sy(z, 60), "dBm", SMLSIZE + COLOR_UNIT)

    lcd.drawText(sx(z, 545), sy(z, 48), "TPWR", MIDSIZE + COLOR_TITLE)
    if d.tpwr ~= nil then
        lcd.drawNumber(sx(z, 700), sy(z, 45), d.tpwr, mediumValueSize(z) + RIGHT + COLOR_GRAPH_TPWR)
    else
        lcd.drawText(sx(z, 700), sy(z, 45), "--", mediumValueSize(z) + RIGHT + COLOR_GRAPH_TPWR)
    end

    local gx1 = sx(z, 55)
    local gx2 = sx(z, 745)
    local gy1 = sy(z, 125)
    local gy2 = sy(z, 405)
    local gw = gx2 - gx1
    local gh = gy2 - gy1
    lcd.drawRectangle(gx1, gy1, gw, gh, COLOR_LINE)
    for i = 1, 3 do
        local yy = gy1 + math.floor(gh * i / 4)
        lcd.drawLine(gx1, yy, gx2, yy, DOTTED, COLOR_GRAPH_GRID)
    end
    for i = 1, 4 do
        local xx = gx1 + math.floor(gw * i / 5)
        lcd.drawLine(xx, gy1, xx, gy2, DOTTED, COLOR_GRAPH_GRID)
    end

    local n = #widget.graphLQ
    if n >= 2 then
        local rssiMin, rssiMax = graphMinMax(widget.graphRSSI)
        local tpwrMin, tpwrMax = graphMinMax(widget.graphTPWR)
        rssiMin = math.min(rssiMin, -30)
        rssiMax = math.max(rssiMax, -20)
        if rssiMax - rssiMin < 10 then rssiMin = rssiMax - 10 end
        tpwrMin = 0
        tpwrMax = math.max(tpwrMax, 10)

        local px, pyLQ, pyRSSI, pyTPWR = nil, nil, nil, nil
        local i = 1
        while i <= n do
            local x = gx1 + math.floor((i - 1) * gw / math.max(1, GRAPH_MAX_SAMPLES - 1))
            local lq = math.max(0, math.min(100, widget.graphLQ[i]))
            local yLQ = gy2 - math.floor(lq * gh / 100)
            local yRSSI = gy2 - math.floor((widget.graphRSSI[i] - rssiMin) * gh / (rssiMax - rssiMin))
            local yTPWR = gy2 - math.floor((widget.graphTPWR[i] - tpwrMin) * gh / (tpwrMax - tpwrMin))
            if px ~= nil then
                lcd.drawLine(px, pyLQ, x, yLQ, SOLID, COLOR_GRAPH_LQ)
                lcd.drawLine(px, pyRSSI, x, yRSSI, SOLID, COLOR_GRAPH_RSSI)
                lcd.drawLine(px, pyTPWR, x, yTPWR, SOLID, COLOR_GRAPH_TPWR)
            end
            px, pyLQ, pyRSSI, pyTPWR = x, yLQ, yRSSI, yTPWR
            i = i + GRAPH_DRAW_STEP
        end

        -- Disegna sempre anche il campione piu' recente.
        if ((n - 1) % GRAPH_DRAW_STEP) ~= 0 then
            local x = gx1 + math.floor((n - 1) * gw / math.max(1, GRAPH_MAX_SAMPLES - 1))
            local lq = math.max(0, math.min(100, widget.graphLQ[n]))
            local yLQ = gy2 - math.floor(lq * gh / 100)
            local yRSSI = gy2 - math.floor((widget.graphRSSI[n] - rssiMin) * gh / (rssiMax - rssiMin))
            local yTPWR = gy2 - math.floor((widget.graphTPWR[n] - tpwrMin) * gh / (tpwrMax - tpwrMin))
            lcd.drawLine(px, pyLQ, x, yLQ, SOLID, COLOR_GRAPH_LQ)
            lcd.drawLine(px, pyRSSI, x, yRSSI, SOLID, COLOR_GRAPH_RSSI)
            lcd.drawLine(px, pyTPWR, x, yTPWR, SOLID, COLOR_GRAPH_TPWR)
        end
        lcd.drawText(gx1 + 3, gy1 + 2, "LQ 100%", SMLSIZE + COLOR_GRAPH_LQ)
        lcd.drawText(gx1 + 3, gy2 - 17, "LQ 0%", SMLSIZE + COLOR_GRAPH_LQ)
        lcd.drawText(gx2 - 3, gy1 + 2, "RSSI", SMLSIZE + RIGHT + COLOR_GRAPH_RSSI)
        lcd.drawText(gx2 - 3, gy2 - 17, "TPWR", SMLSIZE + RIGHT + COLOR_GRAPH_TPWR)
    else
        lcd.drawText((gx1 + gx2) / 2, (gy1 + gy2) / 2 - 10, "RACCOLTA DATI...", MIDSIZE + CENTER + COLOR_STATUS)
    end

    lcd.drawText(gx1, sy(z, 414), "5 MIN", SMLSIZE + COLOR_STATUS)
    lcd.drawText(gx2, sy(z, 414), "ORA", SMLSIZE + RIGHT + COLOR_STATUS)
    drawPageIndicator(z, 7)
end

----------------------------------------------------------
-- REFRESH + NAVIGAZIONE TOUCH + TASTI FISICI
----------------------------------------------------------
local function refresh(widget, event, touchState)

    telemetry.update()
    updateCellCache(widget, telemetry.data.cells)
    updateVarioAverage(widget, telemetry.data.vario)
    updateGraphSamples(widget, telemetry.data.alt, telemetry.data.vario)
    updateLinkGraphSamples(widget, telemetry.data.lq, telemetry.data.rssi, telemetry.data.tpwr)

    -- Navigazione circolare: 1 FLIGHT -> 2 NAV -> 3 RADIO -> 4 GLIDER -> 5 POWER -> 6 GRAPH -> 7 LINK GRAPH
    if touchState and event == EVT_TOUCH_SLIDE then
        if touchState.swipeLeft then
            widget.page = widget.page + 1
            if widget.page > 7 then widget.page = 1 end
        elseif touchState.swipeRight then
            widget.page = widget.page - 1
            if widget.page < 1 then widget.page = 7 end
        end
    end

    -- Navigazione con i tasti fisici della radio.
    -- NEXT_PAGE / PREV_PAGE sono gli eventi EdgeTX dedicati al cambio pagina.
    -- Manteniamo anche NEXT / PREV come compatibilita' aggiuntiva.
    if touchState == nil then
        if event == EVT_VIRTUAL_NEXT_PAGE or event == EVT_VIRTUAL_NEXT then
            widget.page = widget.page + 1
            if widget.page > 7 then widget.page = 1 end
        elseif event == EVT_VIRTUAL_PREV_PAGE or event == EVT_VIRTUAL_PREV then
            widget.page = widget.page - 1
            if widget.page < 1 then widget.page = 7 end
        end
    end

    if widget.page == 7 then
        drawLinkGraph(widget)
    elseif widget.page == 6 then
        drawGraph(widget)
    elseif widget.page == 5 then
        drawPower(widget)
    elseif widget.page == 4 then
        drawGlider(widget)
    elseif widget.page == 3 then
        drawRadio(widget)
    elseif widget.page == 2 then
        drawNav(widget)
    else
        drawFlight(widget)
    end
end

return {
    name = NAME,
    options = {},
    create = create,
    update = update,
    refresh = refresh
}
