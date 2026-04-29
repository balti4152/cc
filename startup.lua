-- ==========================================
-- CONFIGURACION IA Y PERIFERICOS
-- ==========================================
local apiKey = "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"
local modelName = "llama-3.3-70b-versatile"
local monitor = peripheral.wrap("top")
local speaker = peripheral.find("speaker")

local chatHistory = {
    { 
        role = "system", 
        content = "Eres una IA en un terminal de Minecraft. IMPORTANTE: Responde en espanol pero usa SOLO el alfabeto ingles estandar. No uses signos de interrogacion invertidos, acentos ni letras especiales. Se breve y directo." 
    }
}

-- ==========================================
-- SISTEMA DE AUDIO
-- ==========================================
local function playSound(soundName, pitch)
    if speaker then
        -- Formato: playSound(nombre_del_sonido, volumen, pitch)
        speaker.playSound(soundName, 1.0, pitch or 1.0)
    end
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
-- INTERFAZ GRAFICA (UI Mejorada)
-- ==========================================
local function wrapText(text, maxWidth)
    local lines = {}
    local currentLine = ""
    
    for word in text:gmatch("%S+") do
        if #currentLine + #word + 1 > maxWidth then
            if #currentLine > 0 then
                table.insert(lines, currentLine)
            end
            currentLine = word .. " "
        else
            currentLine = currentLine .. word .. " "
        end
    end
    if #currentLine > 0 then
        table.insert(lines, currentLine)
    end
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

local function refreshUI()
    if not monitor then return end
    monitor.setTextScale(0.5)
    local w, h = monitor.getSize()
    
    local displayLines = {}
    for i = 2, #chatHistory do
        local msg = chatHistory[i]
        local isUser = (msg.role == "user")
        
        local name = isUser and "Usuario" or "Sistema"
        local nameColor = isUser and colors.cyan or colors.lime
        local textColor = isUser and colors.white or colors.lightGray
        
        local safeText = cleanText(msg.content)
        local wrapped = wrapText(safeText, w - 2)
        
        table.insert(displayLines, {text = " " .. name .. ":", color = nameColor})
        
        for _, lineStr in ipairs(wrapped) do
            table.insert(displayLines, {text = "  " .. lineStr, color = textColor})
        end
        table.insert(displayLines, {text = "", color = colors.black})
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
        monitor.write(lineData.text)
        currentY = currentY + 1
    end
end

-- ==========================================
-- CONEXION CON GROQ
-- ==========================================
local function askGroq(input)
    table.insert(chatHistory, { role = "user", content = input })
    
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
            
            -- Sonido de notificacion al recibir el mensaje de la IA
            playSound("block.note_block.bell", 1.5)
            playSound("block.note_block.chime", 1.0)
            return true
        end
    end
    
    table.insert(chatHistory, { role = "assistant", content = "Error: Senal perdida." })
    -- Sonido de error grave
    playSound("block.note_block.bass", 0.5)
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
print("Escribe 'clear' para reiniciar memoria.\n")

-- Sonido de arranque del sistema operativo
playSound("entity.experience_orb.pickup", 0.8)
sleep(0.2)
playSound("entity.experience_orb.pickup", 1.2)

while true do
    refreshUI()
    term.setTextColor(colors.cyan)
    write("Comando> ")
    term.setTextColor(colors.white)
    local input = read()
    
    -- Sonido de click al mandar el mensaje
    playSound("ui.button.click", 1.2)
    
    if input == "clear" then
        chatHistory = { chatHistory[1] }
        print("Memoria borrada con exito.")
        playSound("block.note_block.pling", 2.0)
    elseif #input > 0 then
        print("Procesando consulta...")
        askGroq(input)
    end
end
