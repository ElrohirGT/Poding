package main

import lua "vendor:lua/5.4"
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
