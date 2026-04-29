using System.Security.Cryptography;
using System.Text;

namespace GodotDotnetMcp.DotnetBridge;

internal static class WriteToolHelpers
{
    public static string PreviewText(string text, int maxChars = 4_000)
    {
        return text.Length <= maxChars ? text : text[..maxChars] + Environment.NewLine + "...[truncated]";
    }

    public static string ComputeSha256(string text)
    {
        var bytes = Encoding.UTF8.GetBytes(text);
        var hash = SHA256.HashData(bytes);
        return Convert.ToHexString(hash).ToLowerInvariant();
    }
}
