# Poding

All variants are under it's respective directory inside `./src`.

## Tasks

### clean

Cleans all artifacts.

```bash
find . -type f -iname "*.bin" -delete -print
find . -type f -iname "out" -delete -print
```

### run

Compiles the game (in production mode).

```bash
cd ./src/game/
# FILE=$(nix-build cfg.nix --no-out-link)
odin build -out:game.bin . && ./game.bin &> out
```

### game

Compiles the game (in debug mode).

```bash
cd ./src/game/
# FILE=$(nix-build cfg.nix --no-out-link)
odin build -debug -out:game.bin . && ./game.bin &> out
```

### normal

Compiles the unstructured example of Breakout (in debug mode), and runs it

```bash
cd ./src/normal && odin build -debug -out:game.bin . && ./game.bin &> out
```

### ecs

Compiles the ecs example of Breakout (in debug mode), and runs it

```bash
cd ./src/ecs && odin build -debug -out:game.bin . && ./game.bin &> out
```
