-- Sam's Lightroom Plug-in
--
-- @copyright 2022 peddamat
-- @license: TBD
return {
  LrSdkVersion = 10.0,
  LrToolkitIdentifier = "net.tbd.lightroom.SamsTools",
  LrPluginName = "Sam's Tools",
  LrPluginInfoUrl = "",
  VERSION = {
    major = 0,
    minor = 1,
    revision = 1,
  },
  LrLibraryMenuItems = {
    {
      title = "Automatically create collections...",
      file = "AutoCollections.lua",
    },
    {
      title = "Export File List for Selected Collection(s)...",
      file = "ExportFileListSelected.lua",
    },
    {
      title = "Export Photos from Selected Collection(s)...",
      file = "ExportFilesSelected.lua",
    },
  },
}
