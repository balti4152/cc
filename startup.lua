-- ==========================================
-- CONFIGURACION IA
-- ==========================================
local apiKey = "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"
local modelName = "llama-3.3-70b-versatile" -- Modelo muy superior
local monitor = peripheral.wrap("top")

-- Instruccion estricta para forzar formato ASCII
local chatHistory = {
    { 
        role = "system", 
        content = "Eres una IA en un terminal de Minecraft. IMPORTANTE: Responde en espanol latino pero usando EXCLUSIVAMENTE el alfabeto ingles (ASCII). Reemplaza la 'enye' por 'n'. No uses NINGUNA tilde, acento o caracter especial. Tus respuestas deben ser breves, claras y con un tono robotico avanzado." 
    }
}

-- ==========================================
-- INTERFAZ GRAFICA (UI Avanzada)
-- ==========================================

-- Divide el texto en renglones exactos segun el ancho del monitor
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

-- Dibuja el chat con scroll automatico desde abajo hacia arriba
local function refreshUI()
    if not monitor then return end
    monitor.setTextScale(0.5)
    local w, h = monitor.getSize()
    
    -- Procesamos todo el historial para convertirlo en renglones
    local displayLines = {}
    for i = 2, #chatHistory do
        local msg = chatHistory[i]
        local prefix = (msg.role == "user") and "Usr> " or "IA> "
        local color = (msg.role == "user") and colors.cyan or colors.lime
        
        local wrapped = wrapText(prefix .. msg.content, w)
        for _, lineStr in ipairs(wrapped) do
            table.insert(displayLines, {text = lineStr, color = color})
        end
        -- Separador visual entre mensajes
        table.insert(displayLines, {text = "", color = colors.white})
    end
    
    -- Limpiamos pantalla
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    
    -- Dibujamos el Encabezado centrado
    monitor.setCursorPos(1, 1)
    monitor.setBackgroundColor(colors.gray)
    monitor.setTextColor(colors.yellow)
    local title = " TERMINAL IA ONLINE "
    local padding = math.floor((w - #title) / 2)
    monitor.write(string.rep(" ", math.max(0, padding)) .. title .. string.rep(" ", math.max(0, padding + 1)))
    monitor.setBackgroundColor(colors.black)
    
    -- Calculamos que lineas caben en pantalla (Scroll)
    local maxLines = h - 1
    local startIdx = math.max(1, #displayLines - maxLines + 1)
    
    local currentY = 2
    for i = startIdx, #displayLines do
        if currentY > h then break end
        local lineData = displayLines[i]
        monitor.setCursorPos(1, currentY)
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
            local content = data.choices[1].message.content
            table.insert(chatHistory, { role = "assistant", content = content })
            return true
        end
    end
    
    -- Si hay error, lo mostramos como mensaje de la IA
    table.insert(chatHistory, { role = "assistant", content = "Error: Senal perdida con el servidor." })
    return false
end

-- ==========================================
-- BUCLE PRINCIPAL
-- ==========================================
term.clear()
term.setCursorPos(1,1)
term.setTextColor(colors.yellow)
print("=============================")
print("SISTEMA CENTRAL INICIADO")
print("=============================")
term.setTextColor(colors.white)
print("Escribe 'clear' para reiniciar memoria.\n")

while true do
    refreshUI()
    term.setTextColor(colors.orange)
    write("> ")
    term.setTextColor(colors.white)
    local input = read()
    
    if input == "clear" then
        -- Conservamos solo la instruccion principal (posicion 1)
        chatHistory = { chatHistory[1] }
        print("Memoria borrada con exito.")
    elseif #input > 0 then
        print("Procesando consulta...")
        askGroq(input)
    end
end
