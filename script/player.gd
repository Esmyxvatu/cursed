extends CharacterBody2D

enum State { IDLE, RUN, JUMP, FALL }

# --- Mouvement ---
const SPEED := 300.0
const JUMP_VELOCITY := -400.0
const GRAVITY := 1500.0
const FALL_GRAVITY_MULT := 1.6   # la chute est plus rapide que la montée
const MAX_FALL_SPEED := 900.0
const JUMP_HEIGHT := 75.0
const FRICTION := SPEED / 4.0
const COYOTE_TIME := 0.1         # marge de saut après avoir quitté une plateforme
const JUMP_BUFFER_TIME := 0.1    # marge d'appui avant l'atterrissage

# --- Visuel ---
const SWORD_ROT_RIGHT := 200.0
const SWORD_ROT_LEFT := 250.0
const ATTACK_OFFSET_LEFT := Vector2(-55.0, 0.0)
const HEAD_LOOK_TILT := 10.0     # inclinaison de la flamme (degrés)
const SWORD_LOOK_TILT := 15.0    # rotation de l'épée avec look_down (degrés)

@onready var head: AnimatedSprite2D = $FlameHead
@onready var feet: AnimatedSprite2D = $Feat
@onready var coat: AnimatedSprite2D = $Coat
@onready var sword: AnimatedSprite2D = $Sword
@onready var attack: AnimatedSprite2D = $attack
@onready var attack_up: AnimatedSprite2D = $"attack up"
@onready var attack_down: AnimatedSprite2D = $"attack down"

var state: State = State.IDLE
var attacking := false   # overlay visuel : n'interrompt pas le mouvement
var current_attack: AnimatedSprite2D = null
var facing_left := false
var jump_target_y := 0.0
var coyote_timer := 0.0
var jump_buffer_timer := 0.0


func _ready() -> void:
	# Connexion des signaux animation_finished par code.
	# Le test is_connected evite un double appel si le signal
	# est deja connecte dans l'editeur.
	var connections := {
		coat: _on_coat_animation_finished,
		feet: _on_feat_animation_finished,
		attack: _on_attack_animation_finished,
		attack_up: _on_attack_up_animation_finished,
		attack_down: _on_attack_down_animation_finished,
	}
	for sprite: AnimatedSprite2D in connections:
		if not sprite.animation_finished.is_connected(connections[sprite]):
			sprite.animation_finished.connect(connections[sprite])


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_handle_movement()
	_handle_look()
	_handle_attack()
	_update_state(delta)
	_update_animations()
	move_and_slide()


func _update_timers(delta: float) -> void:
	# Coyote time : rechargé au sol, décompte en l'air.
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)

	# Jump buffer : mémorise l'appui sur saut pendant un court instant.
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)


func _update_state(delta: float) -> void:
	match state:
		State.IDLE, State.RUN:
			if not is_on_floor():
				state = State.FALL  # tombé d'une plateforme sans sauter
			elif not _try_jump():
				state = State.RUN if velocity.x != 0.0 else State.IDLE

		State.JUMP:
			velocity.y = JUMP_VELOCITY
			# Fin de la montée : touche relâchée, hauteur max, ou plafond.
			if Input.is_action_just_released("jump") \
					or global_position.y <= jump_target_y \
					or is_on_ceiling():
				state = State.FALL

		State.FALL:
			if is_on_floor():
				# Atterrissage : saut bufferisé, sinon retour au sol.
				if not _try_jump():
					state = State.RUN if velocity.x != 0.0 else State.IDLE
			else:
				# Gravité asymétrique, plafonnée à MAX_FALL_SPEED.
				velocity.y = minf(
					velocity.y + GRAVITY * FALL_GRAVITY_MULT * delta,
					MAX_FALL_SPEED
				)
				_try_jump()  # coyote time


func _try_jump() -> bool:
	if jump_buffer_timer > 0.0 and (is_on_floor() or coyote_timer > 0.0):
		jump_buffer_timer = 0.0
		coyote_timer = 0.0  # empêche le double saut
		jump_target_y = global_position.y - JUMP_HEIGHT
		velocity.y = JUMP_VELOCITY
		state = State.JUMP
		feet.play("jump")
		return true
	return false


func _handle_movement() -> void:
	var direction := Input.get_axis("move_left", "move_right")  # -1 = gauche, 1 = droite
	if direction:
		velocity.x = direction * SPEED
		_flip_sprites(direction < 0.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION)


func _handle_look() -> void:
	# Inversé quand le perso regarde à gauche.
	var mirror := -1.0 if facing_left else 1.0

	# La flamme penche vers l'arrière (look_up) ou l'avant (look_down).
	if Input.is_action_pressed("look_up"):
		head.rotation_degrees = -HEAD_LOOK_TILT * mirror
	elif Input.is_action_pressed("look_down"):
		head.rotation_degrees = HEAD_LOOK_TILT * mirror
	else:
		head.rotation_degrees = 0.0

	# L'épée s'incline vers l'avant quand look_down est actif.
	var sword_base := SWORD_ROT_LEFT if facing_left else SWORD_ROT_RIGHT
	if Input.is_action_pressed("look_down"):
		sword.rotation_degrees = sword_base + SWORD_LOOK_TILT * mirror
	else:
		sword.rotation_degrees = sword_base


func _handle_attack() -> void:
	if Input.is_action_just_pressed("attack_1") and not attacking:
		if Input.is_action_pressed("look_up"):
			_start_attack(attack_up, "attack_1_up")
		elif Input.is_action_pressed("look_down") and not is_on_floor():
			# Attaque vers le bas uniquement en l'air (style pogo).
			_start_attack(attack_down, "attack_1_down")
		else:
			_start_attack(attack, "attack_1")


func _start_attack(sprite: AnimatedSprite2D, anim: String) -> void:
	attacking = true
	current_attack = sprite
	sword.hide()
	sprite.play(anim)


func _end_attack() -> void:
	attacking = false
	sword.show()
	if current_attack:
		current_attack.play("idle")  # fotogramme vide
		current_attack = null


func _update_animations() -> void:
	match state:
		State.IDLE:
			coat.play("idle")
			feet.play("idle")
		State.RUN:
			coat.play("running")
			feet.play("running")
		State.JUMP:
			coat.play("jump")
		State.FALL:
			if coat.animation != "start_falling" and coat.animation != "falling":
				coat.play("start_falling")
				feet.play("falling")


func _flip_sprites(left: bool) -> void:
	facing_left = left
	head.flip_h = left
	coat.flip_h = left
	feet.flip_h = left
	sword.flip_h = left
	sword.flip_v = left
	attack.flip_h = left
	attack.offset = ATTACK_OFFSET_LEFT if left else Vector2.ZERO
	# Sprites tournes de 90 degres : leur axe X local est vertical a l'ecran,
	# donc c'est flip_v qui produit un miroir gauche/droite.
	attack_up.flip_v = left
	attack_down.flip_v = left
	# Si les attaques haut/bas sont decalees en regardant a gauche,
	# ajoute ici un offset comme pour attack.


func _on_coat_animation_finished() -> void:
	if coat.animation == "start_falling":
		coat.play("falling")


func _on_feat_animation_finished() -> void:
	if feet.animation == "jump" or feet.animation == "falling":
		feet.set_animation("idle")


func _on_attack_animation_finished() -> void:
	# Le filtre evite que la fin de "idle" (fotogramme vide) rappelle _end_attack.
	if attack.animation == "attack_1":
		_end_attack()


func _on_attack_up_animation_finished() -> void:
	if attack_up.animation == "attack_1_up":
		_end_attack()


func _on_attack_down_animation_finished() -> void:
	if attack_down.animation == "attack_1_down":
		_end_attack()
