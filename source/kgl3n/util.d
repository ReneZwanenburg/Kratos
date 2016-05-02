/**
kgl3n.util

Authors: David Herberth
License: MIT
*/

module kgl3n.util;

import std.meta : AliasSeq;


template TupleRange(int from, int to)
if (from <= to)
{
    static if (from >= to)
	{
        alias TupleRange = AliasSeq!();
    }
	else
	{
        alias TupleRange = AliasSeq!(from, TupleRange!(from + 1, to));
    }
}
