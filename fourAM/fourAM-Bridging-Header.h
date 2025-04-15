#ifndef TagLib_h
#define TagLib_h

#include <stddef.h> // For size_t
#include <stdbool.h> // For bool type
#include <stdlib.h> // For standard C types and functions

struct Metadata {
    const char* title;
    const char* artist;
    const char* album;
    const char* albumArtist;
    const char* genre;
    int trackNumber;
    int discNumber;
    int releaseYear;
    unsigned char* artwork;
    size_t artworkSize;
};

struct Metadata* getMetadata(const char* filePath);
void freeMetadata(struct Metadata* metadata);

// Force linking C++ symbols from TagLib
void forceTagLibSymbolLinking(void);

// Additional linking functions for TagLib's constructors/destructors and methods
void* taglib_bytevector_create(void);
void taglib_bytevector_destroy(void*);
const char* taglib_bytevector_data(void*);
size_t taglib_bytevector_size(void*);

void* taglib_string_create(const char*);
void taglib_string_destroy(void*);
int taglib_string_toint(void*);
void* taglib_string_to8bit(void*, bool);

void* taglib_fileref_create(const char*);
void taglib_fileref_destroy(void*);
bool taglib_fileref_isnull(void*);
void* taglib_fileref_file(void*);
void* taglib_fileref_tag(void*);

void* taglib_propertymap_create(void);
void taglib_propertymap_destroy(void*);
bool taglib_propertymap_contains(void*, const char*);
void* taglib_propertymap_operator(void*, const char*);

void* taglib_file_properties(void*);
void* taglib_flacfile_picturelist(void*);
void* taglib_flacpicture_data(void*);
void* taglib_stringlist_tostring(void*, const char*);

#endif /* TagLib_h */
