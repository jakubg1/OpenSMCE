# OpenSMCE
**Open-source Sphere Matcher Community Engine** - an engine that is made to run various Sphere Matching games.

This is a project that runs on the [**LÖVE2D**](http://love2d.org/) framework and is currently designed to run on version **11.5**.

## Current Status
This project is currently work-in-progress. While heavily rebuilt and having big changes each version, the releases should be stable and no bugs are to be expected.
If otherwise, [feel free to submit a bug report](https://github.com/jakubg1/OpenSMCE/issues).

## Launching
If you have LÖVE2D installed, you can run the game by launching `start.bat` (or `love .` on Linux).
Note that you may need to change the LÖVE executable path in that file first.

## Games
There are currently no released games which can be installed on this engine.
However, that doesn't mean you can't play anything - you can convert the original *Luxor* and *Luxor: Amun Rising* games.

Mods for these games will be supported in an upcoming release.
Other Luxor installments such as Luxor 2 and beyond as well as other games like Zuma and Sparkle are currently unsupported.

You can have multiple games at once - each game is its own directory in the `games` folder.

### Game Conversion
In order to play Luxor or Luxor Amun Rising on this engine, you need to have an original copy of the game.
Then, you need to convert this game using the [game converter](https://github.com/jakubg1/OpenSMCE_Converter),
which is bundled in the `games/` directory if you've downloaded from the Releases page.

You will need:
- raw uncompressed Luxor 1 or Luxor Amun Rising's data (Luxor 2, Luxor 3, Luxor Evolved etc. WILL NOT WORK!),
- Python 3 installed on your computer.

The conversion is a one-time process, though it needs to be repeated for each OpenSMCE version, because of incompatibilities between versions.
Make sure you're running the correct converter for your OpenSMCE version.

#### Python Installation (Windows only)
1. Download the latest Python version from the [official Python page](https://www.python.org/downloads/windows/).
2. Open the installer and click "Install Now"
3. You don't need to add Python to PATH, but you can if you want to.
4. Wait until the installation finishes.

#### Pillow Installation
Pillow is a library that is used to process images from the original games.
On Linux, you might need to install `pip` first:
- Ubuntu/Debian: `sudo apt install python3-pip`
- Fedora: `sudo dnf install python3-pip`

To install Pillow, regardless of your OS, run this command in the command prompt:
`python -m pip install pillow`

#### Installation
1. Uncompress Luxor files using QuickBMS - both `data.mjz` and `English.mjz` files will be needed.
2. Copy the unpacked `data/` and `English/` folders, ALONG WITH `assets` folder to the `games` folder in your OpenSMCE main directory.
3. Run the `convert.bat` (Windows) / `convert.sh` (Linux) script and follow the instructions if necessary.

#### Running the game
If the conversion has been successful, go back to the main engine directory and launch OpenSMCE. The converted game should be visible on the boot screen.

If the conversion has been unsuccessful or the converted game crashed during startup, make sure to report an issue on the [converter repository](https://github.com/jakubg1/OpenSMCE_Converter/issues).

***Important Note:***

During OpenSMCE's development, the game converter is usually lagging behind the current state of the source code.
Because of this, running the code from source will most likely **not** work with the converter result.
Hopefully, the versions Beta 5.0.0 and onwards will no longer have this problem, but I can't promise anything yet!

<!--The engine runs games and thus you need to have some installed.
You can install games by putting them in the `games` directory where the executable/batch script sits.

There are no games publicly available right now, however three games are known to be converted.
We will provide tools to convert and create games at some point.
In the future, we are considering bundling all releases with a builtin game - to save you the hassle! More info soon.-->

<!--## What do I need?
- For running the engine and playing the games:
  - just the executable, the files, the game and you're ready to go

- For modifying the games, additionally:
  - a text editor (preferably *Visual Studio Code* for schema/autofill support), some JSON knowledge

- For modifying the engine, additionally:
  - Lua knowledge, LÖVE2D 11.5 installed.
  - You can also take a look at [contribution guidelines](https://github.com/jakubg1/OpenSMCE/blob/master/CONTRIBUTING.md).-->

## Building
You can build an OpenSMCE executable (or `.love` file) like [any other LÖVE2D game or program](https://love2d.org/wiki/Game_Distribution).
Note that strictly only `.lua` files need to be there. Any other file packaged into the executable will increase its size without any meaningful effect.

Alongside the executable, you also need the `assets/` directory with its contents (specifically, fonts) to make the engine work fully properly.
The engine can work without them though, there is fallback font support.

In the future, makelove support is planned and [there is an open issue about it](https://github.com/jakubg1/OpenSMCE/issues/146).

Releases on this page also include the [OpenSMCE game converter](https://github.com/jakubg1/OpenSMCE_Converter).

## Documentation
Code documentation is done by LDoc annotations in source files which are parsed and displayed in Visual Studio Code.
See [contribution guidelines](https://github.com/jakubg1/OpenSMCE/blob/master/CONTRIBUTING.md) for more information.

Game documentation can be found in `doc/game`, in the form of easily parseable `.docl` files.
Additionally, when editing the game files through Visual Studio Code, schemas provide linting and descriptions for all fields.
The JSON schemas are generated using the `doc/game/generate.py` script.

For more information on how the documentation generator works, you can look into [this article](https://github.com/jakubg1/OpenSMCE/wiki/The-Doc-Language).

## Plans
The ongoing plan is to keep releasing Beta 4.x versions, which will contain new functionalities.

Beta 5.0 is an upcoming version, which is planned once the full game documentation is finished (https://github.com/jakubg1/OpenSMCE/issues/70, https://github.com/jakubg1/OpenSMCE/issues/112). This includes both a reference manual and JSON schemas.

For more information on how the documentation works, you can look at the [article on how the generation pipeline works and the syntax of .docl files.](https://github.com/jakubg1/OpenSMCE/wiki/The-Doc-Language)

From Beta 5.0 onwards, all games are intended to be backwards compatible. Then, further Beta 5.x versions will be released, which would ideally include:
- Complete rewrite of UI system (https://github.com/jakubg1/OpenSMCE/issues/63; paused)
- Partial *Luxor 2* support (mainly focusing on bringing the converter to parity)
- Some quality-of-life changes for modders (https://github.com/jakubg1/OpenSMCE/issues/66, https://github.com/jakubg1/OpenSMCE/issues/74, https://github.com/jakubg1/OpenSMCE/issues/84, https://github.com/jakubg1/OpenSMCE/issues/90, https://github.com/jakubg1/OpenSMCE/issues/98, https://github.com/jakubg1/OpenSMCE/issues/101, https://github.com/jakubg1/OpenSMCE/issues/114, https://github.com/jakubg1/OpenSMCE/issues/117, https://github.com/jakubg1/OpenSMCE/issues/123)

If you want to help me, don't hesitate to do so! If you have any questions or you need more information, make a ticket on the Issues page. Any support is greatly appreciated.

For more information, you can take a look at the [Beta 5.0 issue list](https://github.com/jakubg1/OpenSMCE/issues?q=is%3Aopen+is%3Aissue+milestone%3A%22Beta+5.0.0+release%22) and the [1.0 issue list](https://github.com/jakubg1/OpenSMCE/issues?q=is%3Aopen+is%3Aissue+milestone%3A%22Full+1.0+release%22).

### Further plans
After the data management module is finished, the engine will be separated. The sphere matching gameplay will stay on this repository, while the rest will be extracted into another repository (the OpenSMCE Engine).
The OpenSMCE Engine will be able to handle any type of game and will handle resource management, UI and hopefully more.

The idea is to have an in-between solution between fantasy consoles (such as Picotron, PICO-8 and TIC-80) and professional game engines (Godot, Unity, UE).

## Credits
This repository contains code and other assets from the following sources:
  - Class implementation from https://github.com/bncastle/love2d-tutorial/blob/Episode4/class.lua (MIT license)
  - JSON decoder/encoder implementation from https://github.com/rxi/json.lua (MIT license)
  - Discord Rich Presence DLL from https://github.com/discord/discord-rpc (MIT license)
  - Lua wrapper for Discord Rich Presence from https://github.com/pfirsich/lua-discordRPC (MIT license)
  - JProf Profiler from https://github.com/pfirsich/jprof (MIT license)
  - Advanced Sound Library from https://github.com/zorggn/love-asl (ISC license)
  - Unifont font from https://unifoundry.com/unifont/ (GNU GPLv2 license: https://unifoundry.com/LICENSE.txt)
  - DejaVu Sans font from https://dejavu-fonts.github.io/ (custom license: https://dejavu-fonts.github.io/License.html)
