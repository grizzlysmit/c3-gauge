import std::io;
import libc;
import std::io::path;
import std::os::env;
import std::core::dstring @public;
import terminal::gauge;
import gnu;
import io::utils;
import string_utils::su;
import array_utils;

int major  = 0;
int minor  = 1;
int subver = 0;


fn void usage(ZString arg0, int retcode){
    @pool()
    {
        String? prog = path::temp(ZString.str_view(arg0)).basename();
        File* out = retcode ? io::stderr() : io::stdout();
        (void)io::fprintfn(out, "%s [options] [files...]\n",  prog);
        io::fprintfn(out, "Where options are:",  );
        io::fprintfn(out, "    -h|--help                                            // show this help and exit.",  );
        io::fprintfn(out, "    -v|--version                                         // show version info and exit.",  );
        io::fprintfn(out, "    -b|--batchsize=BATCHSIZE                             // set the batchsize to BATCHSIZE the value must be greater than 0 (default 1).",  );
        io::fprintfn(out, "    -b|--targeting-self                                  // Target this machine as well (run locally).",  );
        io::fprintfn(out, "    -c|--bar-char=BAR-CHAR                               // set bar-char to BAR-CHAR.",  );
        io::fprintfn(out, "    -e|--empty-char=EMPTY-CHAR                           // set empty-char to EMPTY-CHAR.",  );
        io::fprintfn(out, "    -C|--cmd=COMMAND                                     // set the command to run to COMMAND.",  );
        io::fprintfn(out, "    -f|--prefix=PREFIX                                   // set the prefix string.",  );
        io::fprintfn(out, "    -l|--pause=PAUSE                                     // set the amount to pause after each call to command in nanoseconds must be ≥ 0 (default 0).",  );
        io::fprintfn(out, "    -P|--prefix-foreground=PREFIX-FOREGROUND             // set the prefixes foreground colour.",  );
        io::fprintfn(out, "    -p|--prefix-background=PREFIX-BACKGROUND             // set the prefixes background colour.",  );
        io::fprintfn(out, "    -G|--gauge-foreground=GAUGE-FOREGROUND               // set the gauge's foreground colour.",  );
        io::fprintfn(out, "    -g|--gauge-background=GAUGE-BACKGROUND               // set the gauge's background colour.",  );
        io::fprintfn(out, "    -S|--suffix-foreground=SUFFIX-FOREGROUND             // set the foreground colour of the suffix.",  );
        io::fprintfn(out, "    -s|--suffix-background=SUFFIX-BACKGROUND             // set the background colour of the suffix.",  );
        io::fprintfn(out, "    -L|--outer_loop_vals=OUTER_LOOP_VALS                 // set the outer_loop_vals file.",  );
        io::fprintfn(out, "    -F|--sub-prefix=SUB-PREFIX                           // set the sub-prefix string.",  );
        io::fprintfn(out, "    -X|--sub-prefix-foreground=SUB-PREFIX-FOREGROUND     // set the sub-prefixes foreground colour.",  );
        io::fprintfn(out, "    -x|--sub-prefix-background=SUB-PREFIX-BACKGROUND     // set the sub-prefixes background colour.",  );
        io::fprintfn(out, "    -A|--sub-gauge-foreground=SUB-GAUGE-FOREGROUND       // set the sub-gauge's foreground colour.",  );
        io::fprintfn(out, "    -a|--sub-gauge-background=SUB-GAUGE-BACKGROUND       // set the sub-gauge's background colour.",  );
        io::fprintfn(out, "    -U|--sub-suffix-foreground=SUB-SUFFIX-FOREGROUND     // set the foreground colour of the sub-suffix.",  );
        io::fprintfn(out, "    -u|--sub-suffix-background=SUB-SUFFIX-BACKGROUND     // set the background colour of the sub-suffix.",  );
    }; // free prog //
    os::exit(retcode);
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
    os::exit(retcode);
}

String prefix = "";
String outer_loop_val_  = "";

fn void call_progress_bar(CInt sig){
    gauge::init_term(gauge::Bars.TWO);
    gauge::sub_progress_bar(outer_loop_val_); // display the progress bar //
    gauge::progress_bar(prefix);
}

fn void process_files(String user, String outer_loop_val, String thisouter_loop_val, String cmd, String[] files, int pause) {
    /*
    io::printfn("%s[%d] user == `%s'", $$FILE, $$LINE, user);
    io::printfn("%s[%d] outer_loop_val == `%s'", $$FILE, $$LINE, outer_loop_val);
    io::printfn("%s[%d] thisouter_loop_val == `%s'", $$FILE, $$LINE, thisouter_loop_val);
    io::printfn("%s[%d] cmd == `%s'", $$FILE, $$LINE, cmd);
    io::printfn("processing batch of %d files", files.len);
    files.print_diag("files");
    // */
    int nano_pause = pause % 1000000000;
    pause /= 1000000000; // integer division //
    //libc::fflush(libc::__stdout);
    gauge::printf("processing %d files.\n", files.len);
    //libc::fflush(libc::__stdout);

    if(cmd.len > 0){
        DString d = dstring::new(mem, cmd);
        defer d.free();
        //io::printfn("%s[%d] command == `%s'", $$FILE, $$LINE, d);
        //io::printfn("%s[%d] command == `%s'", $$FILE, $$LINE, d);
        foreach(file : files){
            d.append(" ");
            d.append(file);
            //io::printfn("%s[%d] command == `%s'", $$FILE, $$LINE, d);
        }
        //io::printfn("%s[%d] command == `%s'", $$FILE, $$LINE, d);
        ZString command  = d.copy_zstr(mem);
        defer free(command);
        //io::printfn("%s[%d] command == `%s'", $$FILE, $$LINE, command);
        CInt r = libc::system(command);
        if(r != 0){
            //io::printfn("%s[%d] call to command (%s) failed: %d", $$FILE, $$LINE, command, r);
        }
        libc::TimeSpec timespec = { .s = pause, .ns = nano_pause };
        libc::nanosleep(&timespec, null);
    } else {
        foreach(file : files){
            io::printfn("-> %s", file);
            //                                        999'999'999 //
            libc::TimeSpec timespec = { .s = 0, .ns = 50000000 };
            libc::nanosleep(&timespec, null);
        }
        //                                        999'999'999 //
        libc::TimeSpec timespec = { .s = pause, .ns = nano_pause };
        libc::nanosleep(&timespec, null);
    }
} // fn void process_files(String, user, outer_loop_val cmd, ZString[] files, int pause) //

String thisouter_loop_val_;

fn void proccess_args(usz files_index, String[] files, String cmd, String sub_prefix, String[] outer_loop_vals,
                        CInt batchsize, int pause, bool targeting_self){

    // Process remaining non-option arguments using optind
    if(files_index > 0) {
        String? thisouter_loop_val = utils::ex("hostname --long", mem);
        if(try thisouter_loop_val){
            thisouter_loop_val_ = thisouter_loop_val;
            defer thisouter_loop_val_.free(mem);
            thisouter_loop_val_ = thisouter_loop_val_.trim();
            String? user_ = env::get_var(mem, "USER");
            String  user @noinit;
            if(try user_){
                user = user_;
                defer user.free(mem);
                //outer_loop_vals.print_diag("outer_loop_vals");
                String[] outer_loop_vals_d @noinit;
                if(!targeting_self){
                    outer_loop_vals_d = outer_loop_vals.grep(mem, fn (elt) => elt != thisouter_loop_val_);
                    defer gauge::printf("%s[%d] cope ended", $$FILE, $$LINE);
                }else{
                    outer_loop_vals_d = outer_loop_vals.copy_str_array(mem);
                }
                defer free(outer_loop_vals_d);
                //outer_loop_vals_d.print_diag("outer_loop_vals_d");
                gauge::set_length(outer_loop_vals_d.len * (int)files_index);
                usz cnt = outer_loop_vals.count_contains(thisouter_loop_val_);
                if(cnt > 0){
                    gauge::length -= (int)cnt;
                }
                gauge::place  = 0;
                //io::printfn("gauge::length == %d\ngauge::place == %d", gauge::length, gauge::place);
                libc::signal(gauge::SIGWINCH, &call_progress_bar);
                gauge::init_term(gauge::Bars.TWO);
                gauge::progress_bar(prefix); // display the main progress bar //
                int nano_pause = pause % 1000000000;
                pause /= 1000000000; // integer division //
                foreach(outer_loop_val : outer_loop_vals_d){
                    outer_loop_val_ = outer_loop_val;
                    gauge::init_sub_place();
                    gauge::set_sub_length((int)files_index);
                    gauge::sub_progress_bar(outer_loop_val_); // display the progress bar //
                    for(usz i = 0; i < files_index; i += batchsize) {
                        if(i + batchsize < files_index){
                            process_files(user, outer_loop_val, thisouter_loop_val_, cmd, files[i : batchsize], pause);
                        } else {
                            process_files(user, outer_loop_val, thisouter_loop_val_, cmd, files[i ..], pause);
                        }
                        gauge::inc_place(batchsize);
                        gauge::inc_sub_place(batchsize);
                        gauge::sub_progress_bar(outer_loop_val_); // display the sub_progress bar //
                        gauge::progress_bar(prefix); // display the progress bar //
                        libc::TimeSpec timespec = { .s = pause, .ns = nano_pause };
                        libc::nanosleep(&timespec, null);
                    }
                    //gauge::sub_progress_bar(outer_loop_val_, gauge::sub_length); // display the progress bar //
                } // foreach(outer_loop_val : outer_loop_vals) //
                gauge::progress_bar(prefix, gauge::length); // display the progress bar //
                //                                        999'999'999 //
                libc::TimeSpec timespec = { .s = 5, .ns = 500000000 };
                libc::nanosleep(&timespec, null);
                gauge::deinit_term(0);
            }else{
                io::eprintfn("Error: could not get environment variable: USER: %s", @catch(user_));
                os::exit(-42);
            }
        }else{
            io::eprintfn("Error: ex failed could not get outer_loop_valname: %s", @catch(thisouter_loop_val));
            os::exit(-41);
        }
    }else{ // if (files_index > 0) //
        io::eprintfn("Error: no files specified");
        os::exit(-43);
    }
} /* fn void proccess_args(usz files_index, String[] files, String cmd, String sub_prefix, String[] outer_loop_vals,
                        CInt batchsize, int pause, bool targeting_self) */

fn int main(CInt argc, char** argv) {
    CInt      c;
    CInt      option_index         = 0;
    bool      errflg               = false;
    String    cmd                  = "";
    String    sub_prefix           = "";
    String    outer_loop_val_names = "dummy:᭽,";
    String[]  outer_loop_vals;
    CInt      batchsize            = 1;
    int       pause                = 0;
    bool      targeting_self       = false;
    usz       files_index          = 0;
    usz       files_capacity       = 16;
    Allocator allocator            = mem;
    String*   files                = allocator::alloc_array(allocator, String, files_capacity);

    // main progress bar                       //
    gauge::set_bar_char('⧫');
    gauge::set_empty_char(' ');
    gauge::set_prefix_foreground("bold,red", mem);
    gauge::set_prefix_background("green", mem);
    gauge::set_gauge_foreground("bold,red", mem);
    gauge::set_gauge_background("cyan", mem);
    gauge::set_suffix_foreground("bold,green", mem);
    gauge::set_suffix_background("blue", mem);

    // sub progress bar                        //
    gauge::set_sub_bar_char('❚');
    gauge::set_sub_empty_char(' ');
    gauge::set_sub_prefix_foreground("bold,cyan", mem);
    gauge::set_sub_prefix_background("red", mem);
    gauge::set_sub_gauge_foreground("bold,green", mem);
    gauge::set_sub_gauge_background("red", mem);
    gauge::set_sub_suffix_foreground("bold,red", mem);
    gauge::set_sub_suffix_background("cyan", mem);
    
    // Define long options structure (must be null-terminated)
    Option[*] long_options = {
        { .name  = "help",                  .has_arg  = 0, .flag  = null, .val  = 'h' },
        { .name  = "version",               .has_arg  = 0, .flag  = null, .val  = 'v' },
        { .name  = "batchsize",             .has_arg  = 1, .flag  = null, .val  = 'b' },
        { .name  = "targeting-self",        .has_arg  = 0, .flag  = null, .val  = 't' },
        { .name  = "bar-char",              .has_arg  = 1, .flag  = null, .val  = 'c' },
        { .name  = "empty-char",            .has_arg  = 1, .flag  = null, .val  = 'e' },
        { .name  = "cmd",                   .has_arg  = 1, .flag  = null, .val  = 'C' },
        { .name  = "prefix",                .has_arg  = 1, .flag  = null, .val  = 'f' },
        { .name  = "pause",                 .has_arg  = 1, .flag  = null, .val  = 'l' },
        { .name  = "prefix-foreground",     .has_arg  = 1, .flag  = null, .val  = 'P' },
        { .name  = "prefix-background",     .has_arg  = 1, .flag  = null, .val  = 'p' },
        { .name  = "gauge-foreground",      .has_arg  = 1, .flag  = null, .val  = 'G' },
        { .name  = "gauge-background",      .has_arg  = 1, .flag  = null, .val  = 'g' },
        { .name  = "suffix-foreground",     .has_arg  = 1, .flag  = null, .val  = 'S' },
        { .name  = "suffix-background",     .has_arg  = 1, .flag  = null, .val  = 's' },
        { .name  = "outer_loop_vals",       .has_arg  = 1, .flag  = null, .val  = 'L' },
        { .name  = "sub-prefix",            .has_arg  = 1, .flag  = null, .val  = 'F' },
        { .name  = "sub-prefix-foreground", .has_arg  = 1, .flag  = null, .val  = 'X' },
        { .name  = "sub-prefix-background", .has_arg  = 1, .flag  = null, .val  = 'x' },
        { .name  = "sub-gauge-foreground",  .has_arg  = 1, .flag  = null, .val  = 'A' },
        { .name  = "sub-gauge-background",  .has_arg  = 1, .flag  = null, .val  = 'a' },
        { .name  = "sub-suffix-foreground", .has_arg  = 1, .flag  = null, .val  = 'U' },
        { .name  = "sub-suffix-background", .has_arg  = 1, .flag  = null, .val  = 'u' },
        // row of null or 0 values to mark the end //
        { .name  = null,                    .has_arg  = 0, .flag  = null, .val  =  0  }
    };

    ZString shortopts = "-:vhb:tc:e:C:f:l:P:p:G:g:S:s:L:F:X:x:A:a:U:u:";

    char *endptr = null;

    while (true) {
        option_index = 0;
        c = gnu::getopt_long(argc, argv, shortopts, (Option*)&long_options, &option_index);

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
                        io::eprintfn("bad value for option '-%c' '%s' left over junk '%s'",
                                                gnu::optopt, (ZString)gnu::optarg, (ZString)endptr);
                    }else if((ZString)argv[gnu::optind - 1] == (ZString)gnu::optarg){
                        io::eprintfn("bad value for option '%s' '%s' left over junk '%s'",
                                    (ZString)argv[gnu::optind - 2], (ZString)gnu::optarg, (ZString)endptr);
                    }else{
                        io::eprintfn("bad value for option '%s' left over junk '%s'",
                                                        (ZString)argv[gnu::optind - 1], (ZString)endptr);
                    }
                    os::exit(-32);
                }
                if(batchsize <= 0){
                    if(gnu::optopt != '\0'){
                        io::eprintfn("bad value for option '-%c' '%s' BATCHSIZE must be > 0",
                                                                        gnu::optopt, (ZString)gnu::optarg);
                    }else if((ZString)argv[gnu::optind - 1] == (ZString)gnu::optarg){
                        io::eprintfn("bad value for option '%s' '%s' BATCHSIZE must be > 0",
                                                      (ZString)argv[gnu::optind - 2], (ZString)gnu::optarg);
                    }else{
                        io::eprintfn("bad value for option '%s' BATCHSIZE must be > 0",
                                                                            (ZString)argv[gnu::optind - 1]);
                    }
                    os::exit(-33);
                }
                break;
            case 't':
                targeting_self = true;
                break;
            case 'c':
                @pool()
                {
                    DString t = dstring::new(tmem, ((ZString)gnu::optarg).str_view());
                    Char32[] tmp = t.copy_utf32(tmem);
                    if(tmp.len != 1){
                        io::eprintfn("BAR-CHAR should be a single unicode char you supplied: '%s'", t);
                        os::exit(-34);
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
                        os::exit(-35);
                    }
                    gauge::empty_char = tmp[0];
                }; // t and tmp are freed here //
                break;
            case 'C':
                cmd = ((ZString)gnu::optarg).str_view();
                break;
            case 'f':
                prefix = ((ZString)gnu::optarg).str_view();
            case 'l':
                pause = (CInt)libc::strtol((ZString)gnu::optarg, &endptr, 0);
                if ((ZString)endptr != "") {
                    if(gnu::optopt != '\0'){
                        io::eprintfn("bad value for option '-%c' '%s' left over junk '%s'",
                                                gnu::optopt, (ZString)gnu::optarg, (ZString)endptr);
                    }else if((ZString)argv[gnu::optind - 1] == (ZString)gnu::optarg){
                        io::eprintfn("bad value for option '%s' '%s' left over junk '%s'",
                                    (ZString)argv[gnu::optind - 2], (ZString)gnu::optarg, (ZString)endptr);
                    }else{
                        io::eprintfn("bad value for option '%s' left over junk '%s'",
                                                        (ZString)argv[gnu::optind - 1], (ZString)endptr);
                    }
                    os::exit(-32);
                }
                if(pause < 0){
                    if(gnu::optopt != '\0'){
                        io::eprintfn("bad value for option '-%c' '%s' --pause must be ≥ 0",
                                                                        gnu::optopt, (ZString)gnu::optarg);
                    }else if((ZString)argv[gnu::optind - 1] == (ZString)gnu::optarg){
                        io::eprintfn("bad value for option '%s' '%s' --pause must be ≥ 0",
                                                      (ZString)argv[gnu::optind - 2], (ZString)gnu::optarg);
                    }else{
                        io::eprintfn("bad value for option '%s' --pause must be ≥ 0",
                                                                            (ZString)argv[gnu::optind - 1]);
                    }
                    os::exit(-33);
                }
                break;
            case 'P':
                gauge::prefix_foreground.free(mem);
                gauge::prefix_foreground = gauge::colour_from_string(((ZString)gnu::optarg).str_view(), mem);
                break;
            case 'p':
                gauge::prefix_background.free(mem);
                gauge::prefix_background = gauge::colour_from_string(((ZString)gnu::optarg).str_view(), mem, true);
                break;
            case 'G':
                gauge::gauge_foreground.free(mem);
                gauge::gauge_foreground = gauge::colour_from_string(((ZString)gnu::optarg).str_view(), mem);
                break;
            case 'g':
                gauge::gauge_background.free(mem);
                gauge::gauge_background = gauge::colour_from_string(((ZString)gnu::optarg).str_view(), mem, true);
                break;
            case 'S':
                gauge::suffix_foreground.free(mem);
                gauge::suffix_foreground = gauge::colour_from_string(((ZString)gnu::optarg).str_view(), mem);
                break;
            case 's':
                gauge::suffix_background.free(mem);
                gauge::suffix_background = gauge::colour_from_string(((ZString)gnu::optarg).str_view(), mem, true);
                break;
            case 'L':
                outer_loop_val_names = ((ZString)gnu::optarg).str_view();
                break;
            case 'F':
                sub_prefix = ((ZString)gnu::optarg).str_view();
                break;
            case 'X':
                gauge::sub_prefix_foreground.free(mem);
                gauge::sub_prefix_foreground = gauge::colour_from_string(((ZString)gnu::optarg).str_view(), mem);
                break;
            case 'x':
                gauge::sub_prefix_background.free(mem);
                gauge::sub_prefix_background = gauge::colour_from_string(((ZString)gnu::optarg).str_view(), mem, true);
                break;
            case 'A':
                gauge::sub_gauge_foreground.free(mem);
                gauge::sub_gauge_foreground = gauge::colour_from_string(((ZString)gnu::optarg).str_view(), mem);
                break;
            case 'a':
                gauge::sub_gauge_background.free(mem);
                gauge::sub_gauge_background = gauge::colour_from_string(((ZString)gnu::optarg).str_view(), mem, true);
                break;
            case 'U':
                gauge::sub_suffix_foreground.free(mem);
                gauge::sub_suffix_foreground = gauge::colour_from_string(((ZString)gnu::optarg).str_view(), mem);
                break;
            case 'u':
                gauge::sub_suffix_background.free(mem);
                gauge::sub_suffix_background = gauge::colour_from_string(((ZString)gnu::optarg).str_view(), mem, true);
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
            case 1:
                if(files_index == files_capacity){
                    files_capacity *= 2;
                    files = allocator::realloc(allocator, files, String.sizeof * files_capacity);
                }
                files[files_index++] = ((ZString)gnu::optarg).str_view();
                //io::printfn("%s[%d] gnu::optarg == `%s'", $$FILE, $$LINE, (ZString)gnu::optarg);
                break;
            default:
                // not an option I guess //
                break;
        }
    }

    defer gauge::prefix_foreground.free(mem);
    defer gauge::prefix_background.free(mem);
    defer gauge::gauge_foreground.free(mem);
    defer gauge::gauge_background.free(mem);
    defer gauge::suffix_foreground.free(mem);
    defer gauge::suffix_background.free(mem);
    defer gauge::sub_prefix_foreground.free(mem);
    defer gauge::sub_prefix_background.free(mem);
    defer gauge::sub_gauge_foreground.free(mem);
    defer gauge::sub_gauge_background.free(mem);
    defer gauge::sub_suffix_foreground.free(mem);
    defer gauge::sub_suffix_background.free(mem);
    defer free(files);

    if(errflg){
        usage((ZString)argv[0], 2);
    }

    if(outer_loop_val_names != ""){
        @pool()
        {
            //io::eprintfn("%s[%d] outer_loop_val_names == `%s'", $$FILE, $$LINE, outer_loop_val_names);
            if(!outer_loop_val_names.contains_char(',')){
                //io::eprintfn("%s[%d] outer_loop_val_names == `%s'", $$FILE, $$LINE, outer_loop_val_names);
                Path? outer_loop_val_path = path::temp(outer_loop_val_names);
                if(try outer_loop_val_path){
                    String? contents = outer_loop_val_path.slurp(mem);
                    if(try contents){
                        defer contents.free(mem);
                        //contents.print_diag("contents");
                        String[] array = contents.split_char_set(mem, "\n\r", skip_empty: true);
                        defer free(array);
                        //array.print_diag("array");
                        outer_loop_vals = array.map(mem, fn (elt) => elt.trim());
                        defer free(outer_loop_vals);
                        //outer_loop_vals.print_diag("outer_loop_vals");
                        proccess_args(files_index, files[:files_index], cmd, sub_prefix, outer_loop_vals, batchsize, pause, targeting_self);
                        //outer_loop_vals.print_diag("outer_loop_vals");
                    }else{
                        io::eprintfn("%s[%d] Error: cannot split `%s' to a String[]: %s",
                                                                $$FILE, $$LINE, outer_loop_val_path.str_view(), @catch(contents));
                        os::exit(-40);
                    }
                }else{
                    io::eprintfn("%s[%d] Error: cannot convert `%s' to a path: %s",
                                                                $$FILE, $$LINE, outer_loop_val_names, @catch(outer_loop_val_path));
                    os::exit(-40);
                }
            }else{
                outer_loop_vals = outer_loop_val_names.split_char_set(mem, ",", skip_empty: true).map(mem, fn (elt) => elt.trim());
                defer free(outer_loop_vals);
                proccess_args(files_index, files[:files_index], cmd, sub_prefix, outer_loop_vals, batchsize, pause, targeting_self);
            }
        }; // free all the tmem stuff //
    }else{
        os::exit(0);
    }

    return 0;
} // fn int main(CInt argc, char** argv) //

