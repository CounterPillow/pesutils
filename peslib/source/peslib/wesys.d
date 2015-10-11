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
    static ubyte[8] LEMAGIC = cast(ubyte[8])"\x00\x10\x01WESYS";
    static ubyte[8] BEMAGIC = cast(ubyte[8])"\x00\x01\x01WESYS";
    ubyte[8] magic;
    uint compressed_size;
    uint uncompressed_size;
    
    @property {
        Endianness endianness() {
            if (this.magic[1] == '\x10') {
                return Endianness.WESYS_LE;
            } else {
                return Endianness.WESYS_BE;
            }
        }
    }

    this(ubyte[16] header) {
        this.magic = header[0..8];
        if (this.magic == LEMAGIC) {
            this.compressed_size = littleEndianToNative!(uint, 4)(header[8..12]);
            this.uncompressed_size = littleEndianToNative!(uint, 4)(header[12..16]);
        } else if (this.magic == BEMAGIC) {
            this.compressed_size = bigEndianToNative!(uint, 4)(header[8..12]);
            this.uncompressed_size = bigEndianToNative!(uint, 4)(header[12..16]);
        } else {
            throw new WESYSException(this.magic, "Not a WESYS file");
        }
        
    }
    
}

enum Endianness {
    WESYS_LE,
    WESYS_BE
}

void[] compressWESYS(in void[] buf, int level,
                     Endianness e = Endianness.WESYS_LE)
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
    ubyte[4] function(uint x) conv_func;
    ubyte[] magic;
    if (e == Endianness.WESYS_LE) {
        conv_func = &(nativeToLittleEndian!uint);
        magic = cast(ubyte[])WESYS_header.LEMAGIC;
    } else if (e == Endianness.WESYS_BE) {
        conv_func = &(nativeToBigEndian!uint);
        magic = cast(ubyte[])WESYS_header.BEMAGIC;
    }
    app.put(magic);
    app.put(cast(ubyte[])conv_func(cast(uint)outbuf.length));
    app.put(cast(ubyte[])conv_func(cast(uint)buf.length));
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

unittest {
    auto ayy = uncompressWESYSfile(File("testdata/wesys_testfile"));
    assert(cast(string) ayy == "Hello World!\n");
}

void[] compressWESYSfile(File srcfile, int level,
                         Endianness e = Endianness.WESYS_LE)
{
    enforce(srcfile.size() <= uint.max, new WESYSException("File too large"));
    void[] src_data = new void[cast(uint)srcfile.size()];
    srcfile.rawRead(src_data);
    return(compressWESYS(src_data, level, e));
}
