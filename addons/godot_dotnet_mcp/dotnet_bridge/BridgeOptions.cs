namespace GodotDotnetMcp.DotnetBridge;

internal enum BridgeMode
{
    Stdio,
    Health,
    Version,
    Help,
}

internal sealed record BridgeOptions(BridgeMode Mode, string[] RemainingArguments)
{
    public static BridgeOptions Parse(string[] args)
    {
        if (args.Length == 0)
        {
            return new BridgeOptions(BridgeMode.Stdio, []);
        }

        var remaining = new List<string>();
        var mode = BridgeMode.Stdio;

        foreach (var arg in args)
        {
            switch (arg)
            {
                case "--stdio":
                    mode = BridgeMode.Stdio;
                    break;
                case "--health":
                    mode = BridgeMode.Health;
                    break;
                case "--version":
                case "-v":
                    mode = BridgeMode.Version;
                    break;
                case "--help":
                case "-h":
                case "/?":
                    mode = BridgeMode.Help;
                    break;
                default:
                    remaining.Add(arg);
                    break;
            }
        }

        return new BridgeOptions(mode, remaining.ToArray());
    }
}
