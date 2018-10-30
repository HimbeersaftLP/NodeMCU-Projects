-- Simple example using both the WebServer and the DS18S20-Temperature-Sensor scripts from this repo.
-- You will need to upload therm.html to your esp's flash for this to work

local therm = require("ds18s20")

local server = dofile("server.lua")

local paths = {
  ["/get"] = function(sck, pl)
    local tsec, tusec = rtctime.get()
    therm:getTemperature(function(temp)
      local nsec, nusec = rtctime.get()
      local tdiff = (nsec - tsec) * 1000 + (nusec - tusec) / 1000
      sck:send('HTTP/1.0 200 OK\r\nContent-Type: text/html\r\n\r\n{"tmp":' .. temp .. ',"time":' .. tdiff .. '}')
    end, function()
      sck:send("HTTP/1.0 500 Internal Server Error\r\nContent-Type: text/html\r\n\r\nError")
    end)
  end,
  ["/"] = function(sck, pl)
    server.serveFile(sck, "therm.html")
  end
}

server.start(paths)
