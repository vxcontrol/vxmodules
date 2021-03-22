local lfs = require("lfs")
local path = require("path")
local cjson = require("cjson.safe")

local function read_file(filepath)
    local fc = assert(io.open(filepath, "rb"))
    local content = fc:read("*all")
    fc:close()

    return content
end

local function get_module_config(cur_path, modname)
    local confpath = path.normalize(path.combine(cur_path, "config.json"))
    local confdata = read_file(confpath)
    local modules = cjson.decode(confdata) or {}
    for _, module in ipairs(modules) do
        if module and module.name == modname then
            return module
        end
    end

    return {}
end

local function check_dir(dir)
    local attrs = lfs.attributes(dir)
    if not attrs or lfs.attributes(dir).mode ~= "directory" then
        return false
    end

    return true
end

local cur_path = lfs.currentdir() or "."
local modname = "pam"
local modconf = get_module_config(cur_path, modname)
local modpath = path.normalize(path.combine(cur_path, modname))
local modpathver = path.normalize(path.combine(modpath, modconf.version))
local modpathverconf = path.normalize(path.combine(modpathver, "config"))

if not check_dir(modpath) or not check_dir(modpathver) or not check_dir(modpathverconf) then
    print("Module configuration corrupted")
    return
end

local info = read_file(path.normalize(path.combine(modpathverconf, "info.json")))
local config_schema = read_file(path.normalize(path.combine(modpathverconf, "config_schema.json")))
local current_config = read_file(path.normalize(path.combine(modpathverconf, "current_config.json")))
local current_event_config = read_file(path.normalize(path.combine(modpathverconf, "current_event_config.json")))
local event_config_schema = read_file(path.normalize(path.combine(modpathverconf, "event_config_schema.json")))
local event_data_schema = read_file(path.normalize(path.combine(modpathverconf, "event_data_schema.json")))
local tmp_dir = "/tmp/engine_test"

if not check_dir(tmp_dir) and not lfs.mkdir(tmp_dir) then
    print("Can't create new temporary directory")
    return
end

require("engine")
require("tests.api_mock")

__api = assert(CAPI())
local event_engine = assert(CEventEngine(event_data_schema, current_event_config, info, "test.", false, tmp_dir))
local action_engine = assert(CActionEngine("my_test_agent_id", {}, false))
local test_data = require("tests.engine_test_data")
for _, info in ipairs(test_data) do
    print("Push event :", require'prettycjson'(info))
    local result, list = event_engine:push_event(info)
    if result then
        action_engine:exec(list)
    end
end

__api = nil
event_engine = nil
action_engine = nil
collectgarbage()

print("done")
