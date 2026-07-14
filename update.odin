package main

import "vendor:raylib"

update :: proc(state: ^GameState, dt: f32) {
	if raylib.IsKeyDown(raylib.KeyboardKey.RIGHT) {
		state.padel_pos.x += PADEL_VELOCITY * dt
	}
	if raylib.IsKeyDown(raylib.KeyboardKey.LEFT) {
		state.padel_pos.x -= PADEL_VELOCITY * dt
	}

	state.ball.pos += state.ball.vel * dt
	for i := 0; i < len(state.blocks); i+=1{
		b_pos := state.blocks[i]
		touching := is_ball_touching_block(state.ball.pos, b_pos)
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
	}

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


// TODO: Implement correctly
is_ball_touching_block :: proc(ball_pos: Vec2, block_pos: Vec2) -> BallTouching {
	// debug_on(ball_pos.x - BALL_RADIUS, ball_pos.y)
	// debug_on(block_pos.x + BLOCK_WIDTH, block_pos.y)

	if is_left(ball_pos.x - BALL_RADIUS, block_pos.x + BLOCK_WIDTH) && is_right(ball_pos.x - BALL_RADIUS, block_pos.x) && is_bottom(ball_pos.y, block_pos.y) && is_top(ball_pos.y, block_pos.y+BLOCK_HEIGHT) {
		return .LEFT
	} if is_left(ball_pos.x + BALL_RADIUS, block_pos.x + BLOCK_WIDTH) && is_right(ball_pos.x + BALL_RADIUS, block_pos.x) && is_bottom(ball_pos.y, block_pos.y) && is_top(ball_pos.y, block_pos.y+BLOCK_HEIGHT) {
		return .RIGHT
	} if is_left(ball_pos.x, block_pos.x + BLOCK_WIDTH) && is_right(ball_pos.x, block_pos.x) && is_bottom(ball_pos.y - BALL_RADIUS, block_pos.y) && is_top(ball_pos.y - BALL_RADIUS, block_pos.y+BLOCK_HEIGHT) {
		return .TOP
	} if is_left(ball_pos.x, block_pos.x + BLOCK_WIDTH) && is_right(ball_pos.x, block_pos.x) && is_bottom(ball_pos.y + BALL_RADIUS, block_pos.y) && is_top(ball_pos.y + BALL_RADIUS, block_pos.y+BLOCK_HEIGHT) {
		return .BOTTOM
	} else {
		return .NO_TOUCH
	}
}

