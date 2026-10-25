# sm-asset-loader
Automatically precaches and downloads assets via json config

Only supports precaching of mdl, vmt, wav, and mp3 because I've never needed to precache anything else

Use the ConVar `sm_assetloader_log <0/1>` to log all assets to `logs/assetloader.log`

## Dependencies
- SourceMod 1.12+
- [ripext](https://github.com/srcdslab/sm-ext-ripext) (srcdslab's fork)
  - If you're on the Extension API v9, use [this](https://github.com/Bradasparky/sm-ext-ripext) fork instead.

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