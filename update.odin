package main

import "vendor:raylib"

update :: proc(state: ^GameState, dt: f32) {
	padel_vel_x :f32 = 0.0
	if raylib.IsKeyDown(raylib.KeyboardKey.RIGHT) {
		padel_vel_x += PADEL_VELOCITY * dt
	}
	if raylib.IsKeyDown(raylib.KeyboardKey.LEFT) {
		padel_vel_x -= PADEL_VELOCITY * dt
	}
	state.padel_pos.x += padel_vel_x

	del_idx := -1
	for i := 0; i < len(state.blocks); i+=1 {
		b_pos := state.blocks[i]
		touching := is_ball_touching_block(state.ball.pos, b_pos, BLOCK_WIDTH, BLOCK_HEIGHT)
		switch (touching) {
		case BallTouching.NO_TOUCH:
			continue
		case BallTouching.TOP:
			fallthrough
		case BallTouching.BOTTOM:
			state.ball.vel.y *= -1
		case BallTouching.LEFT:
			fallthrough
		case BallTouching.RIGHT:
			state.ball.vel.x *= -1
		}

		if touching != BallTouching.NO_TOUCH {
			del_idx = i
		}
	}

	try_remove_from_slice(&state.blocks, del_idx)

	if len(state.blocks) == 0 {
		state.end_state = "YOU WIN!"
	}

	{
		touching := is_ball_touching_block(state.ball.pos, state.padel_pos, PADEL_WIDTH, PADEL_HEIGHT)
		switch (touching) {
		case BallTouching.NO_TOUCH:
		case BallTouching.TOP:
			fallthrough
		case BallTouching.BOTTOM:
			state.ball.vel.y *= -1
		case BallTouching.LEFT:
			fallthrough
		case BallTouching.RIGHT:
			state.ball.vel.x *= -1
		}

		if touching != BallTouching.NO_TOUCH {
			state.ball.vel *= 1.1
			state.ball.vel.x += padel_vel_x / dt
		}
	}

	// TOP and BOTTOM borders
	if is_ball_touching_block(state.ball.pos, Vec2{0,-SCREEN_HEIGHT}, SCREEN_WIDTH, SCREEN_HEIGHT) == .TOP {
		state.ball.vel.y *= -1
	}

	if is_ball_touching_block(state.ball.pos, Vec2{0, SCREEN_HEIGHT}, SCREEN_WIDTH, SCREEN_HEIGHT) == .BOTTOM  {
		state.end_state = "YOU LOSE!"
	}

	// LEFT and RIGHT borders
	if is_ball_touching_block(state.ball.pos, Vec2{-SCREEN_WIDTH,0}, SCREEN_WIDTH, SCREEN_HEIGHT) == .LEFT ||
	is_ball_touching_block(state.ball.pos, Vec2{SCREEN_WIDTH, 0}, SCREEN_WIDTH, SCREEN_HEIGHT) == .RIGHT {
		state.ball.vel.x *= -1
	}

	if state.end_state != "" && raylib.IsKeyDown(.R) {
		state^ = generate_default_scene()
	}

	state.ball.pos += state.ball.vel * dt
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

is_ball_touching_block :: proc(ball_pos: Vec2, block_pos: Vec2, block_width, block_height: f32) -> BallTouching {
	// debug_on(ball_pos.x - BALL_RADIUS, ball_pos.y)
	// debug_on(block_pos.x + BLOCK_WIDTH, block_pos.y)

	if is_left(ball_pos.x - BALL_RADIUS, block_pos.x + block_width) && is_right(ball_pos.x - BALL_RADIUS, block_pos.x) && is_bottom(ball_pos.y, block_pos.y) && is_top(ball_pos.y, block_pos.y+block_height) {
		return .LEFT
	} if is_left(ball_pos.x + BALL_RADIUS, block_pos.x + block_width) && is_right(ball_pos.x + BALL_RADIUS, block_pos.x) && is_bottom(ball_pos.y, block_pos.y) && is_top(ball_pos.y, block_pos.y+block_height) {
		return .RIGHT
	} if is_left(ball_pos.x, block_pos.x + block_width) && is_right(ball_pos.x, block_pos.x) && is_bottom(ball_pos.y - BALL_RADIUS, block_pos.y) && is_top(ball_pos.y - BALL_RADIUS, block_pos.y+block_height) {
		return .TOP
	} if is_left(ball_pos.x, block_pos.x + block_width) && is_right(ball_pos.x, block_pos.x) && is_bottom(ball_pos.y + BALL_RADIUS, block_pos.y) && is_top(ball_pos.y + BALL_RADIUS, block_pos.y+block_height) {
		return .BOTTOM
	} else {
		return .NO_TOUCH
	}
}

try_remove_from_slice :: proc(arr: ^[]$T, idx: int) {
	if idx < 0 || idx >= len(arr) {
		return
	}

	if len(arr) == 1 {
		arr^ = []T{}
		return
	}

	arr[0], arr[idx] = arr[idx], arr[0]
	arr^ = arr[1:]
}
