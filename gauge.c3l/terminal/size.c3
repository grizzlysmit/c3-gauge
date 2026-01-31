module terminal::tsize;
import libc;
import std::io;

<*
 @require $typeof(s) == String || $typeof(s) == DString || $typeof(s) == ZString || $typeof(s) == Char32[] || $typeof(s) == Char32 : "Expected String, DString, ZString,  Char32[] or Char32"
*>
macro int wcswidth(s){
    var $Type = $typeof(s);
    $switch $Type:
        $case Char32:
            return 1;
        $case Char32[]:
            return s.len;
        $default:
            @pool()
            {
                DString t = dstring::new(tmem, s);
                Char32[] s_ = t.copy_utf32(tmem);
                int len = s_.len;
                return len;
            }; // t and s_ are freed here //
    $endswitch
} // macro int wcswidth(s) //

fn bool is_term(){
    return io::stdout().isatty();
}

// Structure for terminal size (from <sys/ioctl.h>)
// You might need to define this based on your system headers
struct Winsize {
    ushort ws_row;    // Number of rows in characters            //
    ushort ws_col;    // Number of columns in characters         //
    ushort ws_xpixel; // Horizontal size in pixels (unused here) //
    ushort ws_ypixel; // Vertical size in pixels (unused here)   //
}

const ulong TIOCGWINSZ = 0x5413;

fn bool getsize(Winsize *winsize) {
    //fd := sys.Fd(posix.FD(os.stdin)) // Use stdin file descriptor
    //CInt fd = libc::__stdout._fileno; // Use stdout file descriptor
    CInt fd = 1; // Use stdout file descriptor
    //fd := os.stdin // Use stdin file descriptor
    // Use ioctl to get window size
    if(libc::ioctl(fd, TIOCGWINSZ, winsize) == 0){
        return true;
    }
    return false;
}

module libc @if(env::LIBC);

extern fn CFile popen(ZString command, ZString type);

