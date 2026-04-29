local speaker = nil
local drive = nil
local lados = {"top", "bottom", "front", "back", "left", "right"}

for _, lado in ipairs(lados) do
    if peripheral.getType(lado) == "speaker" then
        speaker = peripheral.wrap(lado)
    elseif peripheral.getType(lado) == "drive" then
        drive = peripheral.wrap(lado)
    end
end

if not speaker or not drive then
    print("Error: Conecta perifericos.")
    return
end

local decoder = require("cc.audio.dfpwm")

local function dibujarInterfaz(cancion, progreso, total)
    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- Titulo en Verde
    term.setTextColor(colors.green)
    term.setCursorPos(2, 2)
    print("REPRODUCIENDO:")
    
    term.setTextColor(colors.white)
    term.setCursorPos(2, 3)
    local nombre = cancion:sub(1, 20)
    print(nombre)

    -- Barra de progreso
    local anchoBarra = 20
    local completado = math.floor((progreso / total) * anchoBarra)
    
    term.setCursorPos(2, 5)
    term.setTextColor(colors.gray)
    term.write("[")
    term.setTextColor(colors.green)
    term.write(string.rep("|", completado))
    term.setTextColor(colors.gray)
    term.write(string.rep(".", anchoBarra - completado))
    term.write("]")

    -- Tiempo
    term.setCursorPos(2, 6)
    term.setTextColor(colors.white)
    local seg = math.floor(progreso % 60)
    local min = math.floor(progreso / 60)
    term.write(string.format("%02d:%02d", min, seg))
end

local function reproducir(url)
    local respuesta, err = http.get({ url = url, binary = true })
    if not respuesta then return end

    local decode = decoder.make_decoder()
    local tamanoTotal = tonumber(respuesta.getResponseHeaders()["Content-Length"]) or 1000000
    local leido = 0
    local inicioTime = os.epoch("utc")

    while true do
        if not drive.isDiskPresent() then break end

        local chunk = respuesta.read(16 * 1024)
        if not chunk then break end
        
        leido = leido + #chunk
        local buffer = decode(chunk)
        
        -- Calcular progreso estimado (DFPWM es ~6000 bytes por segundo)
        local tiempoActual = (os.epoch("utc") - inicioTime) / 1000
        dibujarInterfaz("Streaming Audio", tiempoActual, tamanoTotal / 6000)

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
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setTextColor(colors.green)
    term.setCursorPos(2, 2)
    print("NUEVO DISCO")
    term.setTextColor(colors.white)
    term.setCursorPos(2, 4)
    print("Pega la URL:")
    term.setCursorPos(2, 5)
    local url = read()
    
    if url ~= "" then
        local f = fs.open(path .. "/song_url.txt", "w")
        f.write(url)
        f.close()
    end
end

-- Bucle Principal
while true do
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.green)
    term.clear()
    term.setCursorPos(2, 2)
    print("SPOTIFY TURTLE")
    term.setTextColor(colors.gray)
    term.setCursorPos(2, 4)
    print("Inserta un disco...")

    -- Esperar disco
    local event, side = os.pullEvent()
    if event == "disk" or drive.isDiskPresent() then
        local path = drive.getMountPath()
        if path then
            local archivo = path .. "/song_url.txt"
            if fs.exists(archivo) then
                local f = fs.open(archivo, "r")
                local url = f.readAll()
                f.close()
                -- Reset de variables antes de reproducir
                reproducir(url)
            else
                grabar(path)
            end
        end
    end
    sleep(0.5)
end
