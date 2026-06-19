using System.Xml;
using System.Xml.Linq;

namespace GodotDotnetMcp.DotnetBridge;

internal static class SafeXmlDocumentLoader
{
    public static XDocument Load(string path, LoadOptions options = LoadOptions.None)
    {
        var settings = new XmlReaderSettings
        {
            DtdProcessing = DtdProcessing.Prohibit,
            XmlResolver = null
        };
        using var stream = File.OpenRead(path);
        using var reader = XmlReader.Create(stream, settings);
        return XDocument.Load(reader, options);
    }
}
