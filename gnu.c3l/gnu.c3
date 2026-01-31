module gnu;
import std::io;
import libc;
import std::io::path;

int major  = 0;
int minor  = 1;
int subver = 0;

// Declare the C struct option structure
// The layout should match the C definition from <getopt.h>
struct Option @cname("option") {
    char* name;
    CInt has_arg;
    CInt* flag;
    CInt val;
}

// Declare the external C function getopt_long
// The @cname attribute can be used if the C name doesn't conform to C3 naming rules
extern fn CInt getopt_long(CInt argc, char** argv, ZString optstring,
                            Option* longopts, CInt* longindex) @cname("getopt_long");

// Declare global variables used by getopt
extern CInt  optind @cname("optind");
extern char* optarg @cname("optarg");
extern CInt  optopt @cname("optopt");

