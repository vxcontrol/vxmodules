require("yaci")
require("strict")
local lfs = require("lfs")

CAPI = newclass("CAPI")

function CAPI:init()
    print("API was initialized successful")
end

function CAPI:free()
    print("finalize CAPI object")
end

function CAPI.push_event(aid, info)
    print("CAPI push_event ", aid, info)
end
