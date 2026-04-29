-- ==========================================
-- CONFIGURACION IA Y PERIFERICOS
-- ==========================================
local apiKey = "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"
local modelName = "llama-3.3-70b-versatile"
local dfpwm = require("cc.audio.dfpwm")

-- Encontrar monitor
local monitor = peripheral.find("monitor")
if not monitor then
    local sides = {"top", "bottom", "left", "right", "front", "back"}
    for _, side in ipairs(sides) do
        if peripheral.getType(side) == "monitor" then
            monitor = peripheral.wrap(side)
            break
        end
    end
end

-- Busqueda Agresiva del Speaker
local speaker = peripheral.find("speaker")
if not speaker then
    local sides = {"left", "right", "top", "bottom", "front", "back"}
    for _, side in ipairs(sides) do
        if peripheral.getType(side) == "speaker" then
            speaker = peripheral.wrap(side)
            break
        end
    end
end

local chatHistory = {
    { 
        role = "system", 
        content = "Eres una IA en un terminal de Minecraft. IMPORTANTE: Responde en espanol pero usa SOLO el alfabeto ingles estandar. No uses signos de interrogacion invertidos, acentos ni letras especiales. Se breve y directo." 
    }
}

-- ==========================================
-- SISTEMA DE AUDIO
-- ==========================================
local function playNoteSafe(instrument, volume, pitch)
    if speaker then
        speaker.playNote(instrument, volume or 3.0, pitch or 12)
    end
end

-- ==========================================
-- REPRODUCTOR DE AUDIO (EASTER EGG EXACTO)
-- ==========================================
local function playBailecito()
    local urlAudio = "https://od.lk/s/MjJfMzcxNjI3NDdf/Rat%20Dance%20Meme%20%20Beginner%20Piano%20Tutorial%20%20Easy%20Piano%20%286%29.dfpwm"

    if not speaker then
        term.setTextColor(colors.red)
        print("Error: No se detecta un speaker conectado.")
        term.setTextColor(colors.white)
        return
    end

    term.setTextColor(colors.cyan)
    print("Conectando al servidor de audio...")
    term.setTextColor(colors.white)

    -- El tercer parametro 'true' es vital: descarga el archivo en modo binario
    local response = http.get(urlAudio, nil, true)

    if not response then
        term.setTextColor(colors.red)
        print("Error: No se pudo conectar. Verifica el enlace RAW.")
        term.setTextColor(colors.white)
        return
    end

    term.setTextColor(colors.green)
    print("Reproduciendo audio...")
    term.setTextColor(colors.gray)
    print("(Presiona Ctrl + T para detener)")
    term.setTextColor(colors.white)

    -- Creamos el decodificador
    local decoder = dfpwm.make_decoder()

    -- Bucle de reproduccion
    while true do
        -- Leemos el audio en pequenos fragmentos (16KB)
        local chunk = response.read(16 * 1024)
        
        -- Si ya no hay chunk, termino la cancion
        if not chunk then 
            break 
        end
        
        -- Decodificamos el fragmento
        local buffer = decoder(chunk)
        
        -- Enviamos el buffer al speaker. 
        -- Si el buffer interno del speaker esta lleno, esperamos.
        while not speaker.playAudio(buffer) do
            os.pullEvent("speaker_audio_empty")
        end
    end

    -- Cerramos la conexion
    response.close()

    term.setTextColor(colors.yellow)
    print("\nReproduccion finalizada.")
    term.setTextColor(colors.white)
end

-- ==========================================
-- FILTRO ABSOLUTO DE CARACTERES
-- ==========================================
local function cleanText(str)
    if type(str) ~= "string" then return str end
    str = str:gsub("\194\191", "?")
    str = str:gsub("\194\161", "!")
    str = str:gsub("[^\n\32-\126]", "")
    return str
end

-- ==========================================
-- INTERFAZ GRAFICA Y ANIMACION ORIGINAL
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
    
    monitor.setCursorPos(1, 2)
    monitor.setBackgroundColor(colors.gray)
    monitor.setTextColor(colors.lightGray)
    monitor.write(string.rep("-", w))
end

local function refreshUI(animateLast)
    if not monitor then return end
    monitor.setTextScale(0.5)
    local w, h = monitor.getSize()
    
    local displayLines = {}
    for i = 2, #chatHistory do
        local msg = chatHistory[i]
        local isUser = (msg.role == "user")
        local isLastMsg = (i == #chatHistory) and not isUser
        
        local name = isUser and "Usuario" or "Sistema"
        local nameColor = isUser and colors.cyan or colors.lime
        local textColor = isUser and colors.white or colors.lightGray
        
        local safeText = cleanText(msg.content)
        local wrapped = wrapText(safeText, w - 2)
        
        table.insert(displayLines, {text = " " .. name .. ":", color = nameColor, animate = false})
        for _, lineStr in ipairs(wrapped) do
            table.insert(displayLines, {text = "  " .. lineStr, color = textColor, animate = isLastMsg})
        end
        table.insert(displayLines, {text = "", color = colors.black, animate = false})
    end
    
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    drawHeader(w)
    
    local maxLines = h - 2
    local startIdx = math.max(1, #displayLines - maxLines + 1)
    
    local currentY = 3
    for i = startIdx, #displayLines do
        if currentY > h then break end
        local lineData = displayLines[i]
        monitor.setCursorPos(1, currentY)
        monitor.setBackgroundColor(colors.black)
        monitor.setTextColor(lineData.color)
        
        if animateLast and lineData.animate then
            local charsPerTick = 2
            for charIdx = 1, #lineData.text do
                monitor.write(lineData.text:sub(charIdx, charIdx))
                if charIdx % charsPerTick == 0 then
                    playNoteSafe("hat", 0.3, 24)
                    sleep(0)
                end
            end
            if #lineData.text % charsPerTick ~= 0 then sleep(0) end
        else
            monitor.write(lineData.text)
        end
        
        currentY = currentY + 1
    end
    
    if animateLast then
        playNoteSafe("bell", 3.0, 12)
        sleep(0.1)
        playNoteSafe("bell", 3.0, 16)
    end
end

-- ==========================================
-- CONEXION CON GROQ
-- ==========================================
local function askGroq(input)
    table.insert(chatHistory, { role = "user", content = input })
    refreshUI(false)
    
    local body = {
        model = modelName,
        messages = chatHistory,
        max_tokens = 250,
        temperature = 0.5
    }
    
    local response = http.post(
        "https://api.groq.com/openai/v1/chat/completions",
        textutils.serializeJSON(body),
        { ["Authorization"] = "Bearer " .. apiKey, ["Content-Type"] = "application/json" }
    )

    if response then
        local rawData = response.readAll()
        response.close()
        local data = textutils.unserializeJSON(rawData)
        
        if data and data.choices and data.choices[1] then
            local content = cleanText(data.choices[1].message.content)
            table.insert(chatHistory, { role = "assistant", content = content })
            refreshUI(true)
            return true
        end
    end
    
    table.insert(chatHistory, { role = "assistant", content = "Error: Senal perdida." })
    refreshUI(true)
    playNoteSafe("bass", 3.0, 1)
    return false
end

-- ==========================================
-- BUCLE PRINCIPAL
-- ==========================================
term.clear()
term.setCursorPos(1,1)
term.setTextColor(colors.cyan)
print("=============================")
print(" GROQ OS INICIADO ")
print("=============================")
term.setTextColor(colors.white)

if not speaker then
    term.setTextColor(colors.red)
    print("ALERTA: Speaker no detectado fisicamente.")
    print("Asegurate de que el bloque toca la PC.")
    term.setTextColor(colors.white)
else
    term.setTextColor(colors.green)
    print("Speaker conectado.")
    term.setTextColor(colors.white)
end

print("Escribe 'clear' para reiniciar memoria.")
print("Escribe 'bailecito' para probar el audio.\n")

playNoteSafe("chime", 3.0, 8)
sleep(0.1)
playNoteSafe("chime", 3.0, 12)
sleep(0.1)
playNoteSafe("chime", 3.0, 16)

while true do
    refreshUI(false)
    term.setTextColor(colors.cyan)
    write("Comando> ")
    term.setTextColor(colors.white)
    local input = read()
    
    playNoteSafe("hat", 1.0, 12)
    
    if input:lower() == "bailecito" then
        playBailecito()
    elseif input:lower() == "clear" then
        chatHistory = { chatHistory[1] }
        print("Memoria borrada.")
        playNoteSafe("pling", 3.0, 24)
    elseif #input > 0 then
        print("Procesando consulta...")
        askGroq(input)
    end
end
