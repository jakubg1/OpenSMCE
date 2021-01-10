# OpenSMCE
**Open-source Sphere Matcher Community Engine** - an engine that is made to run various Sphere Matching games.

This is a **LÖVE2D** project. The supported version of the engine is **11.3**

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

There are no games publicly available right now, however two games are known to be converted.
We will provide tools to convert and create games at some point.

### Luxor
The original Luxor game is the main one supported - however, due to copyright issues, we can't provide it along with the engine releases.
However, if you do have the original game, there's a way to convert it.

Check the README file in the main release directory for instructions. Note that there may be some outdated information.
We will simplify the conversion process down the road, and we plan to make a video tutorial as well (once the full version is released).

### Mario's Voyage
This is the first Luxor mod to be successfully converted.
However, for now there are just private playtest versions and the game is not publicly available yet.

## What do I need?
- For running the engine and playing the games:
  - just the executable, the files, the game and you're ready to go

- For modifying the games:
  - same as above, plus some editors like you're modding Luxor, JSON knowledge (just a bit)

- For modifying the engine:
  - same as above, a text editor (preferably Notepad++), Lua knowledge, JSON knowledge, LOVE 11.3 installed and the code repository program to easily manage the code and update it

## Documentation
The documentation will come at some point. Unfortunately, there is no documentation for now.

## Notes
This engine is on beta stage - currently, some modules are being overhauled and new features being added to fully support the Luxor game.

In current shape, it is intended to play the Luxor game along with its mods. Next steps will add support for Luxor Amun Rising, its huge variety of mods and Zuma respectively.

ETA of leaving beta stage (original Luxor game fully working and playable) is January 17, 2021.
Keep it mind that it might be delayed!

Stay tuned!



This repository contains code from following sources:
  - Class implementation from https://github.com/bncastle/love2d-tutorial/blob/Episode4/class.lua
  - JSON decoder/encoder implementation from https://github.com/rxi/json.lua
  - Discord Rich Presence DLL from https://github.com/discord/discord-rpc
  - Lua wrapper for Discord Rich Presence from https://github.com/pfirsich/lua-discordRPC
All of the above is licensed under MIT license.
