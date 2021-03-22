require("yaci")
require("strict")
local pp    = require("pp")
local lfs   = require("lfs")
local glue  = require("glue")
local path  = require("path")
local time  = require("time")
local cjson = require("cjson.safe")
local mdb   = require("lightningmdb")
local jsonschema = require("jsonschema")

local lightningmdb = _VERSION>="Lua 5.2" and mdb or lightningmdb
local MDB = setmetatable({}, {__index = function(t, k)
  return lightningmdb["MDB_" .. k]
end})

CEventEngine = newclass("CEventEngine")

--[[
  External API for CEventEngine:
  init(event_data_schema, event_config, module_config, is_debug, tmp_dir)
  push_event(info)
]]

local module_config_schema_t = {
    type = "object",
    properties = {
        name = {
            type = "string",
        },
        events = {
            type = "array",
            items = {
                type = "string",
            },
        },
    },
    additionalProperties = true,
}

local event_data_schema_t = {
    type = "object",
    properties = {
        type = {
            type = "string",
            enum = { "object" },
        },
        properties = {
            type = "object",
        },
    },
}

local complex_event_config_schema_t = {
    type = "object",
    properties = {
        actions = {
            type = "array",
        },
        group_by = {
            type = "array",
            items = {
                type = "string",
            },
            uniqueItems = true,
        },
        max_count = {
            type = "integer",
            minimum = 0,
        },
        max_time = {
            type = "integer",
            minimum = 0,
        },
        seq = {
            type = "array",
            items = {
                type = "object",
                properties = {
                    name = {
                        type = "string",
                    },
                    min_count = {
                        type = "integer",
                        minimum = 1,
                    },
                },
            },
            additionalProperties = false,
            minProperties = 1,
        },
        type = {
            type = "string",
            enum = {
                "aggregation",
                "correlation",
            },
        },
    },
}

local atomic_event_config_schema_t = {
    type = "object",
    properties = {
        actions = {
            type = "array",
        },
        type = {
            type = "string",
            enum = {
                "atomic",
            },
        },
    },
    additionalProperties = true,
}

local function cursor_pairs(cursor_,key_,op_)
  return coroutine.wrap(
    function()
      local k, v = key_
      repeat
        k,v = cursor_:get(k,op_ or MDB.NEXT)
        if k then
          coroutine.yield(k,v)
        end
      until not k
    end)
end

function CEventEngine:print(...)
    if self.is_debug then
        local t = glue.pack(...)
        for i, v in ipairs(t) do
            if type(v) ~= "string" and type(v) ~= "number" then
                t[i] = pp.format(v)
            end
        end
        print(glue.unpack(t))
    end
end

function CEventEngine:open()
    self:print("Openning DB and start transaction")
    if self.mdb_env == nil then
        self:print("Can't open db because env isn't exist")
        return false
    end

    if self.mdb_txn == nil then
        self.mdb_txn = self.mdb_env:txn_begin(nil,0)
        if self.mdb_txn == nil then
            self:print("Can't open db because transaction couldn't start")
            return false
        end
    else
        return false
    end

    if self.mdb_db == nil then
        self.mdb_db = self.mdb_txn:dbi_open(nil,0)
        if self.mdb_db == nil then
            self:print("Can't open db because getting descriptor process was failed")
            return false
        end
    else
        return false
    end

    return true
end

function CEventEngine:close(is_abort)
    self:print("Closing DB and commit transaction")
    if self.mdb_env == nil then
        self:print("Can't close db because env isn't exist")
        return false
    end

    if self.mdb_db == nil then
        self:print("Can't close db because it's already closed")
        return false
    end
    self.mdb_env:dbi_close(self.mdb_db)
    self.mdb_db = nil

    if self.mdb_txn == nil then
        self:print("Can't close db because transaction has already finished")
        return false
    end
    if is_abort then
        self:print("Transaction abort")
        self.mdb_txn:abort()
    else
        self:print("Transaction commit")
        self.mdb_txn:commit()
    end
    self.mdb_txn = nil

    return true
end

function CEventEngine:free()
    self:print("finalize CEventEngine object")
    if self.mdb_db and self.mdb_txn then
        self:close(true)
    end
    self.mdb_env = nil
end

function CEventEngine:set_config(event_config)
    local config = cjson.decode(event_config)
    if type(config) ~= "table" then
        return false
    end

    for ev_name, ev_cfg in pairs(config) do
        if self.complex_event_config_schema_validator(ev_cfg) then
            self.complex_event_config[ev_name] = ev_cfg
        end
        if self.atomic_event_config_schema_validator(ev_cfg) then
            self.atomic_event_config[ev_name] = ev_cfg
        end
    end

    return true
end

function CEventEngine:db_get(key)
    if self.mdb_env == nil then
        self:print("Can't get data because env isn't exist")
        return
    end

    local is_open_db = false
    if not self.mdb_txn and not self.mdb_db then
        if not self:open() then
            self:print("Can't get data because transation and database aren't exist")
            return
        end
        is_open_db = true
    end

    local result
    local data = self.mdb_txn:get(self.mdb_db, key)
    if data then
        result = cjson.decode(data)
    end

    if is_open_db then
        self:close(true)
    end

    return result
end

function CEventEngine:db_put(key, data)
    if self.mdb_env == nil then
        self:print("Can't put data because env isn't exist")
        return
    end

    local is_open_db = false
    if not self.mdb_txn and not self.mdb_db then
        if not self:open() then
            self:print("Can't put data because transation and database aren't exist")
            return
        end
        is_open_db = true
    end

    local result = self.mdb_txn:put(self.mdb_db, key, cjson.encode(data), MDB.NODUPDATA)

    if is_open_db then
        self:close()
    end

    return result
end

function CEventEngine:db_dump()
    if not self.is_debug then
        return
    end

    if self.mdb_env == nil then
        self:print("Can't dump data because env isn't exist")
        return
    end

    local is_open_db = false
    if not self.mdb_txn and not self.mdb_db then
        if not self:open() then
            self:print("Can't dump data because transation and database aren't exist")
            return
        end
        is_open_db = true
    end

    local cur = self.mdb_txn:cursor_open(self.mdb_db)
    self:print("Dump database:")
    if cur then
        for key, value in cursor_pairs(cur) do
            self:print("\t" .. tostring(key) .. ' => ' .. '(' .. type(value) .. ') ' .. pp.format(value))
        end
        cur:close()
    else
        self:print("Can't dump data because cursor to database isn't exist")
    end
    self:print()

    if is_open_db then
        self:close(true)
    end
end


----------------------------------------------
-- Public methods:
----------------------------------------------

function CEventEngine:init(event_data_schema, event_config, module_config, prefix, is_debug, tmp_dir)
    self.is_debug             = false
    self.prefix               = ""
    self.tmp_dir              = path.normalize(path.combine(lfs.currentdir(), "data"))
    self.module_config        = cjson.decode(module_config) or {}
    self.atomic_event_config  = {}
    self.complex_event_config = {}
    self.event_data_list      = {}
    self.event_name_list      = {}
    self.event_data_defaults  = {}

    if type(prefix) == "string" then
        self.prefix = prefix
    end
    if type(is_debug) == "boolean" then
        self.is_debug = is_debug
    end
    if type(tmp_dir) == "string" then
        self.tmp_dir = tmp_dir
    end

    self:print("Arg event data schema: ", event_data_schema)
    self:print("Arg event config: ", event_config)
    self:print("Arg module config: ", module_config)

    local module_config_validator = jsonschema.generate_validator(module_config_schema_t)
    if not module_config_validator(self.module_config) then
        return false, "can't parse module config"
    else
        self.event_name_list = self.module_config.events
        complex_event_config_schema_t.properties.seq.items.
            properties.name.enum = self.event_name_list
    end

    self.event_data_schema = cjson.decode(event_data_schema) or {}
    self.event_data_schema_validator = jsonschema.generate_validator(self.event_data_schema)
    if not jsonschema.generate_validator(event_data_schema_t)(self.event_data_schema) then
        return nil, "can't parse event data config"
    else
        local properties = self.event_data_schema.properties or {}
        self.event_data_list = glue.keys(properties)
        complex_event_config_schema_t.properties.group_by.items.enum = self.event_data_list
        for _, data_item in ipairs(self.event_data_list) do
            local default = properties[data_item].default
            self.event_data_defaults[data_item] = type(default) == "nil" and "" or default
        end
    end

    self.atomic_event_config_schema_validator  = jsonschema.generate_validator(atomic_event_config_schema_t)
    self.complex_event_config_schema_validator = jsonschema.generate_validator(complex_event_config_schema_t)
    if not self:set_config(event_config) then
        return false, "can't parse event config"
    end

    local attr, err = lfs.attributes(self.tmp_dir)
    if attr == nil or attr.mode ~= "directory" then
        self.tmp_dir = path.normalize(lfs.currentdir())
    end

    self.mdb_name = self.prefix .. self.module_config.name
    self.mdb_path = path.normalize(path.combine(self.tmp_dir, self.mdb_name))
    attr, err = lfs.attributes(self.mdb_path)
    if (attr == nil or attr.mode ~= "directory") and not lfs.mkdir(self.mdb_path) then
        return false, "can't create database directory"
    end

    local env, code
    local flags = 0
    self.mdb_env = mdb.env_create()
    self.mdb_env:set_mapsize(100485760) -- 100 MB
    self:print("Env descriptor: ", self.mdb_env)
    env, err, code = self.mdb_env:open(self.mdb_path, flags, 420)
    if err then
        os.remove(path.normalize(path.combine(self.mdb_path, "lock.mdb")))
        env, err, code = self.mdb_env:open(self.mdb_path, flags, 420)
        if err then
            os.remove(path.normalize(path.combine(self.mdb_path, "lock.mdb")))
            os.remove(path.normalize(path.combine(self.mdb_path, "data.mdb")))
            env, err, code = self.mdb_env:open(self.mdb_path, flags, 420)
            if err then
                return false, "can't repair database"
            end
        end
    end
    self:print("Env open directory: ", env, err, code)
    self:print("Env stat: ", self.mdb_env:stat())
    self:print("Env info: ", self.mdb_env:info())
    self:print("Env path: ", self.mdb_env:get_path())

    return true
end

--[[
    ev_*     - current event * (name, data)
    ce_*     - complex event * (name, data, cfg)
    cei_*    - complex event initial * (data)
    ae_*     - atomic event * (name, data, cfg)
    seq_ev_* - event sequence for a complex event (id, item, list)
    info     - data of current event
]]
function CEventEngine:push_event(info, is_rec)
    if type(info) ~= "table" then
        return false
    end
    if type(info.name) ~= "string" then
        return false
    end
    if type(info.data) ~= "table" then
        return false
    end

    local ev_actions = {}
    local ev_name = info.name
    local ev_data = glue.merge(glue.update({}, info.data), self.event_data_defaults)
    if not self.event_data_schema_validator(ev_data) then
        return false
    end

    local function get_time()
        return os.time(os.date("!*t"))
    end

    local function generate_uniq(name)
        local rand = tostring(math.ceil(os.clock()*1000000) % 1000000)
        return name .. "_" .. os.date("!%d.%m.%y_%H:%M:%S") .. "_" .. rand
    end

    local function update_counts(ce_info, seq_ev_id)
        ce_info.data.counts[seq_ev_id] = ce_info.data.counts[seq_ev_id] + 1
        ce_info.time = get_time()
        return true
    end

    local function generate_ce_data(ce_cfg, cei_data)
        local ce_data = glue.merge(glue.update({}, cei_data), { counts = { 1 } })
        for i=2, glue.count(ce_cfg.seq) do
            ce_data.counts[i] = 0
        end
        return ce_data
    end

    local function generate_ce_info(ce_name, ce_cfg, cei_data)
        local ce_uniq = generate_uniq(ce_name)
        local ce_time = get_time()
        local ce_data = generate_ce_data(ce_cfg, cei_data)
        return { name = ce_name, data = ce_data, uniq = ce_uniq, time = ce_time }
    end

    local function generate_ce_key(ce_name, ce_cfg, ev_data)
        local cei_data = {}
        local ce_key = ce_name
        for _, group_key in ipairs(ce_cfg.group_by) do
            ce_key = ce_key .. ":" .. tostring(ev_data[group_key])
            cei_data[group_key] = ev_data[group_key]
        end
        return ce_key, cei_data
    end

    local function remove_old_ce()
        if self.mdb_env == nil then
            self:print("Can't remove old ce because env isn't exist")
            return
        end

        local cur_time = get_time()
        if os.difftime(cur_time, self.last_check or 0) == 0 then
            return
        end

        self.last_check = cur_time
        local rem_keys = {}

        local is_open_db = false
        if not self.mdb_txn and not self.mdb_db then
            if not self:open() then
                self:print("Can't remove old ce because transation and database aren't exist")
                return
            end
            is_open_db = true
        end

        self:print("Remove old ce from database:")
        local cur = self.mdb_txn:cursor_open(self.mdb_db)
        self:print("Dump database:")
        if cur then
            for key, value in cursor_pairs(cur) do
                local info = cjson.decode(value)
                local ce_cfg = {}
                for name, cfg in pairs(self.complex_event_config) do
                    if name == info.name then
                        ce_cfg = cfg
                        break
                    end
                end
                if os.difftime(cur_time, info.time) > ce_cfg.max_time then
                  self:print("\t" .. tostring(key) .. ' => ' .. pp.format(info))
                  table.insert(rem_keys, key)
                end
            end
            cur:close()
        else
            self:print("Can't remove old ce because cursor to database isn't exist")
        end
        self:print()

        for _, key in ipairs(rem_keys) do
            self.mdb_txn:del(self.mdb_db, key, "")
        end

        if is_open_db then
            self:close(glue.count(rem_keys) == 0)
        end
    end

    remove_old_ce()

    for ce_name, ce_cfg in pairs(self.complex_event_config) do
        -- check this event name in seq
        -- generate complex event key
        -- find open complex events
        -- if not found and event name is first in seq then create one
        -- if openned complex events found then foreach apply this one and update
        -- check all is complex event finished

        local ce_key, cei_data = generate_ce_key(ce_name, ce_cfg, ev_data)
        local seq_ev_list = ce_cfg.seq or {}
        local seq_ev_id_cf = 0
        local seq_ev_update = false
        local ce_info = self:db_get(ce_key)
        for seq_ev_id, seq_ev_item in ipairs(seq_ev_list) do
            if seq_ev_item.name == ev_name then
                if seq_ev_id == 1 and not ce_info then
                    ce_info = generate_ce_info(ce_name, ce_cfg, cei_data)
                    self:db_put(ce_key, ce_info)
                elseif ce_info then
                    update_counts(ce_info, seq_ev_id)
                    self:db_put(ce_key, ce_info)
                end
                seq_ev_update = true
            end
            if not ce_info or ce_info.data.counts[seq_ev_id] < seq_ev_item.min_count then
                break
            else
                seq_ev_id_cf = seq_ev_id_cf + 1
            end
        end
        if seq_ev_update and seq_ev_id_cf == glue.count(ce_cfg.seq) then
            if not ce_info.data.start_time then
                ce_info.data.start_time = os.date("!%d.%m.%y %H:%M:%S")
                self:db_put(ce_key, ce_info)
                local res, tev_actions = self:push_event(ce_info, true)
                if res then
                    ev_actions = glue.merge(glue.update({}, ev_actions), tev_actions)
                end
            end
            ev_actions[ce_name] = { actions = ce_cfg.actions, info = ce_info }
        end
    end

    for ae_name, ae_cfg in pairs(self.atomic_event_config) do
        if ae_name == ev_name and #ae_cfg.actions ~= 0 then
            info.uniq = generate_uniq(ae_name)
            ev_actions[ae_name] = { actions = ae_cfg.actions, info = info }
            break
        end
    end

    if not is_rec then
        self:db_dump()
    end

    return true, ev_actions
end
