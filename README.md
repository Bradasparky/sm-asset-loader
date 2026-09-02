# sm-asset-loader
Automatically precaches and downloads assets via json config

Only supports precaching of mdl, vmt, wav, and mp3 because I've never needed to precache anything else

## Dependencies
- [sm-json](https://github.com/clugg/sm-json) by clugg

## Example Config
```json
{
    "precache": [
        "models/default_model.mdl",
        "sound/default_sound.wav",
        "sound/default_sound.mp3"
    ],
    "download": [
        "models/custom_model.mdl",
        "materials/custom_material.vmt",
        "materials/custom_material.vtf",
        "scripts/items/custom_items_game.txt"
    ]
}
```
