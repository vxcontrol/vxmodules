require("yaci")
require("strict")
local pp    = require("pp")
local ffi   = require("ffi")
local glue  = require("glue")

CSystemInfo = newclass("CSystemInfo")

-- Powershell get local Host ID
--[[
    $system_drive = $env:SystemDrive
    $sm_bios_guid = Get-CimInstance -Class Win32_ComputerSystemProduct | Select -ExpandProperty UUID
    $device_id = Get-CimInstance -Class Win32_Volume -Filter "DriveLetter = '$system_drive'" | Select -ExpandProperty DeviceID
    $volume_serial_number = Get-CimInstance -Class Win32_LogicalDisk -Filter "Caption = '$system_drive'" | Select -ExpandProperty VolumeSerialNumber
    $cleaned_device_id = [regex]::match($device_id,'\{(\S+)\}').Groups[1].Value
    $keys = $sm_bios_guid, $cleaned_device_id, $volume_serial_number
    $system_id = [system.String]::Join(":", $keys)
    echo $system_id.ToUpper()
]]
local win_host_id_cmd = "powershell -noprofile -EncodedCommand " ..
    "JABzAHkAcwB0AGUAbQBfAGQAcgBpAHYAZQAgAD0AIAAkAGUAbgB2ADoAUwB5AHMAdABlAG0ARAB" ..
    "yAGkAdgBlAAoAJABzAG0AXwBiAGkAbwBzAF8AZwB1AGkAZAAgAD0AIABHAGUAdAAtAEMAaQBtAE" ..
    "kAbgBzAHQAYQBuAGMAZQAgAC0AQwBsAGEAcwBzACAAVwBpAG4AMwAyAF8AQwBvAG0AcAB1AHQAZ" ..
    "QByAFMAeQBzAHQAZQBtAFAAcgBvAGQAdQBjAHQAIAB8ACAAUwBlAGwAZQBjAHQAIAAtAEUAeABw" ..
    "AGEAbgBkAFAAcgBvAHAAZQByAHQAeQAgAFUAVQBJAEQACgAkAGQAZQB2AGkAYwBlAF8AaQBkACA" ..
    "APQAgAEcAZQB0AC0AQwBpAG0ASQBuAHMAdABhAG4AYwBlACAALQBDAGwAYQBzAHMAIABXAGkAbg" ..
    "AzADIAXwBWAG8AbAB1AG0AZQAgAC0ARgBpAGwAdABlAHIAIAAiAEQAcgBpAHYAZQBMAGUAdAB0A" ..
    "GUAcgAgAD0AIAAnACQAcwB5AHMAdABlAG0AXwBkAHIAaQB2AGUAJwAiACAAfAAgAFMAZQBsAGUA" ..
    "YwB0ACAALQBFAHgAcABhAG4AZABQAHIAbwBwAGUAcgB0AHkAIABEAGUAdgBpAGMAZQBJAEQACgA" ..
    "kAHYAbwBsAHUAbQBlAF8AcwBlAHIAaQBhAGwAXwBuAHUAbQBiAGUAcgAgAD0AIABHAGUAdAAtAE" ..
    "MAaQBtAEkAbgBzAHQAYQBuAGMAZQAgAC0AQwBsAGEAcwBzACAAVwBpAG4AMwAyAF8ATABvAGcAa" ..
    "QBjAGEAbABEAGkAcwBrACAALQBGAGkAbAB0AGUAcgAgACIAQwBhAHAAdABpAG8AbgAgAD0AIAAn" ..
    "ACQAcwB5AHMAdABlAG0AXwBkAHIAaQB2AGUAJwAiACAAfAAgAFMAZQBsAGUAYwB0ACAALQBFAHg" ..
    "AcABhAG4AZABQAHIAbwBwAGUAcgB0AHkAIABWAG8AbAB1AG0AZQBTAGUAcgBpAGEAbABOAHUAbQ" ..
    "BiAGUAcgAKACQAYwBsAGUAYQBuAGUAZABfAGQAZQB2AGkAYwBlAF8AaQBkACAAPQAgAFsAcgBlA" ..
    "GcAZQB4AF0AOgA6AG0AYQB0AGMAaAAoACQAZABlAHYAaQBjAGUAXwBpAGQALAAnAFwAewAoAFwA" ..
    "UwArACkAXAB9ACcAKQAuAEcAcgBvAHUAcABzAFsAMQBdAC4AVgBhAGwAdQBlAAoAJABrAGUAeQB" ..
    "zACAAPQAgACQAcwBtAF8AYgBpAG8AcwBfAGcAdQBpAGQALAAgACQAYwBsAGUAYQBuAGUAZABfAG" ..
    "QAZQB2AGkAYwBlAF8AaQBkACwAIAAkAHYAbwBsAHUAbQBlAF8AcwBlAHIAaQBhAGwAXwBuAHUAb" ..
    "QBiAGUAcgAKACQAcwB5AHMAdABlAG0AXwBpAGQAIAA9ACAAWwBzAHkAcwB0AGUAbQAuAFMAdABy" ..
    "AGkAbgBnAF0AOgA6AEoAbwBpAG4AKAAiADoAIgAsACAAJABrAGUAeQBzACkACgBlAGMAaABvACA" ..
    "AJABzAHkAcwB0AGUAbQBfAGkAZAAuAFQAbwBVAHAAcABlAHIAKAApAA=="

local lin_host_id_cmd = "hostname"

local osx_host_id_cmd = "hostname"

-- Powershell get local FQDN
--[[
(Get-WmiObject win32_computersystem).DNSHostName+"." +
(Get-WmiObject win32_computersystem).Domain
]]
local win_local_fqdn_cmd = "powershell -noprofile -EncodedCommand " ..
    "KAAKACAAIAAgACAARwBlAHQALQBXAG0AaQBPAGIAagBlAGMAdAAgAHcAaQBuADMAMgBfAGMAbwB" ..
    "tAHAAdQB0AGUAcgBzAHkAcwB0AGUAbQAKACkALgBEAE4AUwBIAG8AcwB0AE4AYQBtAGUAKwAiAC" ..
    "4AIgAgACsACgAoAAoAIAAgACAAIABHAGUAdAAtAFcAbQBpAE8AYgBqAGUAYwB0ACAAdwBpAG4AM" ..
    "wAyAF8AYwBvAG0AcAB1AHQAZQByAHMAeQBzAHQAZQBtAAoAKQAuAEQAbwBtAGEAaQBuAA=="

local lin_local_fqdn_cmd = "hostname"

local osx_local_fqdn_cmd = "hostname"

-- Powershell get non local IP address
--[[
(
    Get-NetIPConfiguration |
    Where-Object {
        $_.IPv4DefaultGateway -ne $null -and
        $_.NetAdapter.Status -ne "Disconnected"
    }
).IPv4Address.IPAddress
]]
local win_non_local_ip_cmd = "powershell -noprofile -EncodedCommand " ..
    "KAAKACAAIAAgACAARwBlAHQALQBOAGUAdABJAFAAQwBvAG4AZgBpAGcAdQByAGEAdABpAG8AbgA" ..
    "gAHwACgAgACAAIAAgAFcAaABlAHIAZQAtAE8AYgBqAGUAYwB0ACAAewAKACAAIAAgACAAIAAgAC" ..
    "AAIAAkAF8ALgBJAFAAdgA0AEQAZQBmAGEAdQBsAHQARwBhAHQAZQB3AGEAeQAgAC0AbgBlACAAJ" ..
    "ABuAHUAbABsACAALQBhAG4AZAAKACAAIAAgACAAIAAgACAAIAAkAF8ALgBOAGUAdABBAGQAYQBw" ..
    "AHQAZQByAC4AUwB0AGEAdAB1AHMAIAAtAG4AZQAgACIARABpAHMAYwBvAG4AbgBlAGMAdABlAGQ" ..
    "AIgAKACAAIAAgACAAfQAKACkALgBJAFAAdgA0AEEAZABkAHIAZQBzAHMALgBJAFAAQQBkAGQAcg" ..
    "BlAHMAcwA="

local lin_non_local_ip_cmd = "ip route get 1 | awk '{print $(NF-2);exit}'"

local osx_non_local_ip_cmd = "route get 8.8.8.8 | grep interface: | cut -d' ' -f4 | xargs -I {} ipconfig getifaddr {}"

function CSystemInfo:print(...)
    if self.is_debug then
        local t = glue.pack(...)
        for i, v in ipairs(t) do
            t[i] = pp.format(v)
        end
        print(glue.unpack(t))
    end
end

function CSystemInfo:init(cfg, is_debug)
    self.is_debug = false

    if type(is_debug) == "boolean" then
        self.is_debug = is_debug
    end
    self:print("intialize CSystemInfo object")
end

function CSystemInfo:free()
    self:print("finalize CSystemInfo object")
end

function CSystemInfo:exec_cmd(cmd, raw)
    self:print("cmd to exec: " .. tostring(cmd))
    local f = assert(io.popen(cmd, 'r'))
    local s = assert(f:read('*a'))
    f:close()
    self:print("cmd output: " .. tostring(s))
    if raw or raw == nil then return s end
    s = string.gsub(s, '^%s+', '')
    s = string.gsub(s, '%s+$', '')
    s = string.gsub(s, '[\n\r]+', ' ')
    return s
end

function CSystemInfo:get_os()
    self:print("current os name: " .. tostring(ffi.os))
    return ffi.os
end

function CSystemInfo:get_fqdn()
    local fqdn
    local os_name = self:get_os()
    if os_name == "Windows" then
        fqdn = string.match(self:exec_cmd(win_local_fqdn_cmd) or "", "([^\r\n]+)") or ""
    elseif os_name == "Linux" then
        fqdn = string.match(self:exec_cmd(lin_local_fqdn_cmd) or "", "([^\r\n]+)") or ""
    elseif os_name == "OSX" then
        fqdn = string.match(self:exec_cmd(osx_local_fqdn_cmd) or "", "([^\r\n]+)") or ""
    else
        fqdn = "unknown"
    end

    self:print("current fqdn: ", fqdn)
    return fqdn
end

function CSystemInfo:get_host_id()
    local host_id
    local os_name = self:get_os()
    if os_name == "Windows" then
        host_id = string.match(self:exec_cmd(win_host_id_cmd) or "", "([^\r\n]+)") or ""
    elseif os_name == "Linux" then
        host_id = string.match(self:exec_cmd(lin_host_id_cmd) or "", "([^\r\n]+)") or ""
    elseif os_name == "OSX" then
        host_id = string.match(self:exec_cmd(osx_host_id_cmd) or "", "([^\r\n]+)") or ""
    else
        host_id = "unknown"
    end

    self:print("current host_id: ", host_id)
    return host_id
end

function CSystemInfo:get_ip()
    local ip
    local os_name = self:get_os()
    if os_name == "Windows" then
        ip = string.match(self:exec_cmd(win_non_local_ip_cmd) or "", "([^\r\n]+)") or ""
    elseif os_name == "Linux" then
        ip = string.match(self:exec_cmd(lin_non_local_ip_cmd) or "", "([^\r\n]+)") or ""
    elseif os_name == "OSX" then
        ip = string.match(self:exec_cmd(osx_non_local_ip_cmd) or "", "([^\r\n]+)") or ""
    else
        ip = "unknown"
    end

    self:print("current ip: ", ip)
    return ip
end
