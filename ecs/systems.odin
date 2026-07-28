package main

import "vendor:raylib"

Vec2 :: [2]f32
Transform :: struct {
	position: Vec2,
	velocity: Vec2
}

RectangleRender :: struct {
	top_left: Vec2,
	dimensions: Vec2,
	color: raylib.Color,
}


rectangle_renderer :: proc(cps: ^RectangleRender) {
	raylib.DrawRectangle(i32(cps.top_left.x), i32(cps.top_left.y), i32(cps.dimensions.x), i32(cps.dimensions.y), cps.color)
}

CircleRender :: struct {
	center: Vec2,
	radius: f32,
	color: raylib.Color,
}

circle_renderer :: proc(cps: ^CircleRender) {
	raylib.DrawCircle(i32(cps.center.x), i32(cps.center.y), cps.radius, cps.color)
}
