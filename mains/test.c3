import terminal::tsize;
import std::io;
import libc;

fn void main() {
    tsize::Winsize winsize;
    if(!tsize::getsize(&winsize)){
        io::eprintn("Error: could not get terminal size");
        libc::exit(-1);
    }
    io::printfn("cols == %d\nrows == %d", winsize.ws_col, winsize.ws_row);
}
