package main

import "core:math"
import "vendor:raylib"

Vec2 :: [2]f32
Transform :: struct {
	position: Vec2,
	velocity: Vec2
}

movement :: proc(transforms: []^Transform, dt: f32) {
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
	static: bool,
	dimensions: Vec2
}

check_collisions :: proc(entities: []struct{ct1: ^SquareCollider, ct2: ^Transform}) {
	non_static := make([dynamic]struct{ct1: ^SquareCollider, ct2: ^Transform}, 0, len(entities))
	for ent1 in entities {
		if !ent1.ct1.static {
			append(&non_static, ent1)
		}
	}

	for ent in non_static {
		for other in entities {
			if other.ct1.id == ent.ct1.id { // Avoid self collision
				continue
			}

			touching := is_touching_block(ent, other)
			switch (touching) {
			case BallTouching.NO_TOUCH:
				continue
			case BallTouching.TOP:
				fallthrough
			case BallTouching.BOTTOM:
				ent.ct2.velocity.y *= -1
			case BallTouching.LEFT:
				fallthrough
			case BallTouching.RIGHT:
				ent.ct2.velocity.x *= -1
			}
		}
	}
}

BallTouching :: enum {
	NO_TOUCH,
	TOP,
	RIGHT,
	LEFT,
	BOTTOM
}

between :: proc(n, minimum, maximum: f32) -> bool {
	return n >= minimum && n <= maximum
}

is_touching_block :: proc(ent1: struct{ct1: ^SquareCollider, ct2: ^Transform}, ent2: struct{ct1: ^SquareCollider, ct2: ^Transform}) -> BallTouching {
	// debug_on(ball_pos.x - BALL_RADIUS, ball_pos.y)
	// debug_on(block_pos.x + BLOCK_WIDTH, block_pos.y)

	ent1_top_left := ent1.ct2.position
	ent1_dimensions := ent1.ct1.dimensions

	ent2_top_left  := ent2.ct2.position
	ent2_dimensions := ent2.ct1.dimensions

	diff := ent1_top_left - ent2_top_left

	if between(diff.x, 0, ent2_dimensions.x) &&
		(between(ent1_top_left.y, ent2_top_left.y, ent2_top_left.y+ent2_dimensions.y) || between(ent2_top_left.y, ent1_top_left.y, ent1_top_left.y+ent1_dimensions.y)) {
		return .LEFT
	}
	if between(diff.y, 0, ent2_dimensions.y) &&
	(between(ent1_top_left.x, ent2_top_left.x, ent2_top_left.x+ent2_dimensions.x) || between(ent2_top_left.x, ent1_top_left.x, ent1_top_left.x+ent1_dimensions.x)) {
		return .BOTTOM
	}

	diff = ent2_top_left - ent1_top_left
	if between(diff.x, 0, ent1_dimensions.x) &&
		(between(ent1_top_left.y, ent2_top_left.y, ent2_top_left.y+ent2_dimensions.y) || between(ent2_top_left.y, ent1_top_left.y, ent1_top_left.y+ent1_dimensions.y)) {
		return .RIGHT
	}
	if between(diff.y, 0, ent1_dimensions.y) &&
	(between(ent1_top_left.x, ent2_top_left.x, ent2_top_left.x+ent2_dimensions.x) || between(ent2_top_left.x, ent1_top_left.x, ent1_top_left.x+ent1_dimensions.x)) {
		return .TOP
	}

	return .NO_TOUCH
	
	// if is_left(ball_pos.x - f32(cfg.BallRadius), block_pos.x + block_width) && is_right(ball_pos.x - f32(cfg.BallRadius), block_pos.x) && is_bottom(ball_pos.y, block_pos.y) && is_top(ball_pos.y, block_pos.y+block_height) {
	// 	return .LEFT
	// } if is_left(ball_pos.x + f32(cfg.BallRadius), block_pos.x + block_width) && is_right(ball_pos.x + f32(cfg.BallRadius), block_pos.x) && is_bottom(ball_pos.y, block_pos.y) && is_top(ball_pos.y, block_pos.y+block_height) {
	// 	return .RIGHT
	// } if is_left(ball_pos.x, block_pos.x + block_width) && is_right(ball_pos.x, block_pos.x) && is_bottom(ball_pos.y - f32(cfg.BallRadius), block_pos.y) && is_top(ball_pos.y - f32(cfg.BallRadius), block_pos.y+block_height) {
	// 	return .TOP
	// } if is_left(ball_pos.x, block_pos.x + block_width) && is_right(ball_pos.x, block_pos.x) && is_bottom(ball_pos.y + f32(cfg.BallRadius), block_pos.y) && is_top(ball_pos.y + f32(cfg.BallRadius), block_pos.y+block_height) {
	// 	return .BOTTOM
	// } else {
	// 	return .NO_TOUCH
	// }
}
