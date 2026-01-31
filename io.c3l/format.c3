module my::templates::fmt;
import std::core::ascii;
import libc;
import std::collections::map;
import std::collections::list;
import my::collections::arg;
import string_utils::su;
import std::core::mem;
import std::core::mem::allocator @public;
import std::math;
import my::loc;
import std::io;
import my::debug::dbg;


const int FMT_NTOA_BUFFER_SIZE = 256;

interface Fmtable
{
	fn String to_constant_fmt_string() @optional;
	fn usz? to_fmt(Fmter* fmter) @optional;
}

faultdef BUFFER_EXCEEDED, INTERNAL_BUFFER_EXCEEDED, INVALID_FORMAT,
         NOT_ENOUGH_ARGUMENTS, INVALID_ARGUMENT, NUMERIC_ARG_SPEC_OUT_OF_BOUNDS, 
         BODY_MUST_BE_AN_IDENIFIER_OR_NUMBER, ERROR_WIDTH_CANNOT_BE_NEGATIVE, 
         ERROR_PRECISION_CANNOT_BE_NEGATIVE, ERROR_CLOSE_BRACKET_NOT_FOUND, 
         ERROR_BASE_VALUE_UNACCEPTABLE_BASE_MUST_BE_GT_ONE, 
         ERROR_BASE_TOO_LARGE_MUST_BE_BETWEEN_TWO_AND_THIRTY_SIX, 
         ERROR_MISSING_CLOSING_MAIN_BRACE, POSITIONAL_ARGUMENTS_EXHUSTED_FORMAT_EXCEEDS_SUPPLY;

alias OutputFn = fn void?(void* buffer, char c);
alias FloatType = double;


macro bool is_struct_with_default_fmt($Type)
{
	return ($Type.kindof == STRUCT ||| $Type.kindof == BITSTRUCT)
		&&& !$defined($Type.to_fmt)
		&&& !$defined($Type.to_constant_fmt_string);
}

<*
 Introspect a struct and print it to a fmter

 @require $kindof(value) == STRUCT || $kindof(value) == BITSTRUCT : `This macro is only valid on macros`
*>
macro usz? struct_to_fmt(value, Fmter* f, bool $force_dump)
{
    var $Type = $typeof(value);
    usz total = f.print("{ ")!;
    $foreach $i, $member : $Type.membersof:
        $if $i > 0:
            total += f.print(", ")!;
        $endif
        $if $member.nameof != "":
            total += f.printf("%s: ", $member.nameof)!;
		$endif
		$if ($force_dump &&& ($member.typeid.kindof == STRUCT || $member.typeid.kindof == BITSTRUCT)) |||
			is_struct_with_default_fmt($member.typeid):
			total += struct_to_fmt($member.get(value), f, $force_dump)!;
		$else
			total += f.printf("%s", $member.get(value))!;
		$endif
	$endforeach
	return total + f.print(" }");
}

fn usz? ReflectedParam.to_fmt(&self, Fmter* f) @dynamic
{
	return f.printf("[Parameter '{:s}']", self.name);
}

macro usz? Fmter.printf(&self, String format, ...)
{
    ArgHash named;
    named.init(mem); 
    any[$vacount] args;
    $for var $i = 0; $i < $vacount; $i++:
        $switch($typeof($vaarg[$i])):
            $case NameArgPair*:
                named.set(($vaarg[$i]).name, (*$vaarg[$i]).arg);
            $case NameArgPair:
                named.set($vaarg[$i].name, $vaarg[$i].arg);
            $case ArgHash*:
                named.put_all_for_create($vaarg[$i]);
            $case ArgHash:
                named.put_all_for_create(&$vaarg[$i]);
            $default:
                args[$i] = any_make(&$vaarg[$i], $typeof($vaarg[$i]));
        $endswitch
    $endfor
	return self.vsprintf(format, args[..], named) @inline;
}

//                                   Normal spec       DateTime            Range (Array, Vector or Slice) //
enum  FmtSpec : const inline char { REGULARSPEC = 0x0, DATETIMESPEC = 0x1, RANGESPEC = 0x2, }

struct Fmter
{
	void *data;
	OutputFn out_fn;
    bool* debug;
	struct
	{
		FmtFlags flags;
		uint     width;
		uint     prec;
        char     fill;
        char     conversion;
        String   datetimespec;
		fault    first_fault;
	}
}

//                                                       '<'            '^'          '>'          //
enum FmtAlignment : const inline char { NOPADDING = 0x0, LEFT = 0x1, CENTRE = 0x2, RIGHT = 0x3    }

//                                        '-'             '_'          '0'        //
enum FmtPadding   : const inline char { NOSPACES = 0x0, SPACES = 0x1, ZEROS = 0x2 }

//                                        '-'             '+'              ' '            //
enum FmtSign      : const inline char { ONLY_NEGS = 0x0, BOTH = 0x1, SPACE_OR_MINUS = 0x2 }

bitstruct FmtFlags : uint
{
    FmtSpec      stype           : 0..1;
	FmtPadding   padding         : 2..3;
	FmtAlignment alignment       : 4..5;
	FmtSign      sign            : 6..7;
	bool         alternate       : 8;
	bool         uppercase       : 9;
	bool         precision       : 10;
    bool         usebracketing   : 11;
    bool         range_as_string : 12;
    bool         use_locale      : 13;
    bool         zero_padding    : 14;
}


fn void Fmter.init(&self, OutputFn out_fn, void* data = null, bool* debug = &gdebug)
{
	*self = { .data = data, .out_fn = out_fn, .debug = debug};
}

fn usz? Fmter.out(&self, char c) @private
{
	if (catch err = self.out_fn(self.data, c))
	{
		if (self.first_fault) return self.first_fault~;
		self.first_fault = err;
		return err~;
	}
	return 1;
}

fn usz? Fmter.print_with_function(&self, Fmtable arg)
{
	if (&arg.to_fmt)
	{
		FmtFlags old = self.flags;
		uint old_width = self.width;
		uint old_prec = self.prec;
		defer
		{
			self.flags = old;
			self.width = old_width;
			self.prec = old_prec;
		}
		if (!arg) return self.out_substr("(null)");
		return arg.to_fmt(self);
	}
	if (&arg.to_constant_fmt_string)
	{
		FmtFlags old = self.flags;
		uint old_width = self.width;
		uint old_prec = self.prec;
		defer
		{
			self.flags = old;
			self.width = old_width;
			self.prec = old_prec;
		}
		if (!arg) return self.out_substr("(null)");
		return self.out_substr(arg.to_constant_fmt_string());
	}
	return NOT_FOUND~;
}

fn usz? Fmter.out_unknown(&self, String category, any arg) @private
{
	return self.out_substr("<") + self.out_substr(category) + self.out_substr(" type:")
                            + self.ntoa((iptr)arg.type, false, 16) + self.out_substr(", addr:")
                                            + self.ntoa((iptr)arg.ptr, false, 16) + self.out_substr(">");
}

fn usz? Fmter.out_str(&self, any arg) @private {
	switch(arg.type.kindof){
		case VOID:
			return self.out_substr("void");
		case FAULT:
			fault f = *(fault*)arg.ptr;
			return self.out_substr(f ? f.nameof : "(empty-fault)");
		case INTERFACE:
			any a = *(any*)arg;
			return a ? self.out_str(a) : self.out_substr("(empty-interface)");
		case ANY:
			any a = *(any*)arg;
			return a ? self.out_str(a) : self.out_substr("(empty-any)");
		case OPTIONAL:
			unreachable();
		case SIGNED_INT:
		case UNSIGNED_INT:
			FmtFlags flags = self.flags;
			uint width = self.width;
			defer{
				self.flags = flags;
				self.width = width;
			}
			self.flags = {};
            self.flags.usebracketing = true;
			self.width = 0;
			return self.ntoa_any(arg, 10) ?? self.out_substr("<INVALID>");
		case FLOAT:
			FmtFlags flags = self.flags;
			uint width = self.width;
			defer{
				self.flags = flags;
				self.width = width;
			}
			self.flags = {};
            self.flags.usebracketing = true;
			self.width = 0;
			return self.ftoa(float_from_any(arg)) ?? self.out_substr("ERR");
		case BOOL:
			return self.out_substr(*(bool*)arg.ptr ? "true" : "false");
		default:
	}
	usz? n = self.print_with_function((Fmtable)arg);
	if (try n) return n;
	if (@catch(n) != NOT_FOUND) n!;
	switch(arg.type.kindof){
		case TYPEID:
			return self.out_substr("typeid[")!
                                + self.ntoa((iptr)*(typeid*)arg, false, 16)! + self.out_substr("]")!;
		case ENUM:
			usz i = types::any_to_enum_ordinal(arg, usz)!!;
			assert(i < arg.type.names.len, "Illegal enum value found, numerical value was %d.", i);
			return self.out_substr(arg.type.names[i]);
		case STRUCT:
			return self.out_unknown("struct", arg);
		case UNION:
			return self.out_unknown("union", arg);
		case BITSTRUCT:
			return self.out_unknown("bitstruct", arg);
		case FUNC:
			FmtFlags flags = self.flags;
			uint width = self.width;
			defer{
				self.flags = flags;
				self.width = width;
			}
			self.width = 0;
			return self.out_substr("0x")! + self.ntoa_any(arg, 16);
		case CONST_ENUM:
		case DISTINCT:
			if (arg.type == String.typeid)
			{
				return self.out_substr(*(String*)arg);
			}
			if(arg.type == ZString.typeid){
				return self.out_substr(*(ZString*)arg ? ((ZString*)arg).str_view() : "(null)");
			}
			if(arg.type == DString.typeid){
				return self.out_substr(*(DString*)arg ? ((DString*)arg).str_view() : "(null)");
			}
			return self.out_str(arg.as_inner());
		case POINTER:
			typeid inner = arg.type.inner;
			void** pointer = arg.ptr;
			if (arg.type.inner != void.typeid)
			{
				any deref = any_make(*pointer, inner);
				n = self.print_with_function((Fmtable)deref);
				if (try n) return n;
				if (@catch(n) != NOT_FOUND) n!;
			}
			FmtFlags flags = self.flags;
			uint width = self.width;
			defer{
				self.flags = flags;
				self.width = width;
			}
			self.width = 0;
			return self.out_substr("0x")! + self.ntoa_any(arg, 16);
		case ARRAY:
			// this is SomeType[*] so grab the "SomeType"
			FmtFlags flags = self.flags;
			uint width = self.width;
            //*
			defer{
				self.flags = flags;
				self.width = width;
			}
			self.flags = {};
            self.flags.usebracketing = true;
			self.width = 0;
            // */
			typeid inner = arg.type.inner;
			usz size = inner.sizeof;
			usz alen = arg.type.len;
			// Pretend this is a String
			void* ptr = (void*)arg.ptr;
            usz len = 0;
			if(self.flags.usebracketing) len = self.out('[')!;
			for (usz i = 0; i < alen; i++)
			{
				if (i != 0) len += self.out_substr(", ")!;
				len += self.out_str(any_make(ptr, inner))!;
				ptr += size;
			}
			if(self.flags.usebracketing) len += self.out(']')!;
			return len;
		case VECTOR:
			FmtFlags flags = self.flags;
			uint width = self.width;
            //*
			defer{
				self.flags = flags;
				self.width = width;
			}
			self.flags = {};
            self.flags.usebracketing = true;
			self.width = 0;
            // */
			// this is SomeType[*] so grab the "SomeType"
			typeid inner = arg.type.inner;
			usz size = inner.sizeof;
			usz vlen = arg.type.len;
			// Pretend this is a String
			void* ptr = (void*)arg.ptr;
            usz len = 0;
			if(self.flags.usebracketing) len = self.out_substr("[<")!;
			for(usz i = 0; i < vlen; i++){
				if (i != 0) len += self.out_substr(", ")!;
				len += self.out_str(any_make(ptr, inner))!;
				ptr += size;
			}
			if(self.flags.usebracketing) len += self.out_substr(">]")!;
			return len;
		case SLICE:
			// this is SomeType[] so grab the "SomeType"
			typeid inner = arg.type.inner;
			if(inner == void.typeid) inner = char.typeid;
			FmtFlags flags = self.flags;
			uint width = self.width;
            //*
			defer{
				self.flags = flags;
				self.width = width;
			}
			self.flags = {};
            self.flags.usebracketing = true;
			self.width = 0;
            // */
			usz size = inner.sizeof;
			// Pretend this is a String
			String* temp = (void*)arg.ptr;
			void* ptr = (void*)temp.ptr;
			usz slen = temp.len;
            usz len = 0;
			if(self.flags.usebracketing) len = self.out('[')!;
			for(usz i = 0; i < slen; i++){
				if (i != 0) len += self.out_substr(", ")!;
				len += self.out_str(any_make(ptr, inner))!;
				ptr += size;
			}
			if(self.flags.usebracketing) len += self.out(']')!;
			return len;
		case ANY:
		case INTERFACE:
			unreachable("Already handled");
		default:
	}
	return self.out_substr("Invalid type");
}




fn void? out_null_fn(void* data @unused, char c @unused) @private
{
}

macro usz? @report_fault(Fmter* f, $fault)
{
	(void)f.out_substr($fault);
	return INVALID_FORMAT~;
}

macro usz? @wrap_bad(Fmter* f, #action)
{
	usz? len = #action;
	if (catch err = len)
	{
		switch (err)
		{
			case BUFFER_EXCEEDED:
        	case INTERNAL_BUFFER_EXCEEDED:
        		return f.first_err(err)~;
        	default:
				err = f.first_err(INVALID_ARGUMENT);
        		f.out_substr("<INVALID>")!;
        		return err~;
		}
	}
	return len;
}

alias ArgHash     = map::HashMap{String, any*};
alias ArgList     = List {any*};
alias ArgMapEntry = Entry {String, any*};

fn usz? Fmter.vsprintf(&self, String format, any[] anys, ArgHash named){
    if(self.fill == 0) self.fill = ' ';
    const  char     BEGIN  = '{'; // using these as is messes up my editors //
    const  char     END    = '}'; // bracket matching so I tokenise these   //
	self.first_fault = {};
	if(!self.out_fn){
		// use null output function
		self.out_fn = &out_null_fn;
	}
	usz    total_len;
	usz    format_len      = format.len;
	usz    variant_index   = 0;
    any    arg;
    char*  endptr;
    int128 num;
	for MAIN: (usz i = 0; i < format_len; i++){
		// format specifier?  %[flags][width][.precision][length]
		char c = format[i];
		if(c == BEGIN){
            if(i + 1 < format_len){
                char peek = format[i + 1];
                if(peek == BEGIN){
                    total_len += self.out(c)!; // just a quoted BEGIN //
                    continue;
                }
            }else{
                return ERROR_MISSING_CLOSING_MAIN_BRACE~;
            }
		}else{ // c != BEGIN //
			total_len += self.out(c)!;
			continue;
        }
		i++; // jump over BEGIN //
		if(i >= format_len) return @report_fault(self, "%ERR");
		c = format[i];
		// evaluate flags
        dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                        " i == %d\n format_len == `%d'",
                $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len);
		self.flags = {};
        self.flags.usebracketing = true;
        DString body;
        while(c != END && c != BEGIN && c != ':' && i < format_len){
            body.append_char(c);
            i++;
            if(i >= format_len) return @report_fault(self, "%ERR");
            c = format[i];
        }
        dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                            " i == %d\n format_len == `%d'\n body == `%s'",
                    $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len, body);
        if(c == END || c == ':'){
            if(body.len() == 0){
                if(variant_index >= anys.len){
                    return POSITIONAL_ARGUMENTS_EXHUSTED_FORMAT_EXCEEDS_SUPPLY~;
                }
                arg = anys[variant_index++];
            }else{
                endptr  = null;
                ZString chunk  = body.zstr_view();
                long? n = chunk.strtol(&endptr, 0);
                if(catch num_excuse = n){
                    return num_excuse~;
                }else{
                    num = n;
                }
                // check if all of chunk was consumed by strtol() //
                if(endptr != null && (endptr - (char*)chunk) == chunk.len()){ 
                    if(num < 0 || num >= anys.len){
                        return NUMERIC_ARG_SPEC_OUT_OF_BOUNDS~;
                    } // 0 ≤ num < args.len //
                    arg = anys[(long)num]; // it was the number of an arg //
                }else if(endptr != null && ((endptr - (char*)chunk) == 0)){
                    String name = body.str_view();
                    if(name.is_identifier()){ // body is an identifier //
                        dbg::eprintfn("%s[%d]«%s» name == `%s'", $$FILE, $$LINE, $$FUNC, name);
                        dbg::eprintfn("%s[%d]«%s» named == `%s'", $$FILE, $$LINE, $$FUNC, named);
                        any*? a = named[name];
                        if(catch excuse = a){
                            return excuse~;
                        }else{
                            arg = *a;
                            dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                            " i == %d\n format_len == `%d'\n arg == `%s'",
                            $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len, arg);
                        }
                    }else{
                        return BODY_MUST_BE_AN_IDENIFIER_OR_NUMBER~;
                    }
                }else{
                    return BODY_MUST_BE_AN_IDENIFIER_OR_NUMBER~;
                }
            }
        } // if(c == END || c == ':') // got the arg //
        dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                            " i == %d\n format_len == `%d'",
                                    $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len);
        if(c == ':'){
            if(i >= format_len) return @report_fault(self, "%ERR");
            i++;
            c = format[i]; // jump over ':' //
            dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                            " i == %d\n format_len == `%d'",
                                    $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len);
            if(arg.is_date_time_arg() && format.is_date_time_spec(c, i)){
                dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                " i == %d\n format_len == `%d'",
                        $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len);
                self.flags.stype = FmtSpec.DATETIMESPEC;
                if(i + 1 < format_len){
                    char peek = format[i + 1];
                    dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                            " i == %d\n format_len == `%d'\n peek == %c",
                        $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len, peek);
                    if("<^>".contains_char(peek)){
                        self.fill = c;
                        i++;
                        c = format[i];
                        self.flags.alignment = c.alignment_value();
                    }else if("<^>".contains_char(c)){
                        self.flags.alignment = c.alignment_value();
                        dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                        " i == %d\n format_len == `%d'\n self.flags.alignment == `%c'",
                                    $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len, 
                                self.flags.alignment);
                    }
                }else if("<^>".contains_char(c)){
                    self.flags.alignment = c.alignment_value();
                    dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                        " i == %d\n format_len == `%d'\n self.flags.alignment == `%c'",
                                    $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len, 
                                self.flags.alignment);
                }
                i++;
                if(i >= format_len) return @report_fault(self, "%ERR");
                c = format[i];
                self.width = 0;
                dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                " i == %d\n format_len == `%d'",
                        $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len);
                long? w = format.get_width_or_precision(&c, &i, anys,
                                                                &variant_index, named, true, true);
                if(catch width_excuse = w){
                    return width_excuse~;
                }else{
                    if(w < 0) return ERROR_WIDTH_CANNOT_BE_NEGATIVE~;
                    self.width = (uint)w;
                }
                if(c == '.'){
                    self.flags.precision = true;
                    self.prec = 0;
                    dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                    " i == %d\n format_len == `%d'",
                            $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len);
                    long? p = format.get_width_or_precision(&c, &i, anys,
                                                                &variant_index, named, false, true);
                    if(catch prec_excuse = p){
                        return prec_excuse~;
                    }else{
                        if(p < 0) return ERROR_PRECISION_CANNOT_BE_NEGATIVE~;
                        self.prec = (uint)p;
                    }
                }
                if(c == ':'){
                    i++;
                    if(i >= format_len) return @report_fault(self, "%ERR");
                    c = format[i]; // jump over ':' //
                    DString ds;
                    while(c != END && i < format_len){
                        ds.append_char(c);
                        i++;
                        if(i >= format_len) return @report_fault(self, "%ERR");
                        c = format[i];
                    }
                    self.datetimespec = ds.str_view();
                }
                usz size = 512; 
                char* dest = allocator::malloc(mem, size);
                defer allocator::free(mem, dest);
                libc::Tm tm;
                if(arg.type == libc::Tm.typeid){
                    tm = *(libc::Tm*)(arg.ptr);
                }else if(arg.type == libc::Time_t.typeid){
                    tm = *libc::localtime((libc::Time_t*)arg.ptr);
                }else if(arg.type == libc::TimeSpec.typeid){ // TimeSpec contains a Time_t //
                    tm = *libc::localtime(&(*((libc::TimeSpec*)arg.ptr)).s);
                }
                /*
                dbg::eprintfn("%s[%d]«%s» self.datetimespec == `%s'",
                                        $$FILE, $$LINE, $$FUNC, self.datetimespec);
                // */
                usz r = libc::strftime(dest, size, self.datetimespec.zstr_tcopy(), &tm);
                if(self.fill == 0) self.fill = ' ';
                String res = (String)dest[:r];
                if(self.flags.precision){
                    usz padding = max(self.width, self.prec);
                    switch(self.flags.alignment){
                        case FmtAlignment.NOPADDING:
                            total_len += self.out_substr(res)!;
                        case FmtAlignment.LEFT:
                            total_len += self.out_substr(res)!;
                            if(padding > res.len) total_len += self.pad(self.fill, padding, res.len)!;
                        case FmtAlignment.CENTRE:
                            padding -= res.len;
                            if(padding > 0){
                                bool odd    = (bool)(padding & 0x0000000000000001);
                                padding /= 2;
                                total_len += self.pad2(self.fill, padding + (usz)odd)!;
                            }
                            total_len += self.out_substr(res)!;
                            if(padding > 0) total_len += self.pad2(self.fill, padding)!;
                        case FmtAlignment.RIGHT:
                            if(padding > res.len) total_len += self.pad(self.fill, padding, res.len)!;
                            total_len += self.out_substr(res)!;
                    }
                }else{
                    total_len += self.out_substr(res)!;
                }
                continue MAIN;
            }else if(arg.is_range_arg()){ // arg is a range argument //
                dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                " i == %d\n format_len == `%d'",
                        $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len);
                self.flags.stype = FmtSpec.RANGESPEC;
                if(c == 'n'){
                    self.flags.usebracketing = true;
                    i++;
                    if(i >= format_len) return @report_fault(self, "%ERR");
                    c = format[i];
                }
                switch(c){
                    case 's':
                        self.flags.range_as_string = true;
                        i++;
                        if(i >= format_len) return @report_fault(self, "%ERR");
                        c = format[i];
                    case '?':
                        i++;
                        if(i >= format_len) return @report_fault(self, "%ERR");
                        c = format[i];
                        if(c == 's'){
                            self.flags.range_as_string = true;
                            *(self.debug)              = true;
                            i++;
                            if(i >= format_len) return @report_fault(self, "%ERR");
                            c = format[i];
                        }
                } // switch(c) //
                if(i >= format_len) return @report_fault(self, "%ERR");
                if(c == ':'){
                    if(i >= format_len) return @report_fault(self, "%ERR");
                    i++;
                    c = format[i];
                }
                if(i + 1 < format_len){
                    char peek = format[i + 1];
                    if("<^>".contains_char(peek)){
                        self.fill = c;
                        i++;
                        if(i >= format_len) return @report_fault(self, "%ERR");
                        c = format[i];
                        self.flags.alignment = c.alignment_value();
                    }else if("<^>".contains_char(c)){
                        self.flags.alignment = c.alignment_value();
                        i++;
                        if(i >= format_len) return @report_fault(self, "%ERR");
                        c = format[i];
                        if(i >= format_len) return @report_fault(self, "%ERR");
                    }
                }else if("<^>".contains_char(c)){
                    self.flags.alignment = c.alignment_value();
                    i++;
                    if(i >= format_len) return @report_fault(self, "%ERR");
                    c = format[i];
                    if(i >= format_len) return @report_fault(self, "%ERR");
                }
                switch(c){
                    case '+':
                        self.flags.sign = FmtSign.BOTH;
                        i++;
                        if(i >= format_len) return @report_fault(self, "%ERR");
                        c = format[i];
                        if(i >= format_len) return @report_fault(self, "%ERR");
                    case '-':
                        self.flags.sign = FmtSign.ONLY_NEGS;
                        i++;
                        if(i >= format_len) return @report_fault(self, "%ERR");
                        c = format[i];
                    case ' ':
                        self.flags.sign = FmtSign.SPACE_OR_MINUS;
                        i++;
                        if(i >= format_len) return @report_fault(self, "%ERR");
                        c = format[i];
                }
                if(c == '#'){
                    self.flags.alternate = true;
                    i++;
                    if(i >= format_len) return @report_fault(self, "%ERR");
                    c = format[i];
                }
                if(c == '0'){
                    self.flags.zero_padding = true;
                    i++;
                    if(i >= format_len) return @report_fault(self, "%ERR");
                    c = format[i];
                }
                self.width = 0;
                dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                " i == %d\n format_len == `%d'",
                        $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len);
                long? w = format.get_width_or_precision(&c, &i, anys,
                                                                &variant_index, named, true, false);
                if(catch width_excuse = w){
                    return width_excuse~;
                }else{
                    if(w < 0) return ERROR_WIDTH_CANNOT_BE_NEGATIVE~;
                    self.width = (uint)w;
                }
                if(c == '.'){
                    self.flags.precision = true;
                    self.prec = 0;
                    dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                    " i == %d\n format_len == `%d'",
                            $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len);
                    long? p = format.get_width_or_precision(&c, &i, anys,
                                                                &variant_index, named, false, false);
                    if(catch prec_excuse = p){
                        return prec_excuse~;
                    }else{
                        if(p < 0) return ERROR_PRECISION_CANNOT_BE_NEGATIVE~;
                        self.prec = (uint)p;
                    }
                }
                if(c == 'L'){
                   self.flags.use_locale = true;
                    i++;
                    if(i >= format_len) return @report_fault(self, "%ERR");
                    c = format[i];
                }
                if(c == '?' || c.is_conversion_char()){
                    self.conversion = c;
                    //*
                    i++;
                    if(i >= format_len) return @report_fault(self, "%ERR");
                    c = format[i];
                    // */
                }
                total_len += self.out_str(arg)!;
                continue MAIN;
            }else{ // not a datetime or a range type //
                dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                " i == %d\n format_len == `%d'",
                        $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len);
                self.flags.stype = FmtSpec.REGULARSPEC;
                if(i + 1 < format_len){
                    char peek = format[i + 1];
                    dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                    " i == %d\n format_len == `%d'\n peek == `%c'",
                            $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len, peek);
                    if("<^>".contains_char(peek)){
                        self.fill = c;
                        i++;
                        self.flags.alignment = c.alignment_value();
                        c = format[i];
                        dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n i == %d\n"
                                " format_len == `%d'\n self.fill == `%c'\n self.flags.alignment == `%s'",
                                $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len, 
                                         self.fill, self.flags.alignment);
                        i++;
                        if(i >= format_len) return @report_fault(self, "%ERR");
                        c = format[i];
                    }else if("<^>".contains_char(c)){
                        self.flags.alignment = c.alignment_value();
                        i++;
                        if(i >= format_len) return @report_fault(self, "%ERR");
                        c = format[i];
                    }
                }else if("<^>".contains_char(c)){
                    self.flags.alignment = c.alignment_value();
                    i++;
                    if(i >= format_len) return @report_fault(self, "%ERR");
                    c = format[i];
                }
                switch(c){
                    case '+':
                        self.flags.sign = FmtSign.BOTH;
                        i++;
                        if(i >= format_len) return @report_fault(self, "%ERR");
                    c = format[i];
                    case '-':
                        self.flags.sign = FmtSign.ONLY_NEGS;
                        i++;
                        if(i >= format_len) return @report_fault(self, "%ERR");
                        c = format[i];
                    case ' ':
                        self.flags.sign = FmtSign.SPACE_OR_MINUS;
                        i++;
                        if(i >= format_len) return @report_fault(self, "%ERR");
                        c = format[i];
                }
                if(c == '#'){
                    self.flags.alternate = true;
                    i++;
                    if(i >= format_len) return @report_fault(self, "%ERR");
                    c = format[i];
                }
                if(c == '0'){
                    self.flags.zero_padding = true;
                    i++;
                    if(i >= format_len) return @report_fault(self, "%ERR");
                    c = format[i];
                }
                self.width = 0;
                dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                " i == %d\n format_len == `%d'",
                        $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len);
                long? w = format.get_width_or_precision(&c, &i, anys,
                                                                &variant_index, named, true, false);
                if(catch width_excuse = w){
                    return width_excuse~;
                }else{
                    if(w < 0) return ERROR_WIDTH_CANNOT_BE_NEGATIVE~;
                    self.width = (uint)w;
                    dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                    " i == %d\n format_len == `%d'\n w == `%d'",
                            $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len, w);
                }
                if(c == '.'){
                    self.flags.precision = true;
                    self.prec = 0;
                    dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                    " i == %d\n format_len == `%d'",
                            $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len);
                    long? p = format.get_width_or_precision(&c, &i, anys,
                                                                &variant_index, named, false, false);
                    if(catch prec_excuse = p){
                        return prec_excuse~;
                    }else{
                        if(p < 0) return ERROR_PRECISION_CANNOT_BE_NEGATIVE~;
                        self.prec = (uint)p;
                        dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                        " i == %d\n format_len == `%d'\n p == `%d'",
                                $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len, p);
                    }
                }
                dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                " i == %d\n format_len == `%d'",
                        $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len);
                if(c == 'L'){
                   self.flags.use_locale = true;
                    i++;
                    if(i >= format_len) return @report_fault(self, "%ERR");
                    c = format[i];
                }
                dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                " i == %d\n format_len == `%d'",
                        $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len);
                /*
                if(c == '?' || c.is_conversion_char()){
                    self.conversion = c;
                    //*
                    i++;
                    if(i >= format_len) return @report_fault(self, "%ERR");
                    c = format[i];
                    // */
                }
                // */
            }
        } // done parsing for regular type arg //
        if(i + 1 < format_len){
            char peek = format[i + 1];
            char back = format[i - 1];
            dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                            " i == %d\n format_len == `%d'\n peek == `%c'\n back == `%c'",
                                $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len, peek, back);
        }
        uint base;
        bool closing_brace_already_found = false;
		switch(c){
            case END:
                closing_brace_already_found = true;
                dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                " i == %d\n format_len == `%d'",
                        $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len);
                nextcase;
			case 's':
				if(self.flags.alignment == FmtAlignment.LEFT){
					usz len = self.out_str(arg)!;
					total_len += len;
					total_len += self.pad(' ', self.width, len)!;
                    if(closing_brace_already_found) continue;
                    i++;
                    if(i >= format_len) return @report_fault(self, "%ERR");
                    c = format[i];
                    if(c != END) return ERROR_MISSING_CLOSING_MAIN_BRACE~;
					continue;
				}else if(self.flags.alignment == FmtAlignment.CENTRE){
                    DString ds;
                    ds.appendf("%s", arg); // TODO: get rid of this kludge?? //
                    isz padding = self.width - ds.len();
                    if(padding > 0){
                        bool odd = (bool)(padding & 0x0000000000000001);
                        padding /= 2;
                        total_len += self.pad2(self.fill, padding + (isz)odd)!;
                        usz len = self.out_str(arg)!;
                        total_len += len;
                        total_len += self.pad2(self.fill, padding)!;
                    }
                    if(closing_brace_already_found) continue;
                    i++;
                    if(i >= format_len) return @report_fault(self, "%ERR");
                    c = format[i];
                    if(c != END) return ERROR_MISSING_CLOSING_MAIN_BRACE~;
					continue;
                }
				if(self.width){
					OutputFn out_fn = self.out_fn;
					self.out_fn = (OutputFn)&out_null_fn;
					usz len = self.out_str(arg)!;
					self.out_fn = out_fn;
					total_len += self.pad(' ', self.width, len)!;
				}
				total_len += self.out_str(arg)!;
                if(closing_brace_already_found) continue;
                i++;
                if(i >= format_len) return @report_fault(self, "%ERR");
                c = format[i];
                if(c != END) return ERROR_MISSING_CLOSING_MAIN_BRACE~;
				continue;
			case 'R':
                self.flags.uppercase = true;
                nextcase;
			case 'r':
                i++;
                if(i >= format_len) return @report_fault(self, "%ERR");
                c = format[i];
                const char OPEN  = '(';
                const char CLOSE = ')';
                if(c == OPEN){
                    i++;
                    if(i >= format_len) return @report_fault(self, "%ERR");
                    c = format[i];
                }
                long? number = format.strtol(&endptr, 10);
                if(catch base_excuse = number){
                    return base_excuse~;
                }else{
                    if(number <= 0) return ERROR_BASE_VALUE_UNACCEPTABLE_BASE_MUST_BE_GT_ONE~;
                    if(number > 36) return ERROR_BASE_TOO_LARGE_MUST_BE_BETWEEN_TWO_AND_THIRTY_SIX~;
                    base = (uint)number;
                }
                if(c != CLOSE) return ERROR_CLOSE_BRACKET_NOT_FOUND~;
			case 'd':
				base = 10;
				self.flags.alternate = false;
			case 'X' :
				self.flags.uppercase = true;
				nextcase;
			case 'x' :
				base = 16;
			case 'O':
				self.flags.uppercase = true;
				nextcase;
			case 'o' :
				base = 8;
			case 'B':
				self.flags.uppercase = true;
				nextcase;
			case 'b' :
				base = 2;
			case 'A':
				self.flags.uppercase = true;
				nextcase;
			case 'a':
				total_len += @wrap_bad(self, self.atoa(float_from_any(arg)))!;
                i++;
                if(i >= format_len) return ERROR_MISSING_CLOSING_MAIN_BRACE~;
                c = format[i];
                if(c != END) return ERROR_MISSING_CLOSING_MAIN_BRACE~;
				continue;
			case 'F' :
				self.flags.uppercase = true;
				nextcase;
			case 'f':
				total_len += @wrap_bad(self, self.ftoa(float_from_any(arg)))!;
                i++;
                if(i >= format_len) return @report_fault(self, "%ERR");
                c = format[i];
                if(c != END) return ERROR_MISSING_CLOSING_MAIN_BRACE~;
				continue;
			case 'E':
				self.flags.uppercase = true;
				nextcase;
			case 'e':
				total_len += @wrap_bad(self, self.etoa(float_from_any(arg)))!;
                i++;
                if(i >= format_len) return @report_fault(self, "%ERR");
                c = format[i];
                if(c != END) return ERROR_MISSING_CLOSING_MAIN_BRACE~;
				continue;
			case 'G':
				self.flags.uppercase = true;
				nextcase;
			case 'g':
                dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                " i == %d\n format_len == `%d'",
                        $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len);
				total_len += @wrap_bad(self, self.gtoa(float_from_any(arg)))!;
                dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                " i == %d\n format_len == `%d'",
                        $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len);
                i++;
                if(i >= format_len) return @report_fault(self, "%ERR");
                c = format[i];
                if(c != END) return ERROR_MISSING_CLOSING_MAIN_BRACE~;
				continue;
			case 'c':
				total_len += self.out_char(arg)!;
                i++;
                if(i >= format_len) return @report_fault(self, "%ERR");
                c = format[i];
                if(c != END) return ERROR_MISSING_CLOSING_MAIN_BRACE~;
				continue;
			case 'H':
				self.flags.uppercase = true;
				nextcase;
			case 'h':
            	char[] out @noinit;
				switch (arg.type)
				{
					case char[]:
					case ichar[]:
						out = *(char[]*)arg;
					default:
						if (arg.type.kindof == ARRAY
                               && (arg.type.inner == char.typeid || arg.type.inner == ichar.typeid)){
							out = ((char*)arg.ptr)[:arg.type.sizeof];
							break;
						}
						if (arg.type.kindof == POINTER)
						{
							out = ((*(char**)arg.ptr))[:arg.type.inner.sizeof];
							break;
						}
						total_len += self.out_substr("<INVALID>")!;
                        i++;
                        if(i >= format_len) return @report_fault(self, "%ERR");
                        c = format[i];
                        if(c != END) return ERROR_MISSING_CLOSING_MAIN_BRACE~;
						continue;
				}
				if(self.flags.alignment == FmtAlignment.LEFT){
					usz len = print_hex_chars(self, out, self.flags.uppercase)!;
					total_len += len;
					total_len += self.pad(self.fill, self.width, len)!;
                    i++;
                    if(i >= format_len) return @report_fault(self, "%ERR");
                    c = format[i];
                    if(c != END) return ERROR_MISSING_CLOSING_MAIN_BRACE~;
					continue;
				}else if(self.flags.alignment == FmtAlignment.CENTRE){
                    isz padding = self.width - out.len;
                    if(padding > 0){
                        bool odd = (bool)(padding & 0x0000000000000001);
                        padding /= 2;
                        total_len += self.pad2(self.fill, padding + (isz)odd)!;
                        usz len = print_hex_chars(self, out, self.flags.uppercase)!;
                        total_len += len;
                        total_len += self.pad2(self.fill, padding)!;
                    }
                    i++;
                    if(i >= format_len) return @report_fault(self, "%ERR");
                    c = format[i];
                    if(c != END) return ERROR_MISSING_CLOSING_MAIN_BRACE~;
					continue;
                }
				if(self.width){
					total_len += self.pad(' ', self.width, out.len * 2)!;
				}
				total_len += print_hex_chars(self, out, self.flags.uppercase)!;
                i++;
                if(i >= format_len) return @report_fault(self, "%ERR");
                c = format[i];
                if(c != END) return ERROR_MISSING_CLOSING_MAIN_BRACE~;
				continue;
			case 'p':
				self.flags.sign      = FmtSign.BOTH;
				self.flags.alternate = true;
				base = 16;
			default:
                dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                                " i == %d\n format_len == `%d'",
                        $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len);
				self.first_err(INVALID_FORMAT);
				total_len += self.out_substr("<BAD FORMAT>")!;
                i++;
                if(i >= format_len) return @report_fault(self, "%ERR");
                c = format[i];
                if(c != END) return ERROR_MISSING_CLOSING_MAIN_BRACE~;
				continue;
		} // switch(c) //
		if(base != 10){
			self.flags.sign = FmtSign.ONLY_NEGS;
			//self.flags.padding = FmtPadding.SPACES;
		}
		// ignore '0' flag when precision is given
		if(self.flags.precision) self.flags.padding = FmtPadding.SPACES;

		bool is_neg;
		total_len += @wrap_bad(self, self.ntoa(int_from_any(arg, &is_neg), is_neg, base))!;
        if(i >= format_len) return @report_fault(self, "%ERR");
        i++;
        if(i >= format_len) return @report_fault(self, "%ERR");
        c = format[i];
        dbg::eprintfn("%s[%d]«%s» format[i:format_len - i] == `%s'\n c == `%c'\n"
                        " i == %d\n format_len == `%d'",
                $$FILE, $$LINE, $$FUNC, format[i:format_len - i], c, i, format_len);
	} // for MAIN: (usz i = 0; i < format_len; i++) //
	// termination
	//	out((char)0, buffer, idx < maxlen ? idx : maxlen - 1U, maxlen);

	// return written chars without terminating \0
	if(self.first_fault) return self.first_fault~;
	return total_len;
}


fn usz? Fmter.print(&self, String str){
	if(!self.out_fn){
		// use null output function
		self.out_fn = &out_null_fn;
	}
	foreach(c : str) self.out(c)!;
	return str.len;
}

fn void? out_string_append_fn(void* data, char c) @private
{
	DString* s = data;
	s.append_char(c);
}

bool gdebug = false;

macro String? format(String fmt_str, ...){
    DString ds;
    Fmter f;
    f.init(&out_string_append_fn, &ds, &gdebug);
    ArgHash named;
    named.init(mem); 
    any[$vacount] args;
    $for var $i = 0; $i < $vacount; $i++:
        $switch($typeof($vaarg[$i])):
            $case NameArgPair*:
                named.set(($vaarg[$i]).name, (*$vaarg[$i]).arg);
            $case NameArgPair:
                named.set($vaarg[$i].name, $vaarg[$i].arg);
            $case ArgHash*:
                named.put_all_for_create($vaarg[$i]);
            $case ArgHash:
                named.put_all_for_create(&$vaarg[$i]);
            $default:
                args[$i] = any_make(&$vaarg[$i], $typeof($vaarg[$i]));
        $endswitch
    $endfor
	usz? res = f.vsprintf(fmt_str, args[..], named) @inline!;
    return ds.copy_str(mem);
}
