using System.Text.Json;
using System.Reflection;

namespace GodotDotnetMcp.DotnetBridge;

internal static class Program
{
    private static readonly string Version =
        typeof(Program).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
        ?? typeof(Program).Assembly.GetName().Version?.ToString(3)
        ?? "0.0.0";

    public static async Task<int> Main(string[] args)
    {
        try
        {
            if (args.Length == 0 || IsCommand(args[0], "--capabilities"))
            {
                WriteJson(new
                {
                    success = true,
                    component = "godot-dotnet-mcp-roslyn-runtime",
                    version = Version,
                    mode = "syntax",
                    transport = "single_process_json",
                    tools = BridgeToolCatalog.GetTools(),
                });
                return 0;
            }

            if (args.Length >= 3 && IsCommand(args[0], "--call"))
            {
                var toolName = args[1];
                using var document = JsonDocument.Parse(args[2]);
                return await ExecuteCallAsync(toolName, document.RootElement);
            }

            if (args.Length >= 3 && IsCommand(args[0], "--call-json-file"))
            {
                var toolName = args[1];
                using var document = JsonDocument.Parse(await File.ReadAllTextAsync(args[2]));
                return await ExecuteCallAsync(toolName, document.RootElement);
            }

            WriteJson(new
            {
                success = false,
                error = "Usage: DotnetBridge --capabilities | --call <tool_name> <json_arguments> | --call-json-file <tool_name> <json_file>",
            });
            return 64;
        }
        catch (Exception ex)
        {
            WriteJson(new
            {
                success = false,
                error = ex.Message,
                exception = ex.GetType().Name,
            });
            return 1;
        }
    }

    private static bool IsCommand(string actual, string expected)
    {
        return string.Equals(actual, expected, StringComparison.OrdinalIgnoreCase);
    }

    private static async Task<int> ExecuteCallAsync(string toolName, JsonElement arguments)
    {
        var response = await BridgeToolDispatcher.ExecuteAsync(toolName, arguments, CancellationToken.None);
        WriteJson(new
        {
            success = !response.IsError,
            isError = response.IsError,
            structuredContent = response.StructuredContent,
            content = response.TextContent,
        });
        return response.IsError ? 2 : 0;
    }

    private static void WriteJson(object payload)
    {
        Console.WriteLine(JsonSerializer.Serialize(payload, BridgeSerialization.JsonOptions));
    }
}
