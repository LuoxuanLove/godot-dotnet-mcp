using GodotDotnetMcp.DotnetBridge;

try
{
    var exitCode = await BridgeApplication.RunAsync(
        args,
        Console.OpenStandardInput(),
        Console.OpenStandardOutput(),
        Console.Error);
    Environment.ExitCode = exitCode;
}
catch (Exception ex)
{
    await Console.Error.WriteLineAsync("Fatal bridge error:");
    await Console.Error.WriteLineAsync(ex.ToString());
    Environment.ExitCode = 1;
}
