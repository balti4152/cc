-- ==========================================
-- CONFIGURACION
-- ==========================================
local apiKey = "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"
local modelName = "llama-3.1-8b-instant"
local monitor = peripheral.wrap("top")

-- ==========================================
-- FUNCIONES UTILES
-- ==========================================
local function writeToMonitor(text)
    if monitor then
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monitor.setTextScale(1)
        local old = term.redirect(monitor)
        print(text)
        term.redirect(old)
    else
        print(text)
    end
end

local function getGroqResponse(prompt)
    local url = "https://api.groq.com/openai/v1/chat/completions"
    local body = {
        model = modelName,
        messages = {
            { role = "system", content = "Eres un asistente de Minecraft experto y breve." },
            { role = "user", content = prompt }
        }
    }

    local response = http.post(
        url,
        textutils.serializeJSON(body),
        {
            ["Authorization"] = "Bearer " .. apiKey,
            ["Content-Type"] = "application/json"
        }
    )

    if response then
        local data = textutils.unserializeJSON(response.readAll())
        response.close()
        return data.choices[1].message.content
    end
    return "Error de conexion con Groq."
end

-- ==========================================
-- LOGICA PRINCIPAL
-- ==========================================
term.clear()
term.setCursorPos(1,1)
print("SISTEMA INICIADO")

-- 1. Obtener Ubicacion
print("Localizando via GPS...")
local x, y, z = gps.locate()
local locStr = x and ("X:" .. x .. " Y:" .. y .. " Z:" .. z) or "Desconocida"

-- 2. Consultar IA
print("Consultando IA...")
local saludo = getGroqResponse("Saluda al usuario. Ubicacion actual: " .. locStr)

-- 3. Mostrar Resultado
writeToMonitor(saludo)
print("Proceso completado.")
