local common = require "common"
local json = require "json"
local LrApplication = import "LrApplication"
local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrProgressScope = import "LrProgressScope"


LrFunctionContext.postAsyncTaskWithContext("DumpMetadataSelected", function(context)
  LrDialogs.attachErrorDialogToFunctionContext(context)

  -- show save dialog and open file to write
  -- local fh = common.open_file()
  -- if fh == nil then return end
  -- context:addCleanupHandler(function() fh:close() end)

  -- retrieve target photo list
  local catalog = LrApplication.activeCatalog()
  local photos = catalog:getTargetPhotos()
  local n_photos = string.format("%d photos", #photos)

  local progress = LrProgressScope{title = "Dumping metadata for " .. n_photos}
  progress:attachToFunctionContext(context)

  -- batch get raw
  progress:setCaption("Retrieving raw metadata for " .. n_photos)
  local batch_raw = catalog:batchGetRawMetadata(photos, nil)
  progress:setPortionComplete(1, 3)
  if progress:isCanceled() then return end

  -- batch get formatted
  progress:setCaption("Retrieving formatted metadata for " .. n_photos)
  local batch_formatted = catalog:batchGetFormattedMetadata(photos, nil)
  progress:setPortionComplete(2, 3)
  if progress:isCanceled() then return end

  -- prepare dump data structure and save
  progress:setCaption("Saving dump as JSON")
  local result = common.build_photo_dump(photos, batch_raw, batch_formatted)
  if progress:isCanceled() then return end
  -- fh:write(json.encode(result))
  progress:setPortionComplete(3, 3)
end)
