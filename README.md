# crashcodes.poi
Add-on for [Shroud of the Avatar](https://www.shroudoftheavatar.com/) to manage points of interest.

This add-on is very similar to [SotA-Lua-Waypoints](https://github.com/John-Markus/SotA-Lua-Waypoints) which I wish I would have found earlier!



## Installation

clone this repository

copy the lua directory from this repository to the Shroud of the Avatar Lua directory

### To find the the Shroud of the Avatar Lua directory
Within the game type `/datafolder` 
in Windows this will open a File Explorer to the datafold directory which should contain a Lua subfolder.

type `/lua reload` within Shroud of the Avatar

## Working with this Repository
- install [Shroud of the Avatar](https://www.shroudoftheavatar.com/) and create an account
- install [NodeJS](https://nodejs.org) (I'm using version 12.16.3)
- install [git](https://git-scm.com/)
- fork this repository
- git clone the forked repository to a local dev directory
- run `npm install` in the local dev directory
- update `destFolder` in gulpfile.js to match your Shroud of the Avatar Lua path
- run `npm run dev` this will keep the files your local dev directory
- run Shroud of the Avatar
- type `/lua reload` into Shroud of the Avatar after ever edit
- have fun


### Useful tools
- [Visual Studio Code](https://code.visualstudio.com/download)
- [vscode-lua](https://github.com/trixnz/vscode-lua) Visual Studio Code Extension
- [shroudmods.com](https://shroudmods.com/index.php?apireferences)
- [Shroud of the Avatar Forums](https://www.shroudoftheavatar.com/forum/index.php?forums/lua-discussions.2284/)
- [Discord lua-scripting-api](https://discord.com/channels/179618786972925952/643948781410451472)

