using System.Security.Cryptography;
using System.Text;

namespace GodotDotnetMcp.DotnetBridge;

internal static class WriteToolHelpers
{
    private static readonly UTF8Encoding Utf8NoBom = new(encoderShouldEmitUTF8Identifier: false);

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

    public static void WriteUtf8NoBom(string path, string text)
    {
        var resolvedPath = Path.GetFullPath(path);
        WorkspacePathResolver.ValidateWritableResolvedPath(resolvedPath);

        var directory = Path.GetDirectoryName(resolvedPath)
            ?? throw new BridgeToolException($"Target directory does not exist: {path}");
        var tempPath = Path.Combine(directory, $".{Path.GetFileName(resolvedPath)}.{Guid.NewGuid():N}.tmp");
        var backupPath = Path.Combine(directory, $".{Path.GetFileName(resolvedPath)}.{Guid.NewGuid():N}.bak");

        try
        {
            File.WriteAllText(tempPath, text, Utf8NoBom);
            WorkspacePathResolver.ValidateWritableResolvedPath(resolvedPath);

            if (File.Exists(resolvedPath))
            {
                File.Replace(tempPath, resolvedPath, backupPath, ignoreMetadataErrors: true);
            }
            else
            {
                File.Move(tempPath, resolvedPath, overwrite: false);
            }

            WorkspacePathResolver.ValidateWritableResolvedPath(resolvedPath);
        }
        finally
        {
            DeleteIfExists(tempPath);
            DeleteIfExists(backupPath);
        }
    }

    private static void DeleteIfExists(string path)
    {
        try
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
        catch (IOException)
        {
        }
        catch (UnauthorizedAccessException)
        {
        }
    }
}
