namespace GodotDotnetMcp.Companion;

public static class EditorBridgeCompatibility
{
    public const int CompatibleMajorVersion = 2;

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

        var normalized = pluginVersion.Trim();
        if (normalized.StartsWith("v", StringComparison.OrdinalIgnoreCase))
        {
            normalized = normalized[1..];
        }

        var suffixIndex = normalized.IndexOfAny(['-', '+']);
        if (suffixIndex >= 0)
        {
            normalized = normalized[..suffixIndex];
        }

        return Version.TryParse(normalized, out version!);
    }
}
