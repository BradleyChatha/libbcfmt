module libbc.fmt.conv;

import std.math : abs;
import std.traits : Unqual;
import std.range : isOutputRange;
import libbc.ds.string;

version(unittest) void runTests(){ static foreach(t; __traits(getUnitTests, __traits(parent, runTests))) t(); }

private enum MAX_SIZE_T_STRING_LEN = "18446744073709551615".length;
alias IntToCharBuffer = char[MAX_SIZE_T_STRING_LEN];

private immutable BASE10_CHARS = "0123456789";

String to(StringT : String, ValueT)(auto ref ValueT value)
{
    static if(is(ValueT == bool))
        return value ? String("true") : String("false");
    else static if(__traits(compiles, toBase10(value)))
        return value.toBase10;
    else static if(is(ValueT == struct))
    {
        String output;
        structToString(value, output);
        return output;
    }
    else static if(is(ValueT : const(char)[]))
        return String(value);
    else static if(is(ValueT == String))
        return value;
    else static if(is(ValueT : T[], T))
    {
        // TEMP
        String str;
        str.put('[');
        foreach(element; value)
        {
            str.put(element.to!String);
            str.put(", ");
        }
        str.put(']');

        return str;
    }
    else static if(is(ValueT : T*, T))
    {
        String output;
        pointerToString(value, output);
        return output;
    }
    else static assert(false, "Don't know how to convert '"~ValueT.stringof~"' into a String.");
}
///
@("to!String")
unittest
{
    static struct S
    {
        int a;
        string b;
        bool c;
    }

    static struct SS
    {
        string name;
        S s;
    }

    assert(127.to!String == "127");
    assert(S(29, "yolo", true).to!String == `S(29, "yolo", true)`);
    assert(SS("ribena cow", S(69, "swag", false)).to!String == `SS("ribena cow", S(69, "swag", false))`);
}

NumT to(NumT, ValueT)(ValueT value, out string error)
if(__traits(isIntegral, NumT))
{
    static if(is(ValueT : const(char)[]))
        return fromBase10!NumT(value, error);
    else static if(is(ValueT == String))
        return fromBase10!NumT(value.range, error);
    else static assert(false, "Don't know how to convert `"~ValueT.stringof~"` into a `"~NumT.stringof~"`");
}
///
@("to!NumT")
unittest
{
    string err;
    assert("69".to!int(err) == 69);
    assert(String("-120").to!byte(err) == -120);
}

EnumT to(EnumT, ValueT)(ValueT value)
if(is(EnumT == enum))
{
    import libd.data.foramt;
    switch(value)
    {
        static foreach(name; __traits(allMembers, EnumT))
            case mixin("cast(ValueT)EnumT."~name): return mixin("EnumT."~name);

        default:
            return typeof(return)(raise("Value '{0}' does not belong to enum {1}.".format(value, EnumT.stringof)));
    }
}

private void structToString(StructT, OutputT)(auto ref StructT value, ref OutputT output)
if(is(StructT == struct) && isOutputRange!(OutputT, const(char)[]))
{
    output.put(__traits(identifier, StructT));
    output.put("(");
    foreach(i, ref v; value.tupleof)
    {{
        static if(is(typeof(v) : const(char)[]) || is(typeof(v) == String))
        {
            output.put("\"");
            output.put(v);
            output.put("\"");
        }
        else
        {
            String s = to!String(v);
            output.put(s.range);
        }

        static if(i < StructT.tupleof.length-1)
            output.put(", ");
    }}
    output.put(")");
}

String toBase10(NumT)(NumT num)
{
    // Fun fact, because of SSO, this will always be small enough to go onto the stack.
    // MAX_SIZE_T_STRING_LEN is 20, small strings are up to 22 chars.
    IntToCharBuffer buffer;
    return String(toBase10(num, buffer));
}
///
@("toBase10 - String return")
unittest
{
    assert((cast(byte)127).toBase10!byte == "127");
    assert((cast(byte)-128).toBase10!byte == "-128");
}

char[] toBase10(NumT)(NumT num_, scope ref return IntToCharBuffer buffer)
{
    Unqual!NumT num = num_;
    size_t cursor = buffer.length-1;
    if(num == 0)
    {
        buffer[cursor] = '0';
        return buffer[cursor..$];
    }

    static if(__traits(isScalar, NumT))
    {
        static if(!__traits(isUnsigned, NumT))
        {
            const isNegative = num < 0;
            auto numAbs = isNegative ? num * -1UL : num;
        }
        else
            auto numAbs = num;

        while(numAbs != 0)
        {
            assert(numAbs >= 0);
            buffer[cursor--] = BASE10_CHARS[numAbs % 10];
            numAbs /= 10;
        }

        static if(!__traits(isUnsigned, NumT))
        if(isNegative)
            buffer[cursor--] = '-';
    }
    else static assert(false, "Don't know how to convert '"~NumT.stringof~"' into base-10");

    return buffer[cursor+1..$];    
}
///
@("toBase10")
unittest
{
    IntToCharBuffer buffer;
    assert(toBase10!byte(byte.max, buffer) == "127");
    assert(toBase10!byte(byte.min, buffer) == "-128");
    assert(toBase10!ubyte(ubyte.max, buffer) == "255");
    assert(toBase10!ubyte(ubyte.min, buffer) == "0");

    assert(toBase10!short(short.max, buffer) == "32767");
    assert(toBase10!short(short.min, buffer) == "-32768");
    assert(toBase10!ushort(ushort.max, buffer) == "65535");
    assert(toBase10!ushort(ushort.min, buffer) == "0");

    assert(toBase10!int(int.max, buffer) == "2147483647");
    assert(toBase10!int(int.min, buffer) == "-2147483648");
    assert(toBase10!uint(uint.max, buffer) == "4294967295");
    assert(toBase10!uint(uint.min, buffer) == "0");

    assert(toBase10!long(long.max, buffer) == "9223372036854775807");
    assert(toBase10!long(long.min, buffer) == "-9223372036854775808");
    assert(toBase10!ulong(ulong.max, buffer) == "18446744073709551615");
    assert(toBase10!ulong(ulong.min, buffer) == "0");
}

NumT fromBase10(NumT)(const(char)[] str, out string error)
{
    if(str.length == 0)
    {
        error = "String is null.";
        return 0;
    }

    ptrdiff_t cursor = cast(ptrdiff_t)str.length-1;
    
    const firstDigit = str[cursor--] - '0';
    if(firstDigit >= 10 || firstDigit < 0)
    {
        error = "String contains non-base10 characters.";
        return 0;
    }

    NumT result = cast(NumT)firstDigit;
    uint exponent = 10;
    while(cursor >= 0)
    {
        if(cursor == 0 && str[cursor] == '-')
        {
            static if(__traits(isUnsigned, NumT))
            {
                error = "Cannot convert a negative number into an unsigned type.";
                return 0;
            }
            else
            {
                result *= -1;
                break;
            }
        }

        const digit = str[cursor--] - '0';
        if(digit >= 10 || digit < 0)
        {
            error = "String contains non-base10 characters.";
            return 0;
        }

        const oldResult = result;
        result += digit * exponent;
        if(result < oldResult)
        {
            error = "Overflow. String contains a number greater than can fit into specified numeric type.";
            return 0;
        }

        exponent *= 10;
    }

    return result;
}
///
@("fromBase10")
unittest
{
    string err;
    assert(!fromBase10!int(null, err) && err);
    assert(fromBase10!int("0", err) == 0 && !err);
    assert(fromBase10!int("1", err) == 1 && !err);
    assert(fromBase10!int("21", err) == 21 && !err);
    assert(fromBase10!int("321", err) == 321 && !err);
    assert(!fromBase10!ubyte("256", err) && err);
    assert(fromBase10!ubyte("255", err) == 255 && !err);
    assert(!fromBase10!int("yolo", err) && err);
    assert(!fromBase10!uint("-20", err) && err);
    assert(fromBase10!int("-231", err) == -231 && !err);
}

void pointerToString(T, OutputT)(T* pointer, ref OutputT output)
{
    IntToCharBuffer buffer;
    output.put(toBase10(cast(size_t)pointer));
} 