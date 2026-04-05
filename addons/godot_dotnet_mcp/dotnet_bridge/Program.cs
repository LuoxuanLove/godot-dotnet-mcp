namespace GodotDotnetMcp.DotnetBridge;

internal static class LegacyStdioBridgeEntry
{
    public static async Task<int> RunAsync(
        string[] args,
        Stream input,
        Stream output,
        TextWriter error,
        CancellationToken cancellationToken = default)
    {
        try
        {
            return await BridgeApplication.RunAsync(args, input, output, error, cancellationToken);
        }
        catch (Exception ex)
        {
            await error.WriteLineAsync("Fatal bridge error:");
            await error.WriteLineAsync(ex.ToString());
            return 1;
        }
    }
}
