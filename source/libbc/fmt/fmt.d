module libbc.fmt.fmt;

import libbc.ds.string, libbc.fmt.conv;

private struct FormatSegment
{
    bool isRawText;
    union
    {
        struct
        {
            const(char)[] raw;
        }

        struct
        {
            size_t index;
        }
    }
}

String format(Args...)(out string error, const char[] fmt, Args args)
{
    size_t cursor;
    String str;

    while(!error && cursor < fmt.length)
    {
        const seg = nextSegment(fmt, error, cursor);
        if(seg.isRawText)
        {
            str ~= seg.raw;
            continue;
        }

        if(seg.index >= Args.length)
        {
            error = "Format index out of bounds.";
            break;
        }

        Switch: final switch(seg.index)
        {
            static foreach(i; 0..Args.length)
            {
                case i:
                    str ~= args[i].to!String;
                    break Switch;
            }
        }
    }

    return str;
}

private FormatSegment nextSegment(const char[] fmt, out string error, ref size_t cursor)
{
    const start = cursor;
    if(fmt[cursor] != '{')
    {
        while(cursor < fmt.length && fmt[cursor] != '{')
            cursor++;
        FormatSegment seg;
        seg.isRawText = true;
        seg.raw = fmt[start..cursor];
        return seg;
    }

    FormatSegment seg;
    seg.isRawText = false;

    if(cursor + 1 < fmt.length && fmt[cursor+1] == '{')
    {
        seg.isRawText = true;
        seg.raw = "{{";
        cursor += 2;
        return seg;
    }

    while(cursor < fmt.length && fmt[cursor] != '}')
        cursor++;
    if(cursor == fmt.length)
    {
        seg.isRawText = true;
        seg.raw = fmt[start..$];
        return seg;
    }

    seg.index = fmt[start+1..cursor].to!size_t(error);
    cursor++;
    return seg;
}

unittest
{
    struct DoeRayMe
    {
        string easyAs;
        int oneTwoThree;
    }

    string err;
    assert(format(err, "abc") == "abc" && !err);
    assert(format(err, "a{0}c", "b") == "abc" && !err);
    assert(format(err, "abc {1} {0}", 123, "easy as") == "abc easy as 123");
    assert(format(err, "abc {0}", DoeRayMe("hard as", 321)) == `abc DoeRayMe("hard as", 321)`);
}

version(unittest) void runTests(){ static foreach(t; __traits(getUnitTests, __traits(parent, runTests))) t(); }