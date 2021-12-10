# OpenSMCE
**Open-source Sphere Matcher Community Engine** - an engine that is made to run various Sphere Matching games.

This is a **LÖVE2D** project. The supported version of the engine is **11.3**

## Current Status
This project is currently work-in-progress. Currently I'm slowly working on Beta 5.0.0, which will add some level format changes. It might **not** be compatible with existing games.

### Plans
The first priority for now is to release the full 1.0.0 version.

These are the things planned to do before full 1.0.0 version is released:
- Make progress autosave functionality, emergency save function.
- Fix bugs.

For more information, you can take a look [here](https://github.com/jakubg1/OpenSMCE/issues?q=is%3Aopen+is%3Aissue+milestone%3A%22Full+1.0+release%22).

### Further plans
After 1.0.0 is released, I'll focus on making new features and working on *Luxor: Amun Rising* support.

## Overview
This engine was made in order to help the Sphere Matcher community.
Sphere Matching game genre is niche and only a few good titles are released.
In order to make the gameplay less boring and more challenging, the community decided to start modding games, most notably the first version of *Luxor*, along with *Luxor: Amun Rising*.

However, the original engine, while it allows for some flexibility, is filled with bugs and hardcoded parts which can't be changed without decompiling the original executable, which is prohibited.
There were also no attempts to rewrite and improve the original engine, in order for modders to have more control of what they can do.
This is why *OpenSMCE* was created - a project that is attempting to rewrite the Luxor game (not reverse engineer!) along with making it much more flexible and open-source.

The engine is still in development - but you can help!

## Launching
If you have LÖVE2D installed, you can run the game by launching `start.bat`.
Note that you may need to change the LÖVE executable path.

## Games
The engine runs games and thus you need to have some installed.
You can install games by putting them in the `games` directory where the executable/batch script sits.

There are no games publicly available right now, however three games are known to be converted.
We will provide tools to convert and create games at some point.
In future, we are considering bundling all releases with a builtin game - to save you hassle! More info soon.

## What do I need?
- For running the engine and playing the games:
  - just the executable, the files, the game and you're ready to go

- For modifying the games:
  - same as above, plus some editors like you're modding Luxor, JSON knowledge (just a bit)

- For modifying the engine:
  - same as above, a text editor (preferably *Atom* or *Notepad++*), Lua knowledge, JSON knowledge, LOVE 11.3 installed and the code repository program to easily manage the code and update it

### Building instructions
I am using a batch script for creating the OpenSMCE.exe file. This will work under a few assumptions:
- You're using a Windows operating system.
- You have 7-Zip installed on your computer and added to your PATH.
- You have LOVE2D installed and it sits under `C:\Program Files\LOVE\love.exe`.
- The OpenSMCE source code folder is located in the folder named `OpenSMCE` relative to the folder the script is in.
- An `exlist.txt` file is located in the same folder the main batch script you're running is in, with the contents shown below.

If some of the requirements above are not met, you may need to modify the batch script according to your requirements.

Main batch file contents:
```
7z a compiled.zip .\OpenSMCE\* -x@exlist.txt
copy /b "C:\Program Files\LOVE\love.exe"+compiled.zip "OpenSMCE.exe"
del compiled.zip
pause
```

`exlist.txt` contents:
```
assets\
dll\
doc\
doc2\
engine\
games\
.git\
*.bat
*.md
*.ld
*.txt
LICENSE
.gitignore
```

## Showcase
Here are some videos showcasing the recent progress on the engine:

[![Video 1](https://img.youtube.com/vi/vPKg8oilgqI/0.jpg)](https://www.youtube.com/watch?v=vPKg8oilgqI)
[![Video 2](https://img.youtube.com/vi/_bZRL3-Cn8c/0.jpg)](https://www.youtube.com/watch?v=_bZRL3-Cn8c)

## Documentation
Unfortunately, there is no documentation for now.
However, it's currently being worked on - there will be game documentation first.

## Notes
This engine is on beta stage - currently, Luxor game is nearly fully supported and at some point in the future there will be first full releases.

In current shape, it is intended to play the Luxor game along with its mods. Next steps will add support for Luxor Amun Rising, its huge variety of mods and Zuma respectively.

ETA of leaving beta stage (original Luxor game fully working and playable) is around October of 2021.
Keep in mind that it might be delayed!

Stay tuned!



This repository contains code from following sources:
  - Class implementation from https://github.com/bncastle/love2d-tutorial/blob/Episode4/class.lua (MIT license)
  - JSON decoder/encoder implementation from https://github.com/rxi/json.lua (MIT license)
  - Discord Rich Presence DLL from https://github.com/discord/discord-rpc (MIT license)
  - Lua wrapper for Discord Rich Presence from https://github.com/pfirsich/lua-discordRPC (MIT license)
  - Unifont font from https://unifoundry.com/unifont/ (GNU GPLv2 license: https://unifoundry.com/LICENSE.txt)
