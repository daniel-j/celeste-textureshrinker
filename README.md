# Celeste Texture Atlas Shrinker

This tool shrinks the textures in the game Celeste. By default, the atlases are 4096x4096 which is too big for the Raspberry Pi 3 to handle. This tool extracts all textures from those atlases and uses Crunch to pack them into new, smaller textures (2048x2048). The textures within the atlases are not modified in any way. Not all textures in the game can be shrinked this way. The screens that appear at the end of each chapter uses big textures for the artwork, which this tool can't fix (yet).

## How to use

Install [nim](https://nim-lang.org/) from your package manager or with [choosenim](https://github.com/dom96/choosenim). Version 0.19.0 or higher is required. You also need to have g++ installed (to compile Crunch).

Compile the project by running `./build.sh`.

Move Gui*, Journal*, Gameplay* and Checkpoints* from Celeste's `Content/Graphics/Atlases/` directory in the `input/` directory.

`mv /path/to/Celeste/Content/Graphics/Atlases/{Gui,Journal,Checkpoints,Gameplay}* input/`

Now run `./celestetextureshrinker`

This takes some time. Converted textures appear in the `output/` directory. Move these back to the game directory.

`mv output/* /path/to/Celeste/Content/Graphics/Atlases/`

Enjoy some low spec gaming!

[Raspberry Pi 3 Celeste gameplay](https://youtu.be/iTBUNb6IKHo)

## License

MIT.
