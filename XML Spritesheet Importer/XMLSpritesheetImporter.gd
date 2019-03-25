##
# XMLSpritesheetImporter.gd
##
tool
extends EditorScript

# Directory instance for checking and creating folders
var dir: Directory = Directory.new()

# XML parser
var xml: XMLParser = XMLParser.new()

# images path
const IMAGES_PATH: String = "res://image"

func _run() -> void:
  # create spritesheet texture
  var spritesheet: StreamTexture = get_spritesheet_texture()

  if spritesheet:
    # if spritesheet texture exists, proceed to open xml file
    if open_spritesheet_data():
      # start reading subtextures nodes
      var end: bool = false

      # loop trough xml (not closing) elements
      while not end:
        edit_texture(spritesheet)

        end = not read_next_texture()

##
# Create and return a stream texture from the spritesheet
##
func get_spritesheet_texture() -> StreamTexture:
  var spritesheet: StreamTexture = null
  var sprites_path: String = IMAGES_PATH + "/sprites.png"

  # check if spritesheet image exists and load it
  if dir.file_exists(sprites_path):
    spritesheet = load(sprites_path) as StreamTexture

  return spritesheet

##
# Check if a folder exists, if not, create it
##
func init_folder(path: String) -> bool:
  # check if folder exists
  if not dir.dir_exists(path):
    # if not, try to create it
    if dir.make_dir_recursive(path) == OK:
      print("Create ", path, " folder: SUCCESS.")
    else:
      print("Create ", path, " folder: FAIL.")
      return false
  else:
    # folder already exists, do nothing
    print(path, " folder already exists.")

  return true

##
# Open spritesheet xml data to get it ready to be readed
##
func open_spritesheet_data() -> bool:
  # try to open spritesheet xml file
  if xml.open(IMAGES_PATH + "/sprites.xml") == OK:
    # go to first subtexture element
    if xml.seek(1) == OK:
      if read_next_texture():
        print("Open xml data: SUCCESS")
        return true

  print("Open xml data: FAIL")
  return false

##
# Get subtexture 'name' attribute
##
func get_texture_name() -> String:
  var name: PoolStringArray = xml.get_named_attribute_value("name").split("_")
  var file_name: String = name[-1].trim_suffix(".png")

  return file_name

##
# Get subtexture path
##
func get_path(file_name_included: bool = true, folder: String = "") -> String:
  var name: PoolStringArray = xml.get_named_attribute_value("name").split("_")
  var file_name: String = name[-1].trim_suffix(".png")
  name.remove(name.size() - 1)

  var path: String = "res://"

  for part in name:
    path = path.plus_file(part)

  if not folder.empty():
    path = path.plus_file(folder)

  if file_name_included:
    path = path.plus_file(file_name)

  return path

##
# Get subtexture region from 'x','y','width', and 'height' element's attributes
##
func get_texture_region() -> Rect2:
  var x: float = xml.get_named_attribute_value("x") as float
  var y: float = xml.get_named_attribute_value("y") as float
  var width: float = xml.get_named_attribute_value("width") as float
  var height: float = xml.get_named_attribute_value("height") as float

  return Rect2(x, y, width, height)

##
# Try to read the next xml element.
##
func read_next_texture() -> bool:
  if xml.read() == OK:
    # check if the current element is not an ending one
    if xml.get_node_type() == xml.NODE_ELEMENT:
      print("Read next sprite: SUCCESS")
      return true

  print("Read next sprite: FAIL")
  return false

##
# Edit a new atlas texture, or edit it if already exists
##
func edit_texture(spritesheet: StreamTexture) -> void:
  var atlas_texture: AtlasTexture = null
  # texture folder path (without the filename) plus a 'texture' subfolder
  var folder_path: String = get_path(false, "texture")
  # texture full path
  var resource_path: String = get_path(true, "texture") + ".tres"
  # texture spritesheet region
  var rect: Rect2 = get_texture_region()

  if init_folder(folder_path):
    if not dir.file_exists(resource_path):
      atlas_texture = AtlasTexture.new()
    else:
      atlas_texture = load(resource_path) as AtlasTexture

    atlas_texture.atlas = spritesheet
    atlas_texture.region = rect

    # save new/edited atlas texture to disk
    if ResourceSaver.save(resource_path, atlas_texture) == OK:
      print("Atlas texture: ", resource_path, " saved.")
      if resource_path.find("tile") > -1:
        # texture is part of a tileset
        edit_tileset(atlas_texture, get_texture_name())
    else:
      print("Error while saving atlas texture: ", resource_path)

##
# Edit existing tileset resource or create a new one
##
func edit_tileset(texture: AtlasTexture, texture_name: String) -> void:
  # path to to tileset folder
  var tileset_folder: String = get_path(false)

  # markers of tileset name inside the path
  var begin: int = tileset_folder.find_last("/") + 1
  var length: int = tileset_folder.length() - begin

  # tileset name, derived from last subfolder name in its path
  var tileset_name: String = tileset_folder.substr(begin, length)

  if tileset_name == "tile":
    # if las subfolder name is just "tile" call the tileset simply "tileset"
    tileset_name = "tileset"
  else:
    # call it "lastSubfolderName_tileset"
    tileset_name += "_tileset"

  # full tileset path, including resource name and extension
  var tileset_path: String = tileset_folder.plus_file(tileset_name + ".tres")

  var tileset: TileSet = null

  # create or load existent tileset
  if not dir.file_exists(tileset_path):
    tileset = TileSet.new()
  else:
    tileset = load(tileset_path) as TileSet

  if tileset:
    # check if tile already exists
    var tile_id: int = tileset.find_tile_by_name(texture_name)
    print("id: ", tile_id)

    if tile_id == -1:
      # tile doesn't exists, create a new one
      tile_id = tileset.get_last_unused_tile_id()
      print("new id: ", tile_id)
      tileset.create_tile(tile_id)

    tileset.tile_set_name(tile_id, texture_name)
    tileset.tile_set_texture(tile_id, texture.atlas)
    tileset.tile_set_region(tile_id, texture.region)

    # save new/edited tileset to disk
    if ResourceSaver.save(tileset_path, tileset) == OK:
      print("tileset: ", tileset_path, " saved.")
    else:
      print("Error while saving tileset: ", tileset_path)