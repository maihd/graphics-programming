# Forge GPU in Odin
Ported examples to Odin from repo: https://github.com/Nebulavenus/forge-gpu

## Run examples
In root folder:
```bash
odin run forge-gpu-odin -- 01 # Any pattern match to example folder
```

In current folder:
```bash 
odin run . -- 01 # Any pattern match to example folder
```

## Organization and implementation
- Standalone
- Most code will repeatly implement, to make sure we will remember and understand the code
- Higher complex examples will use gfx to reduce coding time