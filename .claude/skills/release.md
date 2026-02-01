# Release to Steam Workshop

Deploy Prop Hunt: GNC Edition to Steam Workshop.

## Workshop Details
- **Workshop ID:** 3657566048
- **URL:** https://steamcommunity.com/sharedfiles/filedetails/?id=3657566048

## Instructions

Execute these steps in order:

1. **Sync gamemode files to workshop folder:**
   ```bash
   rsync -av --delete --exclude='*.git*' --exclude='.claude' --exclude='satisfactoryIcon.png' --exclude='addon.json' "/mnt/d/Games/Steam/steamapps/common/GarrysMod/garrysmod/gamemodes/prop_hunt/" "/mnt/d/Games/Steam/steamapps/common/GarrysMod/prop_hunt_gnc_workshop/gamemodes/prop_hunt/"
   ```

2. **Build the GMA:**
   ```bash
   powershell.exe -Command "cd 'D:\Games\Steam\steamapps\common\GarrysMod\bin'; .\gmad.exe create -folder 'D:\Games\Steam\steamapps\common\GarrysMod\prop_hunt_gnc_workshop' -out 'D:\Games\Steam\steamapps\common\GarrysMod\prop_hunt_gnc.gma'"
   ```

3. **Push to Workshop:**
   ```bash
   powershell.exe -Command "cd 'D:\Games\Steam\steamapps\common\GarrysMod\bin'; .\gmpublish.exe update -id 3657566048 -addon 'D:\Games\Steam\steamapps\common\GarrysMod\prop_hunt_gnc.gma'"
   ```

4. Report success with the Workshop URL.

## Notes
- Content files (sounds, materials, models, particles) are already in the workshop folder
- The workshop folder is at: `D:\Games\Steam\steamapps\common\GarrysMod\prop_hunt_gnc_workshop\`
- Files like `.claude/`, `addon.json`, and `satisfactoryIcon.png` are excluded (not allowed by GMA whitelist)
