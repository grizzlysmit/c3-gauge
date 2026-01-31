module my::loc;

/* Type used by `nl_langinfo'.  */
alias NlItem                     = CInt;

/* The default message set used by the gencat program.  */
const CInt   NL_SETD             = 1;

/* Value for FLAG parameter of `catgets' to say we want XPG4 compliance.  */
const CInt   NL_CAT_LOCALE       = 1;



/* Message catalog descriptor type.  */
alias NlCatd                     = void*;

const NlItem __LC_CTYPE		     = 0;
const NlItem __LC_NUMERIC		 = 1;
const NlItem __LC_TIME		     = 2;
const NlItem __LC_COLLATE		 = 3;
const NlItem __LC_MONETARY		 = 4;
const NlItem __LC_MESSAGES		 = 5;
const NlItem __LC_ALL		     = 6;
const NlItem __LC_PAPER		     = 7;
const NlItem __LC_NAME		     = 8;
const NlItem __LC_ADDRESS		 = 9;
const NlItem __LC_TELEPHONE	     =	10;
const NlItem __LC_MEASUREMENT    =	11;
const NlItem __LC_IDENTIFICATION =	12;

/* Open message catalog for later use, returning descriptor.

   This function is a possible cancellation point and therefore not
   marked with __THROW.  */
extern fn NlCatd catopen(CChar* __cat_name, CInt __flag) @cname("catopen");

/* Return translation with NUMBER in SET of CATALOG; if not found
   return STRING.  */
extern fn CChar* catgets(NlCatd __catalog, CInt __set, CInt __number,
                                              CChar* __string) @cname("catgets");
/* Close message CATALOG.  */
extern fn CInt catclose(NlCatd __catalog) @cname("catclose");


<*
   Construct an 'nl_item' value for 'nl_langinfo' from a locale category
   (LC_*) and an item index within the category.  Some code may depend on
   the item values within a category increasing monotonically with the
   indices. 
*>
macro NlItem @_nl_item(#category, #index){
    return ((#category << 16) | (#index));
}

/* Extract the category and item index from a constructed `nl_item' value.  */
macro _nl_item_category(item)	 =>	((CInt) (item) >> 16);

macro _nl_item_index(item)	     =>	((CInt) (item) & 0xffff);

const NlItem ZERO                = 0;

/* Enumeration of locale items that can be queried with `nl_langinfo'.  */
enum TimeConsts : const inline NlItem {
  /* LC_TIME category: date and time formatting.  */

  /* Abbreviated days of the week. */
  ABDAY_1 = @_nl_item(__LC_TIME, ZERO), /* Sun */
  ABDAY_2,
  ABDAY_3,
  ABDAY_4,
  ABDAY_5,
  ABDAY_6,
  ABDAY_7,

  /* Long-named days of the week. */
  DAY_1,			/* Sunday */
  DAY_2,			/* Monday */
  DAY_3,			/* Tuesday */
  DAY_4,			/* Wednesday */
  DAY_5,			/* Thursday */
  DAY_6,			/* Friday */
  DAY_7,			/* Saturday */

  /* Abbreviated month names, in the grammatical form used when the month
     is a part of a complete date.  */
  ABMON_1,			/* Jan */
  ABMON_2,
  ABMON_3,
  ABMON_4,
  ABMON_5,
  ABMON_6,
  ABMON_7,
  ABMON_8,
  ABMON_9,
  ABMON_10,
  ABMON_11,
  ABMON_12,

  /* Long month names, in the grammatical form used when the month
     is a part of a complete date.  */
  MON_1,			/* January */
  MON_2,
  MON_3,
  MON_4,
  MON_5,
  MON_6,
  MON_7,
  MON_8,
  MON_9,
  MON_10,
  MON_11,
  MON_12,

  AM_STR,			/* Ante meridiem string.  */
  PM_STR,			/* Post meridiem string.  */

  D_T_FMT,			/* Date and time format for strftime.  */
  D_FMT,			/* Date format for strftime.  */
  T_FMT,			/* Time format for strftime.  */
  T_FMT_AMPM,			/* 12-hour time format for strftime.  */

  ERA,				/* Alternate era.  */
  __ERA_YEAR,			/* Year in alternate era format.  */
  ERA_D_FMT,			/* Date in alternate era format.  */
  ALT_DIGITS,			/* Alternate symbols for digits.  */
  ERA_D_T_FMT,			/* Date and time in alternate era format.  */
  ERA_T_FMT,			/* Time in alternate era format.  */

  _NL_TIME_ERA_NUM_ENTRIES,	/* Number entries in the era arrays.  */
  _NL_TIME_ERA_ENTRIES,		/* Structure with era entries in usable form.*/

  _NL_WABDAY_1,		/* Sun */
  _NL_WABDAY_2,
  _NL_WABDAY_3,
  _NL_WABDAY_4,
  _NL_WABDAY_5,
  _NL_WABDAY_6,
  _NL_WABDAY_7,

  /* Long-named days of the week. */
  _NL_WDAY_1,		/* Sunday */
  _NL_WDAY_2,		/* Monday */
  _NL_WDAY_3,		/* Tuesday */
  _NL_WDAY_4,		/* Wednesday */
  _NL_WDAY_5,		/* Thursday */
  _NL_WDAY_6,		/* Friday */
  _NL_WDAY_7,		/* Saturday */

  /* Abbreviated month names, in the grammatical form used when the month
     is a part of a complete date.  */
  _NL_WABMON_1,		/* Jan */
  _NL_WABMON_2,
  _NL_WABMON_3,
  _NL_WABMON_4,
  _NL_WABMON_5,
  _NL_WABMON_6,
  _NL_WABMON_7,
  _NL_WABMON_8,
  _NL_WABMON_9,
  _NL_WABMON_10,
  _NL_WABMON_11,
  _NL_WABMON_12,

  /* Long month names, in the grammatical form used when the month
     is a part of a complete date.  */
  _NL_WMON_1,		/* January */
  _NL_WMON_2,
  _NL_WMON_3,
  _NL_WMON_4,
  _NL_WMON_5,
  _NL_WMON_6,
  _NL_WMON_7,
  _NL_WMON_8,
  _NL_WMON_9,
  _NL_WMON_10,
  _NL_WMON_11,
  _NL_WMON_12,

  _NL_WAM_STR,		/* Ante meridiem string.  */
  _NL_WPM_STR,		/* Post meridiem string.  */

  _NL_WD_T_FMT,		/* Date and time format for strftime.  */
  _NL_WD_FMT,		/* Date format for strftime.  */
  _NL_WT_FMT,		/* Time format for strftime.  */
  _NL_WT_FMT_AMPM,	/* 12-hour time format for strftime.  */

  _NL_WERA_YEAR,	/* Year in alternate era format.  */
  _NL_WERA_D_FMT,	/* Date in alternate era format.  */
  _NL_WALT_DIGITS,	/* Alternate symbols for digits.  */
  _NL_WERA_D_T_FMT,	/* Date and time in alternate era format.  */
  _NL_WERA_T_FMT,	/* Time in alternate era format.  */

  _NL_TIME_WEEK_NDAYS,
  _NL_TIME_WEEK_1STDAY,
  _NL_TIME_WEEK_1STWEEK,
  _NL_TIME_FIRST_WEEKDAY,
  _NL_TIME_FIRST_WORKDAY,
  _NL_TIME_CAL_DIRECTION,
  _NL_TIME_TIMEZONE,

  _DATE_FMT,		/* strftime format for date.  */
  _NL_W_DATE_FMT,

  _NL_TIME_CODESET,

  /* Long month names, in the grammatical form used when the month
     is named by itself.  */
  __ALTMON_1,			/* January */
  __ALTMON_2,
  __ALTMON_3,
  __ALTMON_4,
  __ALTMON_5,
  __ALTMON_6,
  __ALTMON_7,
  __ALTMON_8,
  __ALTMON_9,
  __ALTMON_10,
  __ALTMON_11,
  __ALTMON_12,

  /* Long month names, in the grammatical form used when the month
     is named by itself.  */
  _NL_WALTMON_1,			/* January */
  _NL_WALTMON_2,
  _NL_WALTMON_3,
  _NL_WALTMON_4,
  _NL_WALTMON_5,
  _NL_WALTMON_6,
  _NL_WALTMON_7,
  _NL_WALTMON_8,
  _NL_WALTMON_9,
  _NL_WALTMON_10,
  _NL_WALTMON_11,
  _NL_WALTMON_12,

  /* Abbreviated month names, in the grammatical form used when the month
     is named by itself.  */
  _NL_ABALTMON_1,			/* Jan */
  _NL_ABALTMON_2,
  _NL_ABALTMON_3,
  _NL_ABALTMON_4,
  _NL_ABALTMON_5,
  _NL_ABALTMON_6,
  _NL_ABALTMON_7,
  _NL_ABALTMON_8,
  _NL_ABALTMON_9,
  _NL_ABALTMON_10,
  _NL_ABALTMON_11,
  _NL_ABALTMON_12,

  /* Abbreviated month names, in the grammatical form used when the month
     is named by itself.  */
  _NL_WABALTMON_1,			/* Jan */
  _NL_WABALTMON_2,
  _NL_WABALTMON_3,
  _NL_WABALTMON_4,
  _NL_WABALTMON_5,
  _NL_WABALTMON_6,
  _NL_WABALTMON_7,
  _NL_WABALTMON_8,
  _NL_WABALTMON_9,
  _NL_WABALTMON_10,
  _NL_WABALTMON_11,
  _NL_WABALTMON_12,

  _NL_NUM_LC_TIME,	/* Number of indices in LC_TIME category.  */

  /* LC_COLLATE category: text sorting.
     This information is accessed by the strcoll and strxfrm functions.
     These `nl_langinfo' names are used only internally.  */
  _NL_COLLATE_NRULES = @_nl_item(__LC_CTYPE, ZERO),
  _NL_CTYPE_TOUPPER,
  _NL_CTYPE_GAP1,
  _NL_CTYPE_TOLOWER,
  _NL_CTYPE_GAP2,
  _NL_CTYPE_CLASS32,
  _NL_CTYPE_GAP3,
  _NL_CTYPE_GAP4,
  _NL_CTYPE_GAP5,
  _NL_CTYPE_GAP6,
  _NL_CTYPE_CLASS_NAMES,
  _NL_CTYPE_MAP_NAMES,
  _NL_CTYPE_WIDTH,
  _NL_CTYPE_MB_CUR_MAX,
  _NL_CTYPE_CODESET_NAME,
  CODESET = _NL_CTYPE_CODESET_NAME,
  _NL_CTYPE_TOUPPER32,
  _NL_CTYPE_TOLOWER32,
  _NL_CTYPE_CLASS_OFFSET,
  _NL_CTYPE_MAP_OFFSET,
  _NL_CTYPE_INDIGITS_MB_LEN,
  _NL_CTYPE_INDIGITS0_MB,
  _NL_CTYPE_INDIGITS1_MB,
  _NL_CTYPE_INDIGITS2_MB,
  _NL_CTYPE_INDIGITS3_MB,
  _NL_CTYPE_INDIGITS4_MB,
  _NL_CTYPE_INDIGITS5_MB,
  _NL_CTYPE_INDIGITS6_MB,
  _NL_CTYPE_INDIGITS7_MB,
  _NL_CTYPE_INDIGITS8_MB,
  _NL_CTYPE_INDIGITS9_MB,
  _NL_CTYPE_INDIGITS_WC_LEN,
  _NL_CTYPE_INDIGITS0_WC,
  _NL_CTYPE_INDIGITS1_WC,
  _NL_CTYPE_INDIGITS2_WC,
  _NL_CTYPE_INDIGITS3_WC,
  _NL_CTYPE_INDIGITS4_WC,
  _NL_CTYPE_INDIGITS5_WC,
  _NL_CTYPE_INDIGITS6_WC,
  _NL_CTYPE_INDIGITS7_WC,
  _NL_CTYPE_INDIGITS8_WC,
  _NL_CTYPE_INDIGITS9_WC,
  _NL_CTYPE_OUTDIGIT0_MB,
  _NL_CTYPE_OUTDIGIT1_MB,
  _NL_CTYPE_OUTDIGIT2_MB,
  _NL_CTYPE_OUTDIGIT3_MB,
  _NL_CTYPE_OUTDIGIT4_MB,
  _NL_CTYPE_OUTDIGIT5_MB,
  _NL_CTYPE_OUTDIGIT6_MB,
  _NL_CTYPE_OUTDIGIT7_MB,
  _NL_CTYPE_OUTDIGIT8_MB,
  _NL_CTYPE_OUTDIGIT9_MB,
  _NL_CTYPE_OUTDIGIT0_WC,
  _NL_CTYPE_OUTDIGIT1_WC,
  _NL_CTYPE_OUTDIGIT2_WC,
  _NL_CTYPE_OUTDIGIT3_WC,
  _NL_CTYPE_OUTDIGIT4_WC,
  _NL_CTYPE_OUTDIGIT5_WC,
  _NL_CTYPE_OUTDIGIT6_WC,
  _NL_CTYPE_OUTDIGIT7_WC,
  _NL_CTYPE_OUTDIGIT8_WC,
  _NL_CTYPE_OUTDIGIT9_WC,
  _NL_CTYPE_TRANSLIT_TAB_SIZE,
  _NL_CTYPE_TRANSLIT_FROM_IDX,
  _NL_CTYPE_TRANSLIT_FROM_TBL,
  _NL_CTYPE_TRANSLIT_TO_IDX,
  _NL_CTYPE_TRANSLIT_TO_TBL,
  _NL_CTYPE_TRANSLIT_DEFAULT_MISSING_LEN,
  _NL_CTYPE_TRANSLIT_DEFAULT_MISSING,
  _NL_CTYPE_TRANSLIT_IGNORE_LEN,
  _NL_CTYPE_TRANSLIT_IGNORE,
  _NL_CTYPE_MAP_TO_NONASCII,
  _NL_CTYPE_NONASCII_CASE,
  _NL_CTYPE_EXTRA_MAP_1,
  _NL_CTYPE_EXTRA_MAP_2,
  _NL_CTYPE_EXTRA_MAP_3,
  _NL_CTYPE_EXTRA_MAP_4,
  _NL_CTYPE_EXTRA_MAP_5,
  _NL_CTYPE_EXTRA_MAP_6,
  _NL_CTYPE_EXTRA_MAP_7,
  _NL_CTYPE_EXTRA_MAP_8,
  _NL_CTYPE_EXTRA_MAP_9,
  _NL_CTYPE_EXTRA_MAP_10,
  _NL_CTYPE_EXTRA_MAP_11,
  _NL_CTYPE_EXTRA_MAP_12,
  _NL_CTYPE_EXTRA_MAP_13,
  _NL_CTYPE_EXTRA_MAP_14,
  _NL_NUM_LC_CTYPE,

  /* LC_MONETARY category: formatting of monetary quantities.
     These items each correspond to a member of `struct lconv',
     defined in <locale.h>.  */
  __INT_CURR_SYMBOL = @_nl_item(__LC_MONETARY, ZERO),
  __CURRENCY_SYMBOL,
  __MON_DECIMAL_POINT,
  __MON_THOUSANDS_SEP,
  __MON_GROUPING,
  __POSITIVE_SIGN,
  __NEGATIVE_SIGN,
  __INT_FRAC_DIGITS,
  __FRAC_DIGITS,
  __P_CS_PRECEDES,
  __P_SEP_BY_SPACE,
  __N_CS_PRECEDES,
  __N_SEP_BY_SPACE,
  __P_SIGN_POSN,
  __N_SIGN_POSN,
  _NL_MONETARY_CRNCYSTR,
  __INT_P_CS_PRECEDES,
  __INT_P_SEP_BY_SPACE,



  __INT_N_CS_PRECEDES,



  __INT_N_SEP_BY_SPACE,



  __INT_P_SIGN_POSN,



  __INT_N_SIGN_POSN,



  _NL_MONETARY_DUO_INT_CURR_SYMBOL,
  _NL_MONETARY_DUO_CURRENCY_SYMBOL,
  _NL_MONETARY_DUO_INT_FRAC_DIGITS,
  _NL_MONETARY_DUO_FRAC_DIGITS,
  _NL_MONETARY_DUO_P_CS_PRECEDES,
  _NL_MONETARY_DUO_P_SEP_BY_SPACE,
  _NL_MONETARY_DUO_N_CS_PRECEDES,
  _NL_MONETARY_DUO_N_SEP_BY_SPACE,
  _NL_MONETARY_DUO_INT_P_CS_PRECEDES,
  _NL_MONETARY_DUO_INT_P_SEP_BY_SPACE,
  _NL_MONETARY_DUO_INT_N_CS_PRECEDES,
  _NL_MONETARY_DUO_INT_N_SEP_BY_SPACE,
  _NL_MONETARY_DUO_P_SIGN_POSN,
  _NL_MONETARY_DUO_N_SIGN_POSN,
  _NL_MONETARY_DUO_INT_P_SIGN_POSN,
  _NL_MONETARY_DUO_INT_N_SIGN_POSN,
  _NL_MONETARY_UNO_VALID_FROM,
  _NL_MONETARY_UNO_VALID_TO,
  _NL_MONETARY_DUO_VALID_FROM,
  _NL_MONETARY_DUO_VALID_TO,
  _NL_MONETARY_CONVERSION_RATE,
  _NL_MONETARY_DECIMAL_POINT_WC,
  _NL_MONETARY_THOUSANDS_SEP_WC,
  _NL_MONETARY_CODESET,
  _NL_NUM_LC_MONETARY,

  /* LC_NUMERIC category: formatting of numbers.
     These also correspond to members of `struct lconv'; see <locale.h>.  */
  __DECIMAL_POINT = @_nl_item(__LC_NUMERIC, ZERO),



  RADIXCHAR = __DECIMAL_POINT,

  __THOUSANDS_SEP,



  THOUSEP = __THOUSANDS_SEP,

  __GROUPING,



  _NL_NUMERIC_DECIMAL_POINT_WC,
  _NL_NUMERIC_THOUSANDS_SEP_WC,
  _NL_NUMERIC_CODESET,
  _NL_NUM_LC_NUMERIC,

  __YESEXPR = @_nl_item(__LC_MESSAGES, ZERO), /* Regex matching ``yes'' input.  */

  __NOEXPR,			/* Regex matching ``no'' input.  */

  __YESSTR,			/* Output string for ``yes''.  */



  __NOSTR,			/* Output string for ``no''.  */



  _NL_MESSAGES_CODESET,
  _NL_NUM_LC_MESSAGES,

  _NL_PAPER_HEIGHT = @_nl_item(__LC_PAPER, ZERO),
  _NL_PAPER_WIDTH,
  _NL_PAPER_CODESET,
  _NL_NUM_LC_PAPER,

  _NL_NAME_NAME_FMT = @_nl_item(__LC_NAME, ZERO),
  _NL_NAME_NAME_GEN,
  _NL_NAME_NAME_MR,
  _NL_NAME_NAME_MRS,
  _NL_NAME_NAME_MISS,
  _NL_NAME_NAME_MS,
  _NL_NAME_CODESET,
  _NL_NUM_LC_NAME,

  _NL_ADDRESS_POSTAL_FMT = @_nl_item(__LC_ADDRESS, ZERO),
  _NL_ADDRESS_COUNTRY_NAME,
  _NL_ADDRESS_COUNTRY_POST,
  _NL_ADDRESS_COUNTRY_AB2,
  _NL_ADDRESS_COUNTRY_AB3,
  _NL_ADDRESS_COUNTRY_CAR,
  _NL_ADDRESS_COUNTRY_NUM,
  _NL_ADDRESS_COUNTRY_ISBN,
  _NL_ADDRESS_LANG_NAME,
  _NL_ADDRESS_LANG_AB,
  _NL_ADDRESS_LANG_TERM,
  _NL_ADDRESS_LANG_LIB,
  _NL_ADDRESS_CODESET,
  _NL_NUM_LC_ADDRESS,

  _NL_TELEPHONE_TEL_INT_FMT = @_nl_item(__LC_TELEPHONE, ZERO),
  _NL_TELEPHONE_TEL_DOM_FMT,
  _NL_TELEPHONE_INT_SELECT,
  _NL_TELEPHONE_INT_PREFIX,
  _NL_TELEPHONE_CODESET,
  _NL_NUM_LC_TELEPHONE,

  _NL_MEASUREMENT_MEASUREMENT = @_nl_item(__LC_MEASUREMENT, ZERO),
  _NL_MEASUREMENT_CODESET,
  _NL_NUM_LC_MEASUREMENT,

  _NL_IDENTIFICATION_TITLE = @_nl_item(__LC_IDENTIFICATION, ZERO),
  _NL_IDENTIFICATION_SOURCE,
  _NL_IDENTIFICATION_ADDRESS,
  _NL_IDENTIFICATION_CONTACT,
  _NL_IDENTIFICATION_EMAIL,
  _NL_IDENTIFICATION_TEL,
  _NL_IDENTIFICATION_FAX,
  _NL_IDENTIFICATION_LANGUAGE,
  _NL_IDENTIFICATION_TERRITORY,
  _NL_IDENTIFICATION_AUDIENCE,
  _NL_IDENTIFICATION_APPLICATION,
  _NL_IDENTIFICATION_ABBREVIATION,
  _NL_IDENTIFICATION_REVISION,
  _NL_IDENTIFICATION_DATE,
  _NL_IDENTIFICATION_CATEGORY,
  _NL_IDENTIFICATION_CODESET,
  _NL_NUM_LC_IDENTIFICATION,

  /* This marks the highest value used.  */
  _NL_NUM
} // enum TimeConsts : const NlItem //

/* This macro produces an item you can pass to `nl_langinfo' or
   `nl_langinfo_l' to get the name of the locale in use for CATEGORY.  */
macro _nl_locale_name(category)  =>	@_nl_item(category, _nl_item_index(-1));

//const NlItem __DECIMAL_POINT     = @_nl_item(__LC_NUMERIC, ZERO);
  
const RADIXCHAR                  = TimeConsts.__DECIMAL_POINT;


/* Return the current locale's value for ITEM.
   If ITEM is invalid, an empty string is returned.

   The string returned will not change until `setlocale' is called;
   it is usually in read-only memory and cannot be modified.  */

extern fn CChar* nl_langinfo(NlItem item) @cname("nl_langinfo");

/*
alias Cleanup = fn void(__LocaleData* );
enum  Alloc { // Flavor of storage used for those //
    LD_MALLOCED,          // Both name and filedata are malloc'd //
    LD_MAPPED,            // name is malloc'd, filedata mmap'd //
    LD_ARCHIVE            // Both point into mmap'd archive regions //
} 

alias Off_t = CLong;

struct __Lc_time_data; @cname("__lc_time_data");

alias Lc_time_data = __Lc_time_data;

struct __LocaleData {
    CChar* name;         // Name of the locale //
    CChar* filedata;     // Region mapping the file data (or malloc'd data) //
    Off_t filesize;      // Size of the file/region //
    Alloc alloc;
    // Slot for category-specific cached data //
    struct {
        Cleanup cleanup;
        union {
            void* data;
            Lc_time_data* time;
            gconv_fcts* ctype;
        };
    } private;
    CUInt usage_count; // Counter for users //
    CInt use_translit; // Nonzero if transliteration should be used //
    CUInt nstrings;    // Number of strings below //
    union Locale_data_value[//nstrings//] {
        uint* wstr;
        CChar* string;
        CInt word;
    } values;
}
// */

/*
<* 
   POSIX.1-2008: the locale_t type, representing a locale context
   (implementation-namespace version).  This type should be treated
   as opaque by applications; some details are exposed for the sake of
   efficiency in e.g. ctype functions.  
*>
struct __LocaleStruct {
  // Note: LC_ALL is not a valid index into this array.  //
  __LocaleData*[13] __locales; // 13 = __LC_LAST. //

  // To increase the speed of this solution we add some special members.  //
  CUShort*__ctype_b;
  CInt* __ctype_tolower;
  CInt* __ctype_toupper;

  // Note: LC_ALL is not a valid index into this array.  //
  CChar*[13] __names;
} // struct __LocaleStruct  //

alias __Locale_t = __LocaleStruct*;

alias Locale_t = __Locale_t;
// */

/* Just like nl_langinfo but get the information from the locale object L.  */
//extern fn CChar* nl_langinfo_l(NlItem __item, Locale_t __l) @cname("nl_langinfo_l");
