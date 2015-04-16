import std.stdio;
import std.zlib;
import std.bitmanip;
import std.stream;
import std.exception;
import std.path;
import std.file;
import std.conv;

import std.getopt;

struct WESYS_header {
    static ubyte[8] DEFAULTMAGIC = cast(ubyte[8])"\x00\x10\x01WESYS";
    ubyte[8] magic;
    uint compressed_size;
    uint uncompressed_size;
    
    this(InputStream input) {
        checkMagic(input);
        input.read(compressed_size);
        input.read(uncompressed_size);
    }
    
    void checkMagic(InputStream input) {
        input.read(magic);
        enforce(magic == DEFAULTMAGIC, new WESYSException(magic, "Not a WESYS file"));
    }
}

class WESYSException : Exception {
    ubyte[8] magic;
    this(ubyte[8] m, string message) {
        this.magic = m;
        super(message);
    }
}

enum Action { compress, decompress };

int main(string[] args) {
    string[] files;
    Action cli_action;
    string prefix;
    bool to_stdout;
    bool force_overwrite;
    GetoptResult helpInformation;
    
    try {
        helpInformation = getopt(
            args,
            std.getopt.config.required,
            "action|a", "Action to take", &cli_action,
            "prefix|p", "Prefix for output files", &prefix,
            "stdout|o", "Write to stdout", &to_stdout,
            "force|f", "Force overwrite files", &force_overwrite
        );
    } catch(Exception e) {
        helpInformation.helpWanted = true;
    }
    
    if (helpInformation.helpWanted) {
        defaultGetoptPrinter(args[0] ~ " --action [compress|decompress] [--prefix prefix] [--stdout] [--force] FILES...", helpInformation.options);
        return 1;
    }
    
    files = args[1..$];
    
    if (cli_action == Action.decompress) {
        if (prefix == "") {
            prefix = "unwesys_";
        }
        foreach(string fpath; files) {
            stderr.writeln("Decompressing ", fpath);
            auto f = new std.stream.File(fpath, FileMode.In);
            WESYS_header head;
            try {
                head = WESYS_header(f);
            } catch(WESYSException we) {
                stderr.writeln("Skipping, not a WESYS file.");
                continue;
            }
            
            ubyte[] compressed_data = new ubyte[head.compressed_size];
            f.read(compressed_data);
            void[] uncompressed_data = uncompress(compressed_data, head.uncompressed_size);
            
            if(to_stdout) {
                stdout.rawWrite(uncompressed_data);
            } else {
                string newname = buildPath(dirName(fpath), prefix ~ baseName(fpath));
                if (exists(newname)) {
                    if(!force_overwrite) {
                        stderr.writefln("File %s exists in filesystem, aborting. (use --force to overwrite)", newname);
                        return 1;
                    }
                }
                std.file.write(newname, uncompressed_data);
            }
            f.close();
        }
    } else if (cli_action == Action.compress) {
        if (prefix == "") {
            prefix = "wesys_";
            foreach(string fpath; files) {
                stderr.writeln("Compressing ", fpath);
                string newname = buildPath(dirName(fpath), prefix ~ baseName(fpath));
                if (exists(newname)) {
                    if(!force_overwrite) {
                        stderr.writefln("File %s exists in filesystem, aborting. (use --force to overwrite)", newname);
                        return 1;
                    }
                }
                if (!exists(fpath)) {
                    stderr.writefln("No such file or directory: %s", fpath);
                    return 2;
                }
                void[] uncompressed_data = read(fpath);
                const ubyte[] compressed_data = cast(const(ubyte[]))compress(uncompressed_data, 9);
                auto f = new std.stream.File(newname, FileMode.Out);
                f.write(WESYS_header.DEFAULTMAGIC);
                f.write(to!uint(compressed_data.length));
                f.write(to!uint(uncompressed_data.length));
                f.write(compressed_data);
                f.close();
            }
        }
    
    }
    return 0;
}