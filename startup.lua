-- Configuracion de Groq (Basado en tu tabla de modelos)
local apiKey = "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"
local url = "https://api.groq.com/openai/v1/chat/completions"
local modelo = "llama-3.1-8b-instant" -- El mas rapido (560 T/s)

local monitor = peripheral.wrap("top")

-- 1. Localizacion GPS
print("Localizando...")
local x, y, z = gps.locate()

if not x then
    print("Error: No se detectan satelites GPS.")
    return
end

local posicion = "X:" .. x .. " Y:" .. y .. " Z:" .. z
print("Coordenadas: " .. posicion)

-- 2. Preparar el cuerpo para la API
local cuerpo = {
    model = modelo,
    messages = {
        {
            role = "user",
            content = "Eres un bot de Minecraft. Saluda de forma creativa y menciona que estas en " .. posicion .. ". Se breve."
        }
    },
    max_tokens = 100 -- Limitamos para ahorrar y ser rapidos
}

-- 3. Enviar peticion
print("Consultando a Groq (" .. modelo .. ")...")
local response = http.post(
    url,
    textutils.serializeJSON(cuerpo),
    {
        ["Authorization"] = "Bearer " .. apiKey,
        ["Content-Type"] = "application/json"
    }
)

if response then
    local sResponse = response.readAll()
    local data = textutils.unserializeJSON(sResponse)
    response.close()
    
    if data and data.choices then
        local saludo = data.choices[1].message.content
        
        -- Salida al monitor
        if monitor then
            monitor.clear()
            monitor.setTextScale(1)
            monitor.setCursorPos(1,1)
            local oldTerm = term.redirect(monitor)
            print(saludo)
            term.redirect(oldTerm)
            print("Listo! Mira el monitor.")
        else
            print("\nGroq dice: " .. saludo)
        end
    else
        print("Error: Respuesta de API malformada.")
    end
else
    print("Error: Sin respuesta de Groq. Revisa tu cuota o conexion.")
end
