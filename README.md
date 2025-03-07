# contour
A framework for creating "content pipelines" in LÖVE projects. This allows offline processing of certain asset files to a transformed file, and makes runtime code that attempts to load the original asset file to load the transformed file instead.

Please report any issues on Issues, or anywhere else like on Discord if you'd rather do that.

# Usage
Clone this repository into the root directory of your LÖVE project. To run the tool, run `love contour` in a terminal. It has to be from the root directory in order for it to work properly!

It is pre-packaged with a processor that converts all .tmx files within the "assets" directory to Lua files using the Tiled CLI. In order to configure contour and create processors, read the Configuration section below.

## Configuration
There are three files/directories of note:
1. **conconf.lua**: This is where you configure contour.
2. **export/**: This is where exported/processed files are recommended to be placed.
3. **processors/**: This is where you will create your asset processor scripts.

### Contour configuration
conconf.lua returns a table with a simple format:
```lua
{
    assetDirectories: string[],
    exportDirectory: string,
    processors: {[string] = globs[]}
}
```
The `assetDirectories` table is a list of all directories that contour will recursively search through when invoked. In the pre-packaged conconf.lua, it is set to read from the directory named "assets".

The `exportDirectory` value is the path to the export directory. It must be within the LÖVE game directory. It is preset to contour/export.

The `processors` table is a key-value table:
- The keys are the module names of each processor in the `processors` namespace. So, for example, if a key is `tmx`, contour will require `processors.tmx`, which maps to the file `contour/processors/tmx.lua`.
- The values are a list of globs. The glob `*.tmx` will match all files with the .tmx extension within the given asset directories. The glob `data/*` will recursively match all files and directories within the data directory.

### Creating processors
Each processor is a Lua module located under the `processors` namespace. Each module must return a function with the following signature:
```
fun(inPath: string, exportDir: string, fileUid: string): string?
```
1. **inPath:** The path to the source file.
2. **exportDir:** The path to the export directory,
3. **fileUid:** A UID used to uniquely identify the source file

The function must then return either nil or the path to the output file that the processor created.

The `fileUid` argument is useful for when you have more than one source asset with the same name, but in potentially different directories, and you don't want to have to mirror the directory structure under the export directory -- in this situation, you can prepend the UID to the output file name.

There are also a few available modules: util, path, and [nativefs](https://github.com/EngineerSmith/nativefs).

### Runtime usage
During runtime, the contour module should be available using `require("contour")`. It provides three functions:

- `isMapped(path: string): bool`: Check if a source file is mapped--that is, processed by contour with a output file associated with it.
- `getPath(path: string): void`: If the given source file is mapped, returns the preprocessed file. Otherwise, it returns the given path.
- `exportApi(): void` Hooks love functions to pass paths through contour.