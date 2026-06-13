using System.Text.Json;

namespace GodotDotnetMcp.DotnetBridge;

internal static class Program
{
    private const string Version = "1.4.0";
    private const int DefaultTimeoutMs = 15000;
    private const int MaxTimeoutMs = 120000;

    public static async Task<int> Main(string[] args)
    {
        var responseJsonFile = BridgeCommandOptions.FindResponseJsonFile(args);
        BridgeCommandOptions? options = null;
        try
        {
            options = BridgeCommandOptions.Parse(args);
            if (options.Command is null || IsCommand(options.Command, "--capabilities"))
            {
                WriteJson(options.ResponseJsonFile, new
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

            if (options.Command is not null && options.Arguments.Count >= 2 && IsCommand(options.Command, "--call"))
            {
                var toolName = options.Arguments[0];
                using var document = JsonDocument.Parse(options.Arguments[1]);
                return await ExecuteCallAsync(toolName, document.RootElement, options);
            }

            if (options.Command is not null && options.Arguments.Count >= 2 && IsCommand(options.Command, "--call-json-file"))
            {
                var toolName = options.Arguments[0];
                using var document = JsonDocument.Parse(await File.ReadAllTextAsync(options.Arguments[1]));
                return await ExecuteCallAsync(toolName, document.RootElement, options);
            }

            WriteJson(options.ResponseJsonFile, new
            {
                success = false,
                error = "Usage: DotnetBridge --capabilities | --call <tool_name> <json_arguments> | --call-json-file <tool_name> <json_file>",
            });
            return 64;
        }
        catch (Exception ex)
        {
            WriteJson(options?.ResponseJsonFile ?? responseJsonFile, new
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

    private static async Task<int> ExecuteCallAsync(string toolName, JsonElement arguments, BridgeCommandOptions options)
    {
        using var timeoutCts = new CancellationTokenSource(options.TimeoutMs);
        try
        {
            var response = await BridgeToolDispatcher.ExecuteAsync(toolName, arguments, timeoutCts.Token);
            WriteJson(options.ResponseJsonFile, new
            {
                success = !response.IsError,
                isError = response.IsError,
                structuredContent = response.StructuredContent,
                content = response.TextContent,
            });
            return response.IsError ? 2 : 0;
        }
        catch (OperationCanceledException) when (timeoutCts.IsCancellationRequested)
        {
            WriteJson(options.ResponseJsonFile, new
            {
                success = false,
                isError = true,
                error = $"Tool '{toolName}' timed out after {options.TimeoutMs} ms.",
                structuredContent = new
                {
                    error = "runtime_timeout",
                    toolName,
                    timeoutMs = options.TimeoutMs,
                },
                content = $"Tool '{toolName}' timed out after {options.TimeoutMs} ms.",
            });
            return 124;
        }
    }

    private static void WriteJson(string? responseJsonFile, object payload)
    {
        var json = JsonSerializer.Serialize(payload, BridgeSerialization.JsonOptions);
        if (!string.IsNullOrWhiteSpace(responseJsonFile))
        {
            File.WriteAllText(responseJsonFile!, json);
            return;
        }

        Console.WriteLine(json);
    }

    private sealed record BridgeCommandOptions(string? Command, IReadOnlyList<string> Arguments, int TimeoutMs, string? ResponseJsonFile)
    {
        public static string? FindResponseJsonFile(IReadOnlyList<string> args)
        {
            for (var index = 0; index < args.Count - 1; index++)
            {
                if (IsCommand(args[index], "--response-json-file") && !string.IsNullOrWhiteSpace(args[index + 1]))
                {
                    return args[index + 1];
                }
            }

            return null;
        }

        public static BridgeCommandOptions Parse(IReadOnlyList<string> args)
        {
            var timeoutMs = DefaultTimeoutMs;
            string? responseJsonFile = null;
            string? command = null;
            var commandArgs = new List<string>();

            for (var index = 0; index < args.Count; index++)
            {
                var arg = args[index];
                if (IsCommand(arg, "--timeout-ms"))
                {
                    if (index + 1 >= args.Count || !int.TryParse(args[index + 1], out var parsedTimeout))
                    {
                        throw new ArgumentException("--timeout-ms requires an integer value.");
                    }

                    timeoutMs = Math.Clamp(parsedTimeout, 1, MaxTimeoutMs);
                    index++;
                    continue;
                }

                if (IsCommand(arg, "--response-json-file"))
                {
                    if (index + 1 >= args.Count || string.IsNullOrWhiteSpace(args[index + 1]))
                    {
                        throw new ArgumentException("--response-json-file requires a path.");
                    }

                    responseJsonFile = args[index + 1];
                    index++;
                    continue;
                }

                command = arg;
                for (var commandIndex = index + 1; commandIndex < args.Count; commandIndex++)
                {
                    commandArgs.Add(args[commandIndex]);
                }
                break;
            }

            return new BridgeCommandOptions(command, commandArgs, timeoutMs, responseJsonFile);
        }
    }
}
