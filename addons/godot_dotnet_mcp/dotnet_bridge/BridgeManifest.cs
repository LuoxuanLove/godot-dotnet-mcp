namespace GodotDotnetMcp.DotnetBridge;

internal static class BridgeManifest
{
    public const string ProductName = "Godot .NET MCP Bridge";
    public const string PackageName = "GodotDotnetMcp.DotnetBridge";
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

    public static IReadOnlyList<string> SupportedTools { get; } =
    [
        "dotnet_build",
        "csproj_read",
        "cs_file_read",
        "cs_diagnostics",
        "solution_analyze",
        "csproj_write",
        "cs_file_patch",
    ];
}
