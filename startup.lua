-- Busqueda automatica de perifericos
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

-- Validacion de conexion
if not speaker or not drive then
    term.clear()
    term.setCursorPos(1,1)
    print("Error: Perifericos faltantes.")
    if not speaker then print("- Falta Speaker") end
    if not drive then print("- Falta Lector (Drive)") end
    return
end

local decoder = require("cc.audio.dfpwm")

local function limpiarPantalla()
    term.clear()
    term.setCursorPos(1, 1)
end

local function reproducirMusica(url)
    limpiarPantalla()
    print("Reproduciendo: Streaming...")
    print("Mantén 'q' para salir")
    
    local respuesta, err = http.get({ url = url, binary = true })
    if not respuesta then
        print("Error de conexion:")
        print(err)
        sleep(2)
        return
    end

    local decode = decoder.make_decoder()
    while true do
        local chunk = respuesta.read(16 * 1024)
        if not chunk then break end
        
        local buffer_audio = decode(chunk)
        
        -- Espera a que el speaker termine de procesar para no saturar
        while not speaker.playAudio(buffer_audio) do
            os.pullEvent("speaker_audio_empty")
        end
        
        -- Check de salida rapida
        if isKeyDown and isKeyDown(keys.q) then 
            break 
        end
        
        -- Pequeno delay para permitir otros eventos
        sleep(0.05)
    end
    
    respuesta.close()
    print("Reproduccion terminada.")
    sleep(1.5)
end

local function grabarDisco(mountPath)
    limpiarPantalla()
    print("--- Grabador de Discos ---")
    print("Pega el link de OpenDrive:")
    local url = read()
    
    if url ~= "" then
        local f = fs.open(mountPath .. "/song_url.txt", "w")
        f.write(url)
        f.close()
        print("URL guardada en el disco.")
    else
        print("Operacion cancelada.")
    end
    sleep(1.5)
end

local function iniciarMenu()
    while true do
        limpiarPantalla()
        print("== SISTEMA DE AUDIO TURTLE ==")
        
        if not drive.isDiskPresent() then
            print("\n[ Esperando disco... ]")
            while not drive.isDiskPresent() do
                sleep(0.5)
            end
        end
        
        local mountPath = drive.getMountPath()
        if not mountPath then
            print("Error: No se pudo leer el disco.")
            sleep(1)
        else
            local archivoUrl = mountPath .. "/song_url.txt"
            
            if fs.exists(archivoUrl) then
                local f = fs.open(archivoUrl, "r")
                local urlData = f.readAll()
                f.close()
                
                print("\nDisco con musica detectado.")
                print("1. Reproducir")
                print("2. Cambiar URL (Borrar)")
                print("3. Expulsar")
                
                local _, key = os.pullEvent("key")
                if key == keys.one then
                    reproducirMusica(urlData)
                elseif key == keys.two then
                    grabarDisco(mountPath)
                elseif key == keys.three then
                    drive.ejectDisk()
                end
            else
                print("\nDisco vacio / nuevo.")
                print("1. Grabar URL de streaming")
                print("2. Expulsar")
                
                local _, key = os.pullEvent("key")
                if key == keys.one then
                    grabarDisco(mountPath)
                elseif key == keys.two then
                    drive.ejectDisk()
                end
            end
        end
    end
end

iniciarMenu()
