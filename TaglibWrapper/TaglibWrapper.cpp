#include <taglib/fileref.h>
#include <taglib/tag.h>
#include <taglib/tpropertymap.h>
#include <taglib/flacfile.h>
#include <taglib/flacpicture.h>
#include <taglib/tstring.h>
#include <taglib/tbytevector.h>

// This is a wrapper file to ensure all TagLib symbols are linked
// We'll simply reference the symbols without taking their addresses

extern "C" {
    void forceTagLibSymbolLinking() {
        // Simply create a few safe objects to force the linker to include them
        TagLib::String str("test", TagLib::String::UTF8);
        TagLib::ByteVector vec;
        
        // Actually call some safe methods
        str.toInt();
        str.to8Bit(true);
        vec.data();
        vec.size();
    }
}

// Additional symbols that need to be preserved - we don't need to reference
// them directly, the force_load linker flag will handle them
