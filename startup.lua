-- Configuración inicial
local speaker = peripheral.find("speaker")
local drive = peripheral.find("drive")
local decoder = require("cc.audio.dfpwm")

if not speaker then
    print("Error: No se encontro un speaker conectado.")
    return
end

if not drive then
    print("Error: No se encontro un lector de discos.")
    return
end

local function limpiarPantalla()
    term.clear()
    term.setCursorPos(1, 1)
end

local function reproducirMusica(url)
    limpiarPantalla()
    print("Reproduciendo musica...")
    print("Presiona 'q' para detener.")
    
    local respuesta, err = http.get({ url = url, binary = true })
    if not respuesta then
        print("Error al conectar con la URL:")
        print(err)
        sleep(2)
        return
    end

    local buffer = ""
    while true do
        local chunk = respuesta.read(16 * 1024)
        if not chunk then break end
        
        local buffer_audio = decoder.make_decoder()(chunk)
        
        -- Esperar a que el speaker este disponible para mas audio
        while not speaker.playAudio(buffer_audio) do
            local event, key = os.pullEvent()
            if event == "key" and key == keys.q then
                respuesta.close()
                return
            end
        end
    end
    respuesta.close()
    print("Finalizado.")
    sleep(2)
end

local function grabarDisco(ruta)
    limpiarPantalla()
    print("--- Grabador de Discos ---")
    print("Pega el link directo de OpenDrive:")
    local url = read()
    
    if url == "" then return end
    
    local f = fs.open(ruta .. "/song_url.txt", "w")
    f.write(url)
    f.close()
    
    print("Cancion guardada en el disco con exito.")
    sleep(2)
end

local function menu()
    while true do
        limpiarPantalla()
        print("=== REPRODUCTOR DE MUSIKA ===")
        
        if not drive.isDiskPresent() then
            print("\nPor favor, inserta un diskete...")
            while not drive.isDiskPresent() do
                sleep(0.5)
            end
        end
        
        local mountPath = drive.getMountPath()
        local archivoUrl = mountPath .. "/song_url.txt"
        
        if fs.exists(archivoUrl) then
            local f = fs.open(archivoUrl, "r")
            local urlGuardada = f.readAll()
            f.close()
            
            print("\nDisco detectado.")
            print("1. Reproducir cancion")
            print("2. Sobrescribir cancion")
            print("3. Expulsar disco")
            
            local event, key = os.pullEvent("key")
            if key == keys.one then
                reproducirMusica(urlGuardada)
            elseif key == keys.two then
                grabarDisco(mountPath)
            elseif key == keys.three then
                drive.ejectDisk()
            end
        else
            print("\nEl disco esta vacio.")
            print("1. Grabar nueva cancion")
            print("2. Expulsar disco")
            
            local event, key = os.pullEvent("key")
            if key == keys.one then
                grabarDisco(mountPath)
            elseif key == keys.two then
                drive.ejectDisk()
            end
        end
    end
end

-- Iniciar el programa
menu()
