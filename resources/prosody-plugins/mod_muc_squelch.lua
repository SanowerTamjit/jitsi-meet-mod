local is_healthcheck_room = module:require "util".is_healthcheck_room;
local inspect = require "inspect"

local defaultFieldValue = {};

-- Module that adds a new room configuration field to keep track of jids that
-- are squelched (forcefully silenced)

function areSquelchListsEquivalent(t1, t2)
    if #t1 ~= #t2 then
        return false;
    end

    for k=1, #t1 do`
        if t1[k] ~= t2[k] then
            return false;
        end
    end

    return true;
end

function changeSquelched(room, squelched)
    if areSquelchListsEquivalent(room._data.squelched, squelched) then
        return false;
    end

    room._data.squelched = squelched;

    return true;
end

-- returns the squelch list form data.
function getSquelchListConfig(room)
    return {
        name = "muc#roomconfig_squelched";
        type = "jid-multi";
        label = "The list of squelched jids.";
        value = room._data.squelched or defaultFieldValue;
    };
end


-- add the squelch list config to the form
module:hook("muc-room-created", function(event)
    local room = event.room;

    if is_healthcheck_room(room.jid) then
        return;
    end

    room._data.squelched = defaultFieldValue;

    module:log("info", "Initialized squelch list for %s", room.jid);
end);

-- add squelch list to the disco info requests to the room
module:hook("muc-disco#info", function(event)
    table.insert(event.form, getSquelchListConfig(event.room));
end);

-- add squelch list in the default config we return to jicofo
module:hook("muc-config-form", function(event)
    table.insert(event.form, getSquelchListConfig(event.room));
end, 90-3);

-- listen to room config changes related to squelch list and mark them to be
-- broadcasted
module:hook("muc-config-submitted/muc#roomconfig_squelched", function(event)
    local value = event.value or defaultFieldValue;
    if changeSquelched(event.room, value) then
        module:log("debug", "Squelch field changed: %s", inspect(value));
        event.status_codes["104"] = true;
    end
end);
