# Poding

All variants are under it's respective directory inside `./src`.

## Tasks

### game

Compiles the game (in debug mode).

```bash
cd ./src/game && odin build -debug -out:game.bin . && ./game.bin &> out
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
