package main

gen_cfg :: proc() -> GameConfig {
	cfg := GameConfig{
    ScreenWidth = 1080,
    ScreenHeight = 720,
    FpsCap = 60,
		BackgroundColor = {74,88,89,255},
	}
	cfg.GameRectangle = {0, 0, cfg.ScreenWidth * 3 / 4, cfg.ScreenHeight}
	cfg.DebugRectangle = {cfg.ScreenWidth * 3 / 4, 0, cfg.ScreenWidth / 4, cfg.ScreenHeight}
	return cfg
}
