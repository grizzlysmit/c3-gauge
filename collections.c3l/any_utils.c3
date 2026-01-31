module my::collections::arg;
import std::collections::map;
import std::collections::list;
import std::io;
import std::core::mem::allocator;
import std::core::env;
import std::math;
import libc;
import my::debug::dbg;

faultdef TYPE_MISMATCH, FAILLED_TO_JOIN_HASHMAP_AND_NAMED_PAIR,   
         FAILED_TO_CONVERT_TO_INTEGER, FAILED_TO_CONVERT_TO_SIGNED_INTEGER,   
         FAILED_TO_CONVERT_TO_FLOAT;   

struct NameArgPair {
    String name;
    any*   arg;
}

macro NameArgPair* String.pair(self, any _arg) @operator(*) {
    NameArgPair* pair;
    pair = allocator::malloc(tmem, NameArgPair.sizeof);
    pair.name = self.copy(mem);
    pair.arg  = &_arg;
    return pair;
}

macro NameArgPair* String.ppair(self, any* _arg) @operator(*) {
    NameArgPair* pair;
    pair = allocator::malloc(tmem, NameArgPair.sizeof);
    pair.name = self.copy(mem);
    pair.arg  = _arg;
    return pair;
}

macro ArgInternalMap* NameArgPair.add_pairp(self, NameArgPair* other) @operator(+) {
    ArgInternalMap map;
    return map.init_with_key_values(mem, (*self).name, (*self).arg, (*other).name, (*other).arg,
                                                capacity: math::next_power_of_2(NameArgPair.sizeof * 2));
}

macro ArgInternalMap* NameArgPair.add_pair(self, NameArgPair other) @operator(+) {
    ArgInternalMap map;
    return map.init_with_key_values(mem, self.name, self.arg, other.name, other.arg,
                                                capacity: math::next_power_of_2(NameArgPair.sizeof * 2));
}

macro ArgInternalMap* ArgInternalMap.add_pair(&self, NameArgPair pair) @operator(+) {
    if(!self.set(pair.name, pair.arg)) return null;
    return self;
}

macro ArgInternalMap* ArgInternalMap.copy(self, Allocator allocator){
    ArgInternalMap map;
    usz size = self.len();
    if(size == 0) size = 1;
    map.init(mem, capacity: (uint)math::next_power_of_2(size));
    foreach(ArgInternalMapEntry* entry : self.table){
        map.set((*entry).key.copy(allocator), (*entry).value);
    }
    return &map;
}

macro ArgInternalMap @make_map(NameArgPair... name_arg_pairs){
    ArgInternalMap map;
    usz size = name_arg_pairs.len;
    if(size == 0) size = 1;
    map.init(mem, capacity: (uint)math::next_power_of_2(size));
    foreach(pair : name_arg_pairs){
        map.set(pair.name, pair.arg);
    }
    return map;
}

fn ArgInternalMap make_map(NameArgPair... name_arg_pairs){
    ArgInternalMap map;
    usz size = name_arg_pairs.len;
    if(size == 0) size = 1;
    map.init(mem, capacity: (uint)math::next_power_of_2(size));
    foreach(pair : name_arg_pairs){
        map.set(pair.name, pair.arg);
    }
    return map;
}

macro any* any.malloc(&self, Allocator allocator, usz size){
    self = allocator::malloc(allocator, size);
    return self;
} // macro any* any.malloc(self, Allocator allocator, usz size) //


<*
 @param [&inout] allocator : "The allocator to use"
 @require $vacount % 2 == 0 : "There must be an even number of arguments provided for keys and values"
 @require capacity > 0 : "The capacity must be 1 or higher"
 @require load_factor > 0.0 : "The load factor must be higher than 0"
 @require !self.is_initialized() : "Map was already initialized"
 @require capacity < MAXIMUM_CAPACITY : "Capacity cannot exceed maximum"
*>
macro ArgInternalMap* ArgInternalMap.init_with_arg_key_values(&self, Allocator allocator, ...,
                    uint capacity = DEFAULT_INITIAL_CAPACITY, float load_factor = DEFAULT_LOAD_FACTOR) {
	self.init(allocator, capacity, load_factor);
	$for var $i = 0; $i < $vacount; $i += 2:
		self.set($vaarg[$i], make_arg($vaarg[$i + 1], allocator));
	$endfor
	return self;
}

macro ArgInternalMap make_map_any(Allocator allocator, ...){
    ArgInternalMap map;
    map.init(allocator, capacity: math::next_power_of_2($vacount));
    $for var $i = 0; $i < $vacount; $i += 2:
        map.set($vaarg[$i], make_arg($vaarg[$i + 1], allocator));
    $endfor
    return map;
}


<*

 //@require 
*>
macro String? any.to_string(self, usz* number_written = null){
    switch(self.type){
        case void:
            if(number_written) *number_written = 2;
            return "{}";
        case void*:
            if(number_written) *number_written = 4;
            return "null";
        case String:
            String? s = self.to(String);
            if(catch excuse = s){
                return excuse~;
            }else{
                if(number_written) *number_written = s.len;
                return s;
            }
        case char[]:
            char[]? s = self.to(char[]);
            if(catch excuse = s){
                return excuse~;
            }else{
                if(number_written) *number_written = s.len;
                return (String)s;
            }
        case ZString:
            ZString? s = self.to(ZString);
            if(catch excuse = s){
                return excuse~;
            }else{
                if(number_written) *number_written = s.len();
                return s.str_view();
            }
        case DString:
           return self.to(DString).str_view();
        case Char32[]:
            Char32[]? chars = self.to(Char32[]);
            if(catch excuse = chars){
                return excuse~;
            }else{
                DString d;
                d.append_utf32(chars);
                if(number_written) *number_written = d.len();
                return d.str_view();
            }
        case bool:
            bool? b = self.to(bool);
            if(catch excuse = b){
                return excuse~;
            }else{
                if(number_written) *number_written = b ? 4 : 5;
                return b ? "true" : "false";
            }
        case ichar:
            ichar? i = self.to(ichar);
            if(catch excuse = i){
                return excuse~;
            }else{
                DString d;
                d.append(i);
                if(number_written) *number_written = d.len();
                return d.str_view();
            }
        case char:
            char? c = self.to(char);
            if(catch excuse = c){
                return excuse~;
            }else{
                DString d;
                d.append(c);
                if(number_written) *number_written = d.len();
                return d.str_view();
            }
        case short:
            short? s = self.to(short);
            if(catch excuse = s){
                return excuse~;
            }else{
                DString d;
                d.append(s);
                if(number_written) *number_written = d.len();
                return d.str_view();
            }
        case ushort:
            ushort? us = self.to(ushort);
            if(catch excuse = us){
                return excuse~;
            }else{
                DString d;
                d.append(us);
                if(number_written) *number_written = d.len();
                return d.str_view();
            }
        case int:
            int? i = self.to(int);
            if(catch excuse = i){
                return excuse~;
            }else{
                DString d;
                d.append(i);
                if(number_written) *number_written = d.len();
                return d.str_view();
            }
        case uint:
            uint? ui = self.to(uint);
            if(catch excuse = ui){
                return excuse~;
            }else{
                DString d;
                d.append(ui);
                if(number_written) *number_written = d.len();
                return d.str_view();
            }
        case long:
            long? l = self.to(long);
            if(catch excuse = l){
                return excuse~;
            }else{
                DString d;
                d.append(l);
                if(number_written) *number_written = d.len();
                return d.str_view();
            }
        case ulong:
            ulong? ul = self.to(ulong);
            if(catch excuse = ul){
                return excuse~;
            }else{
                DString d;
                d.append(ul);
                if(number_written) *number_written = d.len();
                return d.str_view();
            }
        case int128:
            int128? i = self.to(int128);
            if(catch excuse = i){
                return excuse~;
            }else{
                DString d;
                d.append(i);
                if(number_written) *number_written = d.len();
                return d.str_view();
            }
        case uint128:
            uint128? ui = self.to(uint128);
            if(catch excuse = ui){
                return excuse~;
            }else{
                DString d;
                d.append(ui);
                if(number_written) *number_written = d.len();
                return d.str_view();
            }
        case Bfloat16: 
            Bfloat16? f = self.to(Bfloat16);
            if(catch excuse = f){
                return excuse~;
            }else{
                DString ds;
                ds.appendf("%f",  f);
                if(number_written) *number_written = ds.len();
                return ds.str_view();
            }
        case float:
            float? f = self.to(float);
            if(catch excuse = f){
                return excuse~;
            }else{
                DString ds;
                ds.appendf("%f",  f);
                if(number_written) *number_written = ds.len();
                return ds.str_view();
            }
        case double:
            double? d = self.to(double);
            if(catch excuse = d){
                return excuse~;
            }else{
                DString ds;
                ds.appendf("%f",  d);
                if(number_written) *number_written = ds.len();
                return ds.str_view();
            }
        case Float128:
            Float128? f = self.to(Float128);
            if(catch excuse = f){
                return excuse~;
            }else{
                DString ds;
                ds.appendf("%f",  f);
                if(number_written) *number_written = ds.len();
                return ds.str_view();
            }
        case String[]:
            String[]? array = self.to(String[]);
            if(catch excuse = array){
                return excuse~;
            }else{
                DString d;
                d.appendf("%s", array);
                if(number_written) *number_written = d.len();
                return d.str_view();
            }
        case ZString[]:
            ZString[]? array = self.to(ZString[]);
            if(catch excuse = array){
                return excuse~;
            }else{
                DString d;
                d.appendf("%s", array);
                if(number_written) *number_written = d.len();
                return d.str_view();
            }
        case int[]:
            int[]? array = self.to(int[]);
            if(catch excuse = array){
                return excuse~;
            }else{
                DString d;
                d.appendf("%s", array);
                if(number_written) *number_written = d.len();
                return d.str_view();
            }
        case ArgInternalList:
            ArgInternalList? arglist = self.to(ArgInternalList);
            if(catch excuse = arglist){
                return excuse~;
            }else{
                DString d;
                usz n = d.appendf("[")!;
                foreach (i, ol : arglist)
                {
                    if (i > 0) n += d.appendf(",")!;
                    n += d.appendf("%s", ol)!;
                }
                n += d.appendf("]")!;
                if(number_written) *number_written = n;
                return d.str_view();
            }
        case ArgInternalMap:
            ArgInternalMap? argmap = self.to(ArgInternalMap);
            if(catch excuse = argmap){
                return excuse~;
            }else{
                DString ds;
                usz n = ds.appendf("{")!;
                @stack_mem(1024; Allocator mem)
                {
                    foreach (i, key : argmap.keys(mem))
                    {
                        if (i > 0) n += ds.appendf(",")!;
                        n += ds.appendf(`"%s": `, key)!;
                        n += ds.appendf("%s", argmap.get(key))!;
                    }
                };
                n += ds.appendf("}")!;
                if(number_written) *number_written = n;
                return ds.str_view();
            }
        default:
            DString ds;
            ds.appendf("%s", self);
            if(number_written) *number_written = ds.len();
            return ds.str_view();
    } // switch(self.type) //
} // macro String any.to_string(self) //

macro any to_any(value){
    $if $defined(&value):
        return $$any_make(&value, $typeof(value));
    $else 
        return $$any_make(&&value, $typeof(value));
    $endif
}


fn bool any.is_date_time_arg(self){
    switch(self.type.kindof){
        case STRUCT:
            return self.type == libc::Tm.typeid || self.type == libc::TimeSpec;
        case SIGNED_INT:
        case UNSIGNED_INT:
            return self.type == libc::Time_t.typeid;
        default:
            return false;
    }
}


fn bool any.is_range_arg(self){
    /*
    dbg::eprintfn("%s[%d]«%s» self.ptr == `%p'\n self.type.kindof == %s",
                            $$FILE, $$LINE, $$FUNC, self.ptr, self.type.kindof);
    // */
    switch(self.type.kindof){
        case ARRAY:
        case VECTOR:
        case SLICE:
            /*
            dbg::eprintfn("%s[%d]«%s» self.ptr == `%p'\n self.type.kindof == %s",
                            $$FILE, $$LINE, $$FUNC, self.ptr, self.type.kindof);
            // */
            return true;
        default:
            dbg::eprintfn("%s[%d]«%s» self.ptr == `%p'\n self.type.kindof == %s",
                            $$FILE, $$LINE, $$FUNC, self.ptr, self.type.kindof);
            return false;
    }
}


macro any[] @copy_to_args_array(any[] args, Allocator allocator = tmem){
    any[] args = allocator::alloc_array(allocator, any, args.len);
    usz index = 0;
    foreach(elt : args){
        args[index++] = elt;
    }
    args.len = self.len;
    return args;
}

macro any[] any[].copy_to_args_array(self, Allocator allocator = tmem){
    any[] args = allocator::alloc_array(allocator, any, self.len);
    usz index = 0;
    foreach(elt : self){
        args[index++] = elt;
    }
    args.len = self.len;
    return args;
}

fn bool any.is_char(self){
    return self.type == char.typeid || self.type == ichar.typeid;
}

fn bool any.is_integer(self){
    return self.type.kindof == SIGNED_INT || self.type.kindof == UNSIGNED_INT;
}


fn bool any.is_signed_integer(self){
    return self.type.kindof == SIGNED_INT;
}


fn bool any.is_unsigned_integer(self){
    return self.type.kindof == UNSIGNED_INT;
}


fn bool any.is_bool(self){
    return self.type.kindof == BOOL;
}


fn bool any.is_enum(self){
    return self.type.kindof == ENUM;
}


fn bool any.is_float(self){
    return self.type.kindof == FLOAT;
}


macro bool any.is_number(self){
    return self.is_integer() || self.is_float();
}

fn bool any.is_array(self){
    return self.type.kindof == ARRAY;
}


fn bool any.is_string(self){
    if(self.type.kindof == DISTINCT){
        switch(self.type){
            case String:  return true;
            case ZString: return true;
            case DString: return true;
        }
    }
    return false;
}


fn bool any.is_pointer(self){
    return self.type.kindof == POINTER;
}

alias ArgInternalMap      @private = HashMap {String, any*};
alias ArgInternalList     @private = List {any*};
alias ArgInternalMapEntry @private = Entry {String, any*};


macro uint128? any.to_integer(self){
   switch(self.type){
       case bool:
            bool? b = self.to(bool);
            if(catch excuse = b){
                return excuse~;
            }else{
                return (int128)b;
            }
       case ichar:
            ichar? c = self.to(ichar);
            if(catch excuse = c){
                return excuse~;
            }else{
                return (int128)c;
            }
       case char:
            char? c = self.to(char);
            if(catch excuse = c){
                return excuse~;
            }else{
                return (int128)c;
            }
       case short:
           short? s = self.to(short);
           if(catch excuse = s){
               return excuse~;
           }else{
               return (int128)s;
           }
       case ushort:
           ushort? us = self.to(ushort);
           if(catch excuse = us){
               return excuse~;
           }else{
               return (int128)us;
           }
       case int:
           int? i = self.to(int);
           if(catch excuse = i){
               return excuse~;
           }else{
               return (int128)i;
           }
       case uint:
           uint? ui = self.to(uint);
           if(catch excuse = ui){
               return excuse~;
           }else{
               return (int128)ui;
           }
       case long:
           long? l = self.to(long);
           if(catch excuse = l){
               return excuse~;
           }else{
               return (int128)l;
           }
       case ulong:
           ulong? ul = self.to(ulong);
           if(catch excuse = ul){
               return excuse~;
           }else{
               return (int128)ul;
           }
       case int128:
           int128? i = self.to(int128);
           if(catch excuse = i){
               return excuse~;
           }else{
               return i;
           }
       case uint128:
           uint128? ui = self.to(uint128);
           if(catch excuse = ui){
               return excuse~;
           }else{
               return (int128)ui;
           }
        default:
           return FAILED_TO_CONVERT_TO_INTEGER~;
   } // switch(self.type) //
} // macro int128? any.to_integer(self) //

macro int128? any.to_signed_integer(self){
   switch(self.type){
       case bool:
            bool? b = self.to(bool);
            if(catch excuse = b){
                return excuse~;
            }else{
                return (int128)b;
            }
       case ichar:
            ichar? c = self.to(ichar);
            if(catch excuse = c){
                return excuse~;
            }else{
                return (int128)c;
            }
       case short:
           short? s = self.to(short);
           if(catch excuse = s){
               return excuse~;
           }else{
               return (int128)s;
           }
       case int:
           int? i = self.to(int);
           if(catch excuse = i){
               return excuse~;
           }else{
               return (int128)i;
           }
       case long:
           long? l = self.to(long);
           if(catch excuse = l){
               return excuse~;
           }else{
               return (int128)l;
           }
       case int128:
           int128? i = self.to(int128);
           if(catch excuse = i){
               return excuse~;
           }else{
               return (int128)i;
           }
        default:
           return FAILED_TO_CONVERT_TO_SIGNED_INTEGER~;
   } // switch(self.type) //
} // macro int128? any.to_signed_integer(self) //

fn double? any.to_float(self){
	switch (self.type) {
		case Bfloat16:
            Bfloat16? f = self.to(Bfloat16);
            if(catch excuse = f){
                return excuse~;
            }else{
                return (double)f;
            }
		case float16:
            float16? f = self.to(float16);
            if(catch excuse = f){
                return excuse~;
            }else{
                return (double)f;
            }
		case float:
            float? f = self.to(float);
            if(catch excuse = f){
                return excuse~;
            }else{
                return (double)f;
            }
		case double:
            double? d = self.to(double);
            if(catch excuse = d){
                return excuse~;
            }else{
                return (double)d;
            }
		case float128:
            float128? f = self.to(float128);
            if(catch excuse = f){
                return excuse~;
            }else{
                return (double)f;
            }
		default:
            return FAILED_TO_CONVERT_TO_FLOAT~;
	} // switch (self.type) //
} // fn double? any.to_float(self) //

fn usz? any.to_format(&self, Formatter* formatter) {
	switch (self.type) {
		case void:
			return formatter.printf("{}")!;
		case void*:
			return formatter.printf("null")!;
		case String:
            String? s = self.to(String);
            if(catch excuse = s){
                return excuse~;
            }else{
                return formatter.printf(`"%s"`, s)!;
            }
		case bool:
            bool? b = self.to(bool);
            if(catch excuse = b){
                return excuse~;
            }else{
                return formatter.printf("%s", b ? "true" : "false")!;
            }
		case ichar:
            ichar? ch = self.to(ichar);
            if(catch excuse = ch){
                return excuse~;
            }else{
                return formatter.printf(`"%c"`, ch)!;
            }
		case char:
            char? ch = self.to(char);
            if(catch excuse = ch){
                return excuse~;
            }else{
                return formatter.printf(`"%c"`, ch)!;
            }
		case short:
            short? sh = self.to(short);
            if(catch excuse = sh){
                return excuse~;
            }else{
                return formatter.printf(`"%d"`, sh)!;
            }
		case ushort:
            ushort? us = self.to(ushort);
            if(catch excuse = us){
                return excuse~;
            }else{
                return formatter.printf(`"%d"`, us)!;
            }
		case int:
            int? i = self.to(int);
            if(catch excuse = i){
                return excuse~;
            }else{
                return formatter.printf(`"%d"`, i)!;
            }
		case uint:
            uint? ui = self.to(uint);
            if(catch excuse = ui){
                return excuse~;
            }else{
                return formatter.printf(`"%d"`, ui)!;
            }
		case long:
            long? l = self.to(long);
            if(catch excuse = l){
                return excuse~;
            }else{
                return formatter.printf(`"%d"`, l)!;
            }
		case ulong:
            ulong? ul = self.to(ulong);
            if(catch excuse = ul){
                return excuse~;
            }else{
                return formatter.printf(`"%d"`, ul)!;
            }
		case int128:
            int128? i = self.to(int128);
            if(catch excuse = i){
                return excuse~;
            }else{
                return formatter.printf(`"%d"`, i)!;
            }
		case uint128:
            uint128? i = self.to(uint128);
            if(catch excuse = i){
                return excuse~;
            }else{
                return formatter.printf(`"%d"`, i)!;
            }
		case Bfloat16:
            Bfloat16? f = self.to(Bfloat16);
            if(catch excuse = f){
                return excuse~;
            }else{
                return formatter.printf(`"%f"`, f)!;
            }
		case float16:
            float16? f = self.to(float16);
            if(catch excuse = f){
                return excuse~;
            }else{
                return formatter.printf(`"%f"`, f)!;
            }
		case float:
            float? f = self.to(float);
            if(catch excuse = f){
                return excuse~;
            }else{
                return formatter.printf(`"%f"`, f)!;
            }
		case double:
            double? d = self.to(double);
            if(catch excuse = d){
                return excuse~;
            }else{
                return formatter.printf(`"%f"`, d)!;
            }
		case float128:
            float128? f = self.to(float128);
            if(catch excuse = f){
                return excuse~;
            }else{
                return formatter.printf(`"%f"`, f)!;
            }
		case ArgInternalList:
            ArgInternalList? arglist = self.to(ArgInternalList);
            if(catch excuse = arglist){
                return excuse~;
            }else{
                usz n = formatter.printf("[")!;
                foreach (i, ol : arglist)
                {
                    if (i > 0) n += formatter.printf(",")!;
                    n += ol.to_format(formatter)!;
                }
                n += formatter.printf("]")!;
                return n;
            }
		case ArgInternalMap:
            ArgInternalMap? argmap = self.to(ArgInternalMap);
            if(catch excuse = argmap){
                return excuse~;
            }else{
                usz n = formatter.printf("{")!;
                @stack_mem(1024; Allocator mem)
                {
                    foreach (i, key : argmap.keys(mem))
                    {
                        if (i > 0) n += formatter.printf(",")!;
                        n += formatter.printf(`"%s":`, key)!;
                        n += argmap.get(key).to_format(formatter)!;
                    }
                };
                n += formatter.printf("}")!;
                return n;
            }
		default:
            return formatter.printf("%s", self);
	} // switch (self.type) //
} // fn usz? any.to_format(&self, Formatter* formatter) @dynamic //
