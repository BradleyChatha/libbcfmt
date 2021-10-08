import libbc.fmt, core.internal.entrypoint;

mixin _d_cmain;

extern(C) int _Dmain(char[][])
{
    libbc.fmt.conv.runTests();
    libbc.fmt.fmt.runTests();
    return 0;
}