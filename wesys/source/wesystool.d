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
    int compression_level = 9;
    GetoptResult helpInformation;
    
    try {
        helpInformation = getopt(
            args,
            std.getopt.config.required,
            "action|a", "Action to take", &cli_action,
            "prefix|p", "Prefix for output files", &prefix,
            "stdout|o", "Write to stdout", &to_stdout,
            "force|f", "Force overwrite files", &force_overwrite,
            "level|l", "Compression level, default 9", &compression_level,
            std.getopt.config.passThrough
        );
    } catch (GetOptException e) {
        stderr.writeln(e.msg);
        stderr.writeln("Use --help for help information.");
        return 1;
    }
    files = args[1..$];
    if (files.length == 0) {
        stderr.writeln("No files supplied.");
        helpInformation.helpWanted = true;
    }
    
    if (helpInformation.helpWanted) {
        defaultGetoptPrinter(args[0] ~ " --action [compress|decompress] [--prefix prefix] [--stdout] [--force] FILES...", helpInformation.options);
        return 1;
    }
    
    if (compression_level < 0 || compression_level > 9) {
        stderr.writefln("Invalid compression level '%s'. Must be between 0 and 9.", compression_level);
        return 1;
    }
    
    string message;
    void[] delegate(File) action_func;
    
    if(cli_action == Action.decompress) {
        if (prefix == "") {
            prefix = "unwesys_";
        }
        message = "Decompressing ";
        action_func = f => uncompressWESYSfile(f);
    } else {
        if (prefix == "") {
            prefix = "wesys_";
        }
        message = "Compressing ";
        action_func = f => compressWESYSfile(f, compression_level);
    }
    foreach(string fpath; files) {
        File srcfile;
        File dstfile;
        
        if (fpath == "-") {
            srcfile = stdin;
            fpath = "stdin";
        } else {
            if (!exists(fpath)) {
                stderr.writefln("No such file or directory: %s", fpath);
                return 2;
            }
            srcfile = File(fpath);
        }
        stderr.writeln(message, fpath);

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

        void[] dstdata;
        try {
            dstdata = action_func(srcfile);
            srcfile.close();
        } catch(WESYSException we) {
            if (cli_action == Action.compress) {
                stderr.writeln("Skipping, not a WESYS file.");
                continue;
            } else {
                throw(we);
            }
        }
        
        
        dstfile.rawWrite(dstdata);
        dstfile.close();
    }
    return 0;
}