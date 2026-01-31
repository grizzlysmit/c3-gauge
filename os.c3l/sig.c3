module os::sig;
import libc;

union Sigval {
    CInt  sival_int;
    void* sival_ptr;
}

extern fn CInt sigqueue(libc::Pid_t pid, CInt sig, Sigval val);
