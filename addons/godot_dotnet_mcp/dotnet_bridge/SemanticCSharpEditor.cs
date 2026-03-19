using System.Text;
using System.Text.RegularExpressions;

namespace GodotDotnetMcp.DotnetBridge;

internal sealed record SemanticMemberPatch(
    string TypeName,
    string MemberName,
    IReadOnlyList<string> Modifiers,
    string? ReturnType,
    IReadOnlyList<string> Parameters,
    string? Body,
    string? FieldType,
    string? Initializer,
    string? SignatureHint);

internal static class SemanticCSharpEditor
{
    public static string UpsertMethod(string text, SemanticMemberPatch patch, out PatchOperationResult result)
    {
        var typeRegion = FindTypeRegion(text, patch.TypeName);
        var bodyIndent = typeRegion.BodyIndent;
        var candidate = FindMethodCandidate(typeRegion.BodyText, patch.MemberName, patch.Parameters, patch.SignatureHint);
        var newMember = BuildMethod(patch, bodyIndent);

        if (candidate is not null)
        {
            var updatedBody = ReplaceRange(typeRegion.BodyText, candidate.StartIndex, candidate.EndIndex, newMember);
            result = new PatchOperationResult(
                Kind: "method_upsert",
                Target: $"{patch.TypeName}.{patch.MemberName}",
                MatchCount: candidate.MatchCount,
                AppliedCount: 1,
                Note: candidate.MatchCount > 1 ? $"Multiple candidate methods matched '{patch.MemberName}'; updated first match." : "Updated existing method.");
            return ReplaceTypeBody(text, typeRegion, updatedBody);
        }

        var insertedBody = InsertBeforeTypeEnd(typeRegion.BodyText, newMember, bodyIndent);
        result = new PatchOperationResult(
            Kind: "method_upsert",
            Target: $"{patch.TypeName}.{patch.MemberName}",
            MatchCount: 0,
            AppliedCount: 1,
            Note: "Added new method.");
        return ReplaceTypeBody(text, typeRegion, insertedBody);
    }

    public static string RemoveMethod(string text, string typeName, string memberName, IReadOnlyList<string> parameters, string? signatureHint, out PatchOperationResult result)
    {
        var typeRegion = FindTypeRegion(text, typeName);
        var candidate = FindMethodCandidate(typeRegion.BodyText, memberName, parameters, signatureHint);
        if (candidate is null)
        {
            throw new BridgeToolException($"Method '{memberName}' was not found in type '{typeName}'.");
        }

        var updatedBody = RemoveRange(typeRegion.BodyText, candidate.StartIndex, candidate.EndIndex);
        result = new PatchOperationResult(
            Kind: "method_remove",
            Target: $"{typeName}.{memberName}",
            MatchCount: candidate.MatchCount,
            AppliedCount: 1,
            Note: candidate.MatchCount > 1 ? $"Multiple candidate methods matched '{memberName}'; removed first match." : "Removed existing method.");
        return ReplaceTypeBody(text, typeRegion, updatedBody);
    }

    public static string UpsertField(string text, SemanticMemberPatch patch, out PatchOperationResult result)
    {
        if (string.IsNullOrWhiteSpace(patch.FieldType))
        {
            throw new BridgeToolException("fieldType is required for field upsert.");
        }

        var typeRegion = FindTypeRegion(text, patch.TypeName);
        var bodyIndent = typeRegion.BodyIndent;
        var candidate = FindFieldCandidate(typeRegion.BodyText, patch.MemberName, patch.SignatureHint);
        var newMember = BuildField(patch, bodyIndent);

        if (candidate is not null)
        {
            var updatedBody = ReplaceRange(typeRegion.BodyText, candidate.StartIndex, candidate.EndIndex, newMember);
            result = new PatchOperationResult(
                Kind: "field_upsert",
                Target: $"{patch.TypeName}.{patch.MemberName}",
                MatchCount: candidate.MatchCount,
                AppliedCount: 1,
                Note: candidate.MatchCount > 1 ? $"Multiple candidate fields matched '{patch.MemberName}'; updated first match." : "Updated existing field.");
            return ReplaceTypeBody(text, typeRegion, updatedBody);
        }

        var insertedBody = InsertBeforeTypeEnd(typeRegion.BodyText, newMember, bodyIndent);
        result = new PatchOperationResult(
            Kind: "field_upsert",
            Target: $"{patch.TypeName}.{patch.MemberName}",
            MatchCount: 0,
            AppliedCount: 1,
            Note: "Added new field.");
        return ReplaceTypeBody(text, typeRegion, insertedBody);
    }

    public static string RemoveField(string text, string typeName, string memberName, string? signatureHint, out PatchOperationResult result)
    {
        var typeRegion = FindTypeRegion(text, typeName);
        var candidate = FindFieldCandidate(typeRegion.BodyText, memberName, signatureHint);
        if (candidate is null)
        {
            throw new BridgeToolException($"Field '{memberName}' was not found in type '{typeName}'.");
        }

        var updatedBody = RemoveRange(typeRegion.BodyText, candidate.StartIndex, candidate.EndIndex);
        result = new PatchOperationResult(
            Kind: "field_remove",
            Target: $"{typeName}.{memberName}",
            MatchCount: candidate.MatchCount,
            AppliedCount: 1,
            Note: candidate.MatchCount > 1 ? $"Multiple candidate fields matched '{memberName}'; removed first match." : "Removed existing field.");
        return ReplaceTypeBody(text, typeRegion, updatedBody);
    }

    private static string BuildMethod(SemanticMemberPatch patch, string bodyIndent)
    {
        var modifiers = patch.Modifiers.Count > 0 ? string.Join(' ', patch.Modifiers) + " " : string.Empty;
        var returnType = string.IsNullOrWhiteSpace(patch.ReturnType) ? "void" : patch.ReturnType!.Trim();
        var parameters = string.Join(", ", patch.Parameters);
        var body = IndentMultiline(patch.Body ?? string.Empty, bodyIndent + "    ");

        var builder = new StringBuilder();
        builder.Append(bodyIndent);
        builder.Append(modifiers);
        builder.Append(returnType);
        builder.Append(' ');
        builder.Append(patch.MemberName);
        builder.Append('(');
        builder.Append(parameters);
        builder.AppendLine(")");
        builder.Append(bodyIndent);
        builder.AppendLine("{");
        if (!string.IsNullOrWhiteSpace(body))
        {
            builder.AppendLine(body);
        }
        builder.Append(bodyIndent);
        builder.Append('}');
        return builder.ToString();
    }

    private static string BuildField(SemanticMemberPatch patch, string bodyIndent)
    {
        var modifiers = patch.Modifiers.Count > 0 ? string.Join(' ', patch.Modifiers) + " " : "private ";
        var initializer = string.IsNullOrWhiteSpace(patch.Initializer) ? string.Empty : " = " + patch.Initializer!.Trim();
        return $"{bodyIndent}{modifiers}{patch.FieldType!.Trim()} {patch.MemberName}{initializer};";
    }

    private static SemanticTypeRegion FindTypeRegion(string text, string typeName)
    {
        var pattern = $@"\b(class|struct|record(?:\s+class|\s+struct)?)\s+{Regex.Escape(typeName)}\b";
        var match = Regex.Match(text, pattern, RegexOptions.CultureInvariant);
        if (!match.Success)
        {
            throw new BridgeToolException($"Type '{typeName}' was not found.");
        }

        var openBraceIndex = text.IndexOf('{', match.Index);
        if (openBraceIndex < 0)
        {
            throw new BridgeToolException($"Type '{typeName}' does not have a body.");
        }

        var closeBraceIndex = FindMatchingBrace(text, openBraceIndex);
        var lineStart = FindLineStart(text, match.Index);
        var typeBodyStart = openBraceIndex + 1;
        var typeBodyText = text.Substring(typeBodyStart, closeBraceIndex - typeBodyStart);
        var typeIndent = GetLineIndent(text, lineStart);
        var bodyIndent = typeIndent + "    ";
        return new SemanticTypeRegion(lineStart, closeBraceIndex + 1, typeBodyStart, closeBraceIndex, typeIndent, bodyIndent, typeBodyText);
    }

    private static CandidateMatch? FindMethodCandidate(string bodyText, string memberName, IReadOnlyList<string> parameters, string? signatureHint)
    {
        var matches = FindTopLevelMemberMatches(bodyText, memberName, signatureHint).ToArray();
        if (matches.Length == 0)
        {
            return null;
        }

        if (parameters.Count > 0)
        {
            matches = matches.Where(match => parameters.All(parameter => match.LineText.Contains(parameter, StringComparison.Ordinal))).ToArray();
            if (matches.Length == 0)
            {
                return null;
            }
        }

        return new CandidateMatch(matches[0].StartIndex, matches[0].EndIndex, matches.Length, matches[0].LineText);
    }

    private static CandidateMatch? FindFieldCandidate(string bodyText, string memberName, string? signatureHint)
    {
        var matches = FindTopLevelMemberMatches(bodyText, memberName, signatureHint)
            .Where(match => match.LineText.Contains(';', StringComparison.Ordinal) && !match.LineText.Contains('(', StringComparison.Ordinal))
            .ToArray();

        if (matches.Length == 0)
        {
            return null;
        }

        return new CandidateMatch(matches[0].StartIndex, matches[0].EndIndex, matches.Length, matches[0].LineText);
    }

    private static IEnumerable<MemberMatch> FindTopLevelMemberMatches(string bodyText, string memberName, string? signatureHint)
    {
        var lines = SplitLinesWithOffsets(bodyText);
        var depth = 0;

        foreach (var line in lines)
        {
            var trimmed = line.Text.TrimStart();
            if (depth == 0 && trimmed.Contains(memberName, StringComparison.Ordinal) && (signatureHint is null || trimmed.Contains(signatureHint, StringComparison.Ordinal)))
            {
                var candidateIndex = trimmed.IndexOf(memberName, StringComparison.Ordinal);
                var absoluteIndex = line.StartIndex + line.Text.IndexOf(trimmed, StringComparison.Ordinal) + candidateIndex;
                var memberSpan = FindMemberSpan(bodyText, absoluteIndex);
                yield return new MemberMatch(memberSpan.StartIndex, memberSpan.EndIndex, line.Text);
            }

            depth = UpdateBraceDepth(depth, line.Text);
        }
    }

    private static MemberSpan FindMemberSpan(string text, int memberNameIndex)
    {
        var lineStart = FindLineStart(text, memberNameIndex);
        var arrowIndex = IndexOfToken(text, lineStart, "=>");
        var openBraceIndex = IndexOfChar(text, lineStart, '{');
        var semicolonIndex = IndexOfChar(text, lineStart, ';');

        if (arrowIndex >= 0 && (openBraceIndex < 0 || arrowIndex < openBraceIndex) && (semicolonIndex < 0 || arrowIndex < semicolonIndex))
        {
            if (semicolonIndex < 0)
            {
                throw new BridgeToolException("Expression-bodied member is missing terminating semicolon.");
            }

            return new MemberSpan(lineStart, semicolonIndex + 1);
        }

        if (openBraceIndex >= 0 && (semicolonIndex < 0 || openBraceIndex < semicolonIndex))
        {
            var closeBraceIndex = FindMatchingBrace(text, openBraceIndex);
            return new MemberSpan(lineStart, closeBraceIndex + 1);
        }

        if (semicolonIndex >= 0)
        {
            return new MemberSpan(lineStart, semicolonIndex + 1);
        }

        throw new BridgeToolException("Unable to determine member bounds.");
    }

    private static string ReplaceRange(string text, int startIndex, int endIndex, string replacement)
    {
        return text[..startIndex] + replacement + text[endIndex..];
    }

    private static string RemoveRange(string text, int startIndex, int endIndex)
    {
        var leadingStart = FindLineStart(text, startIndex);
        var trailingEnd = FindLineEnd(text, endIndex);
        return text[..leadingStart] + text[trailingEnd..];
    }

    private static string ReplaceTypeBody(string text, SemanticTypeRegion region, string newBody)
    {
        return text[..region.BodyStartIndex] + newBody + text[region.BodyEndIndex..];
    }

    private static string InsertBeforeTypeEnd(string bodyText, string memberText, string bodyIndent)
    {
        var normalizedMember = memberText.TrimEnd();
        var insertion = bodyText.TrimEnd();
        if (string.IsNullOrWhiteSpace(insertion))
        {
            return Environment.NewLine + normalizedMember + Environment.NewLine;
        }

        return insertion + Environment.NewLine + Environment.NewLine + normalizedMember + Environment.NewLine;
    }

    private static string IndentMultiline(string text, string indent)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return string.Empty;
        }

        var lines = text.Replace("\r\n", "\n", StringComparison.Ordinal).Split('\n');
        var builder = new StringBuilder();
        for (var i = 0; i < lines.Length; i++)
        {
            if (i > 0)
            {
                builder.AppendLine();
            }

            if (lines[i].Length == 0)
            {
                continue;
            }

            builder.Append(indent);
            builder.Append(lines[i].TrimEnd());
        }

        return builder.ToString();
    }

    private static IReadOnlyList<MemberLine> SplitLinesWithOffsets(string text)
    {
        var lines = new List<MemberLine>();
        var index = 0;
        while (index < text.Length)
        {
            var lineEnd = text.IndexOf('\n', index);
            if (lineEnd < 0)
            {
                lines.Add(new MemberLine(index, text[index..], text.Length));
                break;
            }

            var length = lineEnd - index + 1;
            lines.Add(new MemberLine(index, text.Substring(index, length), index + length));
            index = lineEnd + 1;
        }

        if (text.Length == 0)
        {
            lines.Add(new MemberLine(0, string.Empty, 0));
        }

        return lines;
    }

    private static int UpdateBraceDepth(int depth, string text)
    {
        var updated = depth;
        foreach (var ch in text)
        {
            if (ch == '{')
            {
                updated++;
            }
            else if (ch == '}')
            {
                updated = Math.Max(0, updated - 1);
            }
        }

        return updated;
    }

    private static int IndexOfToken(string text, int startIndex, string token)
    {
        return text.IndexOf(token, startIndex, StringComparison.Ordinal);
    }

    private static int IndexOfChar(string text, int startIndex, char value)
    {
        return text.IndexOf(value, startIndex);
    }

    private static int FindMatchingBrace(string text, int openBraceIndex)
    {
        var depth = 0;
        for (var index = openBraceIndex; index < text.Length; index++)
        {
            if (text[index] == '{')
            {
                depth++;
            }
            else if (text[index] == '}')
            {
                depth--;
                if (depth == 0)
                {
                    return index;
                }
            }
        }

        throw new BridgeToolException("Unable to find matching closing brace.");
    }

    private static int FindLineStart(string text, int index)
    {
        var current = Math.Clamp(index, 0, text.Length);
        while (current > 0 && text[current - 1] != '\n' && text[current - 1] != '\r')
        {
            current--;
        }

        return current;
    }

    private static int FindLineEnd(string text, int index)
    {
        var current = Math.Clamp(index, 0, text.Length);
        while (current < text.Length && text[current] != '\n')
        {
            current++;
        }

        if (current < text.Length)
        {
            current++;
        }

        return current;
    }

    private static string GetLineIndent(string text, int lineStartIndex)
    {
        var builder = new StringBuilder();
        for (var index = lineStartIndex; index < text.Length; index++)
        {
            var ch = text[index];
            if (ch == ' ' || ch == '\t')
            {
                builder.Append(ch);
                continue;
            }

            break;
        }

        return builder.ToString();
    }

    private sealed record SemanticTypeRegion(
        int StartIndex,
        int EndIndex,
        int BodyStartIndex,
        int BodyEndIndex,
        string TypeIndent,
        string BodyIndent,
        string BodyText);

    private sealed record MemberSpan(int StartIndex, int EndIndex);

    private sealed record MemberLine(int StartIndex, string Text, int EndIndex);

    private sealed record MemberMatch(int StartIndex, int EndIndex, string LineText);

    private sealed record CandidateMatch(int StartIndex, int EndIndex, int MatchCount, string LineText);
}
