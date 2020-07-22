# OpenSMCE
Open-source Sphere Matcher Community Engine - an engine that is made to run very various SM games.

The code runs on LOVE2D 11.3 and is executed by starting start.bat file.

It will not work on itself though - a game is required.

The engine runs games located in `games` folder - a converter will be available to be able to convert content made for the original Luxor/Luxor AR engine.

There is no game chooser yet - you can change the game name in parenthesis in main.lua:17.

- For running the engine and playing the games:
  - just the executable, the files, the game and you're ready to go

- For modifying the games:
  - same as above, plus some editors like you're modding Luxor, JSON knowledge (just a bit)

- For modifying the engine:
  - same as above, a text editor (preferably Notepad++), Lua knowledge, JSON knowledge, LOVE 11.3 installed and the code repository program to easily manage the code and update it

```
You will need:
- raw uncompressed Luxor 1's data (must be 1; Amun Rising, 2 etc. won't work!),
- Python 3.8 installed on your computer, along with the PIL library.
The conversion is an one-time process, though it's likely that one would need to repeat it when a new version is installed.
It takes about 60 to 90 seconds, not counting the installation of the Python and PIL itself.



Python Installation:
1. Go to the official Python page and download the latest version.
2. Open the installer.
3. MAKE SURE YOU ENABLE "Add Python 3.8 to PATH" setting! It will be important!
4. Click "Install Now"
5. Wait until the installation finishes.

PIL library installation:
1. Open the command prompt.
2. Write "pip install pillow" and press Enter. Confirm everything with Y.

If everything was done properly, Python along with PIL should be installed correctly.



Installation:
1. Uncompress Luxor files using QuickBMS. Only "data.mjz" file will be needed.
2. Copy the folder to the "games" folder in your OpenSMCE main directory.
3. If you can, you can try launching the "main.py" file located in the "games" folder. It doesn't always work!

Workaround:
	1. Open the command prompt.
	2. Go to the "games" folder (cd <path>)
	3. Write "py main.py" and it should work.

If neither of these methods work, please hit me up on Discord (jakubg1#2036) or contact me via other kind of chat, if possible. We'll try to resolve the problem together!

If everything gone well, you should have the following two lines at the bottom of the console:
	Done!
	Everything is done!
If so, proceed on to the next step.

4. Copy the "music" and "sound" folders from the data folder to the newly created "output" folder.
5. Copy the "luxor_appendix" folder contents to the "output" folder.
6. You can delete the "luxor_appendix" and extracted data folders. Same goes with the script used in point 3. However, if you're a developer and want to improve the converter script, feel free to examine it!
7. Rename "output" folder to "Luxor" (the case is important).

After all these tedious steps, everything should work fine. If not, please hit me up and we'll try to resolve the problem!
```



This engine is on late alpha stage - there are some crucial features and fixes to be included before entering beta stage.

In current shape, it is intended to play Luxor game. Next steps will add support for Luxor Amun Rising, its huge variety of mods and Zuma respectively.

ETA of entering beta stage (original Luxor game fully working and playable): end of July 2020

Stay tuned!



This repository contains code from following sources:
  - Class implementation from https://github.com/bncastle/love2d-tutorial/blob/Episode4/class.lua (MIT license)
  - JSON decoder/encoder implementation from https://github.com/rxi/json.lua (MIT license)
