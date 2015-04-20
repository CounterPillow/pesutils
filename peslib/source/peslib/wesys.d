module peslib.wesys;
import std.exception;
import std.bitmanip;
import std.zlib;
import std.stdio;
import std.array;

class WESYSException : Exception {
    ubyte[8] magic;
    this(string message) {
        super(message);
    }
    this(ubyte[8] m, string message) {
        this.magic = m;
        super(message);
    }
}
struct WESYS_header {
    static ubyte[8] DEFAULTMAGIC = cast(ubyte[8])"\x00\x10\x01WESYS";
    ubyte[8] magic;
    uint compressed_size;
    uint uncompressed_size;
    
    this(ubyte[16] header) {
        this.magic = header[0..8];
        enforce(this.magic == DEFAULTMAGIC,
                new WESYSException(this.magic, "Not a WESYS file"));
        
        this.compressed_size = littleEndianToNative!(uint, 4)(header[8..12]);
        this.uncompressed_size = littleEndianToNative!(uint, 4)(header[12..16]);
    }
    
}

void[] compressWESYS(in void[] buf, int level)
in {
    assert(level > 0);
    assert(level <= 9);
    assert(buf.length <= uint.max);
}
body {
    /*
    The reason for this silly casting is that isImplicitlyConvertible(void, anything)
    is always false, thus canPutItem is not given and thus the template won't compile.
    */
    auto app = appender!(ubyte[])();
    auto outbuf = cast(ubyte[])compress(buf, level);
    app.put(cast(ubyte[])WESYS_header.DEFAULTMAGIC);
    app.put(cast(ubyte[])nativeToLittleEndian(cast(uint)outbuf.length));
    app.put(cast(ubyte[])nativeToLittleEndian(cast(uint)buf.length));
    app.put(outbuf);
    return(cast(void[])app.data);
}


void[] uncompressWESYS(void[] buf, size_t destlen = 0u) {
    return(uncompress(buf, destlen));
}

void[] uncompressWESYSfile(File f) {
    ubyte[16] header;
    ubyte[] ret = f.rawRead(header);
    // If the file is shorter than 16 bytes, we know it's not valid.
    enforce(ret.length == 16, new WESYSException("Not a WESYS file"));
    
    WESYS_header wh = WESYS_header(header);
    void[] compressed_data = new void[wh.compressed_size];
    f.rawRead(compressed_data);
    return(uncompressWESYS(compressed_data, wh.uncompressed_size));
}

void[] compressWESYSfile(File srcfile, int level) {
    void[] src_data = new void[srcfile.size()];
    srcfile.rawRead(src_data);
    return(compressWESYS(src_data, level));
}