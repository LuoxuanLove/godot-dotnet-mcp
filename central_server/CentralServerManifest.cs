namespace GodotDotnetMcp.CentralServer;

internal static class CentralServerManifest
{
    public const string ProductName = "Godot .NET MCP Central Server";
    public const string PackageName = "GodotDotnetMcp.CentralServer";
    public const string TargetFramework = "net8.0";
    public const string Version = "0.6.0-dev";
    public const string Protocol = "stdio";

    public static IReadOnlyList<string> SupportedMethods { get; } =
    [
        "initialize",
        "initialized",
        "ping",
        "tools/list",
        "tools/call",
        "shutdown",
        "exit"
    ];
}
