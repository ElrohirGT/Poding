package main

import "vendor:raylib"

Vec2 :: [2]f32
Transform :: struct {
	position: Vec2,
	velocity: Vec2
}

// movement :: proc(transforms: []^Transform, dt: f32) {
// 	for t in transforms {
// 		t.position += t.velocity * dt
// 	}
// }

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
	radius: f32,
	color: raylib.Color,
}

// circle_renderer :: proc(transform: ^Transform, render: ^CircleRender) {
circle_renderer :: proc(cps: []struct{ct1: ^CircleRender, ct2: ^Transform}) {
	for cp in cps {
		transform := cp.ct2
		render := cp.ct1
		raylib.DrawCircle(i32(transform.position.x), i32(transform.position.y), render.radius, render.color)
	}
}
