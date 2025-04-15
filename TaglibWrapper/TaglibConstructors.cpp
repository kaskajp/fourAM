#include <taglib/fileref.h>
#include <taglib/tag.h>
#include <taglib/tpropertymap.h>
#include <taglib/flacfile.h>
#include <taglib/flacpicture.h>
#include <taglib/tstring.h>
#include <taglib/tbytevector.h>

// Force constructors and destructors to be linked
extern "C" {
    TagLib::ByteVector* taglib_bytevector_create() {
        return new TagLib::ByteVector();
    }
    
    void taglib_bytevector_destroy(TagLib::ByteVector* v) {
        delete v;
    }
    
    TagLib::String* taglib_string_create(const char* text) {
        return new TagLib::String(text, TagLib::String::UTF8);
    }
    
    void taglib_string_destroy(TagLib::String* s) {
        delete s;
    }
    
    TagLib::FileRef* taglib_fileref_create(const char* path) {
        return new TagLib::FileRef(path, true, TagLib::AudioProperties::Fast);
    }
    
    void taglib_fileref_destroy(TagLib::FileRef* f) {
        delete f;
    }
    
    TagLib::PropertyMap* taglib_propertymap_create() {
        return new TagLib::PropertyMap();
    }
    
    void taglib_propertymap_destroy(TagLib::PropertyMap* p) {
        delete p;
    }
}
