namespace MyApi.Services;

public static class ModuleRoleParser
{
    public static List<string> ParseModuleAccessRoleToRoles(string moduleAccessRole)
    {
        if (string.IsNullOrWhiteSpace(moduleAccessRole)) return new List<string>();
        return moduleAccessRole.Split(',').Select(r => r.Trim()).Where(r => r.Length > 0).ToList();
    }

    public static List<string> ParseModuleAccessRoleToArwRoles(string moduleAccessRole)
    {
        if (string.IsNullOrWhiteSpace(moduleAccessRole)) return new List<string>();
        const string prefix = "Automated Recruitment Workflow - ";
        return moduleAccessRole.Split(',')
            .Select(p => p.Trim())
            .Where(p => p.StartsWith(prefix, StringComparison.Ordinal))
            .Select(p => "ARW - " + p[prefix.Length..].Trim())
            .Where(r => r.Length > 5)
            .ToList();
    }

    public static List<string> ParseModuleAccessRoleToSkillsHeatmapRoles(string moduleAccessRole)
    {
        return ParseWithPrefix(moduleAccessRole, "Skills Heatmap - ", "Skills Heatmap - ");
    }

    public static List<string> ParseModuleAccessRoleToDeliverablesRoles(string moduleAccessRole)
    {
        return ParseWithPrefix(moduleAccessRole, "Deliverables & Sprint Sign-Off Hub - ", "Deliverables & Sprint Sign-Off Hub - ");
    }

    public static List<string> ParseModuleAccessRoleToSowBuilderRoles(string moduleAccessRole)
    {
        return ParseWithPrefix(moduleAccessRole, "Proposal & SOW Builder - ", "Proposal & SOW Builder - ");
    }

    private static List<string> ParseWithPrefix(string moduleAccessRole, string sourcePrefix, string targetPrefix)
    {
        if (string.IsNullOrWhiteSpace(moduleAccessRole)) return new List<string>();
        return moduleAccessRole.Split(',')
            .Select(p => p.Trim())
            .Where(p => p.StartsWith(sourcePrefix, StringComparison.Ordinal))
            .Select(p => targetPrefix + p[sourcePrefix.Length..].Trim())
            .Where(r => r.Length > targetPrefix.Length)
            .ToList();
    }

    public static string NormalizeThemePreference(string? themePreference)
    {
        var raw = (themePreference ?? "").Trim().ToLowerInvariant();
        return raw == "light" ? "Light" : "dark";
    }

    public static string ResolveThemePreference(Dictionary<string, object>? user, Dictionary<string, object>? onboarding)
    {
        var fromOb = onboarding?.GetValueOrDefault("themePreference")?.ToString();
        var fromUser = user?.GetValueOrDefault("themePreference")?.ToString();
        return NormalizeThemePreference(fromOb ?? fromUser);
    }
}
