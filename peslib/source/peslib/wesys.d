module peslib.wesys;
import std.exception;
import std.bitmanip;
import std.zlib;
import std.stdio;
import std.array;
import std.algorithm.searching;

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
    // Note: The first byte may vary, so this is bytes [1..8] in the header.
    static const ubyte[7] LEMAGIC = cast(ubyte[7])"\x10\x01WESYS";
    static const ubyte[7] BEMAGIC = cast(ubyte[7])"\x01\x01WESYS";
    static const ubyte[7][Endianness.max + 1] MAGICS = [Endianness.WESYS_LE : LEMAGIC,
                                                 Endianness.WESYS_BE : BEMAGIC];
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
        if (endsWith(this.magic[], LEMAGIC[])) {
            this.compressed_size = littleEndianToNative!(uint, 4)(header[8..12]);
            this.uncompressed_size = littleEndianToNative!(uint, 4)(header[12..16]);
        } else if (endsWith(this.magic[], BEMAGIC[])) {
            this.compressed_size = bigEndianToNative!(uint, 4)(header[8..12]);
            this.uncompressed_size = bigEndianToNative!(uint, 4)(header[12..16]);
        } else {
            throw new WESYSException(this.magic, "Not a WESYS file");
        }
        if (this.magic[0] != 0) {
            stderr.writefln("WESYS Warning: "
                            "First byte is %#x instead of 0x00! "
                            "Please report this upstream with a sample file.",
                            this.magic[0]);
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


void[] uncompressWESYS(void[] buf) {
    enforce(buf.length >= 16, new WESYSException("Not a WESYS file"));
    WESYS_header h = WESYS_header(cast(ubyte[16])buf[0..16]);
    return(uncompress(buf[16..$], h.uncompressed_size));
}

void[] uncompressWESYSfile(File f) {
    enforce(f.size() >= 16, new WESYSException("Not a WESYS file"));
    auto h = new ubyte[16];
    h = f.rawRead(h);
    auto dec = new WESYSDecompressor(h[0..16]);
    auto app = appender!(ubyte[])();
    foreach (ubyte[] c; f.byChunk(4096)) {
        app.put(cast(ubyte[]) dec.uncompress(c));
    }
    return(cast(void[])app.data);
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

class WESYSCompressor : Compress {
    uint compressed_size;
    uint decompressed_size;

    this(int level) {
        super(level);
    }

    WESYS_header finalise_header(Endianness e = Endianness.WESYS_LE) {
        WESYS_header h;
        h.magic = [ubyte(0)] ~ WESYS_header.MAGICS[e];
        h.compressed_size = this.compressed_size;
        h.uncompressed_size = this.decompressed_size;
        return h;
    }

    override const(void)[] compress(const(void)[] buf) {
        const(void)[] b = super.compress(buf);
        this.compressed_size += b.length;
        this.decompressed_size += buf.length;
        return buf;
    }
}

class WESYSDecompressor : UnCompress {
    WESYS_header header;

    this(ubyte[16] start) {
        this.header = WESYS_header(start);
        super(this.header.uncompressed_size);
    }
}