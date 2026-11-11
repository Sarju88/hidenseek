class_name BlasterWeapons
extends RefCounted
const IDS = ["pistol", "rifle", "shotgun", "marksman"]
const DATA = {
 "pistol": {"damage":20, "magazine":12, "rate":3.0, "reload":1.2, "pellets":1, "range":100.0, "model":"a", "color":Color("64d5f5")},
 "rifle": {"damage":20, "magazine":24, "rate":6.0, "reload":1.8, "pellets":1, "range":100.0, "model":"d", "color":Color("ffba63")},
 "shotgun": {"damage":8, "magazine":6, "rate":1.0, "reload":2.4, "pellets":8, "range":25.0, "model":"e", "color":Color("b7ee79")},
 "marksman": {"damage":60, "magazine":5, "rate":1.0, "reload":2.0, "pellets":1, "range":100.0, "model":"r", "color":Color("d7a7ff")}
}
static func model(id: String) -> PackedScene:
 return load("res://assets/blasters/blaster-%s.glb" % DATA[id].model)
static func create_icon(id: String) -> ImageTexture:
 var image := Image.create(32,32,false,Image.FORMAT_RGBA8)
 image.fill(Color.TRANSPARENT)
 image.fill_rect(Rect2i(3,10,25,7), DATA[id].color)
 image.fill_rect(Rect2i(12,17,6,10), DATA[id].color.darkened(0.3))
 image.fill_rect(Rect2i(25,11,6,4),Color("26384a"))
 return ImageTexture.create_from_image(image)
