module string_utils::su;
import std::core::string;
import std::collections::list;
import std::io;
import libc;
import std::core::ascii;

alias GrepFunction = fn bool(String elt);
alias MapFunction = fn String(String elt);
alias ListStr = List {String};

faultdef EMPTY_STRING; // String is empty. //
faultdef ERROR_CLOSE_BRACKET_NOT_FOUND; // Missing close Bracket in base specification //
faultdef ERROR_BASE_TOO_LARGE_MUST_BE_BETWEEN_2_AND_36; // The value of base is too large //
faultdef ERROR_NOT_ALL_OF_STRING_CONVERTED; // The value of base is too large //
faultdef ERROR_BASE_TOO_SMALL_MUST_BE_BETWEEN_2_AND_36; // The value of base is too large //

<*
 
*>

fn bool String.less(self, String other) /*@operator(<)*/ {
    @pool()
    {
        return libc::strcmp(self.zstr_tcopy(), other.zstr_tcopy()) < 0;
    };
}

fn CInt String.compare_to(self, String other) /*@operator(<)*/ {
    @pool()
    {
        return libc::strcmp(self.zstr_tcopy(), other.zstr_tcopy());
    };
}

fn bool String.less_dstring(self, DString other)  {
    @pool()
    {
        return libc::strcmp(self.zstr_tcopy(), other.zstr_view()) < 0;
    };
}

fn bool String.equals(self, String other) /*@operator(==)*/ {
    @pool()
    {
        return libc::strcmp(self.zstr_tcopy(), other.zstr_tcopy()) == 0;
    };
}

fn bool String.less_zstrig(self, ZString other) /*@operator(<)*/ {
    @pool()
    {
        return libc::strcmp(self.zstr_tcopy(), other) < 0;
    };
}

fn bool ZString.is_identifier(self){
    if(self.len() == 0) return false;
    if(!(self[0].is_alpha() || self[0] == '_')) return false;
    for(char* ptr = &self[1]; *ptr != 0; ptr++){
        char c = *ptr;
        if(!(c.is_alnum() || c == '_')) return false;
    }
    return true;
}

fn bool String.is_identifier(self){
    if(self.len == 0) return false;
    if(!(self[0].is_alpha() || self[0] == '_')) return false;
    foreach(char c : self[1..]){
        if(!(c.is_alnum() || c == '_')) return false;
    }
    return true;
}

macro long convert_to_base_num(char ch, uint base){
    switch{
        case base <= 10:
            return (long)(ch - '0');
        case base <= 36:
            switch{
                case ascii::is_digit(ch):
                    return (long)(ch - '0');
                case ascii::is_alpha(ch) && ascii::is_lower(ch):
                    return (long)(ch - 'a') + 10;
                case ascii::is_alpha(ch) && ascii::is_upper(ch):
                    return (long)(ch - 'A') + 10;
                default:
                    return 0;
            } // switch //
        default:
            return 0;
    } // switch //
} // macro long convert_to_base_num(char ch, uint base) //

fn long? String.strtol(self, char** endptr = null, uint base = 0, bool error_on_incomplete = false){
    if(self.len == 0){
        if(error_on_incomplete) return EMPTY_STRING~;
        return 0;
    }
    const char OPEN   = '(';
    const char CLOSE  = ')';
              *endptr = self.ptr;
    char*      end    = *endptr + self.len;
    long       result = 0;
    if(base == 0){
        if(**endptr == '0'){
            *endptr++; // next //
            if(*endptr >= end) return 0;
            switch(**endptr){
                case 'B':
                    nextcase;
                case 'b':
                    base = 2;
                case 'O':
                    nextcase;
                case 'o':
                    base = 8;
                case 'X':
                    nextcase;
                case 'x':
                    base = 16;
                case OPEN:
                    io::eprintfn("%s[%d]«%s» self == `%s'\n **endptr == `%c'\n"
                                    " base == %d\n endptr == `%p'\n end == `%p'",
                            $$FILE, $$LINE, $$FUNC, self, **endptr, base, endptr, end);
                    *endptr++; // next //
                    uint n = 0; // read in number as base 10 //
                    io::eprintfn("%s[%d]«%s» self == `%s'\n **endptr == `%c'\n"
                                    " base == %d\n endptr == `%p'\n end == `%p'\n n == `%d'",
                            $$FILE, $$LINE, $$FUNC, self, **endptr, base, endptr, end, n);
                    while(*endptr < end && **endptr != CLOSE && ascii::is_digit(**endptr)){
                        n = n * 10 + (**endptr - '0');
                        *endptr++;
                        io::eprintfn("%s[%d]«%s» self == `%s'\n **endptr == `%c'\n"
                                        " base == %d\n endptr == `%p'\n end == `%p'\n n == `%d'",
                                $$FILE, $$LINE, $$FUNC, self, **endptr, base, endptr, end, n);
                    }
                    if(*endptr >= end){
                        return ERROR_CLOSE_BRACKET_NOT_FOUND~;
                    }
                    if(**endptr != CLOSE) return ERROR_CLOSE_BRACKET_NOT_FOUND~;
                    if(n > 36) return ERROR_BASE_TOO_LARGE_MUST_BE_BETWEEN_2_AND_36~;
                    *endptr++;
                    if(*endptr >= end) return 0;
                    io::eprintfn("%s[%d]«%s» self == `%s'\n **endptr == `%c'\n"
                                    " base == %d\n endptr == `%p'\n end == `%p'\n n == `%d'",
                            $$FILE, $$LINE, $$FUNC, self, **endptr, base, endptr, end, n);
                    base  = n;
                    io::eprintfn("%s[%d]«%s» self == `%s'\n **endptr == `%c'\n"
                                    " base == %d\n endptr == `%p'\n end == `%p'\n n == `%d'",
                            $$FILE, $$LINE, $$FUNC, self, **endptr, base, endptr, end, n);
            } // switch(**endptr) //
        } // if(**endptr == '0') //
    } // if(base == 0) //
    switch{
        case base < 2:
            return ERROR_BASE_TOO_SMALL_MUST_BE_BETWEEN_2_AND_36~;
        case base <= 10:
            while(*endptr < end && ascii::is_digit(**endptr) && **endptr < '0' + base){
                result = result * base + (long)(**endptr - '0');
                *endptr++;
            }
        case base <= 36:
            String fmt_str = "%s[%d]«%s» *endptr == `%s'\n self == `%s'"
                             "\n result == `%d'\n base == `%d'\n next == `%d'";
            io::eprintfn(fmt_str, $$FILE, $$LINE, $$FUNC, **endptr, self, result, base, 0);
            while(*endptr < end && ascii::is_digit(**endptr) && **endptr < '0' + base){
                long next = convert_to_base_num(**endptr, base);
                result = result * base + next;
                *endptr++;
                io::eprintfn(fmt_str, $$FILE, $$LINE, $$FUNC, **endptr, self, result, base, next);
            }
            io::eprintfn(fmt_str, $$FILE, $$LINE, $$FUNC, **endptr, self, result, base, 0);
        default:
            return ERROR_BASE_TOO_LARGE_MUST_BE_BETWEEN_2_AND_36~;
    }
    if(*endptr < end && error_on_incomplete) return ERROR_NOT_ALL_OF_STRING_CONVERTED~;
    return result;
} // fn long? String.strtol(self, char** endptr = null, uint base = 0, bool error_on_incomplete = false) //

fn long? ZString.strtol(self, char** endptr = null, uint base = 0, bool error_on_incomplete = false){
    if(self.len() == 0){
        if(error_on_incomplete) return EMPTY_STRING~;
        return 0;
    }
    const char OPEN   = '(';
    const char CLOSE  = ')';
              *endptr = (char*)self;
    char*      end    = (*endptr) + self.len();
    long       result = 0;
    if(self.len() == 1){
        if(ascii::is_digit(self[0])){
            (*endptr)++;
            return (long)(self[0] - '0');
        }
        (*endptr)++;
        return 0;
    }
    if(base == 0){
        if(**endptr == '0'){
            (*endptr)++; // next //
            if(*endptr >= end) return 0;
            switch(**endptr){
                case 'B':
                    nextcase;
                case 'b':
                    base = 2;
                case 'O':
                    nextcase;
                case 'o':
                    base = 8;
                case 'X':
                    nextcase;
                case 'x':
                    base = 16;
                case OPEN:
                    io::eprintfn("%s[%d]«%s» self == `%s'\n **endptr == `%c'\n"
                                    " base == %d\n endptr == `%p'\n end == `%p'",
                            $$FILE, $$LINE, $$FUNC, self, **endptr, base, endptr, end);
                    (*endptr)++; // next //
                    uint n = 0; // read in number as base 10 //
                    io::eprintfn("%s[%d]«%s» self == `%s'\n **endptr == `%c'\n"
                                    " base == %d\n endptr == `%p'\n end == `%p'\n n == `%d'",
                            $$FILE, $$LINE, $$FUNC, self, **endptr, base, endptr, end, n);
                    while(*endptr < end && **endptr != CLOSE && ascii::is_digit(**endptr)){
                        n = n * 10 + (**endptr - '0');
                        (*endptr)++;
                        io::eprintfn("%s[%d]«%s» self == `%s'\n **endptr == `%c'\n"
                                        " base == %d\n endptr == `%p'\n end == `%p'\n n == `%d'",
                                $$FILE, $$LINE, $$FUNC, self, **endptr, base, endptr, end, n);
                    }
                    if(*endptr >= end){
                        return ERROR_CLOSE_BRACKET_NOT_FOUND~;
                    }
                    if(**endptr != CLOSE) return ERROR_CLOSE_BRACKET_NOT_FOUND~;
                    if(n > 36) return ERROR_BASE_TOO_LARGE_MUST_BE_BETWEEN_2_AND_36~;
                    (*endptr)++;
                    if(*endptr >= end) return 0;
                    io::eprintfn("%s[%d]«%s» self == `%s'\n **endptr == `%c'\n"
                                    " base == %d\n endptr == `%p'\n end == `%p'\n n == `%d'",
                            $$FILE, $$LINE, $$FUNC, self, **endptr, base, endptr, end, n);
                    base  = n;
                    io::eprintfn("%s[%d]«%s» self == `%s'\n **endptr == `%c'\n"
                                    " base == %d\n endptr == `%p'\n end == `%p'\n n == `%d'",
                            $$FILE, $$LINE, $$FUNC, self, **endptr, base, endptr, end, n);
            } // switch(**endptr) //
        }else{ // if(**endptr == '0') //
            base = 10;
        }
    } // if(base == 0) //
    switch{
        case base < 2:
            return ERROR_BASE_TOO_SMALL_MUST_BE_BETWEEN_2_AND_36~;
        case base <= 10:
            while(*endptr < end && ascii::is_digit(**endptr) && **endptr < '0' + base){
                result = result * base + (long)(**endptr - '0');
                (*endptr)++;
            }
        case base <= 36:
            String fmt_str = "%s[%d]«%s» *endptr == `%s'\n self == `%s'"
                             "\n result == `%d'\n base == `%d'\n next == `%d'";
            io::eprintfn(fmt_str, $$FILE, $$LINE, $$FUNC, **endptr, self, result, base, 0);
            while(*endptr < end && ascii::is_digit(**endptr) && **endptr < '0' + base){
                long next = convert_to_base_num(**endptr, base);
                result = result * base + next;
                (*endptr)++;
                io::eprintfn(fmt_str, $$FILE, $$LINE, $$FUNC, **endptr, self, result, base, next);
            }
            io::eprintfn(fmt_str, $$FILE, $$LINE, $$FUNC, **endptr, self, result, base, 0);
        default:
            return ERROR_BASE_TOO_LARGE_MUST_BE_BETWEEN_2_AND_36~;
    }
    if(*endptr < end && error_on_incomplete) return ERROR_NOT_ALL_OF_STRING_CONVERTED~;
    return result;
} // fn long? ZString.strtol(self, char** endptr = null, uint base = 0, bool error_on_incomplete = false) //

fn String char[].reverse_to_string(self){
    DString ds;
    usz len = self.len;
    while(len){
        ds.append_char(self[--len]);
    }
    return ds.copy_str(mem);
}

<*
 Split a string into parts, e.g "a|b|c" split_char_set with  set == "|" yields { "a", "b", "c" }

 @param [in] self
 @param [in] set
 @param max : "Max number of elements, 0 means no limit, defaults to 0"
 @param skip_empty : "True to skip empty elements"
 @param [&inout] allocator : "The allocator to use for the String[]"

 @require set.len > 0 : "The set must be at least 1 character long"
 @ensure return.len > 0 || skip_empty
*>
fn String[] String.split_char_set(self, Allocator allocator, String set, usz max = 0, bool skip_empty = false) {
    usz capacity = 16;
	usz i = 0;
	usz index = 0;
	usz last = 0;
	String* holder = allocator::alloc_array(allocator, String, capacity);
	bool no_more = false;
	while (!no_more) {
		String res @noinit;
        if(index >= self.len){
            res = self[last..];
            no_more = true;
            if (!res.len && skip_empty)
            {
                continue;
            }
        }
        if(!no_more){
            bool? cond = i == max - 1 ? NOT_FOUND~ : set.contains_char(self[index]);
            if (try cond)
            {
                if(cond){
                    res = self[last..index - 1];
                    index++;
                    last = index;
                }else{
                    index++;
                    continue;
                }
            } else {
                res = self[last..];
                no_more = true;
            }
            if (!res.len && skip_empty)
            {
                continue;
            }
        } // if(!no_more) //

		if (i == capacity)
		{
			capacity *= 2;
			holder = allocator::realloc(allocator, holder, String.sizeof * capacity);
		}
		holder[i++] = res;
	} // while (!no_more) //
	return holder[:i];
} // fn String[] String.split_char_set(self, String set, usz max = 0, bool skip_empty = false) //

fn String[] String.tsplit_char_set(self, String set, usz max = 0, bool skip_empty = false) => self.split_char_set(tmem, set, max, skip_empty) @inline;

<*
If character is present in any of the elts of self return true otherwise return false.

 @param [in] self
*>
fn bool String[].contains_char_in_array(self, char character){
    foreach(set : self){
        if(set.contains_char(character)) return true;
    }
    return false;
}

<*
If substr is present in any of the elts of self return true otherwise return false.

 @param [in] self
 @param [in] substr
*>
fn bool String[].contains_substr_in_array(self, String substr){
    foreach(set : self){
        if(set.contains(substr)) return true;
    }
    return false;
}

<*
If substr is present in any of the elts of self return true otherwise return false.

 @param [in] self
 @param [in] str
*>
fn bool String[].contains(self, String str){
    foreach(elt : self){
        if(elt == str) return true;
    }
    return false;
}

<*
If s starts with any string in self return true otherwise return false.

 @param [in] self
 @param [in] s
 @param [inout] del_len
 @ensure del_len && (*del_len > 0) : "if del_len is non null then it will contain the length of the matching elt in self "
*>
fn bool String[].array_elt_starts_with(self, String s, usz* del_len){
    foreach(set : self){
        if(s.starts_with(set)){
            if(del_len) *del_len = set.len;
            return true;
        }
    }
    return false;
}

<*
 Split a string into parts, e.g "a|b|c,d,f" split_char_set with  sets == { "|", "," } yields { "a", "b", "c", "d", "f" }

 @param [in] self
 @param [in] sets
 @param max : "Max number of elements, 0 means no limit, defaults to 0"
 @param skip_empty : "True to skip empty elements"
 @param [&inout] allocator : "The allocator to use for the String[]"

 @require sets.len > 0 : "The sets have at least 1 element"
 @ensure return.len > 0 || skip_empty
*>
fn String[] String.split_on_delimiter_sets(self, Allocator allocator, String[] sets, usz max = 0, bool skip_empty = false) {
    usz capacity = 16;
	usz i = 0;
	usz index = 0;
	usz last = 0;
	String* holder = allocator::alloc_array(allocator, String, capacity);
	bool no_more = false;
    usz  del_len = 0;
	while (!no_more) {
		String res @noinit;
        if(index >= self.len){
            res = self[last..];
            no_more = true;
            if (!res.len && skip_empty)
            {
                continue;
            }
        }
        if(!no_more){
            bool? cond = i == max - 1 ? NOT_FOUND~ : sets.array_elt_starts_with(self[index..], &del_len);
            if (try cond)
            {
                if(cond){
                    res = self[last..index - 1];
                    index += del_len;
                    last = index;
                }else{
                    index++;
                    continue;
                }
            } else {
                res = self[last..];
                no_more = true;
            }
            if (!res.len && skip_empty)
            {
                continue;
            }
        } // if(!no_more) //

		if (i == capacity)
		{
			capacity *= 2;
			holder = allocator::realloc(allocator, holder, String.sizeof * capacity);
		}
		holder[i++] = res;
	} // while (!no_more) //
	return holder[:i];
} // fn String[] String.split_on_delimiter_sets(self, Allocator allocator, String[] sets, usz max = 0, bool skip_empty = false) //

fn String[] String.tsplit_on_delimiter_sets(self, String[] sets, usz max = 0, bool skip_empty = false) => self.split_on_delimiter_sets(tmem, sets, max, skip_empty) @inline;

fn String[] String[].grep(self, Allocator allocator, GrepFunction grep_function) {
    ListStr result;
    result.init(allocator, self.len);
    foreach(elt : self){
        if(grep_function(elt)){
            result.push(elt);
        }
    }
    return result.array_view();
}

fn String[] String[].map(self, Allocator allocator, MapFunction map_function) {
    ListStr result;
    result.init(allocator, self.len);
    foreach(elt : self){
        result.push(map_function(elt));
    }
    //result.print_diag("result");
    return result.array_view();
}

fn String[] String[].copy_str_array(self, Allocator allocator){
    usz capacity   = self.len + 1;
	String* holder = allocator::alloc_array(allocator, String, capacity);
    usz index = 0;
    foreach(elt : self){
		holder[index++] = elt;
    }
	return holder[:index];
}

fn usz String[].count_contains(self, String element){
    usz result = 0;
	foreach (&item : self)
	{
		if (*item == element) result++;
	}
	return result;
}

<*
 @require $typeof(name) == String || $typeof(name) == DString || $typeof(name) == ZString : "Expected String, DString or ZString"
*>
macro void ListStr.print_diag(self, name) {
    io::printf("%s[%d] %s == [", $$FILE, $$LINE, name);
    foreach(elt : self){
        io::printf("%s%c ", elt, ',');
    }
    io::printfn("]");
}

<*
 @require $typeof(name) == String || $typeof(name) == DString || $typeof(name) == ZString : "Expected String, DString or ZString"
*>
macro void ListStr.eprint_diag(self, name) {
    io::eprintf("%s[%d] %s == [", $$FILE, $$LINE, name);
    foreach(elt : self){
        io::eprintf("%s%c ", elt, ',');
    }
    io::eprintfn("]");
}

<*
 @require $typeof(name) == String || $typeof(name) == DString || $typeof(name) == ZString : "Expected String, DString or ZString"
*>
macro void String[].print_diag(self, name) {
    io::printf("%s[%d] %s == [", $$FILE, $$LINE, name);
    foreach(elt : self){
        io::printf("%s%c ", elt, ',');
    }
    io::printfn("]");
}

<*
 @require $typeof(name) == String || $typeof(name) == DString || $typeof(name) == ZString : "Expected String, DString or ZString"
*>
macro void String[].eprint_diag(self, name) {
    io::eprintf("%s[%d] %s == [", $$FILE, $$LINE, name);
    foreach(elt : self){
        io::eprintf("%s%c ", elt, ',');
    }
    io::eprintfn("]");
}

<*
 @require $typeof(name) == String || $typeof(name) == DString || $typeof(name) == ZString : "Expected String, DString or ZString"
*>
macro void ZString[].print_diag(self, name) {
    io::printf("%s[%d] %s == [", $$FILE, $$LINE, name);
    foreach(elt : self){
        io::printf("%s%c ", elt, ',');
    }
    io::printfn("]");
}

<*
 @require $typeof(name) == String || $typeof(name) == DString || $typeof(name) == ZString : "Expected String, DString or ZString"
*>
macro void ZString[].eprint_diag(self, name) {
    io::eprintf("%s[%d] %s == [", $$FILE, $$LINE, name);
    foreach(elt : self){
        io::eprintf("%s%c ", elt, ',');
    }
    io::eprintfn("]");
}

<*
 @require $typeof(name) == String || $typeof(name) == DString || $typeof(name) == ZString : "Expected String, DString or ZString"
*>
macro void String.print_diag(self, name) {
    io::printfn("%s[%d] %s == `%s'", $$FILE, $$LINE, name, self);
}

<*
 @require $typeof(name) == String || $typeof(name) == DString || $typeof(name) == ZString : "Expected String, DString or ZString"
*>
macro void String.eprint_diag(self, name) {
    io::eprintfn("%s[%d] %s == `%s'", $$FILE, $$LINE, name, self);
}

<*
 @require $typeof(name) == String || $typeof(name) == DString || $typeof(name) == ZString : "Expected String, DString or ZString"
*>
macro void DString.print_diag(self, name) {
    io::printfn("%s[%d] %s == `%s'", $$FILE, $$LINE, name, self);
}

<*
 @require $typeof(name) == String || $typeof(name) == DString || $typeof(name) == ZString : "Expected String, DString or ZString"
*>
macro void DString.eprint_diag(self, name) {
    io::eprintfn("%s[%d] %s == `%s'", $$FILE, $$LINE, name, self);
}

fn void DString.quote(&self){
    @pool(){
        String str = self.tcopy_str();
        self.clear();
        self.append_char('"');
        foreach(c : str){
            switch(c){
                case '\\':
                    self.append_char('\\');
                    self.append_char('\\');
                case '"':
                    self.append_char('\\');
                    self.append_char('"');
                default:
                    self.append_char(c);
            }
        }
        self.append_char('"');
    };
} // fn void DString.quote(&self) //

fn String String.quote(self, Allocator allocator){
    DString ds;
    ds.append_char('"');
    foreach(c : self){
        switch(c){
            case '\\':
                ds.append_char('\\');
                ds.append_char('\\');
            case '"':
                ds.append_char('\\');
                ds.append_char('"');
            default:
                ds.append_char(c);
        }
    }
    ds.append_char('"');
    return ds.copy_str(allocator);
} // fn void String.quote(&self) //
