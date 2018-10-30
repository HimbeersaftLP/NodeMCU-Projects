local M = {}

function parsePlData(pldata)
  local data = {}
  for key, value in string.gmatch(pldata, "([^&]+)=([^&]*)&*") do
    data[key] = value
  end
  return data
end

function parsePl(payload)
  local pl = {}
  pl.method,pl.path,pl.rawData = payload:match("([A-Z]+) (.+)?(.+) HTTP")
  if pl.method == nil then
    -- when the pattern doesn't match because there is no GET data
    pl.method,pl.path = payload:match("([A-Z]+) (.+) HTTP")
  end
  if pl.method == "POST" then
    pl.rawData = payload:match("\r\n\r\n(.*)")
  end
  if pl.rawData ~= nil then
    pl.data = parsePlData(pl.rawData)
  end
  return pl
end

-- paths: a list like this {"/pathame" = function(socket, parsedPayload, rawPayload) doStuff() end}
function M.start(paths)
  local srv = net.createServer()
  srv:listen(80, function(conn)
    conn:on("receive", function(sck, payload)
      local pl = parsePl(payload)
      if paths[pl.path] then
        paths[pl.path](sck, pl, payload)
      else
        sck:send("HTTP/1.0 404 Not Found\r\nContent-Type: text/html\r\n\r\n404 Not found!")
      end
    end)
    conn:on("sent", function(sck) sck:close() end)
  end)
end

-- sck: Socket, filename: file name, ctype: Content-Type text (default: text/html)
function M.serveFile(sck, filename, ctype)
  local ctype = ctype or "text/html"
  local hdoc = file.open(filename, "r")
  sck:send("HTTP/1.0 200 OK\r\nContent-Type: " .. ctype .. "\r\n\r\n" .. hdoc:read())
  hdoc:close()
end

return M