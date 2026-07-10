extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var head = $FlameHead
@onready var feet = $Feat
@onready var coat = $Coat
@onready var sword = $Sword


func _physics_process(delta: float) -> void:
	# Show the animation
	if velocity.x != 0:
		feet.play("running")
		coat.play("running")
	else:
		feet.play("idle")
		coat.play("idle")
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("move_left", "move_right")	# 1 -> left -1 -> right
	if direction: # go left
		velocity.x = direction * SPEED
		flip_sprites_around(direction == -1)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED / 4)

	move_and_slide()


func flip_sprites_around(left: bool) -> void:
	if left:
		head.flip_h = true
		coat.flip_h = true
		feet.flip_h = true
		sword.flip_h = true
		sword.flip_v = true
		sword.rotation_degrees = 250
	else:
		head.flip_h = false
		coat.flip_h = false
		feet.flip_h = false
		sword.flip_h = false
		sword.flip_v = false
		sword.rotation_degrees = 200
