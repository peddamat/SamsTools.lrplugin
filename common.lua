local common = {}

local LrLogger = import 'LrLogger'

-- Create the logger and enable the print function.
local myLogger = LrLogger( 'exportLogger' )
-- myLogger:enable( "print" ) -- Pass either a string or a table of actions.
myLogger:enable( "logfile" ) -- Pass either a string or a table of actions.

--------------------------------------------------------------------------------
-- Write trace information to the logger.

local function outputToLog( message )
	myLogger:trace( message )
end

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

-- Show save dialog and open file to write.
function common.open_file()
  local filename = import("LrDialogs").runSavePanel({
    title = "Choose a filename to save the output as JSON.",
    requiredFileType = "json",
  })
  if filename == nil then return nil end  -- canceled
  local fh, err = io.open(filename, "w")
  if fh == nil then error("Cannot write to the file: " .. err) end
  return fh
end

-- Prepare dump structure for photo metadata from Lightroom objects
function common.build_photo_dump(photos, batch_raw, batch_formatted)
  local function convert_LrPhoto_to_uuid(photo)
    if batch_raw[photo] ~= nil then return batch_raw[photo].uuid end
    return photo:getRawMetadata("uuid")
  end

  local result = {}
  for i, photo in ipairs(photos) do
    local r, f = batch_raw[photo], batch_formatted[photo]

    -- convert Lr objects to common values
    if r.masterPhoto ~= nil then
      r.masterPhoto = convert_LrPhoto_to_uuid(r.masterPhoto)
    end
    if r.topOfStackInFolderContainingPhoto ~= nil then
      r.topOfStackInFolderContainingPhoto = convert_LrPhoto_to_uuid(r.topOfStackInFolderContainingPhoto)
    end
    if r.stackInFolderMembers ~= nil then
      for k, v in ipairs(r.stackInFolderMembers) do
        r.stackInFolderMembers[k] = convert_LrPhoto_to_uuid(v)
      end
    end
    if r.virtualCopies ~= nil then
      for k, v in ipairs(r.virtualCopies) do
        r.virtualCopies[k] = convert_LrPhoto_to_uuid(v, rs)
      end
    end
    if r.keywords ~= nil then
      for k, v in ipairs(r.keywords) do
        r.keywords[k] = v:getName()
      end
    end

    outputToLog( dump(r) )

    result[r.uuid] = { raw = r, formatted = f }
  end
  return result
end

-- Recursively dump child sets and collections of a collection set
function common.dump_set(set, progress)
  local result = {
    type = set:type(),
    name = set:getName(),
    children = {},
  }

  for _, val in ipairs(set:getChildCollectionSets()) do
    if progress:isCanceled() then return result end
    table.insert(result.children, common.dump_set(val, progress))
  end
  for _, val in ipairs(set:getChildCollections()) do
    if progress:isCanceled() then return result end
    table.insert(result.children, common.dump_collection(val, progress))
  end

  return result
end

-- Dump a collection and its child photos
function common.dump_collection(collection, progress)
  local result = {
    type = collection:type(),
    name = collection:getName(),
    photos = {},
  }

  progress:setCaption("Retrieving contents of " .. result.name)

  local photos = collection:getPhotos()
  local batch_raw = collection.catalog:batchGetRawMetadata(photos, {
    "uuid",
    "path",
    "isVirtualCopy",
  })

  for _, val in ipairs(photos) do
    table.insert(result.photos, batch_raw[val])
  end

  return result
end

return common
