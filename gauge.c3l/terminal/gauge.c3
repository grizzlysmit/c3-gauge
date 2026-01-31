module terminal::gauge;
import std::io;
import libc;
import std::io::path;
import std::core::mem::allocator;
import std::core::dstring @public;
import std::core::string::ansi;
import terminal::tsize;
import std::ascii;
import std::os::posix;
import os::sig;


Char32 bar_char          = '⧫';
Char32 empty_char        = ' ';
String prefix_foreground = @sprintf("%s;%s", Ansi.BOLD, Ansi.BRIGHT_RED);
String prefix_background = Ansi.BG_GREEN;
String gauge_foreground  = @sprintf("%s;%s", Ansi.BOLD, Ansi.BRIGHT_RED);
String gauge_background  = Ansi.CYAN;
String suffix_foreground = @sprintf("%s;%s", Ansi.BOLD, Ansi.BRIGHT_GREEN);
String suffix_background = Ansi.BG_BLUE;
int    length            = 80;
int    place             = 0;

Char32 sub_bar_char          = '❚';
Char32 sub_empty_char        = ' ';
String sub_prefix_foreground = @sprintf("%s;%s", Ansi.BOLD, Ansi.BRIGHT_CYAN);
String sub_prefix_background = Ansi.RED;
String sub_gauge_foreground  = @sprintf("%s;%s", Ansi.BOLD, Ansi.BRIGHT_GREEN);
String sub_gauge_background  = Ansi.RED;
String sub_suffix_foreground = @sprintf("%s;%s", Ansi.BOLD, Ansi.BRIGHT_RED);
String sub_suffix_background = Ansi.CYAN;
int    sub_length            = 80;
int    sub_place             = 0;

fn bool set_bar_char(Char32 ch = '⧫' ) @inline  {
    if(tsize::wcswidth(ch) != 1){
        _printf("Error: BAR_CHAR must be a single char wide!\n");
        //libc::fflush(libc::__stdout);
        return false;
    }
    bar_char = ch;
    return true;
}

fn bool set_empty_char(Char32 ch = ' ' ) @inline  {
    if(tsize::wcswidth(ch) != 1){
        _printf("Error: EMPTY_CHAR must be a single char wide!\n");
        //libc::fflush(libc::__stdout);
        return false;
    }
    empty_char = ch;
    return true;
}

fn bool set_prefix_foreground(String value = "bold,red", Allocator allocator) @inline  {
    prefix_foreground = colour_from_string(value, allocator);
    return true;
}

fn bool set_prefix_background(String value = "green", Allocator allocator) @inline  {
    prefix_background = colour_from_string(value, allocator, true);
    return true;
}

fn bool set_gauge_foreground(String value = "bold,red", Allocator allocator) @inline  {
    gauge_foreground = colour_from_string(value, allocator);
    return true;
}

fn bool set_gauge_background(String value = "cyan", Allocator allocator) @inline  {
    gauge_background = colour_from_string(value, allocator, true);
    return true;
}

fn bool set_suffix_foreground(String value = "bold,green", Allocator allocator) @inline  {
    suffix_foreground = colour_from_string(value, allocator);
    return true;
}

fn bool set_suffix_background(String value = "blue", Allocator allocator) @inline  {
    suffix_background = colour_from_string(value, allocator, true);
    return true;
}

<*
 @require value > 0 
*>
fn bool set_length(int value) @inline  {
    length = value;
    return true;
}

fn int get_length( ) @inline  {
    return length;
}

fn bool init_place( ) @inline  {
    place = 0;
    return true;
}

<*
 @require inc > 0 
*>
fn bool inc_place(CInt inc) @inline  {
    place += inc;
    return true;
}

fn int get_place( ) @inline  {
    return place;
}

fn bool set_sub_bar_char(Char32 ch = '◼' ) @inline  {
    if(tsize::wcswidth(ch) != 1){
        _printf("Error: SUB_BAR_CHAR must be a single char wide!\n");
        //libc::fflush(libc::__stdout);
        return false;
    }
    sub_bar_char = ch;
    return true;
}

fn bool set_sub_empty_char(Char32 ch = ' ' ) @inline  {
    if(tsize::wcswidth(ch) != 1){
        _printf("Error: SUB_EMPTY_CHAR must be a single char wide!\n");
        //libc::fflush(libc::__stdout);
        return false;
    }
    sub_empty_char = ch;
    return true;
}

fn bool set_sub_prefix_foreground(String value = "bold,red", Allocator allocator) @inline  {
    sub_prefix_foreground = colour_from_string(value, allocator);
    return true;
}

fn bool set_sub_prefix_background(String value = "cyan", Allocator allocator) @inline  {
    sub_prefix_background = colour_from_string(value, allocator, true);
    return true;
}

fn bool set_sub_gauge_foreground(String value = "bold,green", Allocator allocator) @inline  {
    sub_gauge_foreground = colour_from_string(value, allocator);
    return true;
}

fn bool set_sub_gauge_background(String value = "red", Allocator allocator) @inline  {
    sub_gauge_background = colour_from_string(value, allocator, true);
    return true;
}

fn bool set_sub_suffix_foreground(String value = "bold,green", Allocator allocator) @inline  {
    sub_suffix_foreground = colour_from_string(value, allocator);
    return true;
}

fn bool set_sub_suffix_background(String value = "blue", Allocator allocator) @inline  {
    sub_suffix_background = colour_from_string(value, allocator, true);
    return true;
}

<*
 @require value > 0 
*>
fn bool set_sub_length(int value) @inline  {
    sub_length = value;
    return true;
}

fn int get_sub_length( ) @inline  {
    return sub_length;
}

fn bool init_sub_place( ) @inline  {
    sub_place = 0;
    return true;
}

<*
 @require inc > 0 
*>
fn bool inc_sub_place(CInt inc) @inline  {
    sub_place += inc;
    return true;
}

fn int get_sub_place( ) @inline  {
    return sub_place;
}

fn String colour(String col, Allocator allocator = mem){
    @pool()
    {
        Allocator allocator1 = tmem;
        DString d;
        d.init(allocator1, (usz)258); // allow for unicoded //
        d.append(dstring::temp(Ansi.CSI));
        DString t;
        t.init(allocator1, (usz)256); // allow for unicoded //
        t.append(dstring::temp(col));
        t.append(dstring::temp("m"));
        //_printf("colour == %s\n", t.str_view());
        d.append(t);
        return d.copy_str(allocator);
    };
}

const CInt SIGSTKFLT = 16;
const CInt SIGPROF   = 27;
const CInt SIGWINCH  = 28;

enum Ansi : const inline String
{
    ESC                = "\e", 
    CSI                = "\e[",
	RESET              = "\e[0m",
	BOLD               = "1",
	DIM                = "2",
	ITALIC             = "3",
	UNDERLINE          = "4",
	BLINK              = "5",
	BLINK_FAST         = "6",
	INVERT             = "7",
	HIDDEN             = "8",
	STRIKETHROUGH      = "9",
	DOUBLE_UNDER       = "21",
	NO_DIM             = "22",
	NO_ITALIC          = "23",
	NO_UNDERLINE       = "24",
	NO_BLINK           = "25",
	NO_INVERT          = "27",
	NO_HIDDEN          = "28",
	NO_STRIKETHROUGH   = "29",
	BLACK              = "30",
	RED                = "31",
	GREEN              = "32",
	YELLOW             = "33",
	BLUE               = "34",
	MAGENTA            = "35",
	CYAN               = "36",
	WHITE              = "37",
	DEFAULT            = "39",
	BRIGHT_BLACK       = "90",
	BRIGHT_RED         = "91",
	BRIGHT_GREEN       = "92",
	BRIGHT_YELLOW      = "93",
	BRIGHT_BLUE        = "94",
	BRIGHT_MAGENTA     = "95",
	BRIGHT_CYAN        = "96",
	BRIGHT_WHITE       = "97",
	BG_BLACK           = "40",
	BG_RED             = "41",
	BG_GREEN           = "42",
	BG_YELLOW          = "43",
	BG_BLUE            = "44",
	BG_MAGENTA         = "45",
	BG_CYAN            = "46",
	BG_WHITE           = "47",
	BG_DEFAULT         = "49",
	BG_BRIGHT_BLACK    = "100",
	BG_BRIGHT_RED      = "101",
	BG_BRIGHT_GREEN    = "102",
	BG_BRIGHT_YELLOW   = "103",
	BG_BRIGHT_BLUE     = "104",
	BG_BRIGHT_MAGENTA  = "105",
	BG_BRIGHT_CYAN     = "106",
	BG_BRIGHT_WHITE    = "107",
}


fn String colour_from_string(String s, Allocator allocator, bool bg = false) {
    @pool()
    {
        bool first = true;
        DString result = dstring::temp("");
        String   col   = s.to_lower_tcopy();
        String[] parts = col.tsplit_char_set(",", skip_empty: true);
        foreach(part : parts){
            switch(part.trim()){
                case "bold":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append(Ansi.BOLD);
                    break;
                case "faint":
                case "dim":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append(Ansi.DIM);
                    break;
                case "italic":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append(Ansi.ITALIC);
                    break;
                case "underline":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append(Ansi.UNDERLINE);
                    break;
                case "blink":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append(Ansi.BLINK);
                    break;
                case "blink_fast":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append(Ansi.BLINK_FAST);
                    break;
                case "invert":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append(Ansi.INVERT);
                    break;
                case "hidden":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append(Ansi.HIDDEN);
                    break;
                case "strikethrough":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append(Ansi.STRIKETHROUGH);
                    break;
                case "double_under":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append(Ansi.DOUBLE_UNDER);
                    break;
                case "black":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append( (bg ? Ansi.BG_BLACK : Ansi.BLACK) );
                    break;
                case "red":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append( (bg ? Ansi.BG_RED : Ansi.RED) );
                    break;
                case "green":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append( (bg ? Ansi.BG_GREEN : Ansi.GREEN) );
                    break;
                case "yellow":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append( (bg ? Ansi.BG_YELLOW : Ansi.YELLOW) );
                    break;
                case "blue":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append( (bg ? Ansi.BG_BLUE : Ansi.BLUE) );
                    break;
                case "magenta":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append( (bg ? Ansi.BG_MAGENTA : Ansi.MAGENTA) );
                    break;
                case "cyan":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append( (bg ? Ansi.BG_CYAN : Ansi.CYAN) );
                    break;
                case "white":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append( (bg ? Ansi.BG_WHITE : Ansi.WHITE) );
                    break;
                case "default":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append( (bg ? Ansi.BG_DEFAULT : Ansi.DEFAULT) );
                    break;
                case "gray":
                case "grey":
                case "bright_black":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append( (bg ? Ansi.BG_BRIGHT_BLACK : Ansi.BRIGHT_BLACK) );
                    break;
                case "bright_red":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append( (bg ? Ansi.BG_BRIGHT_RED : Ansi.BRIGHT_RED) );
                    break;
                case "bright_green":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append( (bg ? Ansi.BG_BRIGHT_GREEN : Ansi.BRIGHT_GREEN) );
                    break;
                case "bright_yellow":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append( (bg ? Ansi.BG_BRIGHT_YELLOW : Ansi.BRIGHT_YELLOW) );
                    break;
                case "bright_blue":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append( (bg ? Ansi.BG_BRIGHT_BLUE : Ansi.BRIGHT_BLUE) );
                    break;
                case "bright_magenta":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append( (bg ? Ansi.BG_BRIGHT_MAGENTA : Ansi.BRIGHT_MAGENTA) );
                    break;
                case "bright_cyan":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append( (bg ? Ansi.BG_BRIGHT_CYAN : Ansi.BRIGHT_CYAN) );
                    break;
                case "bright_white":
                    if(first){
                        first = false;
                    } else {
                        result.append(";");
                    }
                    result.append( (bg ? Ansi.BG_BRIGHT_WHITE : Ansi.BRIGHT_WHITE) );
                    break;
                default:
                    _printf("unkown colour spec: ``%s''\n", part);
                    //libc::fflush(libc::__stdout);
                    os::exit(-36);
            } // switch(part.trim()) //
        } // foreach(part : parts) //
        return result.copy_str(allocator);
    }; // clean up the memory allocs //
} // fn String colour_from_string(String s, Allocator allocator, bool bg = false) //

enum Bars : const inline char {ONE = 1, TWO = 2}

Bars bars = Bars.ONE;

fn void init_term(Bars bars_ = Bars.ONE){
    bars_ = bars_;
    /*
    CInt[] sigs = {
        libc::SIGSYS, libc::SIGBUS, libc::SIGTERM, libc::SIGPIPE, libc::SIGQUIT,
        libc::SIGTRAP, libc::SIGHUP, libc::SIGCHLD, libc::SIGCONT, libc::SIGTSTP,
        libc::SIGILL, libc::SIGKILL, libc::SIGURG, libc::SIGSEGV, libc::SIGABRT,
        libc::SIGINT, libc::SIGFPE, libc::SIGSTOP, libc::SIGALRM, SIGSTKFLT, 
    };
    foreach(sig_ : sigs){
        libc::signal(sig_, &deinit_term);
    }
    // */
    for(CInt sig_ = 1; sig_ <= 64; sig_++){
        if(sig_ == SIGWINCH) continue;
        libc::signal(sig_, &deinit_term);
    }
    if(!tsize::is_term()){
        return;
    }
    tsize::Winsize winsize;
    if(!tsize::getsize(&winsize)){
        _printf("Error: could not get terminal size\n");
    }
    //libc::fflush(libc::__stdout);
	_printf("\n");                                           // ensure we have space for the scrollbar             //
    if(bars == Bars.TWO){
        _printf("\n");                                       // ensure we have space for the sub_scrollbar         //
        _printf("%s%dA", Ansi.CSI, 1);                       // move cursor up (incase cursor pos was bottom line) //
    }
	_printf("%s%dA", Ansi.CSI, 1);                           // move cursor up (incase cursor pos was bottom line) //
	_printf("%s%d", Ansi.ESC, 7);                            // save the cursor location                           //
	_printf("%s%d;%dr", Ansi.CSI, 0, winsize.ws_row - bars); // set the scrollable region (margin)                 //
	_printf("%s%d", Ansi.ESC, 8);                            // restore the cursor location                        //
	_printf("%s%dA", Ansi.CSI, 1);                           // move cursor up                                     //
    if(bars == Bars.TWO){
        _printf("%s%dA", Ansi.CSI, 1);                       // move cursor up                                     //
    }
    //libc::fflush(libc::__stdout);
}

fn void deinit_term(CInt sig) {
    if(sig == libc::SIGCHLD  || sig == libc::SIGCONT || sig == libc::SIGPIPE
        || sig == SIGPROF){
        return;
    }
    /*
    if(sig == 0){
        CInt pid = posix::getpid();
        sig::Sigval val = { .sival_int = 0 };
        //sig::sigqueue(pid, libc::SIGSTOP, (sig::Sigval)0);
        sig::sigqueue(pid, 64, val);
    }
    // */
    tsize::Winsize winsize;
    if(!tsize::getsize(&winsize)){
        _printf("Error: could not get terminal size\n");
        //libc::fflush(libc::__stdout);
    }
    //libc::fflush(libc::__stdout);
    /*
    if(bars == Bars.TWO){
        _printf("\n");                                        // make space in case of 2 bars                 //
    }
    // */
	_printf("%s%d", Ansi.ESC, 7);                             // save the cursor location                     //
	_printf("%s%d;%dr", Ansi.CSI, 0, winsize.ws_row);         // reset the scrollable region (margin)         //
	_printf("%s%d;%dH", Ansi.CSI, winsize.ws_row, 0);         // move cursor to the bottom line               //
	_printf("%s0K", Ansi.CSI);                                // clear the line                               //
    if(bars == Bars.TWO){
        _printf("%s%d;%dH", Ansi.CSI, winsize.ws_row - 1, 0); // move cursor to the second from bottom line   //
        _printf("%s0K", Ansi.CSI);                            // clear the line                               //
    }
	_printf("%s%d", Ansi.ESC, 8);                             // reset the cursor location                    //
    //*
    if(bars == Bars.TWO){
        _printf("%s0K", Ansi.CSI);                            // clear the line                               //
        //_printf("%s%dA", Ansi.CSI, 1);                        // move cursor up                               //
        //_printf("%s0K", Ansi.CSI);                            // clear the line                               //
    }
    // */

    //libc::fflush(libc::__stdout);
    switch(sig){
        case 0:
            printf("\n");
            if(bars == Bars.TWO){
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
                /*
                _printf("%s%d", Ansi.ESC, 7);                         // save the cursor location                     //
                _printf("%s%d;%dH", Ansi.CSI, winsize.ws_row - 2, 0); // move cursor to the third from bottom line    //
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
                _printf("%s%d;%dH", Ansi.CSI, winsize.ws_row - 3, 0); // move cursor to the fourth from bottom line   //
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
                _printf("%s%d", Ansi.ESC, 8);                         // reset the cursor location                    //
                // */
            }
            os::exit(0);
        case libc::SIGHUP:
            printf("sighup caught.\n");
            if(bars == Bars.TWO){
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
            }
            //libc::fflush(libc::__stdout);
            os::exit(-sig);
        case libc::SIGINT:
            printf("   keyboard interrupt caught.\n");
            if(bars == Bars.TWO){
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
            }
            //libc::fflush(libc::__stdout);
            os::exit(-sig);
        case libc::SIGQUIT:
            printf("sigquit caught.\n");
            if(bars == Bars.TWO){
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
            }
            //libc::fflush(libc::__stdout);
            os::exit(-sig);
        case libc::SIGILL:
            printf("sigill caught.\n");
            if(bars == Bars.TWO){
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
            }
            //libc::fflush(libc::__stdout);
            //io:_printf("\n");
            os::exit(-sig);
        case libc::SIGTRAP:
            printf("sigtrap caught.\n");
            if(bars == Bars.TWO){
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
            }
            //libc::fflush(libc::__stdout);
            os::exit(-sig);
        case libc::SIGABRT:
            printf("sigabrt caught.\n");
            if(bars == Bars.TWO){
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
            }
            //libc::fflush(libc::__stdout);
            os::exit(-sig);
        case libc::SIGFPE:
            printf("sigfpe caught.\n");
            if(bars == Bars.TWO){
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
            }
            //libc::fflush(libc::__stdout);
            os::exit(-sig);
        case libc::SIGKILL:
            printf("sigkill caught.\n");
            if(bars == Bars.TWO){
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
            }
            //libc::fflush(libc::__stdout);
            os::exit(-sig);
        case libc::SIGBUS:
            printf("sigbus caught.\n");
            if(bars == Bars.TWO){
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
            }
            //libc::fflush(libc::__stdout);
            os::exit(-sig);
        case libc::SIGSEGV:
            printf("sigsegv caught.\n");
            if(bars == Bars.TWO){
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
            }
            //libc::fflush(libc::__stdout);
            os::exit(-sig);
        case libc::SIGSYS:
            printf("sigsys caught.\n");
            if(bars == Bars.TWO){
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
            }
            //libc::fflush(libc::__stdout);
            os::exit(-sig);
        case libc::SIGPIPE:
            printf("sigpipe caught.\n");
            if(bars == Bars.TWO){
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
            }
            //libc::fflush(libc::__stdout);
            return;
        case libc::SIGALRM:
            printf("sigalrm caught.\n");
            if(bars == Bars.TWO){
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
            }
            //libc::fflush(libc::__stdout);
            os::exit(-sig);
        case libc::SIGTERM:
            printf("sigterm caught.\n");
            if(bars == Bars.TWO){
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
            }
            //libc::fflush(libc::__stdout);
            os::exit(-sig);
        case libc::SIGURG:
            printf("sigurg caught.\n");
            if(bars == Bars.TWO){
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
            }
            //libc::fflush(libc::__stdout);
            os::exit(-sig);
        case libc::SIGSTOP:
            printf("sigstop caught.\n");
            if(bars == Bars.TWO){
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
            }
            //libc::fflush(libc::__stdout);
            os::exit(-sig);
        case libc::SIGTSTP:
            printf("sigtstp caught.\n");
            if(bars == Bars.TWO){
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
            }
            //libc::fflush(libc::__stdout);
            os::exit(-sig);
        case libc::SIGCONT:
            printf("sigcont caught.\n");
            if(bars == Bars.TWO){
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
            }
            //libc::fflush(libc::__stdout);
            return;
        case libc::SIGCHLD:
            printf("sigchld caught.\n");
            if(bars == Bars.TWO){
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
            }
            //libc::fflush(libc::__stdout);
            return;
        case SIGSTKFLT:
            printf("sigstkflt caught.\n");
            if(bars == Bars.TWO){
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
            }
            //libc::fflush(libc::__stdout);
            os::exit(-sig);
        default:
            printf("\n");
            if(bars == Bars.TWO){
                _printf("%s0K", Ansi.CSI);                            // clear the line                               //
            }
            os::exit(-sig);
    } // switch sig //
} // fn void deinit_term(CInt sig) //

fn bool progress_bar(String prfix, int current = get_place(), int length = get_length()) {
    @pool()
    {
        String prefix = "";
        if(tsize::is_term()){
            if(tsize::wcswidth(prfix) != 0){
                String prefix_colour     = colour(prefix_foreground.tconcat(";").tconcat(prefix_background));
                prefix = prefix.tconcat(prefix_colour);
                prefix = prefix.tconcat(prfix);
                prefix = prefix.tconcat(Ansi.RESET);
            }
        }
        double numerator = (((double)current) * 100.0d );
        double perc_done = numerator;
        if(perc_done){
            perc_done /= ((double)length);
        }
        perc_done = (perc_done > 100.0d)? 100.0d : perc_done;
        Allocator allocator = mem;
        char[256] buf;
        libc::sprintf(&buf, " %d/%d (%f%%)", current, length, perc_done);
        String suffix = ((ZString)(&buf)).str_view();
        if(!tsize::is_term()){
            _printf("%s: %s\n", prfix, suffix);
            //libc::fflush(libc::__stdout);
            return false;
        }
        tsize::Winsize winsize;
        if(!tsize::getsize(&winsize)){
            _printf("Error: could not get terminal size\n");
        }
        int length_   = winsize.ws_col - tsize::wcswidth(prfix) - tsize::wcswidth(suffix) - 2;
        int num_bars = (int)(((perc_done * (double)length_)/100.0d).round());
        String gauge_colour = colour(gauge_foreground.tconcat(";").tconcat(gauge_background));
        DString line;
        line.init(allocator, (usz)(8 * (winsize.ws_col + 1))); // allow for unicoded plus Ansi sequences //
        defer line.free();
        line.append(prefix);
        line.append("[");
        line.append(gauge_colour);
        for(int i = 0; i < num_bars; i++){
            line.append(bar_char);
        }
        for(int i = num_bars; i < length_; i++){
            line.append(empty_char);
        }
        line.append(Ansi.RESET);
        line.append("]");
        String suffix_colour     = colour(suffix_foreground.tconcat(";").tconcat(suffix_background));
        line.append(suffix_colour);
        line.append(suffix);
        line.append(Ansi.RESET);
        //libc::fflush(libc::__stdout);
        _printf("%s%d", "\e", 7);                      // save the cursor location        //
        _printf("%s%d;%dH", "\e[", winsize.ws_row, 0); // move cursor to the bottom line  //
        _printf("%s0K", "\e[");                        // clear the line                  //
        _printf("%s", line.zstr_view());               // print the progress bar          //
        _printf("%s8", "\e");                          // restore the cursor location     //
        //libc::fflush(libc::__stdout);
        return true;
    }; // @pool() //
} // fn bool progress_bar(String prfix, int current = place, int length = length) //

fn bool sub_progress_bar(String prfix, int current = sub_place, int length = sub_length) {
    @pool()
    {
        String prefix = "";
        if(tsize::is_term()){
            if(tsize::wcswidth(prfix) != 0){
                String prefix_colour   = colour(sub_prefix_foreground.tconcat(";").tconcat(sub_prefix_background));
                prefix = prefix.tconcat(prefix_colour);
                prefix = prefix.tconcat(prfix);
                prefix = prefix.tconcat(Ansi.RESET);
            }
        }
        double numerator = (((double)current) * 100.0d );
        double perc_done = numerator;
        if(perc_done){
            perc_done /= ((double)length);
        }
        perc_done = (perc_done > 100.0d)? 100.0d : perc_done;
        Allocator allocator = mem;
        char[256] buf;
        libc::sprintf(&buf, " %d/%d (%f%%)", current, length, perc_done);
        String suffix = ((ZString)&buf).str_view();
        if(!tsize::is_term()){
            _printf("%s: %s\n", prfix, suffix);
            //libc::fflush(libc::__stdout);
            return false;
        }
        tsize::Winsize winsize;
        if(!tsize::getsize(&winsize)){
            _printf("Error: could not get terminal size\n");
        }
        int length_   = winsize.ws_col - tsize::wcswidth(prfix) - tsize::wcswidth(suffix) - 2;
        int num_bars = (int)(((perc_done * (double)length_)/100.0d).round());
        String gauge_colour = colour(sub_gauge_foreground.tconcat(";").tconcat(sub_gauge_background));
        DString line;
        line.init(allocator, (usz)(8 * (winsize.ws_col + 1))); // allow for unicode plus Ansi sequences //
        defer line.free();
        line.append(prefix);
        line.append("[");
        line.append(gauge_colour);
        for(int i = 0; i < num_bars; i++){
            line.append(sub_bar_char);
        }
        for(int i = num_bars; i < length_; i++){
            line.append(sub_empty_char);
        }
        line.append(Ansi.RESET);
        line.append("]");
        String suffix_colour     = colour(sub_suffix_foreground.tconcat(";").tconcat(sub_suffix_background));
        line.append(suffix_colour);
        line.append(suffix);
        line.append(Ansi.RESET);
        //line.print_diag("line");
        //libc::fflush(libc::__stdout);
        _printf("%s%d", "\e", 7);                             // save the cursor location                    //
        _printf("%s%d;%dH", "\e[", winsize.ws_row - 1, 0);    // move cursor to the second from bottom line  //
        _printf("%s0K", "\e[");                               // clear the line                              //
        _printf("%s", line.zstr_view());                      // print the progress bar                      //
        _printf("%s8", "\e");                                 // restore the cursor location                 //
        //libc::fflush(libc::__stdout);
        return true;
    }; // free all the tmem stuff //
} // fn bool sub_progress_bar(String prfix, int current = sub_place, int length = sub_length) //

macro void _printf(ZString format, ...){
    libc::fflush(libc::__stdout);
    libc::printf(format, $vasplat);
    libc::fflush(libc::__stdout);
}

macro void printf(ZString format, ...){
    libc::fflush(libc::__stdout);
    libc::printf("%s0K", "\e[");
    libc::printf(format, $vasplat);
    libc::fflush(libc::__stdout);
}
