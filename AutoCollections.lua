-- local common = require "common"
local json = require "json"
local LrApplication = import "LrApplication"
local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrProgressScope = import "LrProgressScope"
local LrLogger = import 'LrLogger'
local LrDate = import 'LrDate'

-- Create the logger and enable the print function.
local myLogger = LrLogger( 'exportLogger' )
myLogger:enable( "logfile" ) -- Pass either a string or a table of actions.

local function outputToLog( message )
    myLogger:trace( message )
end

-- Show save dialog and open file to write.
function open_file()
    local filename = import("LrDialogs").runSavePanel({
        title = "Choose the output filename.",
        requiredFileType = "txt",
    })
    if filename == nil then return nil end  -- canceled
    local fh, err = io.open(filename, "w")
    if fh == nil then error("Cannot write to the file: " .. err) end
    return fh
end

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '\n['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function getSortedMetadata(catalog, photos, metadata)
    local results, i = {}, 1

    local metadata = catalog:batchGetRawMetadata(photos, metadata)
    for photo, meta in pairs(metadata) do
        -- Unpack metadata array so we can sort it
        results[i] = { photo=photo, timestamp=meta.captureTime }
        i = i+1
    end

    -- Sort by timestamp ascending 
    table.sort(results, function(a,b) return (a.timestamp < b.timestamp) end)

    return results
end


ONEDAY = 60*60*24
ONEWEEK = ONEDAY*7

LrFunctionContext.postAsyncTaskWithContext("AutoCollections", function(context)
    LrDialogs.attachErrorDialogToFunctionContext(context)
    
    local progress = LrProgressScope{title = "Exporting File Lists..."}
    progress:attachToFunctionContext(context)
    
    local catalog = LrApplication.activeCatalog()

    -- Get currently selected photos
    local photos = catalog:getTargetPhotos()
    outputToLog("Selected: " .. #photos .. " photos.")

    -- Get capture times for selected photos
    capture_times = getSortedMetadata(catalog, photos, {'captureTime'})

    -- Group photos by capture times
    local groups = {}
    local prev_index, prev_photo = 1, { timestamp = 0 }
    for index, photo in ipairs(capture_times) do
        -- Get the timespan between this photo and the previous photo
        local time_span = photo.timestamp - prev_photo.timestamp

        -- If the time span is greater than a week...
        if time_span > ONEWEEK then
            -- ... create a new collection
            table.insert(groups, { 
                start_offset = index, 
                start_date = photo.timestamp,
            })
        else
            local g = groups[#groups]
            if g ~= nil then
                g.end_offset = index
                g.end_date = photo.timestamp
            end
        end

        prev_index, prev_photo = index, photo
    end


    -- Create collections from groups
    catalog:withWriteAccessDo("Create parent collection set", function()
        parent = catalog:createCollectionSet("Auto Collections", nil, true)
    end)

    for i, group in ipairs(groups) do
        local year = LrDate.timestampToComponents(group.start_date)

        catalog:withWriteAccessDo("Create child collection set", function()
            child = catalog:createCollectionSet(tostring(year), parent, true)
        end)

        -- Groups don't have an end date if the group only has one photo...
        if group.end_date == nil then group.end_date = group.start_date end

        catalog:withWriteAccessDo("Create child collection set", function()
            catalog:createSmartCollection( 
                LrDate.timeToUserFormat(group.start_date, "%m-%d-%Y") .. ' - ' .. LrDate.timeToUserFormat(group.end_date, "%m-%d-%Y"),
                {
                    {
                        criteria = "captureTime",
                        operation = "in",
                        value = LrDate.timeToIsoDate(group.start_date),
                        value2 = LrDate.timeToIsoDate(group.end_date),
                    },
                    combine = "union",
                },
                child
            )
        end)
    end
end)