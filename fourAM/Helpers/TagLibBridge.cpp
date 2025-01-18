#include <taglib/fileref.h>
#include <taglib/tag.h>
#include <taglib/tpropertymap.h>
#include <string>
#include <taglib/flacfile.h>
#include <taglib/flacpicture.h>

extern "C" {
    struct Metadata {
        const char* title;
        const char* artist;
        const char* album;
        const char* albumArtist;
        const char* genre;
        int trackNumber;
        int discNumber;
        int releaseYear;
        unsigned char* artwork; // Artwork binary data
        size_t artworkSize;     // Size of the artwork
    };

    Metadata* getMetadata(const char* filePath) {
        TagLib::FileRef file(filePath);
        if (file.isNull() || !file.tag()) {
            std::cerr << "Failed to open file or no tags found: " << filePath << std::endl;
            return nullptr;
        }

        TagLib::Tag* tag = file.tag();
        Metadata* metadata = new Metadata();

        TagLib::PropertyMap properties = file.file()->properties();

        // Debug PropertyMap
        /* std::cout << "Debugging PropertyMap:" << std::endl;
        for (auto it = properties.begin(); it != properties.end(); ++it) {
            std::cout << "  Key: " << it->first.toCString(true) << " -> ";
            for (const auto& value : it->second) {
                std::cout << "\"" << value.toCString(true) << "\" ";
            }
            std::cout << std::endl;
        }*/

        // Extract title
        if (properties.contains("TITLE")) {
            metadata->title = strdup(properties["TITLE"].toString().to8Bit(true).c_str());
        } else {
            metadata->title = strdup(tag->title().to8Bit(true).c_str()); // Fallback to basic tag
        }

        // Extract artist
        if (properties.contains("ARTIST")) {
            metadata->artist = strdup(properties["ARTIST"].toString().to8Bit(true).c_str());
        } else {
            metadata->artist = strdup(tag->artist().to8Bit(true).c_str());
        }

        // Extract album
        if (properties.contains("ALBUM")) {
            metadata->album = strdup(properties["ALBUM"].toString().to8Bit(true).c_str());
        } else {
            metadata->album = strdup(tag->album().to8Bit(true).c_str());
        }

        // Extract album artist
        if (properties.contains("ALBUMARTIST")) {
            metadata->albumArtist = strdup(properties["ALBUMARTIST"].toString().to8Bit(true).c_str());
        } else if (properties.contains("ALBUM ARTIST")) {
            metadata->albumArtist = strdup(properties["ALBUM ARTIST"].toString().to8Bit(true).c_str());
        } else {
            metadata->albumArtist = nullptr;
        }

        // Extract genre
        if (properties.contains("GENRE")) {
            metadata->genre = strdup(properties["GENRE"].toString().to8Bit(true).c_str());
        } else {
            metadata->genre = strdup(tag->genre().to8Bit(true).c_str());
        }
        
        if (properties.contains("DATE")) {
            metadata->releaseYear = properties["DATE"].toString().toInt();
        } else {
            metadata->releaseYear = 0; // Default to 0 if not available
        }

        // Extract track number
        if (properties.contains("TRACKNUMBER")) {
            metadata->trackNumber = properties["TRACKNUMBER"].toString().toInt();
        } else {
            metadata->trackNumber = tag->track();
        }

        // Extract disc number
        if (properties.contains("DISCNUMBER")) {
            metadata->discNumber = properties["DISCNUMBER"].toString().toInt();
        } else {
            metadata->discNumber = 0;
        }

        // Debug output
        // std::cout << "Extracted Metadata:" << std::endl;
        // std::cout << "  Title: " << (metadata->title ? metadata->title : "N/A") << std::endl;
        // std::cout << "  Artist: " << (metadata->artist ? metadata->artist : "N/A") << std::endl;
        // std::cout << "  Album: " << (metadata->album ? metadata->album : "N/A") << std::endl;
        // std::cout << "  Album Artist: " << (metadata->albumArtist ? metadata->albumArtist : "N/A") << std::endl;
        // std::cout << "  Genre: " << (metadata->genre ? metadata->genre : "N/A") << std::endl;
        // std::cout << "  Track Number: " << metadata->trackNumber << std::endl;
        // std::cout << "  Disc Number: " << metadata->discNumber << std::endl;
        
        // Check if the file is a FLAC file and extract artwork
        if (TagLib::FLAC::File* flacFile = dynamic_cast<TagLib::FLAC::File*>(file.file())) {
            const TagLib::List<TagLib::FLAC::Picture*>& pictures = flacFile->pictureList();
            if (!pictures.isEmpty()) {
                TagLib::FLAC::Picture* picture = pictures.front();
                metadata->artworkSize = picture->data().size();
                metadata->artwork = new unsigned char[metadata->artworkSize];
                memcpy(metadata->artwork, picture->data().data(), metadata->artworkSize);

                // Debugging
                // std::cout << "Extracted FLAC artwork of size: " << metadata->artworkSize << " bytes" << std::endl;
            } else {
                metadata->artwork = nullptr;
                metadata->artworkSize = 0;
            }
        } else {
            metadata->artwork = nullptr;
            metadata->artworkSize = 0;
        }

        return metadata;
    }

    void freeMetadata(Metadata* metadata) {
        if (metadata->artwork) {
            delete[] metadata->artwork;
        }
        free((void*)metadata->title);
        free((void*)metadata->artist);
        free((void*)metadata->album);
        free((void*)metadata->albumArtist);
        free((void*)metadata->genre);
        delete metadata;
    }
}
