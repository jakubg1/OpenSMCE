# OpenSMCE
**Open-source Sphere Matcher Community Engine** - an engine that is made to run various Sphere Matching games.

This is a **LÖVE2D** project. The supported version of the engine is **11.5**.

## Current Status
This project is currently work-in-progress. While heavily rebuilt and having big changes each version, the releases should be stable and no bugs are to be expected.
If otherwise, [feel free to submit a bug report](https://github.com/jakubg1/OpenSMCE/issues).

### Plans
The ongoing plan is to keep releasing Beta 4.x versions, which will contain new functionalities.

Some of the features planned for Beta 4.8.0 include:
- Sphere selectors
- Difficulty system
- Enhanced sound effects
- Shooter types
- *Luxor: Amun Rising* support (https://github.com/jakubg1/OpenSMCE/issues/81)

Beta 5.0 is an upcoming version, which is planned once the full game documentation is finished (https://github.com/jakubg1/OpenSMCE/issues/70, https://github.com/jakubg1/OpenSMCE/issues/112). This includes both a reference manual and JSON schemas.

For more information on how the documentation works, you can look at the following folders:
- Reference manual (generated automatically from a Python script, uses data contained in `data.txt`): `doc/game`
- JSON schemas: `schemas`
- [An article on how the generation pipeline works and the syntax of .docl files.](https://github.com/jakubg1/OpenSMCE/wiki/The-Doc-Language)

From Beta 5.0 onwards, all games are intended to be backwards compatible. Then, further Beta 5.x versions will be released, which would ideally include:
- Complete rewrite of UI system (https://github.com/jakubg1/OpenSMCE/issues/63; paused)
- Partial *Luxor 2* support (mainly focusing on bringing the converter to parity)
- Some quality-of-life changes for modders (https://github.com/jakubg1/OpenSMCE/issues/66, https://github.com/jakubg1/OpenSMCE/issues/74, https://github.com/jakubg1/OpenSMCE/issues/84, https://github.com/jakubg1/OpenSMCE/issues/90, https://github.com/jakubg1/OpenSMCE/issues/98, https://github.com/jakubg1/OpenSMCE/issues/101, https://github.com/jakubg1/OpenSMCE/issues/114, https://github.com/jakubg1/OpenSMCE/issues/117, https://github.com/jakubg1/OpenSMCE/issues/123)

If you want to help me, don't hesitate to do so! If you have any questions or you need more information, make a ticket on the Issues page. Any support is greatly appreciated.

For more information, you can take a look at the [Beta 5.0 issue list](https://github.com/jakubg1/OpenSMCE/issues?q=is%3Aopen+is%3Aissue+milestone%3A%22Beta+5.0.0+release%22) and the [1.0 issue list](https://github.com/jakubg1/OpenSMCE/issues?q=is%3Aopen+is%3Aissue+milestone%3A%22Full+1.0+release%22).

### Further plans
After 1.0.0 is released, I'll focus on making new features and working on *Luxor 2* support.

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

## Documentation
Code documentation is done by LDoc annotations in source files which are parsed and displayed in Visual Studio Code. Not all classes have been documented yet. See contribution guidelines for more info.

Game documentation can be found in `doc/game`. Data for the documentation is stored in `doc/game/data.txt` in a pseudo-language called Doc Language, and all structures and descriptions are sourced from schemas, found in the `schemas` folder.
The `doc/game/generate.py` script reads the `doc/game/data.txt` file, loads appropriate schemas and converts them to the Doc Language. The intermediate state of this data is printed to the console. Then, the generator takes pure Doc Language data and converts it into HTML code. This code is stored as HTML pages in the `doc/game` directory.

You may notice there are already generated HTML files in this directory - they're outdated files. I don't know yet whether to move the game documentation to a separate repository or to just gitignore the files. Please do not use the outdated documentation, and generate a new set of files instead.
You must have Python 3.x installed on your system in order to run the documentation generator.



This repository contains code and other assets from the following sources:
  - Class implementation from https://github.com/bncastle/love2d-tutorial/blob/Episode4/class.lua (MIT license)
  - JSON decoder/encoder implementation from https://github.com/rxi/json.lua (MIT license)
  - Discord Rich Presence DLL from https://github.com/discord/discord-rpc (MIT license)
  - Lua wrapper for Discord Rich Presence from https://github.com/pfirsich/lua-discordRPC (MIT license)
  - Unifont font from https://unifoundry.com/unifont/ (GNU GPLv2 license: https://unifoundry.com/LICENSE.txt)
  - DejaVu Sans font from https://dejavu-fonts.github.io/ (custom license: https://dejavu-fonts.github.io/License.html)
