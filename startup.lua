-- Busqueda de perifericos
local speaker = nil
local drive = nil
local monitor = nil
local lados = {"top", "bottom", "front", "back", "left", "right"}

for _, lado in ipairs(lados) do
    local tipo = peripheral.getType(lado)
    if tipo == "speaker" then
        speaker = peripheral.wrap(lado)
    elseif tipo == "drive" then
        drive = peripheral.wrap(lado)
    elseif tipo == "monitor" then
        monitor = peripheral.wrap(lado)
    end
end

local terminal_original = term.current()

if not speaker or not drive then
    term.clear()
    term.setCursorPos(1,1)
    print("Error: Conecta el speaker y el lector.")
    return
end

-- Configurar el monitor si existe
local pantalla = monitor or terminal_original
if monitor then
    monitor.setTextScale(1)
end

local decoder = require("cc.audio.dfpwm")

local function dibujarInterfaz(cancion, progreso, total)
    term.redirect(pantalla)
    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- Titulo en Verde
    term.setTextColor(colors.green)
    term.setCursorPos(2, 2)
    print("REPRODUCIENDO:")
    
    term.setTextColor(colors.white)
    term.setCursorPos(2, 3)
    local nombre = string.sub(cancion, 1, 20)
    print(nombre)

    -- Barra de progreso dinamica (se adapta al ancho de tu monitor)
    local w, h = term.getSize()
    local anchoBarra = w - 4

    local proporcion = 0
    if total > 0 then
        proporcion = progreso / total
    end
    if proporcion > 1 then proporcion = 1 end
    
    local completado = math.floor(proporcion * anchoBarra)
    
    term.setCursorPos(2, 5)
    term.setTextColor(colors.gray)
    term.write("[")
    term.setTextColor(colors.green)
    term.write(string.rep("|", completado))
    term.setTextColor(colors.gray)
    term.write(string.rep(".", math.max(0, anchoBarra - completado)))
    term.write("]")

    -- Tiempo en formato Spotify
    term.setCursorPos(2, 6)
    term.setTextColor(colors.white)
    local seg = math.floor(progreso % 60)
    local min = math.floor(progreso / 60)
    term.write(string.format("%02d:%02d", min, seg))
    
    term.redirect(terminal_original)
end

local function reproducir(url)
    local respuesta, err = http.get({ url = url, binary = true })
    if not respuesta then 
        term.redirect(pantalla)
        term.clear()
        term.setCursorPos(2,2)
        term.setTextColor(colors.red)
        print("Error de red.")
        term.redirect(terminal_original)
        sleep(2)
        return 
    end

    local decode = decoder.make_decoder()
    local headers = respuesta.getResponseHeaders()
    local tamanoTotal = tonumber(headers["Content-Length"]) or 1000000
    local totalSegundos = tamanoTotal / 6000 -- DFPWM usa aprox 6000 bytes/seg
    local inicioTime = os.epoch("utc")

    while true do
        if not drive.isDiskPresent() then break end

        local chunk = respuesta.read(16 * 1024)
        if not chunk then break end
        
        local buffer = decode(chunk)
        local tiempoActual = (os.epoch("utc") - inicioTime) / 1000
        
        dibujarInterfaz("Streaming de Audio", tiempoActual, totalSegundos)

        while not speaker.playAudio(buffer) do
            if not drive.isDiskPresent() then 
                respuesta.close()
                return 
            end
            os.pullEvent("speaker_audio_empty")
        end
    end
    
    respuesta.close()
end

local function grabar(path)
    -- Pantalla del monitor
    term.redirect(pantalla)
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setTextColor(colors.green)
    term.setCursorPos(2, 2)
    print("UNIDAD VACIA")
    term.setTextColor(colors.white)
    term.setCursorPos(2, 4)
    print("Ingresa URL en la Turtle")
    
    -- Pantalla de la Turtle (para poder pegar comodo)
    term.redirect(terminal_original)
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setTextColor(colors.green)
    term.setCursorPos(1, 1)
    print("=== MODO GRABACION ===")
    term.setTextColor(colors.white)
    print("Pega el link de OpenDrive aca:")
    
    local url = read()
    
    if url ~= "" then
        local f = fs.open(path .. "/song_url.txt", "w")
        f.write(url)
        f.close()
        print("Enlace guardado. Reproduciendo...")
        sleep(1)
    end
end

-- Bucle Principal
while true do
    term.redirect(pantalla)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.green)
    term.clear()
    term.setCursorPos(2, 2)
    print("SPOTIFY TURTLE")
    term.setTextColor(colors.gray)
    term.setCursorPos(2, 4)
    print("Inserta un diskete...")
    term.redirect(terminal_original)

    -- Detectar si hay un diskete puesto o si insertan uno nuevo
    if drive.isDiskPresent() then
        local path = drive.getMountPath()
        if path then
            local archivo = path .. "/song_url.txt"
            if fs.exists(archivo) then
                local f = fs.open(archivo, "r")
                local url = f.readAll()
                f.close()
                -- Limpia variable y reproduce solo la leida
                reproducir(url)
            else
                grabar(path)
            end
        end
    else
        os.pullEvent("disk")
    end
    
    sleep(0.2)
end
