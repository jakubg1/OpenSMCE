# OpenSMCE
**Open-source Sphere Matcher Community Engine** - an engine that is made to run various Sphere Matching games.

This is a **LÖVE2D** project. The supported version of the engine is **11.5**.

## Current Status
This project is currently work-in-progress. While heavily rebuilt and having big changes each version, the releases should be stable and no bugs are to be expected.
If otherwise, [feel free to submit a bug report](https://github.com/jakubg1/OpenSMCE/issues).

### Plans
The ongoing plan is to keep releasing Beta 4.x versions, which will contain new functionalities.

Some of the features planned for Beta 4.9.0 include:
- Life system config (https://github.com/jakubg1/OpenSMCE/issues/105)
- ...?

Beta 5.0 is an upcoming version, which is planned once the full game documentation is finished (https://github.com/jakubg1/OpenSMCE/issues/70, https://github.com/jakubg1/OpenSMCE/issues/112). This includes both a reference manual and JSON schemas.

For more information on how the documentation works, you can look at the [article on how the generation pipeline works and the syntax of .docl files.](https://github.com/jakubg1/OpenSMCE/wiki/The-Doc-Language)

From Beta 5.0 onwards, all games are intended to be backwards compatible. Then, further Beta 5.x versions will be released, which would ideally include:
- Complete rewrite of UI system (https://github.com/jakubg1/OpenSMCE/issues/63; paused)
- Partial *Luxor 2* support (mainly focusing on bringing the converter to parity)
- Some quality-of-life changes for modders (https://github.com/jakubg1/OpenSMCE/issues/66, https://github.com/jakubg1/OpenSMCE/issues/74, https://github.com/jakubg1/OpenSMCE/issues/84, https://github.com/jakubg1/OpenSMCE/issues/90, https://github.com/jakubg1/OpenSMCE/issues/98, https://github.com/jakubg1/OpenSMCE/issues/101, https://github.com/jakubg1/OpenSMCE/issues/114, https://github.com/jakubg1/OpenSMCE/issues/117, https://github.com/jakubg1/OpenSMCE/issues/123)

If you want to help me, don't hesitate to do so! If you have any questions or you need more information, make a ticket on the Issues page. Any support is greatly appreciated.

For more information, you can take a look at the [Beta 5.0 issue list](https://github.com/jakubg1/OpenSMCE/issues?q=is%3Aopen+is%3Aissue+milestone%3A%22Beta+5.0.0+release%22) and the [1.0 issue list](https://github.com/jakubg1/OpenSMCE/issues?q=is%3Aopen+is%3Aissue+milestone%3A%22Full+1.0+release%22).

### Further plans
After 1.0.0 is released, I'll focus on making new features and working on *Luxor 2* support.

## Launching
If you have LÖVE2D installed, you can run the game by launching `start.bat`.
Note that you may need to change the LÖVE executable path in that file first.

## Games
Currently, the only games that are supported by this engine are:
- *Luxor*
- *Luxor: Amun Rising*

This does **NOT** include mods for these games and other Luxor installments. These are unsupported right now.

In order to play Luxor or Luxor Amun Rising on this engine, you need to have an original copy of the game.
Then, you need to convert this game using the [game converter](https://github.com/jakubg1/OpenSMCE_Converter).

Sounds complicated? Don't worry!
Just proceed with the steps inside of the **README.txt** file contained in the release package for more information.

You can have multiple games at once - each game is its own directory in the `games` folder.

<!--The engine runs games and thus you need to have some installed.
You can install games by putting them in the `games` directory where the executable/batch script sits.

There are no games publicly available right now, however three games are known to be converted.
We will provide tools to convert and create games at some point.
In the future, we are considering bundling all releases with a builtin game - to save you the hassle! More info soon.-->

## What do I need?
- For running the engine and playing the games:
  - just the executable, the files, the game and you're ready to go

- For modifying the games, additionally:
  - a text editor (preferably *Visual Studio Code* for schema/autofill support), some JSON knowledge

- For modifying the engine, additionally:
  - Lua knowledge, LÖVE2D 11.5 installed.
  - You can also take a look at [contribution guidelines](https://github.com/jakubg1/OpenSMCE/blob/master/CONTRIBUTING.md).

### Building instructions
I am using a batch script for creating the OpenSMCE.exe file. This will work under a few assumptions:
- You're using a Windows operating system.
- You have 7-Zip installed on your computer and added to your PATH.
- You have LÖVE2D installed and it is installed in `C:\Program Files\LOVE\love.exe`.
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
Code documentation is done by LDoc annotations in source files which are parsed and displayed in Visual Studio Code. Not all classes have been documented yet. See [contribution guidelines](https://github.com/jakubg1/OpenSMCE/blob/master/CONTRIBUTING.md) for more info.

Game documentation can be found in `doc/game`.
Note that you must generate it yourself - run the `generate.py` script in that folder using Python 3.

For more information on how the documentation generator works, you can look into [this article](https://github.com/jakubg1/OpenSMCE/wiki/The-Doc-Language).

## Credits
This repository contains code and other assets from the following sources:
  - Class implementation from https://github.com/bncastle/love2d-tutorial/blob/Episode4/class.lua (MIT license)
  - JSON decoder/encoder implementation from https://github.com/rxi/json.lua (MIT license)
  - Discord Rich Presence DLL from https://github.com/discord/discord-rpc (MIT license)
  - Lua wrapper for Discord Rich Presence from https://github.com/pfirsich/lua-discordRPC (MIT license)
  - JProf Profiler from https://github.com/pfirsich/jprof (MIT license)
  - Unifont font from https://unifoundry.com/unifont/ (GNU GPLv2 license: https://unifoundry.com/LICENSE.txt)
  - DejaVu Sans font from https://dejavu-fonts.github.io/ (custom license: https://dejavu-fonts.github.io/License.html)
