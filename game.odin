package main

import "core:fmt"
import "vendor:raylib"

main :: proc() {
	fmt.println("Hello!")

	raylib.InitWindow(800, 400, "Main Window")
	defer raylib.CloseWindow()

	for !raylib.WindowShouldClose() {
		{
			raylib.BeginDrawing()
			defer raylib.EndDrawing()
		}
	}
}
