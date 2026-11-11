extends Node

class_name ShooterScript

signal shot_fired
signal reload_complete

var level_node = null
var actors = {}
var multiplayer_api = null

func _ready():
	level_node = get_node_or_null("../level/level") as Node3D
	# Godot 4.x: MultiplayerAPI is accessed via tree.multiplayer, not singleton
	multiplayer_api = get_tree().get_multiplayer() if get_tree() else null

func get_level():
	return level_node

func actors_dict():
	return actors

func has_multiplayer_peer():
	return multiplayer_api != null and multiplayer_api.has_multiplayer_peer()

func get_unique_id():
	if not multiplayer_api or not multiplayer_api.has_multiplayer_peer(): return 0
	return multiplayer_api.get_unique_id()

func blocked():
	if not level_node: return false
	if not level_node.has_method("is_gameplay_input_blocked"): return false
	return level_node.is_gameplay_input_blocked()

func own_id():
	if not multiplayer_api or not multiplayer_api.has_multiplayer_peer(): return 0
	return multiplayer_api.get_unique_id()

func now():
	return Time.get_ticks_msec()/1000.0

func new_actor(id):
	var team = actors.size() % 2
	var data = {"hp":100.0,"stamina":6.0,"team":team,"score":0,"deaths":0,"selected":0,"guns":{},"slots":[],"reload":0.0,"last_shot":0.0,"respawn":0.0,"shield":0.0,"sprint":false,"last_sprint":0.0,"name":"Bot "+str(-id) if id<0 else str(Network.players.get(id,{}).get("nick","Player")),"pos":Vector3.ZERO}
	actors[id]=data
	reset_actor(id)
	return data

func reset_actor(id):
	if not actors.has(id): return
	var actor = actors[id]
	actor["hp"]=100.0
	actor["stamina"]=6.0
	actor["selected"]=0
	actor["guns"]={}
	actor["slots"]=[]
	actor["reload"]=0.0
	actor["last_shot"]=0.0
	actor["respawn"]=0.0
	actor["shield"]=0.0
	actor["sprint"]=false
	actor["last_sprint"]=0.0

func get_bot(id):
	return "Bot"+str(-id)

func local_actor():
	if not multiplayer_api or not multiplayer_api.has_multiplayer_peer(): return {}
	return actors.get(multiplayer_api.get_unique_id(),{})
