#include <taglib/fileref.h>
#include <taglib/tag.h>
#include <taglib/tpropertymap.h>
#include <taglib/flacfile.h>
#include <taglib/flacpicture.h>
#include <taglib/tstring.h>
#include <taglib/tbytevector.h>

// Force external linkage of key TagLib symbols
extern "C" {
    const char* taglib_bytevector_data(TagLib::ByteVector* v) {
        return v->data();
    }
    
    TagLib::uint taglib_bytevector_size(TagLib::ByteVector* v) {
        return v->size();
    }
    
    int taglib_string_toint(TagLib::String* s) {
        return s->toInt();
    }
    
    void* taglib_string_to8bit(TagLib::String* s, bool unicode) {
        return (void*)s->to8Bit(unicode).c_str();
    }
    
    bool taglib_fileref_isnull(TagLib::FileRef* f) {
        return f->isNull();
    }
    
    TagLib::File* taglib_fileref_file(TagLib::FileRef* f) {
        return f->file();
    }
    
    TagLib::Tag* taglib_fileref_tag(TagLib::FileRef* f) {
        return f->tag();
    }
    
    void* taglib_file_properties(TagLib::File* f) {
        TagLib::PropertyMap props = f->properties();
        return &props;
    }
    
    bool taglib_propertymap_contains(TagLib::PropertyMap* p, const char* key) {
        TagLib::String s(key, TagLib::String::UTF8);
        return p->contains(s);
    }
    
    void* taglib_propertymap_operator(TagLib::PropertyMap* p, const char* key) {
        TagLib::String s(key, TagLib::String::UTF8);
        return &((*p)[s]);
    }
    
    void* taglib_stringlist_tostring(TagLib::StringList* l, const char* separator) {
        TagLib::String sep(separator, TagLib::String::UTF8);
        TagLib::String result = l->toString(sep);
        return (void*)result.toCString();
    }
    
    void* taglib_flacfile_picturelist(TagLib::FLAC::File* f) {
        auto list = f->pictureList();
        return &list;
    }
    
    void* taglib_flacpicture_data(TagLib::FLAC::Picture* p) {
        TagLib::ByteVector data = p->data();
        return (void*)data.data();
    }
}
