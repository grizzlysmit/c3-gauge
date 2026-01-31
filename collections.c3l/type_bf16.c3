module my::collections::arg;
import std::core::env;

module my::collections::arg @if(env::F16_SUPPORT);

//typedef Bfloat16 = bfloat16;
typedef Bfloat16 = ushort; // not supported need to create our self //


module my::collections::arg @if(!env::F16_SUPPORT);

typedef Bfloat16 = float16;

module my::collections::arg @if(env::F128_SUPPORT);

typedef Float128 = float128; 

module my::collections::arg @if(!env::F128_SUPPORT);

typedef Float128 = int128; // need to fake it if this is the case //
