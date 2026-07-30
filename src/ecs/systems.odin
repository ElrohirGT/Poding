package main

import "vendor:raylib"
import "vendor:microui"

Vec2 :: [2]f32
Transform :: struct {
	position: Vec2,
	velocity: Vec2
}

movement :: proc(transforms: []^Transform, dt: f32) {
	if !frame {
		return
	}

	for t in transforms {
		t.position += t.velocity * dt
	}
}

RectangleRender :: struct {
	dimensions: Vec2,
	color: raylib.Color,
}


rectangle_renderer :: proc(cps: []struct{ct1: ^RectangleRender, ct2: ^Transform}) {
	for cp in cps {
		transform := cp.ct2
		render := cp.ct1
		raylib.DrawRectangle(i32(transform.position.x), i32(transform.position.y), i32(render.dimensions.x), i32(render.dimensions.y), render.color)
	}
}

CircleRender :: struct {
	offset: Vec2,
	radius: f32,
	color: raylib.Color,
}

// circle_renderer :: proc(transform: ^Transform, render: ^CircleRender) {
circle_renderer :: proc(cps: []struct{ct1: ^CircleRender, ct2: ^Transform}) {
	for cp in cps {
		transform := cp.ct2
		render := cp.ct1
		pos := transform.position + render.offset
		raylib.DrawCircle(i32(pos.x), i32(pos.y), render.radius, render.color)
	}
}

SquareCollider :: struct {
	id: uint,
	tag: string,
	static: bool,
	dimensions: Vec2,
	collision_direction: CollisionDirection,
	collision_with: uint
}

check_collisions :: proc(entities: []struct{ct1: ^SquareCollider, ct2: ^Transform}) {
	non_static := make([dynamic]int, 0, len(entities))
	for ent1, idx in entities {
		if !ent1.ct1.static {
			append(&non_static, idx)
		}
	}

	for idx in non_static {
		ent := entities[idx]
		for other in entities {
			if other.ct1.id == ent.ct1.id { // Avoid self collision
				continue
			}

			ent.ct1.collision_direction = is_touching_block(nil, ent, other)
			if ent.ct1.collision_direction != .NO_TOUCH {
				ent.ct1.collision_with = other.ct1.id
				break
			}
		}
	}
}

reset_collisions :: proc(entities: []^SquareCollider) {
	for ent in entities {
		ent.collision_direction = .NO_TOUCH
		ent.collision_with = 0
	}
}

bounce_ball :: proc(entities: []struct{ct1: ^SquareCollider, ct2: ^Transform}) {
	if !frame {
		return 
	}

	for ent in entities {
		switch (ent.ct1.collision_direction) {
		case CollisionDirection.NO_TOUCH:
			continue
		case CollisionDirection.TOP:
			fallthrough
		case CollisionDirection.BOTTOM:
			ent.ct2.velocity.y *= -1
		case CollisionDirection.LEFT:
			fallthrough
		case CollisionDirection.RIGHT:
			ent.ct2.velocity.x *= -1
		}
	}
}

CollisionDirection :: enum {
	NO_TOUCH,
	TOP,
	RIGHT,
	LEFT,
	BOTTOM
}

between :: proc(minimum, n, maximum: f32) -> bool {
	return minimum < n && maximum > n
}

is_left :: proc(a,b: f32) -> bool {
	return a <= b
}

is_right :: proc(a,b: f32) -> bool {
	return a >= b
}

is_top :: proc(a,b: f32) -> bool {
	return a <= b
}

is_bottom :: proc(a,b: f32) -> bool {
	return a >= b
}

get_cross :: proc(top_left, dim: Vec2) -> (left: Vec2, top: Vec2, right: Vec2, bottom: Vec2) {
	top = top_left
	top.x += dim.x / 2

	left = top_left
	left.y += dim.y / 2

	bottom = top_left + dim
	bottom.x -= dim.x / 2

	right = top_left + dim
	right.y -= dim.y / 2
	return 
}

is_colliding :: proc(point, other_pos, other_dim: Vec2) -> bool {
	return between(other_pos.x, point.x, other_pos.x+other_dim.x) && between(other_pos.y, point.y, other_pos.y+other_dim.y)
}

is_touching_block :: proc(ctx: ^microui.Context, ent1: struct{ct1: ^SquareCollider, ct2: ^Transform}, ent2: struct{ct1: ^SquareCollider, ct2: ^Transform}) -> CollisionDirection {
	// debug_on(ball_pos.x - BALL_RADIUS, ball_pos.y)
	// debug_on(block_pos.x + BLOCK_WIDTH, block_pos.y)

	ent1_top_left := ent1.ct2.position
	ent1_dimensions := ent1.ct1.dimensions
	ent1_left, ent1_top, ent1_right, ent1_bottom := get_cross(ent1_top_left, ent1_dimensions)
	if enable_debug {
		draw_debug_circle(ent1_left)
		draw_debug_circle(ent1_top)
		draw_debug_circle(ent1_right)
		draw_debug_circle(ent1_bottom) 
	}

	ent2_top_left  := ent2.ct2.position
	ent2_dimensions := ent2.ct1.dimensions
	if enable_debug {
		draw_debug_circle(ent2_top_left)
		draw_debug_circle(ent2_top_left + ent2_dimensions)
	}

	if (is_colliding(ent1_left, ent2_top_left, ent2_dimensions)) {
		return .LEFT
	} if (is_colliding(ent1_right, ent2_top_left, ent2_dimensions)) {
		return .RIGHT
	} if (is_colliding(ent1_top, ent2_top_left, ent2_dimensions)) {
		return .TOP
	} if (is_colliding(ent1_bottom, ent2_top_left, ent2_dimensions)) {
		return .BOTTOM
	} else {
		return .NO_TOUCH
	}

}
