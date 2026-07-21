package main

import "core:fmt"
import "core:slice"
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
	blocks: []Vec2,
	end_state: string,
	cfg: ^GameConfig
}

BallTouching :: enum {
	NO_TOUCH,
	TOP,
	RIGHT,
	LEFT,
	BOTTOM
}

generate_blocks :: proc(cfg: ^GameConfig, rows, cells, left_margin, top_margin, horizontal_gap, vertical_gap: int) -> []Vec2 {
	blocks := [dynamic]Vec2{}

	for i := 0; i<rows; i+=1 {
		for j := 0; j<cells; j+=1 {
			x := cast(f32)(int(cfg.BlockWidth) * j + left_margin + horizontal_gap*j)
			y := cast(f32)(int(cfg.BlockHeight) * i + top_margin + vertical_gap*i)
			append(&blocks, Vec2{x,y})
		}
	}

	return blocks[:]
}

generate_default_scene :: proc(cfg: ^GameConfig) -> GameState {
	blocks := []Vec2{}
	state := GameState{
		blocks = generate_blocks(cfg, 3, 7, 50, 50, 3, 3),
		padel_pos = {f32(cfg.ScreenWidth / 2 - cfg.PadelWidth / 2), f32(cfg.ScreenHeight) * 0.9}
	}
	state.ball.pos = Vec2{state.padel_pos.x + f32(cfg.PadelWidth) / 2, state.padel_pos.y - f32(cfg.BallRadius)}
	state.ball.vel = Vec2{0, 75}
	state.cfg = cfg
	return state
}

block_collision_scene :: proc(cfg: ^GameConfig) -> GameState {
	blocks := []Vec2{
		{150.0, 150.0},
		{250.0, 50.0},
		{350.0, 150.0},
		{250.0, 250.0},
	}
	state := GameState{
		blocks = slice.clone(blocks),
		padel_pos = {f32(cfg.ScreenWidth / 2 - cfg.PadelWidth / 2), f32(cfg.ScreenHeight) * 0.9}
	}
	state.ball.pos = Vec2{f32(150 + cfg.BlockWidth + cfg.BallRadius + 50), 150+f32(cfg.BlockHeight) / 2}
	// state.ball.vel = Vec2{-75, 0}
	state.ball.vel = Vec2{0, -75}
	state.cfg = cfg
	return state
}

padel_collision_scene :: proc(cfg: ^GameConfig) -> GameState {
	state := GameState {
		padel_pos = {f32(cfg.ScreenWidth / 2 - cfg.PadelWidth / 2), f32(cfg.ScreenHeight) * 0.9}
	}
	state.ball.pos = Vec2{50, 150+f32(cfg.BlockHeight) / 2}
	state.ball.vel = Vec2{150, 75}
	state.cfg = cfg
	return state
}

main :: proc() {
	cfg := parse_file("cfg.toml")
	fmt.printfln("CFG: %#v", cfg)

	raylib.InitWindow(cfg.ScreenWidth, cfg.ScreenHeight, "Main Window")
	defer raylib.CloseWindow()
	// state := block_collision_scene(cfg)
	// state := padel_collision_scene(cfg)
	state := generate_default_scene(cfg)


	sec_in_ns: i64 = 1_000_000_000
	max_frame_duration := sec_in_ns / i64(cfg.FpsCap)
	lastFrameStart := time.now()._nsec - max_frame_duration
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
