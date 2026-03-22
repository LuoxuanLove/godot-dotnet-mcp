using System.Text.Json;

namespace GodotDotnetMcp.HostShared;

internal static class DotnetBuildTool
{
    public static async Task<BridgeToolCallResponse> ExecuteAsync(JsonElement arguments, CancellationToken cancellationToken)
    {
        try
        {
            var path = WorkspacePathResolver.ResolveExistingPath(BridgeArgumentReader.GetRequiredString(arguments, "path"));
            var operation = BridgeArgumentReader.GetStringOrDefault(arguments, "operation", "build").ToLowerInvariant();
            var configuration = BridgeArgumentReader.GetStringOrDefault(arguments, "configuration", "Debug");
            var framework = BridgeArgumentReader.TryGetString(arguments, "framework", out var frameworkValue) ? frameworkValue : null;
            var verbosity = BridgeArgumentReader.GetStringOrDefault(arguments, "verbosity", "minimal");

            var result = await DotnetCliRunner.RunAsync(path, operation, configuration, framework, verbosity, cancellationToken);
            return BridgeToolCallResponse.Success(result);
        }
        catch (BridgeToolException ex)
        {
            return BridgeToolCallResponse.Error(ex.Message, new { error = ex.Message });
        }
        catch (Exception ex)
        {
            return BridgeToolCallResponse.Error($"dotnet_build failed: {ex.Message}", new { error = ex.Message, exception = ex.GetType().Name });
        }
    }
}

internal static class CsprojReadTool
{
    public static BridgeToolCallResponse Execute(JsonElement arguments)
    {
        try
        {
            var path = WorkspacePathResolver.ResolveExistingPath(BridgeArgumentReader.GetRequiredString(arguments, "path"));
            if (!path.EndsWith(".csproj", StringComparison.OrdinalIgnoreCase))
            {
                throw new BridgeToolException("csproj_read requires a .csproj path.");
            }

            var result = CsprojReader.Read(path);
            return BridgeToolCallResponse.Success(result);
        }
        catch (BridgeToolException ex)
        {
            return BridgeToolCallResponse.Error(ex.Message, new { error = ex.Message });
        }
        catch (Exception ex)
        {
            return BridgeToolCallResponse.Error($"csproj_read failed: {ex.Message}", new { error = ex.Message, exception = ex.GetType().Name });
        }
    }
}

internal static class CsFileReadTool
{
    public static BridgeToolCallResponse Execute(JsonElement arguments)
    {
        try
        {
            var path = WorkspacePathResolver.ResolveExistingPath(BridgeArgumentReader.GetRequiredString(arguments, "path"));
            if (!path.EndsWith(".cs", StringComparison.OrdinalIgnoreCase))
            {
                throw new BridgeToolException("cs_file_read requires a .cs path.");
            }

            var result = CSharpFileReader.Read(path);
            return BridgeToolCallResponse.Success(result);
        }
        catch (BridgeToolException ex)
        {
            return BridgeToolCallResponse.Error(ex.Message, new { error = ex.Message });
        }
        catch (Exception ex)
        {
            return BridgeToolCallResponse.Error($"cs_file_read failed: {ex.Message}", new { error = ex.Message, exception = ex.GetType().Name });
        }
    }
}
