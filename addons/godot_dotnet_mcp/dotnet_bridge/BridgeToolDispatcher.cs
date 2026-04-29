using System.Text.Json;

namespace GodotDotnetMcp.DotnetBridge;

internal static class BridgeToolDispatcher
{
    public static Task<BridgeToolCallResponse> ExecuteAsync(string toolName, JsonElement arguments, CancellationToken cancellationToken)
    {
        return toolName switch
        {
            "dotnet_build" => DotnetBuildTool.ExecuteAsync(arguments, cancellationToken),
            "csproj_read" => Task.FromResult(CsprojReadTool.Execute(arguments)),
            "cs_file_read" => Task.FromResult(CsFileReadTool.Execute(arguments)),
            "cs_diagnostics" => CsDiagnosticsTool.ExecuteAsync(arguments, cancellationToken),
            "solution_analyze" => Task.FromResult(SolutionAnalyzeTool.Execute(arguments)),
            "csproj_write" => CsprojWriteTool.ExecuteAsync(arguments, cancellationToken),
            "cs_file_patch" => CsFilePatchTool.ExecuteAsync(arguments, cancellationToken),
            _ => Task.FromResult(BridgeToolCallResponse.Error($"Unknown tool: {toolName}", new { toolName })),
        };
    }
}
