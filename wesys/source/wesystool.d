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
    string message;
    void[] function(File) action_func;
    
    if (prefix == "") {
        if(cli_action == Action.decompress) {
            prefix = "unwesys_";
            message = "Decompressing ";
            action_func = &uncompressWESYSfile;
        } else {
            prefix = "wesys_";
            message = "Compressing ";
            action_func = function(File f){ return(compressWESYSfile(f, 9));};
        }
    }
    foreach(string fpath; files) {
        stderr.writeln(message, fpath);
        auto srcfile = File(fpath);
        File dstfile;
        
        if (!exists(fpath)) {
            stderr.writefln("No such file or directory: %s", fpath);
            return 2;
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