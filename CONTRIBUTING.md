This is a set of contribution guidelines that should be followed by contributors in order to create a well-readable and consistent code.

Due to IDE changes throughout the lifecycle of this project (Notepad++ -> Atom -> VS Code) and constant improvements of my coding style :'), these guidelines may not apply to already existing code.
However, it is strongly recommended that all new code is following the rules below.
Over time, improvements over already existing code in order for it to support these standards as well are expected and everyone's welcome to take a step in that direction.

This is a WIP document, [you can submit an issue](https://github.com/jakubg1/OpenSMCE/issues/new/choose) if you want to help.



## Editing
The recommended IDE to use is **Visual Studio Code**. It offers a set of plugins which can massively enhance development experience.

We recommend you to use the following plugins:
- **Lua** plugin by **sumneko**
- **Love2D support** plugin by **Pixelbyte Studios**

Any other plugins are optional.

## Source code format
### Bare basics
- All variables, class names or other structures should be named in a camelCase, unless stated otherwise.
- All global variables should be defined in `main.lua` and their names should start with an underscore and the first character should be a capital letter.
  For example: `_MousePos`
- If you're using Visual Studio Code, try to keep the number of warnings in the *Problems* tab as low as possible.
  - Don't be too pathetic about it though, sometimes it's not easy to fix a warning due to bugs or unfinished/imperfect documentation. In such cases, it's best to just leave them as they are.
- As you're writing the code, try to keep the number of hardcoded variables down and make some parameters configurable to enhance the flexibility of the engine!
  - Adding a parameter to an existing file needs to perform the following steps:
    - Add the parameter to the schema, if it exists. If it's not, you can try to create one, it'll be helpful for other people!
    - Add the parameter to the file structure class. Remember to prepend a default value or logic to obtain one for backwards compatibility!
    - Finally, hook it up to your code.
  - Avoid making changes to the engine which modify existing behavior in a way that the old behavior cannot be reproduced. Unless the change is temporary.
    - If you want to make such one, open a ticket on the issue list first and talk about it with other developers!

### Overall file format
- This is the general structure of a class:
  ```lua
  -- we are going to use the com/class.lua file to access class-related methods and be able to create classes
  local class = require "com.class"
  
  -- derive the class and add some documentation parameters
  ---@class <name>
  ---@overload fun(<args>):<name>
  local <name> = class:derive("<name>")
  
  -- include any needed classes
  local <class1> = require("src.<class1>")
  local <class2> = require("src.<class2>")
  local <class3> = require("src.<class3>")
  ...
  
  -- three line gap
  
  -- constructor function
  ---Constructs an instance of <name>.
  ---@param <pname1> <ptype2> first argument
  ---@param <pname1> <ptype2> second argument
  function <name>:new(<args>)
    -- do something
  end
  
  -- another three line gap
  
  ---Another function belonging to this class.
  ---@param <pname> <ptype> first argument
  ---@return string
  function <name>:doSomething(<args>)
    -- do something else
    return "done"
  end
  
  -- another three line gap
  
  ---Yet another function.
  ---@ ...
  function ... end
  
  -- final three line gap
  
  -- return class info (used in require)
  return <name>
  ```

- You don't have to memorize this whole structure - just look around in the code and you'll get the hang of it!
  - When creating a new file, it's a good practice to use the provided `!class` and `!classn` snippets.
- All functions should be documented.

### Tabs, spaces and other whitespace
- The recommended indentation is 4 spaces. Note that not all files support that yet.
- There should be exactly three empty lines between each function.
  - An exception to this rule is a gap between two closely related functions with short bodies; in that case, one empty line is enough.
- Avoid creating scopes or putting multiple statements in the same line.
  For example, instead of writing code like this:
  ```lua
  for i, item in ipairs(items) do if item.nonexistent then return end end
  ```
  write it like this:
  ```lua
  for i, item in ipairs(items) do
      if item.nonexistent then
          return
      end
  end
  ```

- Math operators should always have a single space on each side for readability.
  - Redundant brackets are okay.
