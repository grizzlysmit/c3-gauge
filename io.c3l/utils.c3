module io::utils;
import std::io::file;
import std::io::path;
import string_utils::su;
import libc;

//alias Path = path::Path;
faultdef FILE_DOES_NOT_EXIST;   // define a fault //
faultdef BUFFER_TO_SMALL;   // define a fault //

fn usz? raw_fread(CFile file, char* buffer, usz size_get) @inline
{
    usz? size = libc::fread(buffer, 1, size_get, file);
    if(try size){
        //io::eprintfn("%s[%d] size == `%d'", $$FILE, $$LINE, size);
        //io::eprintfn("%s[%d] size_get == `%d'", $$FILE, $$LINE, size_get);
        //buffer[size] = 0;
    }
    return size;
}

<*
 @param [in] buffer
*>
fn usz? File.raw_read(&self, char* buffer, usz size) @dynamic
{
	return raw_fread(self.file, buffer, size);
}


fn String? Path.slurp(self, Allocator allocator) {
    //self.str_view().eprint_diag("path");
    if(path::exists(self)){
        usz? size = path::file_size(self);
        if(try size){
            //io::eprintfn("%s[%d] size == `%d'", $$FILE, $$LINE, size);
            //size *= 2;
            //size++; // room for the terminating \0 //
            //io::eprintfn("%s[%d] size == `%d'", $$FILE, $$LINE, size);
            File? file = file::open_path(self, "r");
            if(try file){
                char* buffer = allocator::malloc(allocator, size + 2);
                usz? r = file.raw_read(buffer, size);
                //usz? r = file.read(buffer);
                if(try r){
                    //io::eprintfn("%s[%d] r == `%d'", $$FILE, $$LINE, r);
                    buffer[r] = 0; // add \0 to the end //
                    //io::eprintfn("%s[%d] buffer == `%s'", $$FILE, $$LINE, (ZString)buffer);
                    return ((ZString)buffer).str_view();
                }else{
                    return @catch(r)~;
                }
            }else{ // if(try file) //
                return @catch(file)~;
            } // if(try file) ... else ... //
        }else{ // if(path::exists(self)) //
            return @catch(size)~;
        } // if(path::exists(self)) ... else ... //
    }
    return FILE_DOES_NOT_EXIST~;
} // fn String? Path.slurp(self, Allocator allocator) //

fn String? ex(String command, Allocator allocator, usz size = 4096){
    File? file = file::from_handle(libc::popen((ZString)(command.ptr), "r"));
    if(try file){
        char[]? buffer = allocator::new_array(allocator, char, size);
        if(try buffer){
            usz? r = file.read(buffer);
            if(try r){
                if(r >= size) return BUFFER_TO_SMALL~;
                buffer[r] = 0; // add \0 to the end //
                return ((ZString)buffer).str_view();
            }else{
                return @catch(r)~;
            }
        }else{ // if(try file) //
            return @catch(buffer)~;
        } // if(try file) ... else ... //
    }else{
        return @catch(file)~;
    }
} // fn String? ex(String command, Allocator allocator, usz size = 4096) //
