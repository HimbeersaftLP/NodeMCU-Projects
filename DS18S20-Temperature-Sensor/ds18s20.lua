-- returns true if the 8 bit CRC at "pos" matches the bits before "pos"
local function checkCrc(data, pos)
  return ow.crc8(data:sub(1, pos - 1)) == data:byte(pos)
end

-- searches for the sensor and sets the uid, returns true if successful
local function searchSensors(self, pin)
  print("Notice: Searching for DS18S20")
  local found = false
  local uid = nil
  ow.reset_search(pin)
  repeat
    uid = ow.search(pin)
    if uid == nil then
      print("Error: No device found")
    elseif uid:byte(1) ~= 0x10 then
      print("Error: Not a DS18S20")
    elseif not checkCrc(uid, 8) then
      print("Error: CRC doesn't match")
    else
      found = true
    end
  until uid == nil or found
  if found then
    print("Success: Found DS18S20")
    self.uid = uid
  end
  return found
end

-- get the temperature: callback(temperature)
-- calls errback(errid) if something goes wrong
-- errids:
--   1: Search Error
--   2: Data CRC Missmatch
--   3: Maximum tries for getting the temperature reached
-- limit: max amount of tries to check for a response
-- pin: pin the sensor is on
local function getTemperature(self, callback, errback, limit, pin)
  -- https://datasheets.maximintegrated.com/en/ds/DS18S20.pdf
  local errback = errback or function() end
  local limit = limit or 100
  local pin = pin or 1
  local searchfailed = false
  ow.setup(pin)
  if not self.uid then
    searchfailed = not searchSensors(self, pin)
  end
  if searchfailed then
    errback(1)
  else
    ow.reset(pin)
    ow.select(pin, self.uid)
    -- tell it to meassure
    ow.write(pin, 0x44)
    -- check every 100ms if it has finished
    local tries = 0
    local tim = tmr.create()
    tim:alarm(10, tmr.ALARM_SEMI, function()
      -- repeat if the device responds with 0
      if (ow.read(pin) == 0) then tim:start() else
        ow.reset(pin)
        ow.select(pin, self.uid)
        -- tell it to output the "scratchpad"
        ow.write(pin, 0xbe)
        -- get the data
        local data = string.char(ow.read(pin))
        for i = 1, 8 do
          data = data .. string.char(ow.read(pin))
        end
        if not checkCrc(data, 9) then
          print("Error: CRC doesn't match")
          errback(2)
        else
          -- calculate the temperature
          local temperature = math.floor(data:byte(1) / 2)
          if (data:byte(2) == 255) then temperature = temperature * -1 end
          temperature = temperature - 0.25 + (data:byte(8) - data:byte(7)) / data:byte(8)
          callback(temperature)
        end
      end
      tries = tries + 1
      if tries == limit then
        print("Error: Maximum tries reached")
        tim:unregister()
        errback(3)
      end
    end)
  end
end

local M = {
  uid = nil,
  getTemperature = getTemperature,
  errids = {
    "search", "data_crc", "tries_reached"
  }
}
return M