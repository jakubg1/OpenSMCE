# OpenSMCE
**Open-source Sphere Matcher Community Engine** - an engine that is made to run various Sphere Matching games.

This is a **LÖVE2D** project. The supported version of the engine is **11.3**

## Current Status
This project is currently work-in-progress. Currently the most effort is spent to rework UI system, and soon Beta 4.0.0 will be released. This version will offer massive improvements compared to Beta 3.0.0, and will **not** be compatible with existing games.

### Plans
The first priority for now is to release the full 1.0.0 version.

These are the things planned to do before full 1.0.0 version is released:
- Split the game config file into respective files.
- ~~Split sound events and sprites into separate files for each.~~
- ~~Optimize sphere drawing routine.~~
- ~~Add remaining Luxor 1 functionality (profile selector).~~
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

**The game listing below and descriptions are for informing purpose only. We cannot guarantee that all info below is genuine or up to date.**

### Luxor
The original Luxor game is the main one supported - however, due to copyright issues, we can't provide it along with the engine releases.
However, if you do have the original game, there's a way to convert it.

Check the README file in the main release directory for instructions. Note that there may be some outdated information.
We will simplify the conversion process down the road, and we plan to make a video tutorial as well (once the full version is released).

### Mario's Voyage
This is the first Luxor mod to be successfully converted.
However, for now there are just private playtest versions and the game is not publicly available yet.

### Luxor 1 AR Mix
This is the first OpenSMCE game which was built specifically for this engine.
However, we cannot tell you a way to download it, because it contains copyrighted assets.

## What do I need?
- For running the engine and playing the games:
  - just the executable, the files, the game and you're ready to go

- For modifying the games:
  - same as above, plus some editors like you're modding Luxor, JSON knowledge (just a bit)

- For modifying the engine:
  - same as above, a text editor (preferably *Atom* or *Notepad++*), Lua knowledge, JSON knowledge, LOVE 11.3 installed and the code repository program to easily manage the code and update it

## Showcase
Here are some videos showcasing the recent progress on the engine:

[![Video 1](https://img.youtube.com/vi/vPKg8oilgqI/0.jpg)](https://www.youtube.com/watch?v=vPKg8oilgqI)
[![Video 2](https://img.youtube.com/vi/_bZRL3-Cn8c/0.jpg)](https://www.youtube.com/watch?v=_bZRL3-Cn8c)

## Documentation
The documentation will come at some point. Unfortunately, there is no documentation for now.

## Notes
This engine is on beta stage - currently, some modules are being overhauled and new features being added to fully support the Luxor game.

In current shape, it is intended to play the Luxor game along with its mods. Next steps will add support for Luxor Amun Rising, its huge variety of mods and Zuma respectively.

ETA of leaving beta stage (original Luxor game fully working and playable) is January 17, 2021.
Keep it mind that it might be delayed!

Stay tuned!



This repository contains code from following sources:
  - Class implementation from https://github.com/bncastle/love2d-tutorial/blob/Episode4/class.lua (MIT license)
  - JSON decoder/encoder implementation from https://github.com/rxi/json.lua (MIT license)
  - Discord Rich Presence DLL from https://github.com/discord/discord-rpc (MIT license)
  - Lua wrapper for Discord Rich Presence from https://github.com/pfirsich/lua-discordRPC (MIT license)
  - Unifont font from https://unifoundry.com/unifont/ (GNU GPLv2 license: https://unifoundry.com/LICENSE.txt)
