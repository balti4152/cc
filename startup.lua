-- Configuración
local apiKey = "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"
local modelName = "llama-3.1-8b-instant"
local monitor = peripheral.wrap("top")

local chatHistory = {
    { role = "system", content = "Eres una IA integrada en un terminal de Minecraft. Responde de forma concisa y tecnica." }
}

-- Función para ajustar texto al ancho del monitor
local function writeWrapped(text, monitor, y)
    local width, height = monitor.getSize()
    local words = {}
    for word in text:gmatch("%S+") do table.insert(words, word) end
    
    local line = ""
    local currentY = y
    for _, word in ipairs(words) do
        if #line + #word + 1 > width then
            monitor.setCursorPos(1, currentY)
            monitor.write(line)
            line = word .. " "
            currentY = currentY + 1
        else
            line = line .. word .. " "
        end
        if currentY > height then break end
    end
    monitor.setCursorPos(1, currentY)
    monitor.write(line)
    return currentY + 1
end

local function refreshUI()
    if not monitor then return end
    monitor.clear()
    monitor.setTextScale(0.5)
    monitor.setCursorPos(1, 1)
    monitor.setTextColor(colors.cyan)
    monitor.write("--- TERMINAL IA ---")
    
    local nextY = 3
    -- Mostrar los últimos mensajes
    for i = math.max(2, #chatHistory - 3), #chatHistory do
        local msg = chatHistory[i]
        monitor.setTextColor(msg.role == "user" and colors.blue or colors.green)
        monitor.setCursorPos(1, nextY)
        monitor.write(msg.role == "user" and "U: " or "AI: ")
        
        monitor.setTextColor(colors.white)
        nextY = writeWrapped(msg.content, monitor, nextY)
        if nextY > 12 then break end
    end
end

local function askGroq(input)
    table.insert(chatHistory, { role = "user", content = input })
    local body = { model = modelName, messages = chatHistory, max_tokens = 150 }

    local response = http.post(
        "https://api.groq.com/openai/v1/chat/completions",
        textutils.serializeJSON(body),
        { ["Authorization"] = "Bearer " .. apiKey, ["Content-Type"] = "application/json" }
    )

    if response then
        local data = textutils.unserializeJSON(response.readAll())
        response.close()
        local content = data.choices[1].message.content
        table.insert(chatHistory, { role = "assistant", content = content })
        return content
    end
    return "Error de enlace."
end

-- Bucle principal
term.clear()
term.setCursorPos(1,1)
print("Consola lista. Escribe 'clear' para reiniciar chat.")

while true do
    refreshUI()
    term.setTextColor(colors.yellow)
    write("Mensaje: ")
    term.setTextColor(colors.white)
    
    local input = read()
    if input == "clear" then
        chatHistory = { chatHistory[1] }
        print("Historial limpio.")
    elseif #input > 0 then
        print("Procesando...")
        local res = askGroq(input)
        print("\nRespuesta recibida.\n")
    end
end
