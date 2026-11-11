extends Control
var font:Font=preload("res://assets/ui/PixelifySans.ttf")
var icons:Dictionary={}
var start:Button
var scale_factor:=1.0
func _ready() -> void:
	for id in BlasterWeapons.IDS:icons[id]=BlasterWeapons.create_icon(id)
	start=Button.new();start.text="START MATCH / REMATCH  [F6]";start.pressed.connect(func():Shooter.host_start.rpc_id(1));add_child(start)
	start.add_theme_font_size_override("font_size",18)
func text(value:String,pos:Vector2,font_size:int=18,color:Color=Color.WHITE) -> void:
	draw_string(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
func _draw() -> void:
	var a:Dictionary=Shooter.local_actor()
	var show_game:bool=not a.is_empty() and Shooter.level() and not Shooter.level().main_menu.visible

	# Handle inventory UI toggle with 'I' key (same as collect)
	if Input.is_key_pressed(KEY_I) and not Shooter.blocked():
		var inv_ui := get_tree().get_first_node_in_group("inventory_ui")
		if inv_ui:
			inv_ui.toggle_inventory()
	start.visible=show_game and Shooter.own_id()==Shooter.lobby_owner and Shooter.phase in ["waiting","results"]
	var viewport_size:=get_viewport_rect().size
	scale_factor=minf(viewport_size.x/1280.0,viewport_size.y/720.0)
	var offset:Vector2=(viewport_size-Vector2(1280,720)*scale_factor)*0.5
	start.position=offset+Vector2(465,150)*scale_factor;start.size=Vector2(350,44)*scale_factor
	if not show_game:return
	draw_set_transform(offset,0,Vector2.ONE*scale_factor)
	if Shooter.damage_flash>0:draw_rect(Rect2(0,0,1280,720),Color(1,0.1,0.15,Shooter.damage_flash*0.6))
	draw_rect(Rect2(24,20,430,76),Color(0.03,0.06,0.1,0.85))
	text("FOUNDRY / "+Shooter.MODES[Shooter.mode].to_upper(),Vector2(40,46),20,Color("ffc46f"))
	var status:String=Shooter.phase.to_upper()
	if Shooter.phase=="active":status=("Zone: %dm"%int(Shooter.zone_radius())) if Shooter.mode==2 else ("%02d:%02d"%[int(maxf(0,480-Shooter.elapsed))/60,int(maxf(0,480-Shooter.elapsed))%60])
	if Shooter.phase=="countdown":status="MATCH STARTS IN "+str(ceili(Shooter.countdown))
	text(status,Vector2(40,77),17)
	if Shooter.mode==0:text("BLUE %d : %d RED"%[Shooter.team_scores[0],Shooter.team_scores[1]],Vector2(550,42),24)
	else:text("ELIMINATIONS %d"%int(a.score),Vector2(550,42),24)
	var y:=82
	for event in Shooter.feed:text(event,Vector2(900,y),15,Color("dce6ef"));y+=23
	if Shooter.phase=="waiting":text("Practice while waiting · Host starts with F6",Vector2(420,120),20)
	if Shooter.phase=="results":
		draw_rect(Rect2(300,70,680,70),Color(0.03,0.05,0.09,0.92));text(Shooter.result,Vector2(340,113),28,Color("ffd687"))
	var health:float=a.hp
	for i in range(10):heart(Vector2(405+i*28,581),clampf((health-i*10)/10.0,0,1))
	draw_rect(Rect2(405,610,272,12),Color("263744"));draw_rect(Rect2(407,612,268*float(a.stamina)/6.0,8),Color("64e4c6"))
	text("SPRINT",Vector2(687,622),13,Color("8eeddb"))
	var slots:Array=a.slots
	for i in range(9):
		var pos:=Vector2(380+i*58,642)
		draw_rect(Rect2(pos,Vector2(54,54)),Color("d9e5db") if i==int(a.selected) else Color("718188"))
		draw_rect(Rect2(pos+Vector2(3,3),Vector2(48,48)),Color("1c2835"))
		text(str(i+1),pos+Vector2(5,15),12,Color("b4c5ce"))
		if i<slots.size() and BlasterWeapons.DATA.has(slots[i]):
			var gun:String=slots[i];draw_texture_rect(icons[gun],Rect2(pos+Vector2(10,15),Vector2(33,33)),false)
			var selected:int=a.selected;var item_name:String=str(slots[selected]) if selected<slots.size() else ""
			if a.guns.has(gun):
				var ammo:Dictionary=a.guns[gun]
				text(gun.to_upper(),Vector2(980,610),20,BlasterWeapons.DATA[gun].color)
				text("%d / %d"%[ammo.mag,ammo.reserve],Vector2(980,652),32)
				if float(a.reload)>0:text("RELOADING",Vector2(980,680),16,Color("ffd687"))
	text("E collect ·  R reload ·  I inventory ·  T chat ·  Tab scores",Vector2(25,700),14,Color("b5c5ce"))
	if not Shooter.blocked() and health>0:
		var color:=Color("ffe59c") if Shooter.hit_flash>0 else Color.WHITE
		draw_line(Vector2(632,360),Vector2(638,360),color,2);draw_line(Vector2(642,360),Vector2(648,360),color,2)
		draw_line(Vector2(640,352),Vector2(640,358),color,2);draw_line(Vector2(640,362),Vector2(640,368),color,2)
		var player=Shooter.human(Shooter.own_id())
		for loot in Shooter.pickups:
			if float(loot.available)<=Shooter.now() and player and player.position.distance_to(loot.pos)<3:
				text("E  COLLECT "+str(loot.kind).to_upper(),Vector2(530,430),20,Color("fff0a8"));break
	if health<=0:
		draw_rect(Rect2(350,260,580,120),Color(0.03,0.05,0.09,0.85))
	text("ELIMINATED",Vector2(520,307),30,Color("ff8791"))
	text("Spectating · wait for the next round" if Shooter.mode==2 else "Respawning...",Vector2(460,347),20)
	if Input.is_key_pressed(KEY_TAB):
		draw_rect(Rect2(350,180,580,350),Color(0.02,0.04,0.08,0.95));text("PLAYER                          KILLS     DEATHS",Vector2(380,215),19,Color("ffd687"))
		y=250
		for id in Shooter.actors:
			var entry:Dictionary=Shooter.actors[id]
			text(str(entry.name).left(22),Vector2(380,y),18,Color("82cfff") if int(entry.team)==0 else Color("ff9f99"));text("%d          %d"%[entry.score,entry.deaths],Vector2(730,y),18);y+=25

func heart(pos:Vector2,amount:float) -> void:
	var rows=["0110110","1111111","1111111","0111110","0011100","0001000"]
	for y in range(rows.size()):
		for x in range(7):
			if rows[y][x]=="1":draw_rect(Rect2(pos+Vector2(x*3,y*3),Vector2(3,3)),Color("f0647a") if float(x)/7.0<amount else Color("453641"))