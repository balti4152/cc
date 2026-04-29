-- Configuracion
local apiKey = "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"
local modelName = "llama-3.1-8b-instant"
local monitor = peripheral.wrap("top")

local chatHistory = {
    { 
        role = "system", 
        content = "Habla en espanol latino. No uses tildes ni la letra enye. Cambia enye por n. Se muy breve, maximo 20 palabras." 
    }
}

-- Funcion para eliminar acentos y enyes (Seguridad de pantalla)
local function clean(text)
    local replacements = {
        ["á"]="a", ["é"]="e", ["í"]="i", ["ó"]="o", ["ú"]="u",
        ["Á"]="A", ["É"]="E", ["Í"]="I", ["Ó"]="O", ["Ú"]="U",
        ["ñ"]="n", ["Ñ"]="N"
    }
    for k, v in pairs(replacements) do
        text = text:gsub(k, v)
    end
    return text
end

-- Funcion para escribir sin que se corte el texto
local function writeWrapped(text, y)
    if not monitor then return y end
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
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    monitor.setTextScale(0.5)
    
    monitor.setCursorPos(1, 1)
    monitor.setTextColor(colors.black)
    monitor.setBackgroundColor(colors.orange)
    local w, _ = monitor.getSize()
    monitor.write(" TERMINAL IA " .. string.rep(" ", w))
    
    local nextY = 3
    for i = math.max(2, #chatHistory - 2), #chatHistory do
        local msg = chatHistory[i]
        monitor.setBackgroundColor(colors.black)
        monitor.setTextColor(msg.role == "user" and colors.cyan or colors.lime)
        monitor.setCursorPos(1, nextY)
        monitor.write(msg.role == "user" and "> U: " or "> IA: ")
        
        monitor.setTextColor(colors.white)
        nextY = writeWrapped(clean(msg.content), nextY)
        nextY = nextY + 1
        if nextY > 12 then break end
    end
end

local function askGroq(input)
    table.insert(chatHistory, { role = "user", content = input })
    local response = http.post(
        "https://api.groq.com/openai/v1/chat/completions",
        textutils.serializeJSON({ model = modelName, messages = chatHistory, max_tokens = 100 }),
        { ["Authorization"] = "Bearer " .. apiKey, ["Content-Type"] = "application/json" }
    )

    if response then
        local data = textutils.unserializeJSON(response.readAll())
        response.close()
        local content = data.choices[1].message.content
        table.insert(chatHistory, { role = "assistant", content = content })
        return content
    end
    return "Error de red."
end

-- Main
term.clear()
term.setCursorPos(1,1)
print("Consola lista. Escribe 'clear' para reiniciar.")

while true do
    refreshUI()
    term.setTextColor(colors.orange)
    write("\nMensaje: ")
    term.setTextColor(colors.white)
    local input = read()
    
    if input == "clear" then
        chatHistory = { chatHistory[1] }
        print("Chat reiniciado.")
    elseif #input > 0 then
        print("Consultando...")
        askGroq(input)
    end
end
