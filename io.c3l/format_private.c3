module my::templates::fmt;
import std::io;
import my::loc;
import my::collections::arg;
import my::debug::dbg;
import std::math;

const char[16] XDIGITS_H = "0123456789ABCDEF";
const char[16] XDIGITS_L = "0123456789abcdef";

faultdef BAD_FORMAT, ERROR_SPEC_DIED_TOO_SOON_COULD_NOT_GET_PRECISION, 
         ERROR_MISSING_CLOSING_BRACE_IN_WIDTH_OR_PRECISION, 
         ERROR_NESTING_LEVEL_OF_BRACES_TOO_DEEP_IN_WIDTH_OR_PRECISION_SEE_DOCS, 
         ERROR_ARGS_EXHUSTED_WHILST_GETTING_WIDTH, ERROR_ARGS_EXHUSTED_WHILST_GETTING_PRECISION, 
         ERROR_ARG_CONSUMMED_IS_NOT_AN_INTEGER_WIDTH, ERROR_ARG_CONSUMMED_IS_NOT_AN_INTEGER_PRECISION, 
         ERROR_ARG_OUT_OF_RANGE_WIDTH, ERROR_ARG_OUT_OF_RANGE_PRECISION, 
         ERROR_ARG_SPEC_MUST_BE_AN_IDENIFIER_OR_NUMBER, ERROR_WIDTH_AND_PRECISION_MUST_BE_A_NUMBER, 
         ERROR_ARG_SPEC_MUST_BE_A_NUMBER, ERROR_MISSING_OPENING_BRACE_IN_WIDTH_OR_PRECISION;

fn usz? print_hex_chars(Fmter* f, char[] out, bool uppercase) @inline
{
	char past_10 = (uppercase ? 'A' : 'a') - 10;
	usz len = 0;
	foreach (c : out){
		char digit = c >> 4;
		f.out(digit + (digit < 10 ? '0' : past_10))!;
		len++;
		digit = c & 0xf;
		f.out(digit + (digit < 10 ? '0' : past_10))!;
		len++;
	}
	return len;
}

macro fault Fmter.first_err(&self, fault f)
{
	if (self.first_fault) return self.first_fault;
	self.first_fault = f;
	return f;
}

fn usz? Fmter.adjust(&self, usz len) @local
{
    if(!self.fill) self.fill = ' ';
    isz padding = self.width - len;
    if(self.flags.alignment == FmtAlignment.CENTRE){
        if(padding > 0){
            padding /= 2;
            return self.pad2(self.fill, padding);
        }
    }
	if(self.flags.alignment != FmtAlignment.LEFT) return 0;
	return self.pad(self.fill, self.width, len);
} // fn usz? Fmter.adjust(&self, usz len) @local //

fn uint128? int_from_any(any arg, bool *is_neg) @private {
	switch(arg.type.kindof){
		case FUNC:
		case POINTER:
			*is_neg = false;
			return (uint128)(uptr)*(void**)arg.ptr;
		case DISTINCT:
		case CONST_ENUM:
			return int_from_any(arg.as_inner(), is_neg);
		default:
			break;
	}
	*is_neg = false;
	switch(arg.type){
		case bool:
			return (uint128)*(bool*)arg;
		case ichar:
			int val = *(ichar*)arg;
			return (*is_neg = val < 0) ? (~(uint128)val) + 1 : (uint128)val;
		case short:
			int val = *(short*)arg;
			return (*is_neg = val < 0) ? (~(uint128)val) + 1 : (uint128)val;
		case int:
			int val = *(int*)arg;
			return (*is_neg = val < 0) ? (~(uint128)val) + 1 : (uint128)val;
		case long:
			long val = *(long*)arg;
			return (*is_neg = val < 0) ? (~(uint128)val) + 1 : (uint128)val;
		case int128:
			int128 val = *(int128*)arg;
			return (*is_neg = val < 0) ? (~(uint128)val) + 1 : (uint128)val;
		case char:
			return *(char*)arg;
		case ushort:
			return *(ushort*)arg;
		case uint:
			return *(uint*)arg;
		case ulong:
			return *(ulong*)arg;
		case uint128:
			return *(uint128*)arg;
		case float:
			float f = *(float*)arg;
			return (uint128)((*is_neg = f < 0) ? -f : f);
		case double:
			double d = *(double*)arg;
			return (uint128)((*is_neg = d < 0) ? -d : d);
		default:
			return BAD_FORMAT~;
	}
} // fn uint128? int_from_any(any arg, bool *is_neg) @private //

fn FloatType? float_from_any(any arg) @private {
    dbg::eprintfn("%s[%d]«%s» arg == `%s'\n arg.type.kindof == `%s'",
                                                        $$FILE, $$LINE, $$FUNC, arg, arg.type.kindof);
	$if env::F128_SUPPORT:
		if (arg.type == float128.typeid) return (FloatType)*((float128*)arg.ptr);
	$endif
	if(arg.type.kindof == DISTINCT || arg.type.kindof == CONST_ENUM){
		return float_from_any(arg.as_inner());
	}
	switch(arg.type){
		case bool:
			return (FloatType)*(bool*)arg;
		case ichar:
			return *(ichar*)arg;
		case short:
			return *(short*)arg;
		case int:
			return *(int*)arg;
		case long:
			return *(long*)arg;
		case int128:
			return *(int128*)arg;
		case char:
			return *(char*)arg;
		case ushort:
			return *(ushort*)arg;
		case uint:
			return *(uint*)arg;
		case ulong:
			return *(ulong*)arg;
		case uint128:
			return *(uint128*)arg;
		case Bfloat16:
            return (FloatType)*(Bfloat16*)arg;
		case float16:
            return (FloatType)*(float16*)arg;
		case float:
			return (FloatType)*(float*)arg;
		case double:
			return (FloatType)*(double*)arg;
		default:
            dbg::eprintfn("%s[%d]«%s» arg == `%s'\n arg.type.kindof == `%s'",
                                                        $$FILE, $$LINE, $$FUNC, arg, arg.type.kindof);
			return BAD_FORMAT~;
	}
} // fn FloatType? float_from_any(any arg) @private //


<*
 Read a simple integer value, typically for formatting.

 @param [inout] len_ptr : "the length remaining."
 @param [in] buf : "the buf to read from."
 @param maxlen : "the maximum len that can be read."
 @return "The result of the atoi."
*>
fn uint simple_atoi(char* buf, usz maxlen, usz* len_ptr) @inline @private {
	uint i = 0;
	usz len = *len_ptr;
	while(len < maxlen){
		char c = buf[len];
		if(!c.is_digit()) break;
		i = i * 10 + c - '0';
		len++;
	}
	*len_ptr = len;
	return i;
} // fn uint simple_atoi(char* buf, usz maxlen, usz* len_ptr) @inline @private //

fn usz? Fmter.out_substr(&self, String str) @private {
	usz l = conv::utf8_codepoints(str);
	uint prec = self.prec;
	if (self.flags.precision && l < prec) l = prec;
	usz index = 0;
	usz chars = str.len;
	char* ptr = str.ptr;
	while (index < chars)
	{
		char c = ptr[index];
		// Break if we have precision set and we ran out...
		if (c & 0xC0 != 0x80 && self.flags.precision && !prec--) break;
		self.out(c)!;
		index++;
	}
	return index;
} // fn usz? Fmter.out_substr(&self, String str) @private //

fn usz? Fmter.pad(&self, char c, isz width, isz len) @inline {
	isz delta = width - len;
	for (isz i = 0; i < delta; i++) self.out(c)!;
	return max(0, delta);
} // fn usz? Fmter.pad(&self, char c, isz width, isz len) @inline //

fn usz? Fmter.pad2(&self, char c, isz delta) @inline {
	for (isz i = 0; i < delta; i++) self.out(c)!;
	return max(0, delta);
} // fn usz? Fmter.pad2(&self, char c, isz delta) @inline //

fn char* fmt_u(uint128 x, char* s){
	for (; x > ulong.max; x /= 10) *--s = '0' + (char)(x % 10);
	for (ulong y = (ulong)x; y; y /= 10) *--s = '0' + (char)(y % 10);
	return s;
} // fn char* fmt_u(uint128 x, char* s) //

fn usz? Fmter.out_chars(&self, char[] s) {
	foreach (c : s) self.out(c)!;
	return s.len;
}

enum FloatFormatting {
	FLOAT,
	EXPONENTIAL,
	ADAPTIVE,
	HEX
}

fn usz? Fmter.etoa(&self, double y) => self.floatformat(EXPONENTIAL, y);
fn usz? Fmter.ftoa(&self, double y) => self.floatformat(FLOAT, y);
fn usz? Fmter.gtoa(&self, double y) => self.floatformat(ADAPTIVE, y);
fn usz? Fmter.atoa(&self, double y) => self.floatformat(HEX, y);

fn usz? Fmter.floatformat(&self, FloatFormatting formatting, double y) @private {
    if(!self.fill) self.fill = ' ';
	// This code is heavily based on musl's printf code
	const BUF_SIZE = (math::DOUBLE_MANT_DIG + 28) / 29 + 1
		+ (math::DOUBLE_MAX_EXP + math::DOUBLE_MANT_DIG + 28 + 8) / 9;
	uint[BUF_SIZE] big;
	bool is_neg = false;
	if(math::signbit(y)){
		is_neg = true;
		y = -y;
	}
	isz pl = is_neg || (self.flags.sign == FmtSign.BOTH) ? 1 : 0
                            || (self.flags.sign == FmtSign.SPACE_OR_MINUS) ? 1 : 0;
	// sprint inf/nan
	if(!math::is_finite(y)){
        usz padding = self.width - (3 + pl);
		usz len;
		// Add padding
		//if(self.flags.alignment == FmtAlignment.RIGHT) len += self.pad(' ', self.width, 3 + pl)!;
        switch(self.flags.alignment){
            case FmtAlignment.LEFT:
                String s = self.flags.uppercase ? "INF" : "inf";
                if(math::is_nan(y)) s = self.flags.uppercase ? "NAN" : "nan";
                //if(pl) len += self.out(is_neg ? '-' : '+')!;
                switch(self.flags.sign){
                    case FmtSign.ONLY_NEGS:
                        if(is_neg) self.out('-')!;
                    case FmtSign.BOTH:
                        len += self.out(is_neg ? '-' : '+')!;
                    case FmtSign.SPACE_OR_MINUS:
                        len += self.out(is_neg ? '-' : ' ')!;
                } // switch(self.flags.sign) //
                len += self.out_chars(s)!;
                len += self.pad(self.fill, self.width, 3 + pl)!;
            case FmtAlignment.CENTRE:
                if(padding > 0){
                    bool odd = (bool)(padding & 0x0000000000000001);
                    padding /= 2;
                    len += self.pad2(self.fill, padding + (usz)odd)!;
                    String s = self.flags.uppercase ? "INF" : "inf";
                    if(math::is_nan(y)) s = self.flags.uppercase ? "NAN" : "nan";
                    //if(pl) len += self.out(is_neg ? '-' : '+')!;
                    switch(self.flags.sign){
                        case FmtSign.ONLY_NEGS:
                            if(is_neg) self.out('-')!;
                        case FmtSign.BOTH:
                            len += self.out(is_neg ? '-' : '+')!;
                        case FmtSign.SPACE_OR_MINUS:
                            len += self.out(is_neg ? '-' : ' ')!;
                    } // switch(self.flags.sign) //
                    len += self.out_chars(s)!;
                    len += self.pad2(self.fill, padding)!;
                }
            case FmtAlignment.RIGHT:
                len += self.pad(self.fill, self.width, 3 + pl)!;
                String s = self.flags.uppercase ? "INF" : "inf";
                if(math::is_nan(y)) s = self.flags.uppercase ? "NAN" : "nan";
                //if(pl) len += self.out(is_neg ? '-' : '+')!;
                switch(self.flags.sign){
                    case FmtSign.ONLY_NEGS:
                        if(is_neg) self.out('-')!;
                    case FmtSign.BOTH:
                        len += self.out(is_neg ? '-' : '+')!;
                    case FmtSign.SPACE_OR_MINUS:
                        len += self.out(is_neg ? '-' : ' ')!;
                } // switch(self.flags.sign) //
                len += self.out_chars(s)!;
        } // switch(self.flags.alignment) //
		//if(self.flags.alignment == FmtAlignment.LEFT) len += self.pad(' ', self.width, 3 + pl)!;
		return len;
	} // if(!math::is_finite(y)) //
    ZString _radix = (ZString)loc::nl_langinfo(loc::RADIXCHAR);
    char    radix  = '.';
    if(_radix.len()){
        radix      = _radix[0];
    }
	// Rescale
	int e2;

	y = math::frexp(y, &e2) * 2;
	if(y) e2--;
	char[12] ebuf0;
	char* ebuf = 12 + (char*)&ebuf0;
	char[9 + math::DOUBLE_MANT_DIG / 4] buf_array;
	char* buf = &buf_array;
	isz p = self.flags.precision ? self.prec : -1;
	if(formatting == HEX){
		double round = 8.0;
		// 0x / 0X
		pl += 2;
		if(p > 0 && p < math::DOUBLE_MANT_DIG / 4 - 1){
			int re = math::DOUBLE_MANT_DIG / 4 - 1 - (int)p;
			round *= 1 << (math::DOUBLE_MANT_DIG % 4);
			while (re--) round *= 16;
			if (is_neg)
			{
				y = -y;
				y -= round;
				y += round;
				y = -y;
			}else{
				y += round;
				y -= round;
			}
		}
		// Reverse print
		char* estr = fmt_u(e2 < 0 ? (int128)-e2 : (int128)e2, ebuf);
		if (estr == ebuf) *--estr = '0';
		*--estr = (e2 < 0 ? '-' : '+');
		*--estr = self.flags.uppercase ? 'P' : 'p';
		char* s = buf;
		char* xdigits = self.flags.uppercase ? &XDIGITS_H : &XDIGITS_L;
		do{
			int x = (int)y;
			*s++ = xdigits[x];
			y = 16 * (y - x);
			if(s - buf == 1 && (y || p > 0 || self.flags.alternate)){
                *s++ = ((self.flags.use_locale) ? radix : '.');
            }
		}while(y);
		isz outlen = s - buf;
		isz explen = ebuf - estr;
		if(p > int.max - 2 - explen - pl) return INTERNAL_BUFFER_EXCEEDED~;
		usz len;
		usz l = p && outlen - 2 < p
				? p + 2 + explen
				: outlen + explen;
		//if(!self.flags.left && !self.flags.zeropad) len += self.pad(' ', self.width, pl + l)!;
        usz padding = self.width - (outlen + explen + 2 * (usz)self.flags.alternate + pl);
        switch(self.flags.alignment){
            case FmtAlignment.LEFT:
                switch(self.flags.sign){
                    case FmtSign.ONLY_NEGS:
                        if(is_neg) len += self.out('-')!;
                        if(self.flags.alternate) len += self.out_chars(self.flags.uppercase ? "0X" : "0x")!;
                        if(self.flags.padding == FmtPadding.ZEROS){
                            len += self.pad2('0', padding)!;
                        }
                        len += self.out_chars(buf[:outlen])!;
                        len += self.pad('0', l - outlen - explen, 0)!;
                        len += self.out_chars(estr[:explen])!;
                    case FmtSign.BOTH:
                        if(is_neg) len += self.out(is_neg ? '-' : '+')!;
                        if(self.flags.alternate) len += self.out_chars(self.flags.uppercase ? "0X" : "0x")!;
                        //if(self.flags.left) len += self.pad('0', self.width, pl + l)!;
                        if(self.flags.padding == FmtPadding.ZEROS){
                            len += self.pad2('0', padding)!;
                        }
                        len += self.out_chars(buf[:outlen])!;
                        len += self.pad('0', l - outlen - explen, 0)!;
                        len += self.out_chars(estr[:explen])!;
                    case FmtSign.SPACE_OR_MINUS:
                        if(is_neg) len += self.out(is_neg ? '-' : ' ')!;
                        if(self.flags.alternate) len += self.out_chars(self.flags.uppercase ? "0X" : "0x")!;
                        //if(self.flags.left) len += self.pad('0', self.width, pl + l)!;
                        if(self.flags.padding == FmtPadding.ZEROS){
                            len += self.pad2('0', padding)!;
                        }
                        len += self.out_chars(buf[:outlen])!;
                        len += self.pad('0', l - outlen - explen, 0)!;
                        len += self.out_chars(estr[:explen])!;
                }
                len += self.pad(' ', self.width, pl + l)!;
            case FmtAlignment.CENTRE:
                len += self.pad2(' ', padding)!;
                if(padding > 0){
                    bool odd = (bool)(padding & 0x0000000000000001);
                    padding /= 2;
                    dbg::eprintfn("%s[%d]«%s» padding == `%s'\n odd == `%s'",
                                                            $$FILE, $$LINE, $$FUNC, padding, odd);
                    if(self.flags.padding == FmtPadding.SPACES){
                        len += self.pad2(self.fill, padding + (usz)odd)!;
                    }
                    switch(self.flags.sign){
                        case FmtSign.ONLY_NEGS:
                            if(is_neg) len += self.out('-')!;
                            if(self.flags.alternate){
                                len += self.out_chars(self.flags.uppercase ? "0X" : "0x")!;
                            }
                            if(self.flags.padding == FmtPadding.ZEROS){
                                len += self.pad('0', self.width, pl + l)!;
                            }
                            len += self.out_chars(buf[:outlen])!;
                            len += self.pad('0', l - outlen - explen, 0)!;
                            len += self.out_chars(estr[:explen])!;
                        case FmtSign.BOTH:
                            if(is_neg) len += self.out(is_neg ? '-' : '+')!;
                            if(self.flags.alternate){
                                len += self.out_chars(self.flags.uppercase ? "0X" : "0x")!;
                            }
                            //if(self.flags.left) len += self.pad('0', self.width, pl + l)!;
                            if(self.flags.padding == FmtPadding.ZEROS){
                                len += self.pad('0', self.width, pl + l)!;
                            }
                            len += self.out_chars(buf[:outlen])!;
                            len += self.pad('0', l - outlen - explen, 0)!;
                            len += self.out_chars(estr[:explen])!;
                        case FmtSign.SPACE_OR_MINUS:
                            if(is_neg) len += self.out(is_neg ? '-' : ' ')!;
                            if(self.flags.alternate){
                                len += self.out_chars(self.flags.uppercase ? "0X" : "0x")!;
                            }
                            if(self.flags.padding == FmtPadding.ZEROS){
                                len += self.pad('0', self.width, pl + l)!;
                            }
                            len += self.out_chars(buf[:outlen])!;
                            len += self.pad('0', l - outlen - explen, 0)!;
                            len += self.out_chars(estr[:explen])!;
                    } // switch(self.flags.sign) //
                    if(self.flags.padding == FmtPadding.SPACES){
                        len += self.pad2(self.fill, padding)!;
                    }
                } // if(padding > 0) //
            case FmtAlignment.RIGHT:
                switch(self.flags.sign){
                    case FmtSign.ONLY_NEGS:
                        if(is_neg) len += self.out('-')!;
                        if(self.flags.alternate) len += self.out_chars(self.flags.uppercase ? "0X" : "0x")!;
                        if(self.flags.padding == FmtPadding.ZEROS){
                            len += self.pad('0', self.width, pl + l)!;
                        }
                        len += self.out_chars(buf[:outlen])!;
                        len += self.pad('0', l - outlen - explen, 0)!;
                        len += self.out_chars(estr[:explen])!;
                    case FmtSign.BOTH:
                        if(is_neg) len += self.out(is_neg ? '-' : '+')!;
                        if(self.flags.alternate) len += self.out_chars(self.flags.uppercase ? "0X" : "0x")!;
                        //if(self.flags.left) len += self.pad('0', self.width, pl + l)!;
                        if(self.flags.padding == FmtPadding.ZEROS){
                            len += self.pad('0', self.width, pl + l)!;
                        }
                        len += self.out_chars(buf[:outlen])!;
                        len += self.pad('0', l - outlen - explen, 0)!;
                        len += self.out_chars(estr[:explen])!;
                    case FmtSign.SPACE_OR_MINUS:
                        if(is_neg) len += self.out(is_neg ? '-' : ' ')!;
                        if(self.flags.alternate) len += self.out_chars(self.flags.uppercase ? "0X" : "0x")!;
                        if(self.flags.padding == FmtPadding.ZEROS){
                            len += self.pad('0', self.width, pl + l)!;
                        }
                        len += self.out_chars(buf[:outlen])!;
                        len += self.pad('0', l - outlen - explen, 0)!;
                        len += self.out_chars(estr[:explen])!;
                } // switch(self.flags.sign) //
                if(self.flags.padding = FmtPadding.SPACES){
                    len += self.pad2(self.fill, padding)!;
                }
        } // switch(self.flags.alignment) //
		//if (self.flags.left) len += self.pad(' ', self.width, pl + l)!;
		return len;
	} // if(formatting == HEX) //
	if(p < 0) p = 6;
	if(y){
		y *= 0x1p28;
		e2 -= 28;
	}

	uint* a, z, r;
	if(e2 < 0){
		a = r = z = &big;
	}else{
		a = r = z = (uint*)&big + big.len - math::DOUBLE_MANT_DIG - 1;
	}

	do{
		uint v = z++[0] = (uint)y;
		y = 1000000000 * (y - v);
	}while(y);

	while(e2 > 0){
		uint carry = 0;
		int sh = math::min(29, e2);
		for(uint* d = z - 1; d >= a; d--){
			ulong x = (ulong)*d << sh + carry;
			*d = (uint)(x % 1000000000);
			carry = (uint)(x / 1000000000);
		}
		if(carry) *--a = carry;
		while(z > a && !z[-1]) z--;
		e2 -= sh;
	}

	while(e2 < 0){
		uint carry = 0;
		uint* b;
		int sh = math::min(9, -e2);
		int need = (int)(1 + (p + math::DOUBLE_MANT_DIG / 3u + 8) / 9);
		for(uint* d = a; d < z; d++){
			// CHECK THIS
			uint rm = *d & ((1 << sh) - 1);
			*d = (*d >> sh) + carry;
			carry = (1000000000 >> sh) * rm;
		}
		if (!a[0]) a++;
		if (carry) z++[0] = carry;
		// Avoid (slow!) computation past requested precision
		b = formatting == FLOAT ? r : a;
		if (z - b > need) z = b + need;
		e2 += sh;
	}

	int e;
	if(a < z){
		for(int i = 10, e = (int)(9 * (r - a)); *a >= i; i *= 10, e++);
	}

	// Perform rounding: j is precision after the radix (possibly neg)
	int j = (int)p;
	if(formatting != FLOAT) j -= e;
	if(formatting == ADAPTIVE && p != 0) j -= 1;

	if(j < 9 * (z - r - 1)){
		uint x;
		// We avoid C's broken division of negative numbers
		uint* d = r + 1 + ((j + 9 * math::DOUBLE_MAX_EXP) / 9 - math::DOUBLE_MAX_EXP);
		j += 9 * math::DOUBLE_MAX_EXP;
		j %= 9;
		int i;
		for (i = 10, j++; j < 9; i *= 10, j++);
		x = *d % i;
		// Are there any significant digits past j?
		if(x || (d + 1) != z){
			double round = 2 / math::DOUBLE_EPSILON;
			double small;
			if(((*d / i) & 1) || (i == 1000000000 && d > a && (d[-1] & 1))){
				round += 2;
			}
			switch{
				case x < i / 2:
					small = 0x0.8p0;
				case x == i / 2 && d + 1 == z:
					small = 0x1.0p0;
				default:
					small = 0x1.8p0;
			}
			if(pl && is_neg){
				round *= -1;
				small *= -1;
			}
			*d -= x;
			// Decide whether to round by probing round+small
			if(round + small != round){
				*d = *d + i;
				while(*d > 999999999){
					*d-- = 0;
					if (d < a) *--a = 0;
					(*d)++;
				}
				for(i = 10, e = (int)(9 * (r - a)); *a >= i; i *= 10, e++);
			}
		}
		if(z > d + 1) z = d + 1;
	}
	for(; z > a && !z[-1]; z--);

	if(formatting == ADAPTIVE){
		if(!p) p++;
		if(p > e && e >= -4){
			formatting = FLOAT;
			p -= (isz)e + 1;
		}else{
			formatting = EXPONENTIAL;
			p--;
		}
		if(!self.flags.alternate){
			// Count trailing zeros in last place
			if(z > a && z[-1]){
				for (int i = 10, j = 0; z[-1] % i == 0; i *= 10, j++);
			}else{
				j = 9;
			}
			if(formatting == FLOAT){
				p = math::min(p, math::max((isz)0, 9 * (z - r - 1) - j));
			}else{
				p = math::min(p, math::max((isz)0, 9 * (z - r - 1) + e - j));

			}
		}
	}
	if(p > int.max - 1 - (isz)(p || self.flags.alternate)) return INTERNAL_BUFFER_EXCEEDED~;
	int l = (int)(1 + p + (isz)(p || self.flags.alternate));
	char* estr @noinit;
	if(formatting == FLOAT){
		if (e > int.max - l) return INTERNAL_BUFFER_EXCEEDED~;
		if (e > 0) l += e;
	}else{
		estr = fmt_u((uint128)(e < 0 ? -e : e), ebuf);
		while(ebuf - estr < 2) (--estr)[0] = '0';
		*--estr = (e < 0 ? '-' : '+');
		*--estr = self.flags.uppercase ? 'E' : 'e';
		if(ebuf - estr > (isz)int.max - l) return INTERNAL_BUFFER_EXCEEDED~;
		l += (int)(ebuf - estr);
	}
	if(l > int.max - pl) return INTERNAL_BUFFER_EXCEEDED~;
	usz len;
    usz padding = self.width - (l + pl);
    bool odd = false;
    switch(self.flags.alignment){
        case FmtAlignment.LEFT:
            break; // nolthing to do here //
        case FmtAlignment.CENTRE:
            if(padding > 0){
                odd = (bool)(padding & 0x0000000000000001);
                padding /= 2;
                if(self.flags.padding == FmtPadding.SPACES){
                    len += self.pad2(self.fill, padding + (usz)odd)!;
                }
            }
        case FmtAlignment.RIGHT:
            if(self.flags.padding == FmtPadding.SPACES){
                len += self.pad2(self.fill, padding)!;
            }
    } // switch(self.flags.alignment) //
    switch(self.flags.sign){
        case FmtSign.ONLY_NEGS:
            if(is_neg) len += self.out('-')!;
        case FmtSign.BOTH:
            if(is_neg) len += self.out(is_neg ? '-' : '+')!;
        case FmtSign.SPACE_OR_MINUS:
            if(is_neg) len += self.out(is_neg ? '-' : ' ')!;
    } // switch(self.flags.sign) //
	if(self.flags.padding == FmtPadding.ZEROS) len += self.pad('0', self.width, pl + l)!;
	if(formatting == FLOAT){
		if (a > r) a = r;
		uint* d = a;
		for(; d <= r; d++){
			char* s = fmt_u(*d, buf + 9);
			switch{
				case d != a:
					while (s > buf) (--s)[0] = '0';
				case s == buf + 9:
					*--s = '0';
			}
			len += self.out_chars(s[:buf + 9 - s])!;
		}
		if(p || self.flags.alternate) len += self.out('.')!;
		for(; d < z && p > 0; d++, p -= 9){
			char* s = fmt_u(*d, buf + 9);
			while(s > buf) *--s = '0';
			len += self.out_chars(s[:math::min((isz)9, p)])!;
		}
		len += self.pad('0', p + 9, 9)!;
	}else{
		if(z <= a) z = a + 1;
		for(uint* d = a; d < z && p >= 0; d++){
			char* s = fmt_u(*d, buf + 9);
			if(s == buf + 9) (--s)[0] = '0';
			if(d != a){
				while(s > buf) (--s)[0] = '0';
			}else{
				len += self.out(s++[0])!;
				if(p > 0 || self.flags.alternate) len += self.out('.')!;
			}
			len += self.out_chars(s[:math::min(buf + 9 - s, p)])!;
			p -= buf + 9 - s;
		}
		len += self.pad('0', p + 18, 18)!;
		len += self.out_chars(estr[:ebuf - estr])!;
	}

    switch(self.flags.alignment){
        case FmtAlignment.LEFT:
            if(self.flags.padding == FmtPadding.SPACES){
                len = len += self.pad2(self.fill, padding)!;
            }
        case FmtAlignment.CENTRE:
            if(self.flags.padding == FmtPadding.SPACES){
                len = len += self.pad2(self.fill, padding)!;
            }
        case FmtAlignment.RIGHT:
    }

	return len;
} // fn usz? Fmter.floatformat(&self, FloatFormatting formatting, double y) @private //

/*
const char[201] DIGIT_PAIRS @private =
  "00102030405060708090"
  "01112131415161718191"
  "02122232425262728292"
  "03132333435363738393"
  "04142434445464748494"
  "05152535455565758595"
  "06162636465666768696"
  "07172737475767778797"
  "08182838485868788898"
  "09192939495969798999";
// */

const String DIGIT_PAIRS @private =
  "00102030405060708090"
  "01112131415161718191"
  "02122232425262728292"
  "03132333435363738393"
  "04142434445464748494"
  "05152535455565758595"
  "06162636465666768696"
  "07172737475767778797"
  "08182838485868788898"
  "09192939495969798999";


fn usz? Fmter.ntoa(&self, uint128 value, bool negative, uint base) @private {
	char[FMT_NTOA_BUFFER_SIZE] buf @noinit;
	usz len;

	// no hash for 0 values
	if (!value) self.flags.alternate = false;

	// write if precision != 0 or value is != 0
	if(!self.flags.precision || value){
		char past_10 = (self.flags.uppercase ? 'A' : 'a') - 10;
		switch(base){
			case 2:
				do{
					if (len >= FMT_NTOA_BUFFER_SIZE) return INTERNAL_BUFFER_EXCEEDED~;
					buf[len++] = '0' + (char)value & 1;
					value >>= 1;
				}while(value);
			case 10:
				if(!value){
					if(len >= FMT_NTOA_BUFFER_SIZE) return INTERNAL_BUFFER_EXCEEDED~;
					buf[len++] = '0';
					break;
				}
				while(value >= 10){
					if(len + 1 >= FMT_NTOA_BUFFER_SIZE) return INTERNAL_BUFFER_EXCEEDED~;
					char digit = (char)(value % 100);
					buf[len:2] = DIGIT_PAIRS[2 * digit:2];
					len += 2;
					value /= 100;
				}
				if(value > 0){
					if (len >= FMT_NTOA_BUFFER_SIZE) return INTERNAL_BUFFER_EXCEEDED~;
					buf[len++] = '0' + (char)value;
				}
			case 16:
				do{
					if(len >= FMT_NTOA_BUFFER_SIZE) return INTERNAL_BUFFER_EXCEEDED~;
					char digit = (char)value & 0xF;
					buf[len++] = digit + (digit < 10 ? '0' : past_10);
					value >>= 4;
				}while(value);
			case 8:
				do{
					if (len >= FMT_NTOA_BUFFER_SIZE) return INTERNAL_BUFFER_EXCEEDED~;
					buf[len++] = '0' + (char)value & 0x7;
					value >>= 3;
				}while(value);
			default:
                if(2 <= base && base <= 36){
                    if(!value){
                        if (len >= FMT_NTOA_BUFFER_SIZE) return INTERNAL_BUFFER_EXCEEDED~;
                        buf[len++] = '0';
                        break;
                    }
                    while(value >= base){
                        if(len + 1 >= FMT_NTOA_BUFFER_SIZE) return INTERNAL_BUFFER_EXCEEDED~;
                        char digit = (char)(value % base);
                        buf[len] = digit + ((digit < 10) ? '0' : past_10);
                        len++;
                        value /= base;
                    }
                    if(value > 0){
                        if (len >= FMT_NTOA_BUFFER_SIZE) return INTERNAL_BUFFER_EXCEEDED~;
                        buf[len++] = ((value < 10) ? '0' : past_10) + (char)value;
                    }
                }else{
                    unreachable();
                }
		}
	}
	return self.ntoa_format((String)buf[:FMT_NTOA_BUFFER_SIZE], len, negative, base);
} // fn usz? Fmter.ntoa(&self, uint128 value, bool negative, uint base) @private //

fn usz? Fmter.ntoa_format(&self, String buf, usz len, bool negative, uint base) @private {
	// pad leading zeros
	if(self.flags.alignment == FmtAlignment.RIGHT){
		if(self.width && self.flags.padding == FmtPadding.ZEROS
                                && (negative || self.flags.sign == FmtSign.BOTH
                                        || self.flags.sign == FmtSign.SPACE_OR_MINUS)) self.width--;
		while(len < self.prec){
			if(len >= buf.len) return INTERNAL_BUFFER_EXCEEDED~;
			buf[len++] = '0';
		}
		while(self.flags.padding == FmtPadding.ZEROS && len < self.width){
			if(len >= buf.len) return INTERNAL_BUFFER_EXCEEDED~;
			buf[len++] = '0';
		}
	}

	// handle hash
	if(self.flags.alternate && base != 10){
		if(!self.flags.precision && len && len == self.prec && len == self.width){
			len--;
			if(len) len--;
		}
		if(base != 10){
			if(len + 1 >= buf.len) return INTERNAL_BUFFER_EXCEEDED~;
			switch(base){
				case 16:
					buf[len++] = self.flags.uppercase ? 'X' : 'x';
				case 8:
					buf[len++] = self.flags.uppercase ? 'O' : 'o';
				case 2:
					buf[len++] = self.flags.uppercase ? 'B' : 'b';
				default:
                    if(2 <= base && base <= 36){
                        buf[len++] = '(';
                        if(!base){
                            if(len >= FMT_NTOA_BUFFER_SIZE) return INTERNAL_BUFFER_EXCEEDED~;
                            buf[len++] = '0';
                            break;
                        }
                        while(base >= 10){
                            if(len + 1 >= FMT_NTOA_BUFFER_SIZE) return INTERNAL_BUFFER_EXCEEDED~;
                            char digit = (char)(base % 100);
                            buf[len:2] = DIGIT_PAIRS[2 * digit:2];
                            len += 2;
                            base /= 100;
                        }
                        if(base > 0){
                            if (len >= FMT_NTOA_BUFFER_SIZE) return INTERNAL_BUFFER_EXCEEDED~;
                            buf[len++] = '0' + (char)base;
                        }
                        buf[len++] = ')';
                    }else{
                        unreachable();
                    }
			} // switch(base) //
			buf[len++] = '0';
		} // if(base != 10) //
	} // if(self.flags.alternate && base != 10) //

	switch(true){
		case negative:
			if(len >= buf.len) return INTERNAL_BUFFER_EXCEEDED~;
			buf[len++] = '-';
		case self.flags.sign == FmtSign.BOTH:
			if(len >= buf.len) return INTERNAL_BUFFER_EXCEEDED~;
			buf[len++] = '+';
		case self.flags.sign == FmtSign.SPACE_OR_MINUS:
			if(len >= buf.len) return INTERNAL_BUFFER_EXCEEDED~;
			buf[len++] = ' ';
	}
    if(self.fill){
        switch(self.flags.alignment){
            case FmtAlignment.LEFT:
                while(len < self.width){
                    buf[len++] = self.fill;
                }
            case FmtAlignment.CENTRE:
                long padding = self.width - len;
                bool odd = false;
                if(padding > 0 && (bool)(padding & 0x0000000000000001)) odd = true;
                padding /= 2;
                DString ds;
                usz len2 = 0;
                if(padding > 0){
                    ds.append_repeat(self.fill, padding);
                    len2 += padding;
                    ds.append(buf[:len]);
                    len2 += len;
                    ds.append_repeat(self.fill, padding);
                    len2 += padding;
                    if(odd){
                        ds.append_char(self.fill);
                        len2++;
                    }
                    //len = len2;
                }
                String padded = ds.str_view();
                usz i = 0;
                foreach(ch : padded){
                    buf[i++] = ch;
                }
                len = i;
                assert(len == len2, "tally errror len != len2");
            case FmtAlignment.RIGHT:
                usz len2 = 0;
                if(!self.flags.alternate || base == 10){
                    long padding = self.width - len;
                    DString ds;
                    ds.append_repeat(self.fill, padding);
                    len2 += padding;
                    ds.append(buf[:len]);
                    len2 += len;
                    String padded = ds.str_view();
                    usz i = 0;
                    foreach(ch : padded){
                        buf[i++] = ch;
                    }
                    len = i;
                    assert(len == len2, "tally errror len != len2");
                }
        }
    }
	if(len) self.out_reverse(buf[:len])!;
	return len;
} // fn usz? Fmter.ntoa_format(&self, String buf, usz len, bool negative, uint base) @private //


fn usz? Fmter.ntoa_any(&self, any arg, uint base) @private
{
	bool is_neg;
	return self.ntoa(int_from_any(arg, &is_neg)!!, is_neg, base) @inline;
}

fn usz? Fmter.out_char(&self, any arg) @private {
    if(!self.fill) self.fill = ' ';
	if (!arg.type.kindof.is_int())
	{
		return self.out_substr("<NOT CHAR>");
	}
	usz len = 1;
	// pre padding
	Char32 c = types::any_to_int(arg, uint) ?? 0xFFFD;
    bool odd = false;
    DString ds;
    ds.appendf("%s", c);
    isz padding = self.width - ds.len();
	if(self.flags.alignment == FmtAlignment.RIGHT){
    	len += self.pad(self.fill, self.width, len)!;
    }else if(self.flags.alignment == FmtAlignment.CENTRE){
        if(padding > 0){
            odd = (bool)(padding & 0x0000000000000001);
            padding /= 2;
            len += self.pad2(self.fill, padding + (isz)odd)!;
        }
    }

	// char output
	switch(true){
		case c < 0x7f:
			self.out((char)c)!;
		case c < 0x7ff:
			self.out((char)(0xC0 | c >> 6))!;
			self.out((char)(0x80 | (c & 0x3F)))!;
		case c < 0xffff:
			self.out((char)(0xE0 | c >> 12))!;
			self.out((char)(0x80 | (c >> 6 & 0x3F)))!;
			self.out((char)(0x80 | (c & 0x3F)))!;
		default:
			self.out((char)(0xF0 | c >> 18))!;
			self.out((char)(0x80 | (c >> 12 & 0x3F)))!;
			self.out((char)(0x80 | (c >> 6 & 0x3F)))!;
			self.out((char)(0x80 | (c & 0x3F)))!;
	}
	if(self.flags.alignment == FmtAlignment.LEFT){
        len += self.pad(' ', self.width, len)!;
	}else if(self.flags.alignment == FmtAlignment.CENTRE){
        if(padding > 0){
            len += self.pad2(self.fill, padding)!;
        }
    }
	return len;
} // fn usz? Fmter.out_char(&self, any arg) @private //


fn usz? Fmter.out_reverse(&self, char[] buf) @private
{
	usz n;
	usz len = buf.len;
    isz padding = self.width - len;
	// pad spaces up to given width
	if(self.flags.sign == FmtPadding.SPACES && self.flags.alignment == FmtAlignment.RIGHT){
		n += self.pad(' ', self.width, len)!;
	}else if(self.flags.sign == FmtPadding.SPACES && self.flags.alignment == FmtAlignment.CENTRE){
        if(padding > 0){
            bool odd = (bool)(padding & 0x0000000000000001);
            padding /= 2;
            n += self.pad2(' ', padding + (usz)odd)!;
        }
    }
	// reverse string
	while(len) n += self.out(buf[--len])!;

	// append pad spaces up to given width
	n += self.adjust(n)!;
	return n;
}


fn int? printf_parse_format_field(
	any* args_ptr, usz args_len, usz* args_index_ptr,
	char* format_ptr, usz format_len, usz* index_ptr) @inline @private
{
	char c = format_ptr[*index_ptr];
	if (c.is_digit()) return simple_atoi(format_ptr, format_len, index_ptr);
	if (c != '*') return 0;
	usz len = ++(*index_ptr);
	if (len >= format_len) return BAD_FORMAT~;
	if (*args_index_ptr >= args_len) return BAD_FORMAT~;
	any val = args_ptr[(*args_index_ptr)++];
	if (!val.type.kindof.is_int()) return BAD_FORMAT~;
	uint? intval = types::any_to_int(val, int);
	return intval ?? BAD_FORMAT~;
}

fn bool char.is_conversion_char(self) @private {
    switch(self){                 //***********************************************************//
        case 'a': return true; // Hexadecimal floating type prepended with 0x and lowercase //
                               // digits, 'p' to indicate exponent.                         //
        case 'A': return true; // same as 'a' but all uppercase.                            //
        case 'b': return true; // binary integer, if '#' was present then prepend with 0b   //
        case 'B': return true; // binary integer, if '#' was present then prepend with 0B   //
        case 'c': return true; // char, either a char or a integer treated as an char.      //
        case 'd': return true; // decimal integer default for integers                      //
        case 'e': return true; // Floating type as Exponent form 'e' for exponent           //
        case 'E': return true; // Floating type as Exponent form 'E' for exponent           //
        case 'f': return true; // Fixed point. Displays the number as a fixed-point number. //
        case 'F': return true; // Fixed point. Same as 'f', but converts nan to NAN and inf //
                               // to INF. //
        case 'g': return true; // General format. For a given precision p >= 1, this rounds //
                               // the number to p significant digits and then formats the   //
                               // result in either fixed-point format or in scientific      //
                               // notation, depending on its magnitude.                     //
                               //                                                           //
                               // A precision of 0 is treated as equivalent to a precision  //
                               // of 1.                                                     //
        case 'G': return true; // General format. Same as 'g' except switches to 'E' if the // 
                               // number gets too large. The representations of infinity    //
                               // and NaN are uppercased, too.                              //
        case 'o': return true; // Octal format. Outputs the number in base 8.               //
        case 'p': return true; // Pointer format. This is the default type for pointers and //
                               // may be omitted.                                           //
        case 's': return true; // string the default for string                             //
        case 'x': return true; // hexadecimal if '#' was present prepend with 0x            //
        case 'X': return true; // hexadecimal if '#' was present prepend with 0X            //
        //case '?': return true; // debug the quoted and  supports many types                 //
                               // if string the special chars are escaped                   //
                               // if the char is a special then escape it                   //
     // case nothing           // nothing same as default for all types                     //
    }                          //***********************************************************//
    return false;
} // fn bool is_conversion_char(char c) //

fn bool char.valid_chrono_char(self) @private {
    switch(self){
        case 'a':
        case 'A':
        case 'b':
        case 'B':
        case 'c':
        case 'C':
        case 'd':
        case 'D':
        case 'e':
        case 'F':
        case 'g':
        case 'G':
        case 'h':
        case 'H':
        case 'I':
        case 'j':
        case 'k':
        case 'l':
        case 'm':
        case 'M':
        case 'n':
        case 'p':
        case 'P':
        case 'q':
        case 'Q':
        case 'r':
        case 'R':
        case 's':
        case 'S':
        case 't':
        case 'T':
        case 'u':
        case 'U':
        case 'V':
        case 'w':
        case 'W':
        case 'x':
        case 'X':
        case 'y':
        case 'Y':
        case 'z':
        case 'Z':
            return true;
        default:
            return false;
    } // switch(self) //
} // fn bool char.valid_chrono_char(self) //

fn long? String.get_width_or_precision(self, char* ch, usz* sp, any[] args, usz* place, ArgHash named,
                                    bool getting_width = false, bool chrono = false) @inline @private {
    usz len =  self.len;
    dbg::eprintfn("%s[%d]«%s» self[*sp:len - *sp] == `%s'\n *ch == `%c'\n"
                    " sp == %d\n len == `%d'\n getting_width == `%s'\n chrono == `%s'",
                                        $$FILE, $$LINE, $$FUNC, self[*sp:len - *sp],
                                                        *ch, *sp, len, getting_width, chrono);
    const char     BEGIN       = '{'; // using these as is mess up my editors //
    const char     END         = '}'; // bracket matching so I tokenise these //
    long?          num         = -1;
    char*          endptr      = null;
    DString chunk;
    any arg;
    //if(*sp >= len) return 0; // TODO: review this //
    if(*ch == '.'){
        if(getting_width) return 0;
        *ch = self[++(*sp)];
        if(*sp >= len) return ERROR_SPEC_DIED_TOO_SOON_COULD_NOT_GET_PRECISION~;
    }
    //*
    if(*ch != BEGIN && !ascii::is_digit(*ch) && *sp < len){
        *ch = self[++(*sp)]; // skip //
        if(*sp >= len) return ERROR_MISSING_OPENING_BRACE_IN_WIDTH_OR_PRECISION~;
    }
    if(!chrono && getting_width && *ch == '0' && *sp < len){
        *ch = self[++(*sp)]; // skip //
        if(*sp >= len) return ERROR_MISSING_OPENING_BRACE_IN_WIDTH_OR_PRECISION~;
    }
    // */
    dbg::eprintfn("%s[%d]«%s» self[*sp:len - *sp] == `%s'\n *ch == `%c'\n"
                    " sp == %d\n len == `%d'\n getting_width == `%s'\n chrono == `%s'",
                                        $$FILE, $$LINE, $$FUNC, self[*sp:len - *sp],
                                                        *ch, *sp, len, getting_width, chrono);
    if(*ch == BEGIN){
        *ch = self[++(*sp)]; // skip BEGIN //
        if(*sp >= len) return ERROR_MISSING_CLOSING_BRACE_IN_WIDTH_OR_PRECISION~;
        if(*ch == BEGIN) return ERROR_NESTING_LEVEL_OF_BRACES_TOO_DEEP_IN_WIDTH_OR_PRECISION_SEE_DOCS~;
        dbg::eprintfn("%s[%d]«%s» self[*sp:len - *sp] == `%s'\n *ch == `%c'\n"
                    " sp == %d\n len == `%d'\n getting_width == `%s'\n chrono == `%s'",
                                        $$FILE, $$LINE, $$FUNC, self[*sp:len - *sp],
                                                        *ch, *sp, len, getting_width, chrono);
        while(*sp < len && *ch != END){
            chunk.append(*ch);
            *ch = self[++(*sp)];
            if(*sp >= len) return ERROR_MISSING_CLOSING_BRACE_IN_WIDTH_OR_PRECISION~;
            if(*sp >= len && *ch != END) return ERROR_MISSING_CLOSING_BRACE_IN_WIDTH_OR_PRECISION~;
        }
        if(*ch != END) return ERROR_MISSING_CLOSING_BRACE_IN_WIDTH_OR_PRECISION~;
        if(*sp < len){
            *ch = self[++(*sp)];  // skip closing brace //
        }
        ZString chnk = chunk.zstr_view();
        dbg::eprintfn("%s[%d]«%s» self[*sp:len - *sp] == `%s'\n *ch == `%c'\n"
                    " sp == %d\n len == `%d'\n getting_width == `%s'\n chrono == `%s'\n chnk == `%s'",
                                        $$FILE, $$LINE, $$FUNC, self[*sp:len - *sp],
                                                        *ch, *sp, len, getting_width, chrono, chnk);
        if(chnk.len() == 0){
            if(*place >= args.len){
                if(getting_width) return ERROR_ARGS_EXHUSTED_WHILST_GETTING_WIDTH~;
                return ERROR_ARGS_EXHUSTED_WHILST_GETTING_PRECISION~;
            }
            arg = args[(*place)++];
            if(!arg.is_integer()){
                if(getting_width) return ERROR_ARG_CONSUMMED_IS_NOT_AN_INTEGER_WIDTH~;
                return ERROR_ARG_CONSUMMED_IS_NOT_AN_INTEGER_PRECISION~;
            }
        }else{
            num = chnk.strtol(&endptr, 0);
            if(catch excuse = num){
                return 0;
            }else{
                if(endptr && ((endptr - (char*)chnk) >= chnk.len())){
                    if(num < 0 || num >= args.len){
                        if(getting_width) return ERROR_ARG_OUT_OF_RANGE_WIDTH~;
                        return ERROR_ARG_OUT_OF_RANGE_PRECISION~;
                    }
                    arg = args[num];
                }else if(chnk.is_identifier()){
                    any*? arg_d = named[chnk.str_view()];
                    if(catch arg_excuse = arg_d){
                        return arg_excuse~;
                    }else{
                        arg = *arg_d;
                    }
                }else{
                    return ERROR_ARG_SPEC_MUST_BE_AN_IDENIFIER_OR_NUMBER~;
                }
            }
        }
        if(arg.is_integer()){
            int128? i = arg.to_integer();
            if(catch integer_excuse = i){
                return integer_excuse~;
            }else{
                dbg::eprintfn("%s[%d]«%s» self[*sp:len - *sp] == `%s'\n *ch == `%c'\n"
                            " sp == %d\n len == `%d'\n getting_width == `%s'\n chrono == `%s'\n i == `%d'",
                                                    $$FILE, $$LINE, $$FUNC, self[*sp:len - *sp],
                                                                *ch, *sp, len, getting_width, chrono, i);
                //*ch = self[++(*sp)];
                return (int)i;
            }
        }else{
            return ERROR_WIDTH_AND_PRECISION_MUST_BE_A_NUMBER~;
        }
        //num = libc::strtol((char*)(chunk.zstr_view()), &endptr, 0);
    }else{ // did not start with BEGIN //
        //*ch = self[++(*sp)];
        while(*sp < len && *ch != '.' && ascii::is_digit(*ch)){
            chunk.append(*ch);
            *ch = self[++(*sp)];
        }
        //if(chunk.len) return 0;
        ZString chnk = chunk.zstr_view();
        num = chnk.strtol(&endptr, 0);
        if(catch excuse = num){
            return excuse~;
        }else{
            dbg::eprintfn("%s[%d]«%s» self[*sp:len - *sp] == `%s'\n *ch == `%c'\n"
                                            " sp == %d\n len == `%d'",
                                    $$FILE, $$LINE, $$FUNC, self[*sp:len - *sp], *ch, *sp, len);
            if(endptr || (endptr - (char*)chnk) >= chunk.len()){
                dbg::eprintfn("%s[%d]«%s» self[*sp:len - *sp] == `%s'\n *ch == `%c'\n"
                                " sp == %d\n len == `%d'\n getting_width == `%s'\n chrono == `%s'",
                                                    $$FILE, $$LINE, $$FUNC, self[*sp:len - *sp],
                                                                    *ch, *sp, len, getting_width, chrono);
                return (long)num;
            }else{
                if(chrono) return (long)num;
                if(getting_width && (*ch == '.' || (*ch == 'L') ||
                                                    (*ch).is_conversion_char() || *ch == '?')){
                    dbg::eprintfn("%s[%d]«%s» self[*sp:len - *sp] == `%s'\n *ch == `%c'\n"
                                " sp == %d\n len == `%d'\n getting_width == `%s'\n chrono == `%s'",
                                                    $$FILE, $$LINE, $$FUNC, self[*sp:len - *sp],
                                                                    *ch, *sp, len, getting_width, chrono);
                    return (long)num;
                }else if(*ch == 'L' || (*ch).is_conversion_char() || *ch == '?'){
                    dbg::eprintfn("%s[%d]«%s» self[*sp:len - *sp] == `%s'\n *ch == `%c'\n"
                                " sp == %d\n len == `%d'\n getting_width == `%s'\n chrono == `%s'",
                                                    $$FILE, $$LINE, $$FUNC, self[*sp:len - *sp],
                                                                    *ch, *sp, len, getting_width, chrono);
                    return (long)num;
                }else{
                    dbg::eprintfn("%s[%d]«%s» self[*sp:len - *sp] == `%s'\n *ch == `%c'\n"
                                    " sp == %d\n len == `%d'",
                                    $$FILE, $$LINE, $$FUNC, self[*sp:len - *sp], *ch, *sp, len);
                    return ERROR_ARG_SPEC_MUST_BE_A_NUMBER~;
                }
            } // if(endptr || (endptr - (char*)chnk) >= chunk.len()) //
        } // if(catch excuse = num) //
    } // did not start with BEGIN //
} /* fn long? String.get_width_or_precision(self, char* ch, usz* sp, any[] args, usz* place,
                                         ArgHash named, bool getting_width = false, bool chrono = false) */

fn bool String.is_date_time_spec(self, char ch, usz sp) @private {
    //*
    dbg::eprintfn("%s[%d]«%s» self == `%s'\n ch == `%c'\n sp == %d",
                                        $$FILE, $$LINE, $$FUNC, self, ch, sp);
    // */
    long self_len              = self.len;
    //*
    dbg::eprintfn("%s[%d]«%s» self_len == `%d'\n ch == `%c'\n sp == %d",
                                        $$FILE, $$LINE, $$FUNC, self_len, ch);
    // */
    if(sp >= self_len) return false;
    const char     BEGIN       = '{'; // using these as is mess up my editors //
    const char     END         = '}'; // bracket matching so I tokenise these //
    if(ch == ':'){
        ch = self[sp++];
    }
    if(ch != BEGIN && ch != END){
        char peek = self[sp];
        if(peek.is_align_char()){
            // ch is the fill char and peek is the allign //
            sp++; // jump over them //
            if(sp >= self_len) return false;
            ch = self[sp++];
            if(sp >= self_len) return false;
        }else if(ch.is_align_char()){
            // no fill char but straight to align //
            ch = self[sp++];
            if(sp >= self_len) return false;
        }
    }
    if(ch == '.'){ // no width just precision maybe //
        ch = self[sp++];
        if(sp >= self_len) return false;
        if(ch == BEGIN && sp < self_len){
            ch = self[sp++];
            if(sp >= self_len) return false;
            while(ch != END && sp < self_len){
                ch = self[sp++];
                if(ch == BEGIN) return false; // no deep nesting //
            }
            if(sp >= self_len) return false;
        }else{
            ch = self[sp++];
            if(sp >= self_len) return false;
            while(ascii::is_digit(ch) && sp < self_len){
                ch = self[sp++];
            }
            if(sp >= self_len) return false;
        }
    }else{ // width and precision maybe //
        if(ch == BEGIN && sp < self_len){
            ch = self[sp++];
            if(sp >= self_len) return false;
            while(ch != END && sp < self_len){
                ch = self[sp++];
                if(ch == BEGIN) return false; // no deep nesting //
            }
            if(sp >= self_len) return false;
        }else{
            ch = self[sp++];
            if(sp >= self_len) return false;
            while(ascii::is_digit(ch) && sp < self_len){
                ch = self[sp++];
                if(ch == BEGIN || ch == END) return false; // no BEGIN or END embedded //
            }
            if(sp >= self_len) return false;
        }
        if(ch == '%') return true;
        if(ch == '.'){ // precision //
            if(ch == BEGIN && sp < self_len){
                ch = self[sp++];
                if(sp >= self_len) return false;
                while(ch != END && sp < self_len){
                    ch = self[sp++];
                    if(ch == BEGIN) return false; // no deep nesting //
                }
                if(sp >= self_len) return false;
            }else{
                ch = self[sp++];
                if(sp >= self_len) return false;
                while(ascii::is_digit(ch) && sp < self_len){
                    ch = self[sp++];
                    if(ch == BEGIN || ch == END) return false; // no BEGIN or END embedded //
                }
                if(sp >= self_len) return false;
            }
        }
    }
    if(ch == '%') return true;
    while(sp < self_len){
        ch = self[sp++];
        if(ch == '%') return true;
    }
    dbg::eprintfn("%s[%d]«%s» self[sp:self_len - sp] == `%s'\n ch == `%c'\n"
                                                " sp == %d\n self_len == `%d'\n start == `%d'",
                                $$FILE, $$LINE, $$FUNC, self[sp:self_len - sp], ch, sp, self_len);
    return false;
} /* fn bool String.is_date_time_spec(self, char ch, usz sp) */

macro FmtAlignment char.alignment_value(self) @private {
    switch(self){
        case '<': // left align //
            return FmtAlignment.LEFT;
        case '^': // centre align //
            return FmtAlignment.CENTRE;
        case '>': // right align //
            return FmtAlignment.RIGHT;
        default:
            return FmtAlignment.NOPADDING;
    } // switch(self) //
}

macro bool char.is_align_char(self) => "<^>".contains_char(self);
