#ifndef TagLib_h
#define TagLib_h

#include <stddef.h> // For size_t

struct Metadata {
    const char* title;
    const char* artist;
    const char* album;
    const char* albumArtist;
    const char* genre;
    int trackNumber;
    int discNumber;
    unsigned char* artwork;
    size_t artworkSize;
};

struct Metadata* getMetadata(const char* filePath);
void freeMetadata(struct Metadata* metadata);

#endif /* TagLib_h */
