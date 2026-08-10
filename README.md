# Poding

All variants are under it's respective directory inside `./src`.

## Tasks

### normal

```bash
odin build -debug -out:normal.bin ./src/normal/ && ./normal.bin &> out
```

### ecs

Compiles the ecs example of Breakout (in debug mode), and runs it

```bash
odin build -debug -out:ecs.bin ./src/ecs/ && ./ecs.bin &> out
```
