-- local common = require "common"
local json = require "json"
local LrApplication = import "LrApplication"
local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrProgressScope = import "LrProgressScope"
local LrLogger = import 'LrLogger'

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

LrFunctionContext.postAsyncTaskWithContext("ExportFileListSelected", function(context)
    LrDialogs.attachErrorDialogToFunctionContext(context)
    
    local fh = open_file()
    if fh == nil then return end
    context:addCleanupHandler(function() fh:close() end)
    
    local progress = LrProgressScope{title = "Exporting File Lists..."}
    progress:attachToFunctionContext(context)
    
    local results = {}
    local catalog = LrApplication.activeCatalog()
    
    -- Get currently selected collections
    local sources = catalog:getActiveSources()
    
    -- For each collection...
    for _, source in ipairs(sources) do 
        --  ... print its name
        local name = source:getName()
        table.insert(results, "Collection: " .. name)
        
        -- ... get its photos
        local photos = source:getPhotos()
        
        -- ... batch get the path for all of the photos
        progress:setCaption("Retrieving raw metadata for " .. #photos .. "photos in " .. name)
        local metadata = catalog:batchGetRawMetadata(photos, {"path"})
        if progress:isCanceled() then return end
        
        -- ... print its path
        for i, val in ipairs(photos) do
            progress:setPortionComplete(i, #photos)
            table.insert(results, metadata[val].path )
            if progress:isCanceled() then return end
        end
    end
    
    progress:setCaption("Saving file list.")
    for _, line in ipairs(results) do
        fh:write(line .. "\n" )
        if progress:isCanceled() then return end
    end
end)
