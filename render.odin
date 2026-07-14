package main

import "core:fmt"
import "core:c"
import "vendor:raylib"

render :: proc(state: ^GameState) {
	raylib.ClearBackground(BACKGROUND_COLOR)

	if len(state.end_state) == 0 {
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
	} else {
		font_size :i32 = 20
		msg := fmt.ctprintf("%s", state.end_state)
		center_text(msg, SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2, font_size, raylib.WHITE)
		msg = fmt.ctprintf("Press R to restart")
		center_text(msg, SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2 + font_size + 5, font_size -5, raylib.WHITE)
	}
}

center_text :: proc(msg: cstring, x, y, font_size: c.int, color: raylib.Color) {
		text_width := raylib.MeasureText(msg, font_size)
		raylib.DrawText(msg, x - text_width / 2, y - font_size / 2, font_size, raylib.WHITE)
}


debug_on :: proc(x,y: f32) {
	raylib.DrawCircle(i32(x),i32(y), 3, raylib.PINK)
}

