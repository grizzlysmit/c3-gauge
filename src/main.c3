import std::io;
import libc;
import std::io::path;
import std::core::dstring @public;
import terminal::gauge;
import gnu;

int major  = 0;
int minor  = 1;
int subver = 0;


fn void usage(ZString arg0, int retcode){
    String? prog = path::temp(ZString.str_view(arg0)).basename();
    File* out = retcode ? io::stderr() : io::stdout();
    (void)io::fprintfn(out, "%s [options] [files...]\n",  prog);
    io::fprintfn(out, "Where options are:",  );
    io::fprintfn(out, "    -h|--help                                    // show this help and exit.",  );
    io::fprintfn(out, "    -v|--version                                 // show version info and exit.",  );
    io::fprintfn(out, "    -b|--batchsize=BATCHSIZE                     // set the batchsize to BATCHSIZE the value must be greater than 0 (default 1).",  );
    io::fprintfn(out, "    -c|--bar-char=BAR-CHAR                       // set bar-char to BAR-CHAR.",  );
    io::fprintfn(out, "    -e|--empty-char=EMPTY-CHAR                   // set empty-char to EMPTY-CHAR.",  );
    io::fprintfn(out, "    -C|--cmd=COMMAND                             // set the command to run to COMMAND.",  );
    io::fprintfn(out, "    -f|--prefix=PREFIX                           // set the prefix string.",  );
    io::fprintfn(out, "    -P|--prefix-foreground=PREFIX-FOREGROUND     // set the prefixes foreground colour.",  );
    io::fprintfn(out, "    -p|--prefix-background=PREFIX-BACKGROUND     // set the prefixes background colour.",  );
    io::fprintfn(out, "    -G|--gauge-foreground=GAUGE-FOREGROUND       // set the gauge's foreground colour.",  );
    io::fprintfn(out, "    -g|--gauge-background=GAUGE-BACKGROUND       // set the gauge's background colour.",  );
    io::fprintfn(out, "    -S|--suffix-foreground=SUFFIX-FOREGROUND     // set the foreground colour of the suffix.",  );
    io::fprintfn(out, "    -s|--suffix-background=SUFFIX-BACKGROUND     // set the background colour of the suffix.",  );
    libc::exit(retcode);
}

fn void version(ZString arg0, int retcode){
    File* out = retcode ? io::stderr() : io::stdout();
    $if (env::WIN32) : {
        // Code specific to Windows
        //@print("Running on Windows");
        $if env::ARCH_64_BIT : {
            io::fprintfn(out, "%s Version %d.%d.%d-%s-%s",  arg0, major, minor, subver, "windows", "x86_64");
        } $else {
            io::fprintfn(out, "%s Version %d.%d.%d-%s-%s",  arg0, major, minor, subver, "windows", "x86");
        }
        $endif
    } $else $if (env::LINUX) : {
        // Code specific to Linux
        //@fprintfn(out, "Running on Linux");
        $if env::ARCH_64_BIT : {
            io::fprintfn(out, "%s Version %d.%d.%d-%s-%s",  arg0, major, minor, subver, "linux", "x86_64");
        } $else {
            io::fprintfn(out, "%s Version %d.%d.%d-%s-%s",  arg0, major, minor, subver, "linux", "x86");
        }
        $endif
    } $else $if (env::MACOS) : {
        // Code specific to macOS
        //@print("Running on macOS");
        io::fprintfn(out, "%s Version %d.%d.%d-%s-%s",  arg0, major, minor, subver, "macos", "");
    } $else $if (env::ANDROID) : {
        // android code //
        //@print("Running on ANDROID");
        io::fprintfn(out, "%s Version %d.%d.%d-%s-%s",  arg0, major, minor, subver, "android", "");
    } $else {
        // Fallback for an unknown or other OS  //
        // @print("Running on an unknown OS");  //
        io::fprintfn(out, "%s Version %d.%d.%d-%s-%s",  arg0, major, minor, subver, "unkown", "");
    }
    $endif
    $endif
    $endif
    $endif
    libc::exit(retcode);
}

fn void call_progress_bar(CInt sig){
    gauge::init_term();
    gauge::progress_bar("");
}

fn void process_files(String cmd, ZString[] files) {
    io::printfn("processing batch of %d files", files.len);
    /*
    io::eprintf("files == [");
    foreach(file : files){
        io::eprintf("%s, ", file);
    }
    io::eprintfn("]");
    // */

    if(cmd.len > 0){
         DString d = dstring::new(mem, cmd);
         defer d.free();
        foreach(file : files){
            d.append(" ");
            d.append(file.str_view());
        }
        ZString command  = d.copy_zstr(mem);
        defer free(command);
        //io::eprintfn("command == `%s'", command);
        CInt r = libc::system(command);
        if(r != 0){
            io::eprintfn("call to command (%s) failed: %d", command, r);
            libc::exit(-r);
        }
    } else {
        foreach(file : files){
            io::printfn("-> %s", file.str_view());
        }
        //                                        999'999'999 //
        libc::TimeSpec timespec = { .s = 0, .ns = 500000000 };
        libc::nanosleep(&timespec, null);
    }
} // fn void process_files(String cmd, ZString[] files) //

fn int main(CInt argc, char** argv) {
    CInt    c;
    CInt    option_index = 0;
    bool    errflg       = false;
    String  cmd          = "";
    String  prefix       = "";
    CInt    batchsize    = 1;

    gauge::set_bar_char('⧫');
    gauge::set_empty_char(' ');
    gauge::set_prefix_foreground("bold,red", mem);
    gauge::set_prefix_background("green", mem);
    gauge::set_gauge_foreground("bold,red", mem);
    gauge::set_gauge_background("cyan", mem);
    gauge::set_suffix_foreground("bold,green", mem);
    gauge::set_suffix_background("blue", mem);
    
    // Define long options structure (must be null-terminated)
    Option[*] long_options = {
        { .name  = "help",              .has_arg  = 0, .flag  = null, .val  = 'h' },
        { .name  = "version",           .has_arg  = 0, .flag  = null, .val  = 'v' },
        { .name  = "batchsize",         .has_arg  = 1, .flag  = null, .val  = 'b' },
        { .name  = "bar-char",          .has_arg  = 1, .flag  = null, .val  = 'c' },
        { .name  = "empty-char",        .has_arg  = 1, .flag  = null, .val  = 'e' },
        { .name  = "cmd",               .has_arg  = 1, .flag  = null, .val  = 'C' },
        { .name  = "prefix",            .has_arg  = 1, .flag  = null, .val  = 'f' },
        { .name  = "prefix-foreground", .has_arg  = 1, .flag  = null, .val  = 'P' },
        { .name  = "prefix-background", .has_arg  = 1, .flag  = null, .val  = 'p' },
        { .name  = "gauge-foreground",  .has_arg  = 1, .flag  = null, .val  = 'G' },
        { .name  = "gauge-background",  .has_arg  = 1, .flag  = null, .val  = 'g' },
        { .name  = "suffix-foreground", .has_arg  = 1, .flag  = null, .val  = 'S' },
        { .name  = "suffix-background", .has_arg  = 1, .flag  = null, .val  = 's' },
        { .name  = null,                .has_arg  = 0, .flag  = null, .val  =  0  } // row of null or 0 values to mark the end //
    };

    char *endptr = null;

    //*
    while (true) {
        option_index = 0;
        c = gnu::getopt_long(argc, argv, ":vhb:c:e:C:f:P:p:G:g:S:s:", (Option*)&long_options, &option_index);

        if (c == -1) {
            break; // End of options
        }

        endptr = null;
        switch (c) {
            case 'h':
                usage((ZString)argv[0], 0);
            case 'v':
                version((ZString)argv[0], 0);
            case 'b':
                batchsize = (CInt)libc::strtol((ZString)gnu::optarg, &endptr, 0);
                if ((ZString)endptr != "") {
                    if(gnu::optopt != '\0'){
                        io::eprintfn("bad value for option '-%c' '%s' left over junk '%s'", gnu::optopt, (ZString)gnu::optarg, (ZString)endptr);
                    }else if((ZString)argv[gnu::optind - 1] == (ZString)gnu::optarg){
                        io::eprintfn("bad value for option '%s' '%s' left over junk '%s'", (ZString)argv[gnu::optind - 2], (ZString)gnu::optarg, (ZString)endptr);
                    }else{
                        io::eprintfn("bad value for option '%s' left over junk '%s'", (ZString)argv[gnu::optind - 1], (ZString)endptr);
                    }
                    libc::exit(-32);
                }
                if(batchsize <= 0){
                    if(gnu::optopt != '\0'){
                        io::eprintfn("bad value for option '-%c' '%s' BATCHSIZE must be > 0", gnu::optopt, (ZString)gnu::optarg);
                    }else if((ZString)argv[gnu::optind - 1] == (ZString)gnu::optarg){
                        io::eprintfn("bad value for option '%s' '%s' BATCHSIZE must be > 0", (ZString)argv[gnu::optind - 2], (ZString)gnu::optarg);
                    }else{
                        io::eprintfn("bad value for option '%s' BATCHSIZE must be > 0", (ZString)argv[gnu::optind - 1]);
                    }
                    libc::exit(-33);
                }
                break;
            case 'c':
                @pool()
                {
                    DString t = dstring::new(tmem, ((ZString)gnu::optarg).str_view());
                    Char32[] tmp = t.copy_utf32(tmem);
                    if(tmp.len != 1){
                        io::eprintfn("BAR-CHAR should be a single unicode char you supplied: '%s'", t);
                        libc::exit(-34);
                    }
                    gauge::bar_char = tmp[0];
                }; // t and tmp are freed here //
                break;
            case 'e':
                @pool()
                {
                    DString t = dstring::new(tmem, ((ZString)gnu::optarg).str_view());
                    Char32[] tmp = t.copy_utf32(tmem);
                    if(tmp.len != 1){
                        io::eprintfn("EMPTY-CHAR should be a single unicode char you supplied: '%s'", t);
                        libc::exit(-35);
                    }
                    gauge::empty_char = tmp[0];
                }; // t and tmp are freed here //
                break;
            case 'C':
                cmd = ((ZString)gnu::optarg).str_view();
                break;
            case 'f':
                prefix = ((ZString)gnu::optarg).str_view();
                break;
            case 'P':
                gauge::prefix_foreground = gauge::colour_from_string(((ZString)gnu::optarg).str_view(), mem);
                break;
            case 'p':
                gauge::prefix_background = gauge::colour_from_string(((ZString)gnu::optarg).str_view(), mem, true);
                break;
            case 'G':
                gauge::gauge_foreground = gauge::colour_from_string(((ZString)gnu::optarg).str_view(), mem);
                break;
            case 'g':
                gauge::gauge_background = gauge::colour_from_string(((ZString)gnu::optarg).str_view(), mem, true);
                break;
            case 'S':
                gauge::suffix_foreground = gauge::colour_from_string(((ZString)gnu::optarg).str_view(), mem);
                break;
            case 's':
                gauge::suffix_background = gauge::colour_from_string(((ZString)gnu::optarg).str_view(), mem, true);
                break;
            case ':':
                if(gnu::optopt != '\0'){
                    io::printfn("Option -%c requires an operand", gnu::optopt);
                }else{
                    io::printfn("Option %s requires an operand", (ZString)argv[gnu::optind - 1]);
                }
                errflg = true;
                break;
            case '?':
                // Handle unknown option or error
                if(gnu::optopt != '\0'){
                    io::printfn("Unrecognized option: '-%c'", gnu::optopt);
                }else{
                    io::printfn("Unrecognized option: '%s'", (ZString)argv[gnu::optind - 1]);
                }
                errflg = true;
                break;
            default:
                // not an option I guess //
                break;
        }
    }
    // */

    if(errflg){
        usage((ZString)argv[0], 2);
    }

    //*
    // Process remaining non-option arguments using optind
    //io::eprintfn("optind == %d\nargc == %d", gnu::optind, argc);
    if (gnu::optind < argc) {
        gauge::length = argc - gnu::optind;
        gauge::place  = 0;
        //io::eprintfn("gauge::length == %d\ngauge::place == %d", gauge::length, gauge::place);
        libc::signal(gauge::SIGWINCH, &call_progress_bar);
        gauge::init_term();
        gauge::progress_bar(prefix); // display the main progress bar //
        for(CInt i = gnu::optind; i < argc; i += batchsize, gnu::optind += batchsize) {
            gauge::progress_bar(prefix); // display the progress bar //
            if(gnu::optind + batchsize < gauge::length){
                process_files(cmd, (ZString[])argv[gnu::optind : batchsize]);
            } else {
                process_files(cmd, (ZString[])argv[gnu::optind .. argc - 1]);
            }
            gauge::place += batchsize;
        }
        gauge::progress_bar(prefix, gauge::length); // display the progress bar //
        //                                        999'999'999 //
        libc::TimeSpec timespec = { .s = 5, .ns = 500000000 };
        libc::nanosleep(&timespec, null);
        gauge::deinit_term(0);
    }
    // */
    return 0;
} // fn int main(CInt argc, char** argv) //
