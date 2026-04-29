-- ==========================================
-- CONFIGURACION IA
-- ==========================================
local apiKey = "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"
local modelName = "llama-3.3-70b-versatile"
local monitor = peripheral.wrap("top")

-- Instruccion estricta
local chatHistory = {
    { 
        role = "system", 
        content = "Eres una IA en un terminal de Minecraft. IMPORTANTE: Responde en espanol latino pero usando EXCLUSIVAMENTE el alfabeto ingles (ASCII). Reemplaza la 'enye' por 'n'. No uses NINGUNA tilde, acento o caracter especial. Tus respuestas deben ser breves, claras y con un tono robotico avanzado." 
    }
}

-- ==========================================
-- FILTRO DE CARACTERES UTF-8 A ASCII
-- ==========================================
-- ComputerCraft usa Lua 5.1 que no entiende UTF-8.
-- Esto intercepta los bytes crudos y los cambia por letras normales.
local function cleanText(str)
    if type(str) ~= "string" then return str end
    -- Minusculas
    str = str:gsub("\195\161", "a")
    str = str:gsub("\195\169", "e")
    str = str:gsub("\195\173", "i")
    str = str:gsub("\195\179", "o")
    str = str:gsub("\195\186", "u")
    str = str:gsub("\195\177", "n")
    -- Mayusculas
    str = str:gsub("\195\129", "A")
    str = str:gsub("\195\137", "E")
    str = str:gsub("\195\141", "I")
    str = str:gsub("\195\147", "O")
    str = str:gsub("\195\154", "U")
    str = str:gsub("\195\145", "N")
    return str
end

-- ==========================================
-- INTERFAZ GRAFICA (UI Avanzada)
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

local function refreshUI()
    if not monitor then return end
    monitor.setTextScale(0.5)
    local w, h = monitor.getSize()
    
    local displayLines = {}
    for i = 2, #chatHistory do
        local msg = chatHistory[i]
        local prefix = (msg.role == "user") and "Usr> " or "IA> "
        local color = (msg.role == "user") and colors.cyan or colors.lime
        
        -- Aplicamos la limpieza aqui por seguridad
        local safeText = cleanText(msg.content)
        local wrapped = wrapText(prefix .. safeText, w)
        
        for _, lineStr in ipairs(wrapped) do
            table.insert(displayLines, {text = lineStr, color = color})
        end
        table.insert(displayLines, {text = "", color = colors.white})
    end
    
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    
    monitor.setCursorPos(1, 1)
    monitor.setBackgroundColor(colors.gray)
    monitor.setTextColor(colors.yellow)
    local title = " TERMINAL IA ONLINE "
    local padding = math.floor((w - #title) / 2)
    monitor.write(string.rep(" ", math.max(0, padding)) .. title .. string.rep(" ", math.max(0, padding + 1)))
    monitor.setBackgroundColor(colors.black)
    
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
            -- Limpiamos el texto justo cuando llega de la API
            local rawContent = data.choices[1].message.content
            local content = cleanText(rawContent)
            table.insert(chatHistory, { role = "assistant", content = content })
            return true
        end
    end
    
    table.insert(chatHistory, { role = "assistant", content = "Error: Senal perdida." })
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
        chatHistory = { chatHistory[1] }
        print("Memoria borrada con exito.")
    elseif #input > 0 then
        print("Procesando consulta...")
        askGroq(input)
    end
end
