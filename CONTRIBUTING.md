This is a set of contribution guidelines that should be followed by contributors in order to create a well-readable and consistent code.

This is a WIP document, [you can submit an issue](https://github.com/jakubg1/OpenSMCE/issues/new/choose) if you want to help.



## Editing
The recommended editor to use is **Visual Studio Code**. It offers a set of plugins which can massively enhance development experience.

We recommend you to use the following plugins:
- Lua plugin from sumneko
- **List TBD**
- **TBD...**

## Source code format
- Overall file format: **TBD**
- Math operators should always have a single space on each side for readability.
  - Redundant brackets are okay.

### Tabs and spaces
- The recommended indentation is 4 spaces. Note that not all files support that yet.
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
