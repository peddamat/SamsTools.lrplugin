-- local common = require "common"
local json = require "json"
local LrApplication = import "LrApplication"
local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrProgressScope = import "LrProgressScope"
local LrLogger = import 'LrLogger'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'

-- Create the logger and enable the print function.
local myLogger = LrLogger( 'exportLogger' )
myLogger:enable( "logfile" ) -- Pass either a string or a table of actions.

local function outputToLog( message )
    myLogger:trace( message )
end

-- Show save dialog and open file to write.
function get_export_dir()
    local directory = import("LrDialogs").runOpenPanel({
        title = "Choose the export directory.",
        canChooseFiles = false,
        canChooseDirectories = true,
        canCreateDirectories = true,
        allowsMultipleSelection = false,
    })
    if directory == nil then return nil end  -- canceled
    -- TODO: Need to make sure directory is writable
    -- local fh, err = io.open(filename, "w")
    -- if fh == nil then error("Cannot write to the file: " .. err) end
    return directory[1]
end

LrFunctionContext.postAsyncTaskWithContext("ExportFilesSelected", function(context)
    LrDialogs.attachErrorDialogToFunctionContext(context)

    local dst_path = get_export_dir()
    if dst_path == nil then return end

    outputToLog("Exporting to: " .. dst_path)
    
    local progress = LrProgressScope{title = "Starting photo export..."}
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
        
        for i, val in ipairs(photos) do
            -- Get file path to photo
            local src_path = metadata[val].path

            -- Create destination path
            local src_name = LrPathUtils.leafName(src_path)
            local dst_path = LrPathUtils.child(dst_path, src_name)

            progress:setCaption("Exporting: " .. dst_path)
            progress:setPortionComplete(i, #photos)
            LrFileUtils.copy(src_path, dst_path)
            table.insert(results, dst_path)
            if progress:isCanceled() then return end
        end
    end
    
end)