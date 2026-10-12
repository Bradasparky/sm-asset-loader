# sm-asset-loader
Automatically precaches and downloads assets via json config

Only supports precaching of mdl, vmt, wav, and mp3 because I've never needed to precache anything else

By default the plugin sets `#pragma dynamic 32768` to help with json object memory consumption

You may need to recompile with a higher value if you run out of memory

## Dependencies
- [ripext](https://github.com/srcdslab/sm-ext-ripext) (srcdslab's fork)
  - If you're on the Extension API v9, use [this](https://github.com/moonspub/sm-ext-ripext) fork instead.

## Example Config
```json
{
    "maps": {
        ".*": {
            "download": [
                "scripts/items/custom_items_game.txt"
            ]
        },
        "^ctf_(.*)$": {
            "precache": [
                "models/default_model.mdl",
                "sound/default_sound.(wav|mp3)"
            ],
            "download": [
                "models/custom_model.mdl",
                "materials/custom_material.(vmt|vtf)"
            ]
        }
    }
}
```