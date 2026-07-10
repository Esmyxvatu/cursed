extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var head = $FlameHead
@onready var feet = $Feat
@onready var coat = $Coat
@onready var sword = $Sword
@onready var attack = $attack

var jumping: bool = false
var max_jump: float = -400
var last_height: float = -42.0


func _physics_process(delta: float) -> void:
	# Show the animation
	if jumping:
		coat.play("jump")
		feet.play(feet.animation)
	elif not is_on_floor() and (coat.animation == "start_falling" or coat.animation == "falling"):
		coat.play(coat.animation)
		feet.play(feet.animation)
	elif velocity.x != 0:
		coat.play("running")
		feet.play("running")
	else:
		coat.play("idle")
		feet.play("idle")

	# Add the gravity.
	if not is_on_floor():
		velocity += Vector2(0, 1500) * delta

	# Handle jump.
	if get_position_delta().y != 0:
		last_height += get_position_delta().y
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		jumping = true
		max_jump = last_height - 75.0
		feet.play("jump")
	
	if jumping and (Input.is_action_just_released("jump") or last_height <= max_jump or is_on_ceiling()):
		jumping = false
		coat.play("start_falling")
		feet.play("falling")

	# Get the input direction and handle the movement/deceleration.
	# should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("move_left", "move_right")	# 1 -> left -1 -> right
	if direction: # go left
		velocity.x = direction * SPEED
		flip_sprites_around(direction == -1)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED / 4)

	if Input.is_action_just_pressed("attack_1"):
		sword.hide()
		attack.show()
		attack.play("attack_1")

	if jumping:
		velocity.y = JUMP_VELOCITY

	move_and_slide()


func flip_sprites_around(left: bool) -> void:
	if left:
		head.flip_h = true
		coat.flip_h = true
		feet.flip_h = true
		sword.flip_h = true
		sword.flip_v = true
		sword.rotation_degrees = 250
		
		attack.flip_h = true
		attack.offset = Vector2(-55, 0)
	else:
		head.flip_h = false
		coat.flip_h = false
		feet.flip_h = false
		sword.flip_h = false
		sword.flip_v = false
		sword.rotation_degrees = 200
		
		attack.flip_h = false
		attack.offset = Vector2(0, 0)


func _on_coat_animation_finished() -> void:
	if coat.animation == "start_falling":
		coat.set_animation("falling")


func _on_feat_animation_finished() -> void:
	if feet.animation == "jump" or feet.animation == "falling":
		feet.set_animation("idle")


func _on_attack_animation_finished() -> void:
	sword.show()
	attack.hide()
