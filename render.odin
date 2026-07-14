package main

import "vendor:raylib"

render :: proc(state: ^GameState) {
	raylib.ClearBackground(BACKGROUND_COLOR)
	block_colors := BLOCK_COLORS
	i := 0
	for b in state.blocks {
		defer { i+= 1}
		x := cast(i32)(b.x)
		y := cast(i32)(b.y)
		raylib.DrawRectangle(x, y, BLOCK_WIDTH, BLOCK_HEIGHT, block_colors[i%len(block_colors)])
		// raylib.DrawText(fmt.ctprintf(), x, y, 20, raylib.WHITE)
	}

	raylib.DrawRectangle(cast(i32)state.padel_pos.x, cast(i32)state.padel_pos.y, PADEL_WIDTH, PADEL_HEIGHT, PADEL_COLOR)

	raylib.DrawCircle(cast(i32)state.ball.pos.x, cast(i32)state.ball.pos.y, BALL_RADIUS, BALL_COLOR)
}


debug_on :: proc(x,y: f32) {
	raylib.DrawCircle(i32(x),i32(y), 3, raylib.PINK)
}

