namespace GodotDotnetMcp.CentralServer;

internal static class CentralServerPaths
{
    private const string HomeOverrideVariable = "GODOT_DOTNET_MCP_CENTRAL_HOME";

    public static string GetStoreDirectory()
    {
        var overridePath = Environment.GetEnvironmentVariable(HomeOverrideVariable);
        if (!string.IsNullOrWhiteSpace(overridePath))
        {
            return Path.GetFullPath(Environment.ExpandEnvironmentVariables(overridePath));
        }

        return Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "GodotDotnetMcp",
            "central_server");
    }
}
