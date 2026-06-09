using System.Text.RegularExpressions;

namespace GodotDotnetMcp.Companion;

public static class EditorBridgeCompatibility
{
    public const int CompatibleMajorVersion = 2;
    private static readonly Regex SemanticVersionPattern = new(
        """
        ^v?(?<core>(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*))(?:-(?<pre>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+(?<build>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$
        """,
        RegexOptions.CultureInvariant | RegexOptions.IgnorePatternWhitespace);

    public static bool IsPluginVersionCompatible(string? pluginVersion)
    {
        return TryParseVersion(pluginVersion, out var version) &&
            version.Major == CompatibleMajorVersion;
    }

    public static string CompatibilityRequirement =>
        $"Requires a v{CompatibleMajorVersion}.x editor bridge plugin version.";

    private static bool TryParseVersion(string? pluginVersion, out Version version)
    {
        version = new Version(0, 0);
        if (string.IsNullOrWhiteSpace(pluginVersion))
        {
            return false;
        }

        var match = SemanticVersionPattern.Match(pluginVersion);
        return match.Success &&
            Version.TryParse(match.Groups["core"].Value, out version!);
    }
}
