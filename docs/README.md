# 4AM Developer Documentation

## Dependencies

### [TagLib](https://taglib.org/)
fourAM uses TagLib to read metadata from FLAC files. A wrapper is used to make it easier to use in Swift.

For this to work, some build settings are required in Xcode (the paths are specific to my setup):

- Library Search Paths: /opt/homebrew/Cellar/taglib/1.13.1/lib/
- Header Search Paths: /opt/homebrew/include

You also need to link the binary in Build Phases -> Link Binary With Libraries. E.g. drag and drop libtag.1.19.1.dylib into the list. This binary is located in /opt/homebrew/Cellar/taglib/1.13.1/lib/.
