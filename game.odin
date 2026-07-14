package main

import "core:fmt"
import "core:time"
import "vendor:raylib"

Vec2 :: [2]f32
Ball :: struct {
	pos,
	vel: Vec2
}

GameState :: struct {
	padel_pos: Vec2,
	ball: Ball,
	blocks: []Vec2
}

BallTouching :: enum {
	NO_TOUCH,
	TOP,
	RIGHT,
	LEFT,
	BOTTOM
}

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 400
FPS_CAP :: 60

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
PADEL_VELOCITY :: 175

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

generate_default_scene :: proc() -> GameState {
	blocks := []Vec2{}
	state := GameState{
		blocks = generate_blocks(3, 7, 50, 50, 3, 3),
		padel_pos = {SCREEN_WIDTH / 2 - PADEL_WIDTH / 2, SCREEN_HEIGHT * 0.9}
	}
	state.ball.pos = Vec2{state.padel_pos.x + PADEL_WIDTH / 2, state.padel_pos.y - BALL_RADIUS}
	state.ball.vel = Vec2{15, 15}
	return state
}

generate_collision_test_scene :: proc() -> GameState {
	// blocks := []Vec2{
	// 	{150.0, 150.0},
	// 	{250.0, 50.0},
	// 	{350.0, 150.0},
	// 	{250.0, 250.0},
	// }
	state := GameState{
		blocks = []Vec2{
			{150, 150}
		},
		padel_pos = {SCREEN_WIDTH / 2 - PADEL_WIDTH / 2, SCREEN_HEIGHT * 0.9}
	}
	state.ball.pos = Vec2{150 + BLOCK_WIDTH + BALL_RADIUS + 50, 150+BLOCK_HEIGHT / 2}
	state.ball.vel = Vec2{-75, 0}
	// state.ball.vel = Vec2{0, -75}
	return state
}

main :: proc() {
	raylib.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Main Window")
	defer raylib.CloseWindow()
	state := generate_collision_test_scene()
	// state := generate_default_scene()

	fmt.printfln("1: %v", state)

	sec_in_ns: i64 = 1_000_000_000
	max_frame_duration := sec_in_ns / FPS_CAP 
	lastFrameStart := time.now()._nsec - max_frame_duration
	fmt.printfln("2: %v", state)
	for !raylib.WindowShouldClose() {
		{
			frame_start := time.now()._nsec
			raylib.BeginDrawing()
			defer raylib.EndDrawing()

			// Gather input and update state
			update(&state, f32(frame_start - lastFrameStart) / f32(sec_in_ns))

			// Render game
			render(&state)

			lastFrameStart = time.now()._nsec
			time.sleep(cast(time.Duration)(max_frame_duration -(lastFrameStart - frame_start)))
		}
	}
}
