%%% -*- Erlang -*-
%%%-------------------------------------------------------------------
%%% Author: Lon Willett <Lon.Willett@sse.ie>
%%%
%%% Description: Some minimal support for encoding, decoding, and
%%% manipulating strings of ISO-10646 characters (i.e. Unicode).
%%%-------------------------------------------------------------------

%%% Note:
%%% - The ucs server must be started before any call to:
%%%   to_unicode/2, from_unicode/2, getMIB/1, getCharset/1 and all the charset
%%%   test predicates. The server will currently NOT start automatically even
%%%   if this is not the case.


%% NOTICE: This is just an excerpt of the original ucs application
-module(ucs).
-vsn('0.3').
-author('Lon.Willett@sse.ie').
-modified_by('johan.blom@mobilearts.se').
-compile([verbose,report_warnings,warn_unused_vars]).



%%% Conversion to/from IANA recognised character sets
-export([to_unicode/2]).

%%% Micellaneous predicates
-export([is_iso10646/1, is_unicode/1, is_bmpchar/1, is_latin1/1, is_ascii/1,
	 is_visible_latin1/1, is_visible_ascii/1, is_iso646_basic/1,
	 is_incharset/2]).

%%% Conversion to/from RFC-1345 style mnemonic strings consisting
%%% of subsets of ISO-10646 with "escape" sequences.
%-export([from_mnemonic/1, from_mnemonic/2]).

%%% UCS-2, UCS-4, UTF-16, and UTF-8 encoding and decoding
-export([to_ucs2be/1,from_ucs2be/1, from_ucs2be/2]).
-export([to_ucs2le/1,from_ucs2le/1, from_ucs2le/2]).
-export([to_ucs4be/1,from_ucs4be/1, from_ucs4be/2]).
-export([to_ucs4le/1,from_ucs4le/1, from_ucs4le/2]).
-export([to_utf16be/1, from_utf16be/1, from_utf16be/2]).
-export([to_utf16le/1, from_utf16le/1, from_utf16le/2]).
-export([to_utf8/1, from_utf8/1, from_utf8/2]).

%%% NB: Non-canonical UTF-8 encodings and incorrectly used
%%% surrogate-pair codes are disallowed by this code.  There are
%%% important security implications concerning them.  DO NOT REMOVE
%%% THE VARIOUS GUARDS AND TESTS THAT ENFORCE THIS POLICY.  (Yes, I
%%% know the idiots at the unicode consortium decided to allow
%%% non-canonical UTF-8, but I'll refer you to RFC 2279 for my
%%% justification).


%%% Test if Ch is a legitimate ISO-10646 character code
is_iso10646(Ch) when integer(Ch), Ch >= 0 ->
    if Ch  < 16#D800 -> true;
       Ch  < 16#E000 -> false;	% Surrogates
       Ch  < 16#FFFE -> true;
       Ch =< 16#FFFF -> false;	% FFFE and FFFF (not characters)
       Ch =< 16#7FFFFFFF -> true;
       true -> false
    end;
is_iso10646(_) -> false.

%%% Test if Ch is a legitimate ISO-10646 character code capable of
%%% being encoded in a UTF-16 string.
is_unicode(Ch) when Ch < 16#110000 -> is_iso10646(Ch);
is_unicode(_) -> false.

%%% Test if Ch is a legitimate ISO-10646 character code belonging to
%%% the basic multi-lingual plane (BMP).
is_bmpchar(Ch) when integer(Ch), Ch >= 0 ->
    if Ch < 16#D800 -> true;
       Ch < 16#E000 -> false;	% Surrogates
       Ch < 16#FFFE -> true;
       true -> false
    end;
is_bmpchar(_) -> false.

%%% Test for legitimate Latin-1 code
is_latin1(Ch) when integer(Ch), Ch >= 0, Ch =< 255 -> true;
is_latin1(_) -> false.

%%% Test for legitimate ASCII code
is_ascii(Ch) when integer(Ch), Ch >= 0, Ch =< 127 -> true;
is_ascii(_) -> false.

%%% Test for char an element of ISO-646.basic set
is_iso646_basic(Ch) when integer(Ch), Ch >= $\s ->
    if Ch =< $Z ->
	    %% Everything in this range except $# $$ and $@
	    if Ch > $$ -> Ch =/= $@;
	       true -> Ch < $#
	    end;
       %% Only $_ and $a .. $z in range above $Z
       Ch > $z -> false;
       Ch >= $a -> true;
       true -> Ch =:= $_
    end;
is_iso646_basic(_) ->
    false.

%%% Test for char a visible Latin-1 char, i.e. a non-control Latin-1 char,
%%% excepting non-break space (but including space).
is_visible_latin1(Ch) when integer(Ch), Ch >= $\s ->
    if Ch =< $~ -> true;
       Ch >= 161 -> Ch =< 255
    end;
is_visible_latin1(_) ->
    false.

%%% Test for char a visible ASCII char, i.e. a non-control ASCII char
%%% (including space).
is_visible_ascii(Ch) when integer(Ch), Ch >= $\s -> Ch =< $~;
is_visible_ascii(_) -> false.


%%% UCS-4, big and little endian versions, encoding and decoding
to_ucs4be(List) when list(List) -> lists:flatmap(fun to_ucs4be/1, List);
to_ucs4be(Ch) -> char_to_ucs4be(Ch).

from_ucs4be(Bin) when binary(Bin) -> from_ucs4be(Bin,[],[]);
from_ucs4be(List) -> from_ucs4be(list_to_binary(List),[],[]).

from_ucs4be(Bin,Tail) when binary(Bin) -> from_ucs4be(Bin,[],Tail);
from_ucs4be(List,Tail) -> from_ucs4be(list_to_binary(List),[],Tail).

to_ucs4le(List) when list(List) -> lists:flatmap(fun to_ucs4le/1, List);
to_ucs4le(Ch) -> char_to_ucs4le(Ch).

from_ucs4le(Bin) when binary(Bin) -> from_ucs4le(Bin,[],[]);
from_ucs4le(List) -> from_ucs4le(list_to_binary(List),[],[]).

from_ucs4le(Bin,Tail) when binary(Bin) -> from_ucs4le(Bin,[],Tail);
from_ucs4le(List,Tail) -> from_ucs4le(list_to_binary(List),[],Tail).

%%% UCS-2, big and little endian versions, encoding and decoding
to_ucs2be(List) when list(List) -> lists:flatmap(fun to_ucs2be/1, List);
to_ucs2be(Ch) -> char_to_ucs2be(Ch).

from_ucs2be(Bin) when binary(Bin) -> from_ucs2be(Bin,[],[]);
from_ucs2be(List) -> from_ucs2be(list_to_binary(List),[],[]).

from_ucs2be(Bin,Tail) when binary(Bin) -> from_ucs2be(Bin,[],Tail);
from_ucs2be(List,Tail) -> from_ucs2be(list_to_binary(List),[],Tail).

to_ucs2le(List) when list(List) -> lists:flatmap(fun to_ucs2le/1, List);
to_ucs2le(Ch) -> char_to_ucs2le(Ch).

from_ucs2le(Bin) when binary(Bin) -> from_ucs2le(Bin,[],[]);
from_ucs2le(List) -> from_ucs2le(list_to_binary(List),[],[]).

from_ucs2le(Bin,Tail) when binary(Bin) -> from_ucs2le(Bin,[],Tail);
from_ucs2le(List,Tail) -> from_ucs2le(list_to_binary(List),[],Tail).


%%% UTF-16, big and little endian versions, encoding and decoding
to_utf16be(List) when list(List) -> lists:flatmap(fun to_utf16be/1, List);
to_utf16be(Ch) -> char_to_utf16be(Ch).

from_utf16be(Bin) when binary(Bin) -> from_utf16be(Bin,[],[]);
from_utf16be(List) -> from_utf16be(list_to_binary(List),[],[]).

from_utf16be(Bin,Tail) when binary(Bin) -> from_utf16be(Bin,[],Tail);
from_utf16be(List,Tail) -> from_utf16be(list_to_binary(List),[],Tail).

to_utf16le(List) when list(List) -> lists:flatmap(fun to_utf16le/1, List);
to_utf16le(Ch) -> char_to_utf16le(Ch).

from_utf16le(Bin) when binary(Bin) -> from_utf16le(Bin,[],[]);
from_utf16le(List) -> from_utf16le(list_to_binary(List),[],[]).

from_utf16le(Bin,Tail) when binary(Bin) -> from_utf16le(Bin,[],Tail);
from_utf16le(List,Tail) -> from_utf16le(list_to_binary(List),[],Tail).


%%% UTF-8 encoding and decoding
to_utf8(List) when list(List) -> lists:flatmap(fun to_utf8/1, List);
to_utf8(Ch) -> char_to_utf8(Ch).

from_utf8(Bin) when binary(Bin) -> from_utf8(Bin,[],[]);
from_utf8(List) -> from_utf8(list_to_binary(List),[],[]).

from_utf8(Bin,Tail) when binary(Bin) -> from_utf8(Bin,[],Tail);
from_utf8(List,Tail) -> from_utf8(list_to_binary(List),[],Tail).



% code_to_string(Ch) when integer(Ch), Ch >= 0 ->
%     format_code(Ch,0,[]).

% format_code(0,NDigits,Tail) ->
%     if (NDigits band 3) =/= 0 -> format_code(0,NDigits+1,[$0|Tail]);
%        NDigits =:= 0 -> "0000" ++ Tail;
%        true -> Tail
%     end;
% format_code(Ch,NDigits,Tail) ->
%     format_code(Ch bsr 4, NDigits+1, [digit(Ch band 15)|Tail]).

% digit(N) when N < 10 -> $0 + N;
% digit(N) -> ($A - 10) + N.


% from_mnemonic(List) ->
%     from_mnemonic(List,[],[]).

% from_mnemonic(List,Tail) ->
%     from_mnemonic(List,[],Tail).

% from_mnemonic([$&|Rest],Acc,Tail) ->
%     from_mnemonic_escaped(Rest,Acc,Tail);
% from_mnemonic([Ch|Rest],Acc,Tail) ->
%     from_mnemonic(Rest,[Ch|Acc],Tail);
% from_mnemonic([],Acc,Tail) ->
%     lists:reverse(Acc,Tail).

% from_mnemonic_escaped([$&|List],Acc,Tail) ->
%     from_mnemonic(List,[$&|Acc],Tail);
% from_mnemonic_escaped([$_|List],Acc,Tail) ->
%     {Mnem,[$_|Rest]} = lists:splitwith(fun(X) -> X =/= $_ end, List),
%     from_mnemonic(Rest,[long_mnemonic_to_char(Mnem)|Acc],Tail);
% from_mnemonic_escaped([$/,$c|List],Acc,Tail) ->
%     %% Special case: line continuation escape
%     from_mnemonic(skipnl(List),Acc,Tail);
% from_mnemonic_escaped([Ch1,Ch2|Rest],Acc,Tail) ->
%     from_mnemonic(Rest,[mnemonic_to_char([Ch1,Ch2])|Acc],Tail).

%%% skipnl(Str) -- drop a leading newline (possibly preceded by
%%% spaces) from Str, if it has one, else just return Str.
% skipnl(Str) ->
%     skipnl(Str,Str).

% skipnl([Ch|Str], Str0) when Ch =:= $\s; Ch =:= $\r ->
%     skipnl(Str,Str0);
% skipnl([$\n|Rest],_) ->
%     Rest;
% skipnl(_,Str0) ->
%     Str0.

% mnemonic_to_char(Mnem) ->
%     case ucs_data:mnemonic_to_code(Mnem) of
% 	%% undefined -> error;
% 	Code when integer(Code) -> Code
%     end.

% long_mnemonic_to_char([$?,$u|Digits]) when Digits =/= [] ->
%     Ch = hex_to_integer(Digits,0),
%     case is_iso10646(Ch) of
% 	%%false -> error
% 	true -> Ch
%     end;
% long_mnemonic_to_char(Mnem) -> % Other charset encodings not implemented
%     mnemonic_to_char(Mnem).

% hex_to_integer([Digit|Digits],N) when integer(Digit) ->
%     if Digit >= $0, Digit =< $9 ->
% 	    hex_to_integer(Digits,(N bsl 4) + Digit - $0);
%        Digit >= $A, Digit =< $F ->
% 	    hex_to_integer(Digits,(N bsl 4) + Digit - ($A - 10));
%        Digit >= $a, Digit =< $f ->
% 	    hex_to_integer(Digits,(N bsl 4) + Digit - ($a - 10))
%     end;
% hex_to_integer([],N) ->
%     N.

%%% ............................................................................
%%% UCS-4 support
%%% Possible errors encoding UCS-4:
%%%	- Non-character values (something other than 0 .. 2^31-1)
%%%	- Surrogate-pair code in string.
%%%	- 16#FFFE or 16#FFFF character in string.
%%% Possible errors decoding UCS-4:
%%%	- Element out of range (i.e. the "sign" bit is set).
%%%	- Surrogate-pair code in string.
%%%	- 16#FFFE or 16#FFFF character in string.
char_to_ucs4be(Ch) ->
    true = is_iso10646(Ch),
    [(Ch bsr 24),
     (Ch bsr 16) band 16#FF,
     (Ch bsr 8) band 16#FF,
     Ch band 16#FF].

from_ucs4be(<<Ch:32/big-signed-integer, Rest/binary>>,Acc,Tail) ->
    if Ch < 0; Ch >= 16#D800, Ch < 16#E000; Ch =:= 16#FFFE; Ch =:= 16#FFFF ->
	    exit({bad_character_code,Ch});
       true ->
	    from_ucs4be(Rest,[Ch|Acc],Tail)
    end;
from_ucs4be(<<>>,Acc,Tail) ->
    lists:reverse(Acc,Tail);
from_ucs4be(Bin,Acc,Tail) ->
    io:format("ucs Error: Bin=~p~n     Acc=~p~n     Tail=~p~n",[Bin,Acc,Tail]),
    {error,not_ucs4be}.

char_to_ucs4le(Ch) ->
    true = is_iso10646(Ch),
    [Ch band 16#FF,
     (Ch bsr 8) band 16#FF,
     (Ch bsr 16) band 16#FF,
     (Ch bsr 24)].


from_ucs4le(<<Ch:32/little-signed-integer, Rest/binary>>,Acc,Tail) ->
    if Ch < 0; Ch >= 16#D800, Ch < 16#E000; Ch =:= 16#FFFE; Ch =:= 16#FFFF ->
	    exit({bad_character_code,Ch});
       true ->
	    from_ucs4le(Rest,[Ch|Acc],Tail)
    end;
from_ucs4le(<<>>,Acc,Tail) ->
    lists:reverse(Acc,Tail);
from_ucs4le(Bin,Acc,Tail) ->
    io:format("ucs Error: Bin=~p~n     Acc=~p~n     Tail=~p~n",[Bin,Acc,Tail]),
    {error,not_ucs4le}.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% UCS-2 support
%%% FIXME! Don't know how to encode UCS-2!! 
%%% Currently I just encode as UCS-4, but strips the 16 higher bits.
char_to_ucs2be(Ch) ->
    true = is_iso10646(Ch),
    [(Ch bsr 8) band 16#FF,
     Ch band 16#FF].

from_ucs2be(<<Ch:16/big-signed-integer, Rest/binary>>,Acc,Tail) ->
    if Ch < 0; Ch >= 16#D800, Ch < 16#E000; Ch =:= 16#FFFE; Ch =:= 16#FFFF ->
	    exit({bad_character_code,Ch});
       true ->
	    from_ucs2be(Rest,[Ch|Acc],Tail)
    end;
from_ucs2be(<<>>,Acc,Tail) ->
    lists:reverse(Acc,Tail);
from_ucs2be(Bin,Acc,Tail) ->
    io:format("ucs Error: Bin=~p~n     Acc=~p~n     Tail=~p~n",[Bin,Acc,Tail]),
    {error,not_ucs2be}.

char_to_ucs2le(Ch) ->
    true = is_iso10646(Ch),
    [(Ch bsr 16) band 16#FF,
     (Ch bsr 24)].


from_ucs2le(<<Ch:16/little-signed-integer, Rest/binary>>,Acc,Tail) ->
    if Ch < 0; Ch >= 16#D800, Ch < 16#E000; Ch =:= 16#FFFE; Ch =:= 16#FFFF ->
	    exit({bad_character_code,Ch});
       true ->
	    from_ucs4le(Rest,[Ch|Acc],Tail)
    end;
from_ucs2le(<<>>,Acc,Tail) ->
    lists:reverse(Acc,Tail);
from_ucs2le(Bin,Acc,Tail) ->
    io:format("ucs Error: Bin=~p~n     Acc=~p~n     Tail=~p~n",[Bin,Acc,Tail]),
    {error,not_ucs2le}.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% UTF-16 support
%%% Possible errors encoding UTF-16
%%%	- Non-character values (something other than 0 .. 2^31-1)
%%%	- Surrogate-pair code in string.
%%%	- 16#FFFE or 16#FFFF character in string.
%%% NB: the UCS replacement char (U+FFFD) will be quietly substituted
%%% for unrepresentable chars (i.e. those geq to 2^20+2^16).
%%% Possible errors decoding UTF-16:
%%%	- Unmatched surrogate-pair code in string.
%%%	- 16#FFFE or 16#FFFF character in string.
char_to_utf16be(Ch) when integer(Ch), Ch >= 0 ->
    if Ch =< 16#FFFF ->
	    if Ch < 16#D800; Ch >= 16#E000, Ch < 16#FFFE ->
		    [Ch bsr 8, Ch band 16#FF]
	    end;
       Ch < 16#110000 ->
	    %% Encode with surrogate pair
	    X = Ch - 16#10000,
	    [16#D8 + (X bsr 18),
	     (X bsr 10) band 16#FF,
	     16#DC + ((X bsr 8) band 3),
	     X band 16#FF];
       Ch =< 16#7FFFFFFF ->
	    %% Unrepresentable char: use REPLACEMENT CHARACTER (U+FFFD)
	    [16#FF, 16#FD]
    end.

from_utf16be(<<Ch:16/big-unsigned-integer, Rest/binary>>, Acc, Tail)
  when Ch < 16#D800; Ch > 16#DFFF ->
    if Ch < 16#FFFE -> from_utf16be(Rest,[Ch|Acc],Tail) end;
from_utf16be(<<Hi:16/big-unsigned-integer, Lo:16/big-unsigned-integer,
	       Rest/binary>>, Acc, Tail)
  when Hi >= 16#D800, Hi < 16#DC00, Lo >= 16#DC00, Lo =< 16#DFFF ->
    %% Surrogate pair
    Ch = ((Hi band 16#3FF) bsl 10) + (Lo band 16#3FF) + 16#10000,
    from_utf16be(Rest, [Ch|Acc], Tail);
from_utf16be(<<>>,Acc,Tail) ->
    lists:reverse(Acc,Tail);
from_utf16be(Bin,Acc,Tail) ->
    io:format("ucs Error: Bin=~p~n     Acc=~p~n     Tail=~p~n",[Bin,Acc,Tail]),
    {error,not_utf16be}.

char_to_utf16le(Ch) when integer(Ch), Ch >= 0 ->
    if Ch =< 16#FFFF ->
	    if Ch < 16#D800; Ch >= 16#E000, Ch < 16#FFFE ->
		    [Ch band 16#FF, Ch bsr 8]
	    end;
       Ch < 16#110000 ->
	    %% Encode with surrogate pair
	    X = Ch - 16#10000,
	    [(X bsr 10) band 16#FF,
	     16#D8 + (X bsr 18),
	     X band 16#FF,
	     16#DC + ((X bsr 8) band 3)];
       Ch =< 16#7FFFFFFF ->
	    %% Unrepresentable char: use REPLACEMENT CHARACTER (U+FFFD)
	    [16#FD, 16#FF]
    end.

from_utf16le(<<Ch:16/little-unsigned-integer, Rest/binary>>, Acc, Tail)
  when Ch < 16#D800; Ch > 16#DFFF ->
    if Ch < 16#FFFE -> from_utf16le(Rest, [Ch|Acc], Tail) end;
from_utf16le(<<Hi:16/little-unsigned-integer, Lo:16/little-unsigned-integer,
	       Rest/binary>>, Acc, Tail)
  when Hi >= 16#D800, Hi < 16#DC00, Lo >= 16#DC00, Lo =< 16#DFFF ->
    %% Surrogate pair
    Ch = ((Hi band 16#3FF) bsl 10) + (Lo band 16#3FF) + 16#10000,
    from_utf16le(Rest, [Ch|Acc], Tail);
from_utf16le(<<>>,Acc,Tail) ->
    lists:reverse(Acc,Tail);
from_utf16le(Bin,Acc,Tail) ->
    io:format("ucs Error: Bin=~p~n     Acc=~p~n     Tail=~p~n",[Bin,Acc,Tail]),
    {error,not_utf16le}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% UTF-8 support
%%% Possible errors encoding UTF-8:
%%%	- Non-character values (something other than 0 .. 2^31-1).
%%%	- Surrogate pair code in string.
%%%	- 16#FFFE or 16#FFFF character in string.
%%% Possible errors decoding UTF-8:
%%%	- 10xxxxxx or 1111111x as initial byte.
%%%	- Insufficient number of 10xxxxxx octets following an initial octet of
%%%	multi-octet sequence.
%%% 	- Non-canonical encoding used.
%%%	- Surrogate-pair code encoded as UTF-8.
%%%	- 16#FFFE or 16#FFFF character in string.
char_to_utf8(Ch) when integer(Ch), Ch >= 0 ->
    if Ch < 128 ->
	    %% 0yyyyyyy
	    [Ch];
       Ch < 16#800 ->
	    %% 110xxxxy 10yyyyyy
	    [16#C0 + (Ch bsr 6),
	     128+(Ch band 16#3F)];
       Ch < 16#10000 ->
	    %% 1110xxxx 10xyyyyy 10yyyyyy
	    if Ch < 16#D800; Ch > 16#DFFF, Ch < 16#FFFE ->
		    [16#E0 + (Ch bsr 12),
		     128+((Ch bsr 6) band 16#3F),
		     128+(Ch band 16#3F)]
	    end;
       Ch < 16#200000 ->
	    %% 11110xxx 10xxyyyy 10yyyyyy 10yyyyyy
	    [16#F0+(Ch bsr 18),
	     128+((Ch bsr 12) band 16#3F),
	     128+((Ch bsr 6) band 16#3F),
	     128+(Ch band 16#3F)];
       Ch < 16#4000000 ->
	    %% 111110xx 10xxxyyy 10yyyyyy 10yyyyyy 10yyyyyy
	    [16#F8+(Ch bsr 24),
	     128+((Ch bsr 18) band 16#3F),
	     128+((Ch bsr 12) band 16#3F),
	     128+((Ch bsr 6) band 16#3F),
	     128+(Ch band 16#3F)];
       Ch < 16#80000000 ->
	    %% 1111110x 10xxxxyy 10yyyyyy 10yyyyyy 10yyyyyy 10yyyyyy
	    [16#FC+(Ch bsr 30),
	     128+((Ch bsr 24) band 16#3F),
	     128+((Ch bsr 18) band 16#3F),
	     128+((Ch bsr 12) band 16#3F),
	     128+((Ch bsr 6) band 16#3F),
	     128+(Ch band 16#3F)]
    end.

from_utf8(<<0:1, A:7, Rest/binary>>, Acc, Tail) ->
    %% 7 bits: 0yyyyyyy
    from_utf8(Rest,[A|Acc],Tail);
from_utf8(<<>>, Acc, Tail) ->
    lists:reverse(Acc,Tail);
from_utf8(<<6:3, A: 5, 2:2, B:6, Rest/binary>>, Acc, Tail)
  when A >= 2 ->
    %% 11 bits: 110xxxxy 10yyyyyy
    from_utf8(Rest, [A*64+B|Acc], Tail);
from_utf8(<<14:4, A: 4, 2:2, B:6, 2:2, C:6, Rest/binary>>, Acc, Tail)
  when A > 0; B >= 32 ->
    %% 16 bits: 1110xxxx 10xyyyyy 10yyyyyy
    Ch = (A*64+B)*64+C,
    if Ch < 16#D800; Ch > 16#DFFF, Ch < 16#FFFE ->
	    from_utf8(Rest, [Ch|Acc], Tail)
    end;
from_utf8(<<30:5, A:3, 2:2, B:6, 2:2, C:6, 2:2, D:6, Rest/binary>>, Acc, Tail)
  when A > 0; B >= 16 ->
    %% 21 bits: 11110xxx 10xxyyyy 10yyyyyy 10yyyyyy
    from_utf8(Rest, [((A*64+B)*64+C)*64+D|Acc], Tail);
from_utf8(<<62:6, A:2, 2:2, B:6, 2:2, C:6, 2:2, D:6, 2:2, E:6, Rest/binary>>,
	  Acc, Tail)
  when A > 0; B >= 8 ->
    %% 26 bits: 111110xx 10xxxyyy 10yyyyyy 10yyyyyy 10yyyyyy
    from_utf8(Rest, [(((A*64+B)*64+C)*64+D)*64+E|Acc], Tail);
from_utf8(<<126:7, A:1, 2:2, B:6, 2:2, C:6, 2:2, D:6, 2:2, E:6, 2:2, F:6,
	    Rest/binary>>, Acc, Tail)
  when A > 0; B >= 4 ->
    %% 31 bits: 1111110x 10xxxxyy 10yyyyyy 10yyyyyy 10yyyyyy 10yyyyyy
    from_utf8(Rest, [((((A*64+B)*64+C)*64+D)*64+E)*64+F|Acc], Tail);
from_utf8(Bin,Acc,Tail) ->
    io:format("ucs Error: Bin=~p~n     Acc=~p~n     Tail=~p~n",[Bin,Acc,Tail]),
    {error,not_utf8}.

%%% ----------------------------------------------------------------------------
%%% Translation to/from any IANA defined character set, given that a mapping
%%% exists. Don't care about validating valid subsets of Unicode
to_unicode(Input,Cs) when Cs=='ansi_x3.4-1968';Cs=='iso-ir-6';
			  Cs=='ansi_x3.4-1986';Cs=='iso_646.irv:1991';
			  Cs=='ascii';Cs=='iso646-us';Cs=='us-ascii';Cs=='us';
			  Cs=='ibm367';Cs=='cp367';Cs=='csascii' -> % US-ASCII
    Input;
to_unicode(Input,Cs) when Cs=='iso-10646-utf-1';Cs=='csiso10646utf1' ->
    Input;
to_unicode(Input,Cs) when Cs=='iso_646.basic:1983';Cs=='ref';
			  Cs=='csiso646basic1983' ->
    Input;
to_unicode(Input,Cs) when Cs=='iso_8859-1:1987';Cs=='iso-ir-100';
			  Cs=='iso_8859-1';Cs=='latin1';Cs=='l1';Cs=='ibm819';
			  Cs=='cp819';Cs=='csisolatin1' ->
    Input;
% to_unicode(Input,Cs) when Cs=='mnemonic';Cs=='"mnemonic+ascii+38';
% 			  Cs=='mnem';Cs=='"mnemonic+ascii+8200' ->
%     from_mnemonic(Input);
to_unicode(Input,Cs) when Cs=='iso-10646-ucs-2';Cs=='csunicode' ->
    from_ucs2be(Input); % Guess byteorder
to_unicode(Input,Cs) when Cs=='iso-10646-ucs-4';Cs=='csucs4' ->
    from_ucs4be(Input); % Guess byteorder
to_unicode(Input,Cs) when Cs=='utf-16be';Cs=='utf-16' ->
    from_utf16be(Input);
to_unicode(Input,'utf-16le') ->
    from_utf16le(Input);
to_unicode(Input,'utf-8') ->
    from_utf8(Input);
to_unicode(Input,Charset) ->
    exit({bad_character_code,Input,Charset}).
    %ucs_data:to_unicode(Input,Charset).




%%% Tests if Char is in Charset.
%%% Do this by trying to convert it into unicode, if possible a mapping was
%%% found and we are ok.
is_incharset(In,Cs) when Cs=='ansi_x3.4-1968';Cs=='iso-ir-6';
			 Cs=='ansi_x3.4-1986';Cs=='iso_646.irv:1991';
			 Cs=='ascii';Cs=='iso646-us';Cs=='us-ascii';Cs=='us';
			 Cs=='ibm367';Cs=='cp367';Cs=='csascii' -> % US-ASCII
    if
	integer(In) -> is_ascii(In);
	list(In) -> test_charset(fun is_ascii/1,In)
    end;
is_incharset(In,Cs) when Cs=='iso-10646-utf-1';Cs=='csiso10646utf1' ->
    if
	integer(In) -> is_unicode(In);
	list(In) -> test_charset(fun is_unicode/1, In)
    end;
is_incharset(In,Cs) when Cs=='iso_646.basic:1983';Cs=='ref';
			 Cs=='csiso646basic1983' ->
    if
	integer(In) -> is_iso646_basic(In);
	list(In) -> test_charset(fun is_iso646_basic/1, In)
    end;
is_incharset(In,Cs) when Cs=='iso_8859-1:1987';Cs=='iso-ir-100';
			 Cs=='iso_8859-1';Cs=='latin1';Cs=='l1';Cs=='ibm819';
			 Cs=='cp819';Cs=='csisolatin1' ->
    if
	integer(In) -> is_latin1(In);
	list(In) -> test_charset(fun is_latin1/1, In)
    end;
is_incharset(In,Charset) when integer(In) ->
    case to_unicode([In],Charset) of
	{error,unsupported_charset} ->
	    {error,unsupported_charset};
	{error,_} ->
	    false;
	[Int] when integer(Int) ->
	    true
    end;
is_incharset(In,Charset) when list(In) ->
    case to_unicode(In,Charset) of
	{error,unsupported_charset} ->
	    {error,unsupported_charset};
	{error,_} ->
	    false;
	[Int] when integer(Int) ->
	    true
    end.


test_charset(Fun,Input) ->
    case lists:all(Fun, Input) of
	true ->
	    true;
	_ ->
	    false
    end.

