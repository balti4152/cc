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

local pantalla = monitor or terminal_original
if monitor then
    monitor.setTextScale(1)
end

local decoder = require("cc.audio.dfpwm")
local btnY = 8

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
    local respuesta, err = http.get({ url = url, binary = true })
    if not respuesta then 
        term.redirect(pantalla)
        term.clear()
        term.setCursorPos(2,2)
        term.setTextColor(colors.red)
        print("Error de conexion.")
        term.redirect(terminal_original)
        sleep(2)
        return 
    end

    local decode = decoder.make_decoder()
    local headers = respuesta.getResponseHeaders()
    local tamanoTotal = tonumber(headers["Content-Length"]) or 1000000
    local totalSegundos = tamanoTotal / 6000 
    
    local bytesLeidos = 0
    local pausado = false
    local adelantar = false

    -- Hilo 1: Maneja unicamente el flujo de audio
    local function hiloAudio()
        while true do
            if not drive.isDiskPresent() then return end
            
            if pausado then
                sleep(0.1)
            elseif adelantar then
                local bytes_a_saltar = 60000
                local leidos_salto = 0
                while leidos_salto < bytes_a_saltar do
                    local chunk = respuesta.read(16 * 1024)
                    if not chunk then return end
                    leidos_salto = leidos_salto + #chunk
                    bytesLeidos = bytesLeidos + #chunk
                end
                adelantar = false
            else
                local chunk = respuesta.read(16 * 1024)
                if not chunk then return end 
                
                bytesLeidos = bytesLeidos + #chunk
                local buffer = decode(chunk)
                
                while true do
                    if not drive.isDiskPresent() then return end
                    if speaker.playAudio(buffer) then
                        break
                    else
                        local event = {os.pullEvent()}
                        if event[1] == "disk_eject" then return end
                    end
                end
            end
        end
    end

    -- Hilo 2: Maneja la interfaz a 30 FPS y los botones
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
                if y == btnY then
                    if x >= 2 and x <= 8 then
                        pausado = not pausado
                    elseif x >= 11 and x <= 16 then
                        adelantar = true
                        pausado = false
                    end
                end
                
            elseif event == "disk_eject" then
                return
            end
        end
    end

    -- Ejecuta ambos hilos al mismo tiempo. Si uno termina (ej: sacas el disco), el otro frena.
    parallel.waitForAny(hiloAudio, hiloUI)
    
    respuesta.close()
    speaker.stop()
end

local function grabar(path)
    term.redirect(pantalla)
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setTextColor(colors.green)
    term.setCursorPos(2, 2)
    print("DISCO NUEVO")
    term.setTextColor(colors.gray)
    term.setCursorPos(2, 4)
    print("Configurar en consola")
    
    term.redirect(terminal_original)
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setTextColor(colors.green)
    term.setCursorPos(1, 1)
    print("=== GRABAR DISCO ===")
    term.setTextColor(colors.white)
    print("1. Pega la URL:")
    
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
    term.setCursorPos(2, 2)
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
                local nombre = f.readLine() or "Pista Desconocida"
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
