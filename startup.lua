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
    monitor.setTextScale(0.5)
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
        
        while true do
            local event, p1, p2 = os.pullEvent()
            
            if event == "http_success" then
                return p2 
            elseif event == "http_failure" then
                return nil
            elseif event == "disk_eject" or not drive.isDiskPresent() then
                return nil
            elseif event == "timer" and p1 == timer then
                break
            end
        end
        
        i = i + 1
        if i > #frames then i = 1 end
    end
end

local function dibujarInterfaz(cancion, progreso, total)
    term.redirect(pantalla)
    term.setBackgroundColor(colors.black)
    term.clear()
    
    term.setTextColor(colors.green)
    term.setCursorPos(2, 2)
    print("REPRODUCIENDO:")
    
    term.setTextColor(colors.white)
    term.setCursorPos(2, 3)
    local nombre = string.sub(cancion, 1, 35)
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
    
    term.redirect(terminal_original)
end

local function reproducir(url, nombre_cancion)
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
    local bytesLeidos = 0

    while true do
        if not drive.isDiskPresent() then break end
        
        local chunk = respuesta.read(16 * 1024)
        if not chunk or #chunk == 0 then break end 
        
        bytesLeidos = bytesLeidos + #chunk
        local buffer = decode(chunk)
        
        dibujarInterfaz(nombre_cancion, bytesLeidos, pesoTotal)
        
        while not speaker.playAudio(buffer) do
            -- Al usar solo este evento especifico, el audio no se traba nunca
            os.pullEvent("speaker_audio_empty")
        end
    end

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

while true do
    term.redirect(pantalla)
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setTextColor(colors.gray)
    local w, h = term.getSize()
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
