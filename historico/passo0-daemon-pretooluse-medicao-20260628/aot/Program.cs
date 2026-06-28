// ptu-client (pipe) — PROTOTIPO DESCARTAVEL (passo 0b: cliente NativeAOT + named pipe).
// Le o JSON do hook no stdin, conecta ao daemon por named pipe (deadline ~80ms),
// envia o JSON enquadrado, le o enum, monta o hookSpecificOutput e sai. Fail-closed: defer.
// NAO decide allow sozinho: so repassa o enum do daemon. NAO eh codigo final.
using System;
using System.IO;
using System.IO.Pipes;
using System.Text;

const string PipeName = "ptu-daemon-proto";
const int DeadlineMs = 80;

static string Out(string decision, string reason) =>
    "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"" +
    decision + "\",\"permissionDecisionReason\":\"" + reason + "\"}}";
string Defer() => Out("defer", "ptu-daemon-proto fail-closed");

string json;
try
{
    using var sin = Console.OpenStandardInput();
    using var r = new StreamReader(sin, Encoding.UTF8);
    json = r.ReadToEnd();
}
catch { Console.Out.Write(Defer()); return 0; }

try
{
    using var pipe = new NamedPipeClientStream(".", PipeName, PipeDirection.InOut);
    pipe.Connect(DeadlineMs);
    WriteFrame(pipe, 0x01, Encoding.UTF8.GetBytes(json));
    var resp = ReadFrame(pipe);
    var decision = Encoding.UTF8.GetString(resp);
    if (decision == "allow" || decision == "defer")
        Console.Out.Write(Out(decision, "ptu-daemon-proto"));
    else
        Console.Out.Write(Defer());
}
catch { Console.Out.Write(Defer()); }
return 0;

static void WriteFrame(Stream s, byte magic, byte[] payload)
{
    s.WriteByte(magic);
    var len = new byte[4];
    len[0] = (byte)((payload.Length >> 24) & 0xFF);
    len[1] = (byte)((payload.Length >> 16) & 0xFF);
    len[2] = (byte)((payload.Length >> 8) & 0xFF);
    len[3] = (byte)(payload.Length & 0xFF);
    s.Write(len, 0, 4);
    s.Write(payload, 0, payload.Length);
    s.Flush();
}

static byte[] ReadFrame(Stream s)
{
    int magic = s.ReadByte();
    if (magic < 0) throw new EndOfStreamException();
    var len = ReadExact(s, 4);
    int n = (len[0] << 24) | (len[1] << 16) | (len[2] << 8) | len[3];
    if (n < 0 || n > 65536) throw new InvalidDataException("frame len");
    return ReadExact(s, n);
}

static byte[] ReadExact(Stream s, int count)
{
    var buf = new byte[count];
    int off = 0;
    while (off < count)
    {
        int k = s.Read(buf, off, count - off);
        if (k <= 0) throw new EndOfStreamException();
        off += k;
    }
    return buf;
}
