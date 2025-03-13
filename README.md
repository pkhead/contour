# contour
A framework for creating "content pipelines" in LÖVE projects. This allows offline processing of certain asset files to a transformed file, and makes runtime code that attempts to load the original asset file to load the transformed file instead.

Please report any issues on Issues, or anywhere else like on Discord or the forums if you'd rather do that.

# Installation
The contour tool must be installed, for which there are three methods of doing so:

### Clone into project
Contour can be cloned into your LÖVE project by either
```bash
git clone https://github.com/pkhead/contour
```
or
```bash
git submodule add https://github.com/contour
```
With this method, to run contour in a terminal, you must type `love contour` (or `lovec contour` on Windows).

### Add contour to PATH (Windows)
> [!IMPORTANT]
> This assumes you have LÖVE added to your PATH. If not, either add it to your path or modify `contour.cmd` to invoke the full path to lovec.

You may clone contour anywhere you'd like, and add its directory to your system or user PATH. You can install it to %LOCALAPPDATA%\Programs if you don't to deal with administrator permissions.

With this method, to run contour in a terminal, you simply type `contour`.

### Install into /usr/local (Linux/Mac)
> [!IMPORTANT]
> This requires you have LÖVE added to your PATH.

These series of commands will install contour into your /usr/local/ directory:
```sh
git clone https://github.com/pkhead/contour
sudo mv contour /usr/local/share/contour
sudo echo "love /usr/local/share/contour \$@" > /usr/local/bin/contour
sudo chmod +x /usr/local/bin/contour
```
Then, you may run contour from a terminal simply by typing `contour`.

# Usage
You can type `contour help` to print out a help screen.

To set up contour for a project, run `contour init`. It will set up required contour files with a configuration that converts all .tmx files within the "assets" directory to Lua files using the Tiled CLI. In order to configure contour and create processors, read the Configuration section below.

To build a project, you must be cd'd to the root directory of your LÖVE project. You may also pass in `-C <dir>` to make contour operate on the given directory. Then, typing `contour` alone will build the project.

## Configuration
There are three files/directories of note, located relative to your project directory after setup:
1. **contour/conconf.lua**: This is where you configure contour.
2. **contour/processors/**: This is where you will create your asset processor scripts.

### Config file
conconf.lua returns a table with a simple format:
```lua
{
    assetDirectories: string[],
    exportDirectory: string,
    processors: {[string] = globs[]}
}
```
The `assetDirectories` table is a list of all directories that contour will recursively search through when invoked. In the pre-packaged conconf.lua, it is set to read from the directory named "assets".

The `exportDirectory` value is the path to the export directory. It is preset to "exports".

The `processors` table is a key-value table:
- The keys are the module names of each processor in the `contour.processors` namespace within your project. So, for example, if a key is `tmx`, contour will require `contour.processors.tmx`, which maps to the file `contour/processors/tmx.lua`.
- The values are a list of globs. The string `*.tmx` will match all files with the .tmx extension within the given asset directories. The string `data/*` will recursively match all files and directories within the data directory.

### Creating processors
Each processor is a Lua module located under the `contour.processors` namespace. Each module must return a function with the following signature:
```
fun(inPath: string, exportDir: string, fileUid: string): string?
```
1. **inPath:** The path to the source file.
2. **exportDir:** The path to the export directory,
3. **fileUid:** A UID used to uniquely identify the source file

The function must then return either nil or the path to the output file that the processor created. Note that it will not automatically be relative to the export directory; it must already be prefixed with `exportDir` when returning. The processor must also create the file itself.

The `fileUid` argument is useful for when you have more than one source asset with the same name, but in potentially different directories, and you don't want to have to mirror the directory structure under the export directory -- in this situation, you can prepend the UID to the output file name.

There are also a few available modules: util, path, and [nativefs](https://github.com/EngineerSmith/nativefs).

### Runtime usage
During runtime, the contour module should be available using `require("contour")`. It provides three functions:

- `isMapped(path: string): bool`: Check if a source file is mapped--that is, processed by contour with a output file associated with it.
- `getPath(path: string): void`: If the given source file is mapped, returns the preprocessed file. Otherwise, it returns the given path.
- `exportApi(): void` Hooks love functions to pass paths through contour.