-- ==========================================
-- CONFIGURACION IA Y PERIFERICOS
-- ==========================================
local apiKey = "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"
local modelName = "llama-3.3-70b-versatile"
local dfpwm = require("cc.audio.dfpwm")

local monitor = peripheral.find("monitor")
local speaker = peripheral.find("speaker")

-- Enlace del Easter Egg
local urlBailecito = "https://od.lk/s/MjJfMzcxNjI3NDdf/Rat%20Dance%20Meme%20%20Beginner%20Piano%20Tutorial%20%20Easy%20Piano%20%286%29.dfpwm"

local chatHistory = {
    { 
        role = "system", 
        content = "Eres una IA en un terminal de Minecraft. IMPORTANTE: Responde en espanol latino pero usa SOLO el alfabeto ingles estandar. No uses signos de interrogacion invertidos, acentos ni letras especiales. Reemplaza la 'enye' por 'n'. Se breve." 
    }
}

-- ==========================================
-- SISTEMA DE AUDIO Y NOTAS
-- ==========================================
local function playNoteSafe(instrument, volume, pitch)
    if speaker then
        speaker.playNote(instrument, volume or 3.0, pitch or 12)
    end
end

-- Funcion para reproducir el streaming del Easter Egg
local function playEasterEgg(url)
    if not speaker then return end
    
    local response = http.get(url, nil, true)
    if response then
        local decoder = dfpwm.make_decoder()
        while true do
            local chunk = response.read(16 * 1024)
            if not chunk then break end
            local buffer = decoder(chunk)
            while not speaker.playAudio(buffer) do
                os.pullEvent("speaker_audio_empty")
            end
        end
        response.close()
    end
end

-- ==========================================
-- FILTRO DE CARACTERES (ASCII PURITY)
-- ==========================================
local function cleanText(str)
    if type(str) ~= "string" then return str end
    -- Reemplazo de bytes UTF-8 comunes para evitar enyes y acentos
    str = str:gsub("\194\191", "?") -- Signo interrogacion
    str = str:gsub("\194\161", "!") -- Signo exclamacion
    str = str:gsub("\195\177", "n"):gsub("\195\145", "N") -- enyes
    -- Limpieza de cualquier otro byte no ASCII
    str = str:gsub("[^\n\32-\126]", "")
    return str
end

-- ==========================================
-- INTERFAZ GRAFICA (UI)
-- ==========================================
local function wrapText(text, maxWidth)
    local lines = {}
    local currentLine = ""
    for word in text:gmatch("%S+") do
        if #currentLine + #word + 1 > maxWidth then
            if #currentLine > 0 then table.insert(lines, currentLine) end
            currentLine = word .. " "
        else
            currentLine = currentLine .. word .. " "
        end
    end
    if #currentLine > 0 then table.insert(lines, currentLine) end
    return lines
end

local function drawHeader(w)
    monitor.setCursorPos(1, 1)
    monitor.setBackgroundColor(colors.blue)
    monitor.setTextColor(colors.white)
    local title = " GROQ OS - SISTEMA INTELIGENTE "
    local leftPad = math.floor((w - #title) / 2)
    local rightPad = w - #title - leftPad
    monitor.write(string.rep(" ", leftPad) .. title .. string.rep(" ", rightPad))
end

local function refreshUI(animateLast, specialMsg)
    if not monitor then return end
    monitor.setTextScale(0.5)
    local w, h = monitor.getSize()
    
    local displayLines = {}
    
    -- Si hay un mensaje especial (como el del Easter Egg)
    if specialMsg then
        table.insert(displayLines, {text = specialMsg, color = colors.magenta, animate = true})
    else
        for i = 2, #chatHistory do
            local msg = chatHistory[i]
            local isUser = (msg.role == "user")
            local isLast = (i == #chatHistory) and not isUser
            
            local name = isUser and "Usuario" or "Sistema"
            local nCol = isUser and colors.cyan or colors.lime
            local tCol = isUser and colors.white or colors.lightGray
            
            table.insert(displayLines, {text = " " .. name .. ":", color = nCol, animate = false})
            local wrapped = wrapText(cleanText(msg.content), w - 2)
            for _, line in ipairs(wrapped) do
                table.insert(displayLines, {text = "  " .. line, color = tCol, animate = isLast})
            end
            table.insert(displayLines, {text = "", color = colors.black, animate = false})
        end
    end
    
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    drawHeader(w)
    
    local maxLines = h - 2
    local startIdx = math.max(1, #displayLines - maxLines + 1)
    local currentY = 3
    
    for i = startIdx, #displayLines do
        if currentY > h then break end
        local line = displayLines[i]
        monitor.setCursorPos(1, currentY)
        monitor.setTextColor(line.color)
        
        if animateLast and line.animate then
            for charIdx = 1, #line.text do
                monitor.write(line.text:sub(charIdx, charIdx))
                if charIdx % 2 == 0 then
                    playNoteSafe("hat", 0.2, 24)
                    sleep(0.05)
                end
            end
        else
            monitor.write(line.text)
        end
        currentY = currentY + 1
    end
    
    if animateLast and not specialMsg then
        playNoteSafe("bell", 3.0, 12)
        sleep(0.1)
        playNoteSafe("bell", 3.0, 16)
    end
end

-- ==========================================
-- LOGICA DE COMANDOS E IA
-- ==========================================
local function askGroq(input)
    table.insert(chatHistory, { role = "user", content = input })
    refreshUI(false)
    
    local body = {
        model = modelName,
        messages = chatHistory,
        max_tokens = 200,
        temperature = 0.6
    }
    
    local response = http.post(
        "https://api.groq.com/openai/v1/chat/completions",
        textutils.serializeJSON(body),
        { ["Authorization"] = "Bearer " .. apiKey, ["Content-Type"] = "application/json" }
    )

    if response then
        local data = textutils.unserializeJSON(response.readAll())
        response.close()
        if data and data.choices then
            local content = cleanText(data.choices[1].message.content)
            table.insert(chatHistory, { role = "assistant", content = content })
            refreshUI(true)
            return
        end
    end
    table.insert(chatHistory, { role = "assistant", content = "Error de conexion." })
    refreshUI(true)
end

-- ==========================================
-- BUCLE PRINCIPAL
-- ==========================================
term.clear()
term.setCursorPos(1,1)
term.setTextColor(colors.cyan)
print("GROQ OS v3.0 - LISTO")
term.setTextColor(colors.white)

while true do
    refreshUI(false)
    term.setTextColor(colors.cyan)
    write("Comando> ")
    term.setTextColor(colors.white)
    local input = read()
    
    playNoteSafe("hat", 1.0, 12)
    
    if input:lower() == "bailecito" then
        print("Modo Bailecito Activado...")
        refreshUI(true, " >>> MODO BAILECITO ACTIVO <<< ")
        playEasterEgg(urlBailecito)
        print("Baile finalizado.")
    elseif input:lower() == "clear" then
        chatHistory = { chatHistory[1] }
        print("Memoria limpia.")
    elseif #input > 0 then
        print("Pensando...")
        askGroq(input)
    end
end
