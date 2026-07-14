package main

import "core:slice"
import "vendor:raylib"

Vec2 :: struct {
	x: f32,
	y: f32,
}

GameState :: struct {
	PadelPos: Vec2,
	BallPos: Vec2,
	Blocks: []Vec2
}

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 400

BACKGROUND_COLOR  :: raylib.Color{80, 61, 63, 255}

BLOCK_WIDTH :: 100
BLOCK_HEIGHT :: 50
BLOCK_COLORS :: []raylib.Color{
	{82, 255, 184, 255},
	{83, 153, 135, 255}
}

PADEL_WIDTH :: 200
PADEL_HEIGHT :: 25
PADEL_COLOR :: raylib.Color{97, 87, 86, 255}

BALL_RADIUS :: 10
BALL_COLOR :: raylib.Color{77, 255, 243, 255}

generate_blocks :: proc(rows, cells, left_margin, top_margin, horizontal_gap, vertical_gap: int) -> []Vec2 {
	blocks := [dynamic]Vec2{}

	for i := 0; i<rows; i+=1 {
		for j := 0; j<cells; j+=1 {
			x := cast(f32)(BLOCK_WIDTH * j + left_margin + horizontal_gap*j)
			y := cast(f32)(BLOCK_HEIGHT * i + top_margin + vertical_gap*i)
			append(&blocks, Vec2{x,y})
		}
	}

	return blocks[:]
}

main :: proc() {
	raylib.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Main Window")
	defer raylib.CloseWindow()

	blocks := []Vec2{}
	state := GameState{
		Blocks = generate_blocks(3, 7, 50, 50, 3, 3),
		PadelPos = {SCREEN_WIDTH / 2 - PADEL_WIDTH / 2, SCREEN_HEIGHT * 0.9}
	}
	state.BallPos = Vec2{state.PadelPos.x + PADEL_WIDTH / 2, state.PadelPos.y - BALL_RADIUS}

	for !raylib.WindowShouldClose() {
		{
			raylib.BeginDrawing()
			defer raylib.EndDrawing()

			// Gather input and update state

			// Render game
			render_game(&state)
		}
	}
}

render_game :: proc(state: ^GameState) {
	block_colors := BLOCK_COLORS
	raylib.ClearBackground(BACKGROUND_COLOR)
	for i := 0; i < len(state.Blocks); i+=1  {
		b := state.Blocks[i]
		raylib.DrawRectangle(cast(i32)b.x, cast(i32)b.y, BLOCK_WIDTH, BLOCK_HEIGHT, block_colors[i%len(block_colors)])
	}

	raylib.DrawRectangle(cast(i32)state.PadelPos.x, cast(i32)state.PadelPos.y, PADEL_WIDTH, PADEL_HEIGHT, PADEL_COLOR)

	raylib.DrawCircle(cast(i32)state.BallPos.x, cast(i32)state.BallPos.y, BALL_RADIUS, BALL_COLOR)
}
