# OpenSMCE
**Open-source Sphere Matcher Community Engine** - an engine that is made to run various Sphere Matching games.

This is a **LÖVE2D** project. The supported version of the engine is **11.3**.

## Current Status
This project is currently work-in-progress. While heavily rebuilt and having big changes each version, the releases should be stable and no bugs are to be expected.
If otherwise, [feel free to submit a bug report](https://github.com/jakubg1/OpenSMCE/issues).

### Plans
The ongoing plan is to keep releasing Beta 4.x versions, which will contain new functionalities.

Some of the features planned include:
- Sphere tags
- Sphere selectors
- Difficulty system
- Shooter types/presets
- Massively enhanced sound effects
  - Split sound effects into actual effect files and sound definitions (number of samples, stream/load etc.)
- Complete rewrite of UI system
- Progress autosave

Beta 5.0 is an upcoming version, which is planned once the full game documentation is finished. This includes both a reference manual and JSON schemas. For more information you can look at the following folders:
- Reference manual (generated automatically from a Python script, uses data contained in `data.txt`): `doc/game`
- JSON schemas: `schemas`

If you want to help me, don't hesitate to do so! If you have any questions or you need more information, make a ticket on the Issues page. Any support is greatly appreciated.

For more information, you can take a look at the [1.0 issue list](https://github.com/jakubg1/OpenSMCE/issues?q=is%3Aopen+is%3Aissue+milestone%3A%22Full+1.0+release%22).

### Further plans
After 1.0.0 is released, I'll focus on making new features and working on *Luxor: Amun Rising* support.

## Overview
This engine was made in order to help the Sphere Matcher community.
Sphere Matching game genre is niche and only a few good titles are released.
In order to make the gameplay less boring and more challenging, the community decided to start modding games, most notably the first version of *Luxor*, along with *Luxor: Amun Rising*.

However, the original engine, while it allows for some flexibility, is filled with bugs and hardcoded parts which can't be changed without decompiling the original executable, a time-consuming and arguably illegal process.
There were also no attempts to rewrite and improve the original engine, in order for modders to have more control of what they can do.
This is why *OpenSMCE* was created - a project that is attempting to rewrite the Luxor game (not reverse engineer!) along with making it much more flexible and open-source.

## Launching
If you have LÖVE2D installed, you can run the game by launching `start.bat`.
Note that you may need to change the LÖVE executable path in that file first.

## Games
The engine runs games and thus you need to have some installed.
You can install games by putting them in the `games` directory where the executable/batch script sits.

There are no games publicly available right now, however three games are known to be converted.
We will provide tools to convert and create games at some point.
In the future, we are considering bundling all releases with a builtin game - to save you the hassle! More info soon.

The game converter has its own separate repository: https://github.com/jakubg1/OpenSMCE_Converter.
It currently supports only Luxor 1. If you want to help with other versions/games, feel free to open a ticket on its issue list, or contribute!

## What do I need?
- For running the engine and playing the games:
  - just the executable, the files, the game and you're ready to go

- For modifying the games:
  - same as above, plus some editors like you're modding Luxor, JSON knowledge (just a bit)

- For modifying the engine:
  - same as above, a text editor (preferably *Visual Studio Code*), Lua knowledge, JSON knowledge, LÖVE 11.3 installed. You can also take a look at contribution guidelines.

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
Both code and game documentation are currently work in progress.

Code documentation is done by LDoc annotations in source files which are parsed and displayed in Visual Studio Code. See contribution guidelines for more info.

Game documentation is done in the form of schemas - there are only a few structures documented, but this will be built upon in the future.



This repository contains code from following sources:
  - Class implementation from https://github.com/bncastle/love2d-tutorial/blob/Episode4/class.lua (MIT license)
  - JSON decoder/encoder implementation from https://github.com/rxi/json.lua (MIT license)
  - Discord Rich Presence DLL from https://github.com/discord/discord-rpc (MIT license)
  - Lua wrapper for Discord Rich Presence from https://github.com/pfirsich/lua-discordRPC (MIT license)
  - Unifont font from https://unifoundry.com/unifont/ (GNU GPLv2 license: https://unifoundry.com/LICENSE.txt)
