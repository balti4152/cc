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

local pantalla = monitor or terminal_original
if monitor then
    monitor.setTextScale(1)
end

local decoder = require("cc.audio.dfpwm")

local function animacionCarga(url)
    local frames = {
        "[      ]",
        "[=     ]",
        "[==    ]",
        "[===   ]",
        "[ ===  ]",
        "[  === ]",
        "[   ===]",
        "[    ==]",
        "[     =]",
        "[      ]"
    }
    local i = 1
    
    -- Inicia la descarga en segundo plano
    http.request({ url = url, binary = true })
    
    while true do
        term.redirect(pantalla)
        term.setBackgroundColor(colors.black)
        term.clear()
        
        local w, h = term.getSize()
        term.setTextColor(colors.green)
        term.setCursorPos(math.floor(w/2) - 7, math.floor(h/2) - 1)
        print("Leyendo Disco...")
        
        term.setTextColor(colors.white)
        term.setCursorPos(math.floor(w/2) - 3, math.floor(h/2))
        print(frames[i])
        
        term.redirect(terminal_original)
        
        local timer = os.startTimer(0.15)
        
        -- Esperar respuesta o eventos
        while true do
            local event, p1, p2 = os.pullEvent()
            
            if event == "http_success" then
                return p2 -- Retorna el objeto de la descarga
            elseif event == "http_failure" then
                return nil
            elseif event == "disk_eject" or not drive.isDiskPresent() then
                return nil
            elseif event == "timer" and p1 == timer then
                break -- Cambia de frame
            end
        end
        
        i = i + 1
        if i > #frames then i = 1 end
    end
end

local function dibujarInterfaz(cancion, progreso, total, pausado)
    term.redirect(pantalla)
    term.setBackgroundColor(colors.black)
    term.clear()
    
    term.setTextColor(colors.green)
    term.setCursorPos(2, 2)
    print("REPRODUCIENDO:")
    
    term.setTextColor(colors.white)
    term.setCursorPos(2, 3)
    local nombre = string.sub(cancion, 1, 25)
    print(nombre)

    local w, h = term.getSize()
    local anchoBarra = w - 4

    local proporcion = 0
    if total > 0 then proporcion = progreso / total end
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

    term.setCursorPos(2, 6)
    term.setTextColor(colors.white)
    local seg = math.floor(progreso % 60)
    local min = math.floor(progreso / 60)
    term.write(string.format("%02d:%02d", min, seg))
    
    -- Botones siempre abajo
    local btnY = h - 2
    term.setCursorPos(2, btnY)
    
    if pausado then
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.green)
        term.write(" PLAY ")
    else
        term.setTextColor(colors.green)
        term.setBackgroundColor(colors.gray)
        term.write(" PAUSA ")
    end
    
    term.setBackgroundColor(colors.black)
    term.write("  ")
    term.setTextColor(colors.black)
    term.setBackgroundColor(colors.green)
    term.write(" +10s ")
    term.setBackgroundColor(colors.black)
    
    term.redirect(terminal_original)
end

local function reproducir(url, nombre_cancion)
    -- Pantalla de carga animada
    local respuesta = animacionCarga(url)
    
    if not respuesta then 
        term.redirect(pantalla)
        term.clear()
        term.setCursorPos(2,2)
        term.setTextColor(colors.red)
        if drive.isDiskPresent() then
            print("Error de lectura.")
            sleep(2)
        end
        term.redirect(terminal_original)
        return 
    end

    local decode = decoder.make_decoder()
    local headers = respuesta.getResponseHeaders()
    local pesoTotal = tonumber(headers["Content-Length"]) or 1000000
    local totalSegundos = pesoTotal / 6000 
    
    local bytesLeidos = 0
    local pausado = false
    local adelantar = false

    local function hiloAudio()
        while true do
            if not drive.isDiskPresent() then return end
            
            if pausado then
                sleep(0.1)
            elseif adelantar then
                local meta = bytesLeidos + 60000
                while bytesLeidos < meta do
                    local chunk = respuesta.read(16 * 1024)
                    if not chunk or #chunk == 0 then break end
                    bytesLeidos = bytesLeidos + #chunk
                end
                adelantar = false
            else
                local chunk = respuesta.read(16 * 1024)
                if not chunk or #chunk == 0 then return end 
                
                bytesLeidos = bytesLeidos + #chunk
                local buffer = decode(chunk)
                
                while not speaker.playAudio(buffer) do
                    local event = os.pullEvent()
                    if event == "disk_eject" or not drive.isDiskPresent() then return end
                    if event == "speaker_audio_empty" then break end
                end
            end
        end
    end

    local function hiloUI()
        local frameTime = 1 / 30
        local temporizador = os.startTimer(frameTime)
        
        while true do
            if not drive.isDiskPresent() then return end
            
            local event, p1, p2, p3 = os.pullEvent()
            
            if event == "timer" and p1 == temporizador then
                local progresoActual = bytesLeidos / 6000
                dibujarInterfaz(nombre_cancion, progresoActual, totalSegundos, pausado)
                temporizador = os.startTimer(frameTime)
                
            elseif event == "monitor_touch" then
                local x, y = p2, p3
                local w, h = pantalla.getSize()
                local btnY = h - 2
                
                -- Detectar click en botones (hitbox ampliado)
                if y >= btnY - 1 and y <= btnY + 1 then
                    if x >= 1 and x <= 9 then
                        pausado = not pausado
                    elseif x >= 10 and x <= 18 then
                        adelantar = true
                        pausado = false
                    end
                    -- Forzar dibujo inmediato para no sentir lag
                    local progresoActual = bytesLeidos / 6000
                    dibujarInterfaz(nombre_cancion, progresoActual, totalSegundos, pausado)
                end
                
            elseif event == "disk_eject" then
                return
            end
        end
    end

    parallel.waitForAny(hiloAudio, hiloUI)
    
    respuesta.close()
    speaker.stop()
end

local function grabar(path)
    term.redirect(pantalla)
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setTextColor(colors.green)
    local w, h = term.getSize()
    term.setCursorPos(math.floor(w/2) - 5, math.floor(h/2) - 1)
    print("Disco Vacio")
    term.setTextColor(colors.gray)
    term.setCursorPos(math.floor(w/2) - 10, math.floor(h/2) + 1)
    print("Configurar en consola")
    
    term.redirect(terminal_original)
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setTextColor(colors.green)
    term.setCursorPos(1, 1)
    print("=== GRABAR ===")
    term.setTextColor(colors.white)
    print("1. URL:")
    
    local url = read()
    
    if url ~= "" then
        print("\n2. Nombre de la cancion:")
        term.setTextColor(colors.green)
        local nombre = read()
        if nombre == "" then nombre = "Pista 1" end
        
        term.setTextColor(colors.white)
        local f = fs.open(path .. "/song_data.txt", "w")
        f.write(url .. "\n" .. nombre)
        f.close()
        print("\nGuardado.")
        sleep(1)
    end
end

-- Bucle Principal
while true do
    term.redirect(pantalla)
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setTextColor(colors.gray)
    local w, h = term.getSize()
    -- Centrado perfecto para cualquier monitor
    term.setCursorPos(math.floor(w/2) - 6, math.floor(h/2))
    print("Insertar Disco")
    term.redirect(terminal_original)

    if drive.isDiskPresent() then
        local path = drive.getMountPath()
        if path then
            local archivoNuevo = path .. "/song_data.txt"
            local archivoViejo = path .. "/song_url.txt"
            
            if fs.exists(archivoNuevo) then
                local f = fs.open(archivoNuevo, "r")
                local url = f.readLine()
                local nombre = f.readLine() or "Desconocido"
                f.close()
                reproducir(url, nombre)
            elseif fs.exists(archivoViejo) then
                local f = fs.open(archivoViejo, "r")
                local url = f.readAll()
                f.close()
                reproducir(url, "Pista Antigua")
            else
                grabar(path)
            end
        end
    else
        os.pullEvent("disk")
    end
    
    sleep(0.2)
end
