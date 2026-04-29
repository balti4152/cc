-- Configuracion
local apiKey = "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"
local modelName = "llama-3.1-8b-instant"
local monitor = peripheral.wrap("top")

-- Historial con instrucciones de formato estrictas
local chatHistory = {
    { 
        role = "system", 
        content = "Eres una IA tecnica de Minecraft. Habla en espanol latino. IMPORTANTE: No uses tildes ni la letra enye bajo ninguna circunstancia. Cambia la enye por n y las vocales con tilde por vocales simples. Se breve." 
    }
}

-- Funcion para limpiar texto (seguro de vida por si la IA se olvida)
local function cleanText(text)
    local replacements = {
        ["n"] = "n", ["N"] = "N",
        ["a"] = "a", ["e"] = "e", ["i"] = "i", ["o"] = "o", ["u"] = "u",
        ["A"] = "A", ["E"] = "E", ["I"] = "I", ["O"] = "O", ["U"] = "U"
    }
    -- Intentar limpiar patrones comunes de acentos y enyes
    local cleaned = text:gsub("n", "n"):gsub("N", "N")
    cleaned = cleaned:gsub("[%z\1-\127\194-\244][\128-\191]*", function(c)
        return replacements[c] or c
    end)
    return cleaned
end

local function colorWrite(text, textColor, bgColor, y)
    if not monitor then return end
    monitor.setCursorPos(1, y)
    monitor.setTextColor(textColor or colors.white)
    monitor.setBackgroundColor(bgColor or colors.black)
    
    local w, _ = monitor.getSize()
    monitor.write(string.rep(" ", w))
    monitor.setCursorPos(1, y)
    
    -- Limpiamos el texto antes de mandarlo al monitor
    monitor.write(cleanText(text))
end

local function refreshUI()
    if not monitor then return end
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    monitor.setTextScale(0.5)
    
    colorWrite(" --- Hola! Como puedo ayudarte? --- ", colors.black, colors.orange, 1)
    
    local currentY = 3
    for i = math.max(2, #chatHistory - 4), #chatHistory do
        local msg = chatHistory[i]
        local prefix = msg.role == "user" and "U: " or "IA: "
        local pColor = msg.role == "user" and colors.cyan or colors.lime
        
        colorWrite(prefix .. msg.content:sub(1, 22), pColor, colors.black, currentY)
        currentY = currentY + 1
    end
end

local function askGroq(input)
    table.insert(chatHistory, { role = "user", content = input })
    local response = http.post(
        "https://api.groq.com/openai/v1/chat/completions",
        textutils.serializeJSON({ model = modelName, messages = chatHistory }),
        { ["Authorization"] = "Bearer " .. apiKey, ["Content-Type"] = "application/json" }
    )

    if response then
        local data = textutils.unserializeJSON(response.readAll())
        response.close()
        local content = data.choices[1].message.content
        table.insert(chatHistory, { role = "assistant", content = content })
        return content
    end
    return "Error de conexion."
end

-- Inicio del programa
term.clear()
term.setCursorPos(1,1)
term.setTextColor(colors.orange)
print("Hablar con la IA")
term.setTextColor(colors.white)

while true do
    refreshUI()
    write("\nMensaje: ")
    local input = read()
    
    if input == "clear" then
        chatHistory = { chatHistory[1] }
        print("Memoria reseteada.")
    else
        print("Consultando...")
        local res = askGroq(input)
        print("Respuesta: " .. cleanText(res))
    end
end
