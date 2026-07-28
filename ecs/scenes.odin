package main

import "ecs"
import "core:slice"

block_collision_scene :: proc(cfg: ^GameConfig, store: ^ecs.Store) {
	blocks := []Vec2{
		{150.0, 150.0},
		{250.0, 50.0},
		{350.0, 150.0},
		{250.0, 250.0},
	}

	// Blocks
	for b,idx in slice.clone(blocks) {
		transform := new(Transform)
		transform^ = Transform {
			position = b,
			velocity = Vec2{0,0},
		}
		renderer := new(RectangleRender)
		renderer^ = RectangleRender {
			top_left = b,
			dimensions = Vec2{f32(cfg.BlockWidth), f32(cfg.BlockHeight)},
			color = cfg.BlockColors[idx % len(cfg.BlockColors)],
		}
		ecs.spawn_with(store, []any{ transform^, renderer^ })
	}

	// Padel
	ecs.spawn_with(store, []any{
		Transform{
			position = Vec2{f32(cfg.ScreenWidth / 2 - cfg.PadelWidth / 2), f32(cfg.ScreenHeight) * 0.9}
		}
	})

	// Ball
	ball_t := new(Transform)
	ball_t^ = Transform{
			position = Vec2{150.0 + f32(cfg.BlockWidth) + cfg.BallRadius + 50.0, 150+f32(cfg.BlockHeight) / 2},
			velocity = Vec2{0, -75},
		}
	ball_r := new(CircleRender)
	ball_r^ = CircleRender{
		center = ball_t.position,
		radius = cfg.BallRadius,
		color = cfg.BallColor,
	}
	ball_n := new(ecs.Tag)
	ball_n^ = "Ball"
	ecs.spawn_with(store, []any {
		ball_n^,
		ball_t^,
		ball_r^
	})
}


