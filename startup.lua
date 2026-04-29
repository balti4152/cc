-- Busqueda de perifericos en todos los lados
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
    term.clear()
    term.setCursorPos(1,1)
    print("Error: Conecta speaker y drive.")
    return
end

local decoder = require("cc.audio.dfpwm")

local function limpiar()
    term.clear()
    term.setCursorPos(1,1)
end

local function reproducir(url)
    limpiar()
    print("Reproduciendo automaticamente...")
    print("Pulsa 'q' para detener y expulsar")
    
    local respuesta, err = http.get({ url = url, binary = true })
    if not respuesta then
        print("Error de conexion.")
        sleep(2)
        return
    end

    local decode = decoder.make_decoder()
    while true do
        local chunk = respuesta.read(16 * 1024)
        if not chunk then break end
        local buffer = decode(chunk)
        
        while not speaker.playAudio(buffer) do
            os.pullEvent("speaker_audio_empty")
        end
        
        -- Si presionas Q, para la musica y sale
        if os.pullEventRaw("key") and arg[1] == keys.q then
            break
        end
        
        -- Si sacas el disco fisicamente, para el streaming
        if not drive.isDiskPresent() then
            break
        end
    end
    respuesta.close()
end

local function grabar(path)
    limpiar()
    print("=== DISKO VACIO ===")
    print("Pega la URL de streaming:")
    local url = read()
    if url ~= "" then
        local f = fs.open(path .. "/song_url.txt", "w")
        f.write(url)
        f.close()
        print("Guardado. Reiniciando...")
        sleep(1)
    end
end

local function checkDisco()
    if drive.isDiskPresent() then
        local path = drive.getMountPath()
        if path then
            local archivo = path .. "/song_url.txt"
            if fs.exists(archivo) then
                local f = fs.open(archivo, "r")
                local url = f.readAll()
                f.close()
                reproducir(url)
                -- Al terminar, opcionalmente puedes expulsarlo o esperar
                print("Fin de la cancion.")
                drive.ejectDisk()
            else
                grabar(path)
            end
        end
    end
end

-- Bucle principal: Espera eventos sin consumir CPU
limpiar()
print("Esperando disco (como en un auto)...")

while true do
    checkDisco() -- Revisar si ya habia uno puesto al iniciar
    limpiar()
    print("Sistema listo.")
    print("Inserta un diskete para comenzar...")
    
    -- Espera a que ocurra un evento de disco
    os.pullEvent("disk") 
end
