using GodotDotnetMcp.HostShared;

namespace GodotDotnetMcp.CentralServer;

internal static class CentralServerManifest
{
    public const string ProductName = "Godot .NET MCP Central Server";
    public const string PackageName = "GodotDotnetMcp.CentralServer";
    public const string TargetFramework = "net8.0";
    public static string Version => McpProtocolFacts.ServerVersion;
    public static string ServerName => McpProtocolFacts.ServerName;
    public static string ProtocolVersion => McpProtocolFacts.ProtocolVersion;
    public static string ToolSchemaVersion => McpProtocolFacts.ToolSchemaVersion;
    public const string Transport = "stdio";

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
