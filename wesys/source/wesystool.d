import std.stdio;
import std.bitmanip;
import std.path;
import std.file;
import std.conv;

import std.getopt;
import peslib.wesys;


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
            auto srcfile = File(fpath);
            File dstfile;
            void[] uncompressed_data;
            try {
                uncompressed_data = uncompressWESYSfile(srcfile);
                srcfile.close();
            } catch(WESYSException we) {
                stderr.writeln("Skipping, not a WESYS file.");
                continue;
            }
            
            
            if (to_stdout) {
                dstfile = stdout;
            } else {
                string newname = buildPath(dirName(fpath), prefix ~ baseName(fpath));
                if (exists(newname)) {
                    if(!force_overwrite) {
                        stderr.writefln("File %s exists in filesystem, aborting. (use --force to overwrite)", newname);
                        return 1;
                    }
                }
                dstfile = File(newname, "w");
            }
            dstfile.rawWrite(uncompressed_data);
            dstfile.close();
        }
    } else if (cli_action == Action.compress) {
        if (prefix == "") {
            prefix = "wesys_";
        }
        foreach(string fpath; files) {
            stderr.writeln("Compressing ", fpath);
            auto srcfile = File(fpath);
            File dstfile;
            string newname = buildPath(dirName(fpath), prefix ~ baseName(fpath));
            if (to_stdout) {
                dstfile = stdout;
            } else {
                if (exists(newname)) {
                    if(!force_overwrite) {
                        stderr.writefln("File %s exists in filesystem, aborting. (use --force to overwrite)", newname);
                        return 1;
                    }
                }
                dstfile = File(newname, "w");
            }
            if (!exists(fpath)) {
                stderr.writefln("No such file or directory: %s", fpath);
                return 2;
            }
            dstfile.rawWrite(compressWESYSfile(srcfile, 9));
            srcfile.close();
            dstfile.close();
        }
    
    }
    return 0;
}