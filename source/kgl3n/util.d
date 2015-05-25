/**
kgl3n.util

Authors: David Herberth
License: MIT
*/

module kgl3n.util;

import std.typecons : TypeTuple;


template TupleRange(int from, int to)
if (from <= to)
{
    static if (from >= to)
	{
        alias TupleRange = TypeTuple!();
    }
	else
	{
        alias TupleRange = TypeTuple!(from, TupleRange!(from + 1, to));
    }
}
