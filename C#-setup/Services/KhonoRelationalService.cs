using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using MyApi.Data;
using MyApi.Data.Entities;

namespace MyApi.Services;

public class KhonoRelationalService(KhonoDbContext db) : IKhonoRelationalService
{
    public Task<int> GetUserCountAsync(CancellationToken ct = default) =>
        db.AppUsers.CountAsync(ct);

    public async Task<(string? UserId, Dictionary<string, object> UserData)> FindUserByEmailAsync(string normalizedEmail, CancellationToken ct = default)
    {
        var user = await db.AppUsers.FirstOrDefaultAsync(
            u => string.Equals(u.Email, normalizedEmail, StringComparison.OrdinalIgnoreCase),
            ct);
        return user == null ? (null, []) : (user.Id, UserToDict(user));
    }

    public async Task<(string? UserId, Dictionary<string, object> UserData)> FindUserByIdAsync(string userId, CancellationToken ct = default)
    {
        var user = await db.AppUsers.FindAsync([userId], ct);
        return user == null ? (null, []) : (user.Id, UserToDict(user));
    }

    public async Task<Dictionary<string, object>> GetOnboardingAsync(string userId, CancellationToken ct = default)
    {
        var user = await db.AppUsers.FindAsync([userId], ct);
        var profile = await db.UserProfiles.FindAsync([userId], ct);
        if (profile == null) return [];
        return ProfileToOnboardingDict(profile, user?.Email ?? "");
    }

    public async Task<List<Dictionary<string, object>>> ListUsersPayloadsAsync(CancellationToken ct = default)
    {
        var rows = await db.AppUsers
            .Include(u => u.Profile)
            .OrderByDescending(u => u.Profile != null ? u.Profile.UpdatedAt ?? u.Profile.CreatedAt : u.UpdatedAt ?? u.CreatedAt)
            .ToListAsync(ct);

        return rows.ConvertAll(u =>
        {
            var userInfo = UserToDict(u);
            var onboarding = u.Profile != null ? ProfileToOnboardingDict(u.Profile, u.Email) : [];
            var firstName = onboarding.GetValueOrDefault("firstName")?.ToString() ?? "";
            var lastName = onboarding.GetValueOrDefault("lastName")?.ToString() ?? onboarding.GetValueOrDefault("surname")?.ToString() ?? "";
            var modAccessRaw = userInfo.GetValueOrDefault("moduleAccess")?.ToString() ?? onboarding.GetValueOrDefault("moduleAccess")?.ToString() ?? "";
            var modRoleRaw = userInfo.GetValueOrDefault("moduleAccessRole")?.ToString() ?? onboarding.GetValueOrDefault("moduleAccessRole")?.ToString() ?? "";
            return new Dictionary<string, object>
            {
                ["id"] = u.Id,
                ["email"] = u.Email,
                ["role"] = u.Role,
                ["status"] = u.Status,
                ["firstName"] = firstName,
                ["lastName"] = lastName,
                ["department"] = onboarding.GetValueOrDefault("department")?.ToString() ?? "",
                ["designation"] = onboarding.GetValueOrDefault("designation")?.ToString() ?? "",
                ["entity"] = string.IsNullOrEmpty(u.Entity) ? onboarding.GetValueOrDefault("entity")?.ToString() ?? "" : u.Entity,
                ["manager"] = string.IsNullOrEmpty(u.Manager) ? onboarding.GetValueOrDefault("manager")?.ToString() ?? "" : u.Manager,
                ["moduleAccess"] = DeriveModuleAccess(modAccessRaw, modRoleRaw) ?? "",
                ["moduleRole"] = userInfo.GetValueOrDefault("moduleRole")?.ToString() ?? onboarding.GetValueOrDefault("moduleRole")?.ToString() ?? "",
                ["moduleAccessRole"] = modRoleRaw,
                ["profileImageUrl"] = onboarding.GetValueOrDefault("profileImageUrl")?.ToString() ?? "",
                ["createdAt"] = FormatIso(u.CreatedAt) ?? "",
                ["updatedAt"] = FormatIso(u.UpdatedAt ?? u.CreatedAt) ?? "",
                ["lastSignInAt"] = FormatIso(u.LastSignInAt ?? u.Profile?.LastSignInAt) ?? "",
                ["loginCount"] = u.Profile?.LoginCount ?? u.LoginCount
            };
        });
    }

    public async Task<(KbAppUser User, KbUserProfile Profile)> RegisterUserAsync(
        string email, string password, string name, string? firstName, string? lastName,
        string? department, string? designation, string? entity, string role, CancellationToken ct = default)
    {
        var normalized = email.Trim().ToLowerInvariant();
        if (await db.AppUsers.AnyAsync(u => string.Equals(u.Email, normalized, StringComparison.OrdinalIgnoreCase), ct))
            throw new InvalidOperationException("User already exists");

        var userId = Guid.NewGuid().ToString("N");
        var now = DateTime.UtcNow;
        var fullName = $"{firstName ?? ""} {lastName ?? ""}".Trim();
        if (string.IsNullOrEmpty(fullName)) fullName = name;

        var user = new KbAppUser
        {
            Id = userId,
            Email = normalized,
            Password = password,
            Name = fullName,
            Role = role,
            Status = "Inactive",
            Entity = entity ?? "",
            Department = department ?? "",
            Designation = designation ?? "",
            CreatedAt = now,
            UpdatedAt = now
        };
        var profile = new KbUserProfile
        {
            UserId = userId,
            FirstName = firstName ?? "",
            LastName = lastName ?? "",
            Surname = lastName ?? "",
            FullName = fullName,
            Department = department ?? "",
            Designation = designation ?? "",
            Entity = entity ?? "",
            CreatedAt = now,
            UpdatedAt = now,
            Extra = "{}"
        };

        db.AppUsers.Add(user);
        db.UserProfiles.Add(profile);
        db.UserEmails.Add(new KbUserEmail { UserId = userId, Email = normalized, IsPrimary = true });
        await db.SaveChangesAsync(ct);
        return (user, profile);
    }

    public async Task ApplyUserPatchAsync(string userId, Dictionary<string, object> patch, CancellationToken ct = default)
    {
        var user = await db.AppUsers.FindAsync([userId], ct);
        if (user == null) return;

        if (patch.TryGetValue("role", out var role)) user.Role = role?.ToString() ?? user.Role;
        if (patch.TryGetValue("status", out var status)) user.Status = status?.ToString() ?? user.Status;
        if (patch.TryGetValue("entity", out var entity)) user.Entity = entity?.ToString() ?? "";
        if (patch.TryGetValue("department", out var dept)) user.Department = dept?.ToString() ?? "";
        if (patch.TryGetValue("designation", out var des)) user.Designation = des?.ToString() ?? "";
        if (patch.TryGetValue("manager", out var mgr)) user.Manager = mgr?.ToString() ?? "";
        if (patch.TryGetValue("moduleAccess", out var ma)) user.ModuleAccess = ma?.ToString() ?? "";
        if (patch.TryGetValue("moduleRole", out var mr)) user.ModuleRole = mr?.ToString() ?? "";
        if (patch.TryGetValue("moduleAccessRole", out var mar)) user.ModuleAccessRole = mar?.ToString() ?? "";
        if (patch.TryGetValue("admin", out var admin) && admin is JsonElement je && je.ValueKind == JsonValueKind.Object)
            user.AdminJson = je.GetRawText();
        user.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
    }

    public async Task ApplyOnboardingPatchAsync(string userId, Dictionary<string, object> patch, CancellationToken ct = default)
    {
        var profile = await db.UserProfiles.FindAsync([userId], ct);
        if (profile == null)
        {
            profile = new KbUserProfile { UserId = userId, Extra = "{}" };
            db.UserProfiles.Add(profile);
        }

        void SetString(string key, Action<string> setter)
        {
            if (patch.TryGetValue(key, out var val)) setter(val?.ToString() ?? "");
        }

        SetString("firstName", v => profile.FirstName = v);
        SetString("lastName", v => profile.LastName = v);
        SetString("surname", v => profile.Surname = v);
        SetString("fullName", v => profile.FullName = v);
        SetString("department", v => profile.Department = v);
        SetString("designation", v => profile.Designation = v);
        SetString("entity", v => profile.Entity = v);
        SetString("manager", v => profile.Manager = v);
        SetString("managedBy", v => profile.ManagedBy = v);
        SetString("moduleAccess", v => profile.ModuleAccess = v);
        SetString("moduleRole", v => profile.ModuleRole = v);
        SetString("moduleAccessRole", v => profile.ModuleAccessRole = v);
        SetString("token", v => profile.Token = v);
        SetString("profileImageUrl", v => profile.ProfileImageUrl = v);
        SetString("profileImagePublicId", v => profile.ProfileImagePublicId = v);
        SetString("themePreference", v => profile.ThemePreference = v);
        SetString("role", v => profile.OnboardingRole = v);
        SetString("status", v => profile.OnboardingStatus = v);

        if (patch.TryGetValue("token_updated_at", out var tokUpd) && tokUpd is DateTime dt)
            profile.TokenUpdatedAt = dt;
        if (patch.TryGetValue("lastSignInAt", out var lsi) && lsi is DateTime ldt)
            profile.LastSignInAt = ldt;
        if (patch.TryGetValue("loginCount", out var lc) && int.TryParse(lc?.ToString(), out var count))
            profile.LoginCount = count;

        profile.UpdatedAt = DateTime.UtcNow;
        if (profile.CreatedAt == null) profile.CreatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
    }

    public async Task<bool> DeleteUserAsync(string userId, CancellationToken ct = default)
    {
        var user = await db.AppUsers.FindAsync([userId], ct);
        if (user == null) return false;
        db.AppUsers.Remove(user);
        await db.SaveChangesAsync(ct);
        return true;
    }

    public async Task UpdateLoginTrackingAsync(string userId, int loginCount, DateTime lastSignInAt, CancellationToken ct = default)
    {
        var user = await db.AppUsers.FindAsync([userId], ct);
        if (user != null)
        {
            user.LoginCount = loginCount;
            user.LastSignInAt = lastSignInAt;
            user.UpdatedAt = DateTime.UtcNow;
        }
        var profile = await db.UserProfiles.FindAsync([userId], ct);
        if (profile != null)
        {
            profile.LoginCount = loginCount;
            profile.LastSignInAt = lastSignInAt;
            profile.UpdatedAt = DateTime.UtcNow;
        }
        await db.SaveChangesAsync(ct);
    }

    public Task<List<string>> ListDepartmentNamesAsync(CancellationToken ct = default) =>
        db.Departments.OrderByDescending(d => d.CreatedAt).Select(d => d.Name).Distinct().ToListAsync(ct);

    public async Task<List<string>> CreateDepartmentAsync(string name, CancellationToken ct = default)
    {
        var normalized = name.Trim();
        if (!string.IsNullOrEmpty(normalized) && !await db.Departments.AnyAsync(d => string.Equals(d.Name, normalized, StringComparison.OrdinalIgnoreCase), ct))
        {
            db.Departments.Add(new KbDepartment { Id = Guid.NewGuid().ToString("N"), Name = normalized, CreatedAt = DateTime.UtcNow });
            await db.SaveChangesAsync(ct);
        }
        return await ListDepartmentNamesAsync(ct);
    }

    public Task<List<string>> ListDesignationNamesAsync(CancellationToken ct = default) =>
        db.Designations.OrderByDescending(d => d.CreatedAt).Select(d => d.Name).Distinct().ToListAsync(ct);

    public async Task<List<string>> CreateDesignationAsync(string name, CancellationToken ct = default)
    {
        var normalized = name.Trim();
        if (!string.IsNullOrEmpty(normalized) && !await db.Designations.AnyAsync(d => string.Equals(d.Name, normalized, StringComparison.OrdinalIgnoreCase), ct))
        {
            db.Designations.Add(new KbDesignation { Id = Guid.NewGuid().ToString("N"), Name = normalized, CreatedAt = DateTime.UtcNow });
            await db.SaveChangesAsync(ct);
        }
        return await ListDesignationNamesAsync(ct);
    }

    public async Task<List<string>> ListEntityNamesAsync(CancellationToken ct = default)
    {
        var names = await db.Entities.OrderByDescending(e => e.CreatedAt).Select(e => e.Name).Where(n => n != "").Distinct().ToListAsync(ct);
        var userEntities = await db.AppUsers.Select(u => u.Entity).Where(e => e != "").Distinct().ToListAsync(ct);
        foreach (var n in userEntities)
            if (!names.Contains(n)) names.Add(n);
        return names;
    }

    public async Task<List<string>> CreateEntityAsync(string name, CancellationToken ct = default)
    {
        var normalized = name.Trim();
        if (!string.IsNullOrEmpty(normalized) && !await db.Entities.AnyAsync(e => string.Equals(e.Name, normalized, StringComparison.OrdinalIgnoreCase), ct))
        {
            db.Entities.Add(new KbEntity
            {
                Id = Guid.NewGuid().ToString("N"),
                Name = normalized,
                AssignedUserIds = "[]",
                Raw = JsonSerializer.Serialize(new { name = normalized }),
                CreatedAt = DateTime.UtcNow
            });
            await db.SaveChangesAsync(ct);
        }
        return await ListEntityNamesAsync(ct);
    }

    public async Task<Dictionary<string, object>> CreateRoleAsync(Dictionary<string, object> roleData, CancellationToken ct = default)
    {
        var id = Guid.NewGuid().ToString("N");
        var now = DateTime.UtcNow;
        var pageAccess = roleData.GetValueOrDefault("pageAccess");
        var row = new KbRoleDefinition
        {
            Id = id,
            RoleName = roleData.GetValueOrDefault("roleName")?.ToString() ?? "",
            Description = roleData.GetValueOrDefault("description")?.ToString() ?? "",
            PageAccess = pageAccess != null ? JsonSerializer.Serialize(pageAccess) : null,
            CreatedAt = now,
            UpdatedAt = now
        };
        db.RoleDefinitions.Add(row);
        await db.SaveChangesAsync(ct);
        return new Dictionary<string, object>
        {
            ["id"] = id,
            ["roleName"] = row.RoleName,
            ["description"] = row.Description,
            ["pageAccess"] = pageAccess ?? new object(),
            ["created_at"] = now,
            ["updated_at"] = now
        };
    }

    public async Task SeedInitialRolesAsync(CancellationToken ct = default)
    {
        var roles = new[]
        {
            new Dictionary<string, object> { ["roleName"] = "staff", ["pageAccess"] = DefaultStaffPageAccess() },
            new Dictionary<string, object> { ["roleName"] = "admin", ["description"] = "Strategic administrator with full system access except for deletion.", ["pageAccess"] = DefaultAdminPageAccess() },
            new Dictionary<string, object> { ["roleName"] = "manager", ["pageAccess"] = DefaultManagerPageAccess() }
        };
        foreach (var r in roles) await CreateRoleAsync(r, ct);
    }

    public async Task<(string Id, string CreatedAtIso)> CreateAdminNotificationAsync(
        string actorEmail, string title, string message, string area,
        List<string> targetRoles, Dictionary<string, object>? details,
        bool requiresAck, string effectiveDateIso, CancellationToken ct = default)
    {
        List<string> normalizedRoles = [.. targetRoles
            .Where(r => !string.IsNullOrWhiteSpace(r))
            .Select(r => r.Trim().ToLower())
            .Distinct()];
        normalizedRoles.Sort();
        if (normalizedRoles.Count == 0) normalizedRoles = ["admin", "staff"];
        var now = DateTime.UtcNow;
        var nowIso = now.ToString("o").Replace("+00:00", "Z");
        var detailsPayload = details ?? [];
        if (!detailsPayload.ContainsKey("targetCount")) detailsPayload["targetCount"] = normalizedRoles.Count;
        var id = Guid.NewGuid().ToString("N");
        var row = new KbAdminNotification
        {
            Id = id,
            ActorEmail = actorEmail,
            Title = title,
            Message = message,
            Area = area,
            Details = JsonSerializer.Serialize(detailsPayload),
            TargetRoles = JsonSerializer.Serialize(normalizedRoles),
            RequiresAck = requiresAck,
            EffectiveDateIso = effectiveDateIso,
            AcknowledgedByEmails = "[]",
            CreatedAtIso = nowIso,
            CreatedAt = now,
            Raw = JsonSerializer.Serialize(new { actorEmail, title, message, area, details = detailsPayload, targetRoles = normalizedRoles })
        };
        db.AdminNotifications.Add(row);
        await db.SaveChangesAsync(ct);
        return (id, nowIso);
    }

    public async Task<List<Dictionary<string, object>>> ListAdminNotificationsAsync(string role, string userEmail, int limit, CancellationToken ct = default)
    {
        var normalizedRole = role.Trim().ToLower();
        var normalizedEmail = userEmail.Trim().ToLower();
        var all = await db.AdminNotifications.ToListAsync(ct);
        var filtered = all.Where(n =>
        {
            var roles = JsonSerializer.Deserialize<List<string>>(n.TargetRoles ?? "[]") ?? [];
            return roles.Any(r => string.Equals(r.Trim(), normalizedRole, StringComparison.OrdinalIgnoreCase));
        }).ToList();

        DateTime? clearedAfter = null;
        HashSet<string> dismissedIds = [];
        if (!string.IsNullOrEmpty(normalizedEmail))
        {
            var state = await db.AdminNotificationStates.FindAsync([normalizedEmail], ct);
            if (state != null)
            {
                clearedAfter = ParseIso(state.ClearedAtIso);
                dismissedIds = [.. JsonSerializer.Deserialize<List<string>>(state.DismissedIds ?? "[]") ?? []];
            }
        }

        List<Dictionary<string, object>> alerts = [.. filtered.Select(NotificationToAlert).OrderByDescending(a => ParseIso(a["createdAtIso"]?.ToString()))];
        if (clearedAfter.HasValue)
            alerts = [.. alerts.Where(a => ParseIso(a["createdAtIso"]?.ToString()) > clearedAfter.Value)];
        alerts = [.. alerts.Where(a => !dismissedIds.Contains(a["id"]?.ToString() ?? ""))];

        foreach (var item in alerts)
        {
            item["acknowledged"] = false;
            item["acknowledgedCount"] = 0;
            item["targetCount"] = int.TryParse((item.GetValueOrDefault("details") as Dictionary<string, object>)?.GetValueOrDefault("targetCount")?.ToString(), out var tc) ? tc : 0;
        }
        return [.. alerts.Take(limit)];
    }

    public async Task ClearAdminNotificationsAsync(string role, string userEmail, CancellationToken ct = default)
    {
        var nowIso = DateTime.UtcNow.ToString("o").Replace("+00:00", "Z");
        var state = await db.AdminNotificationStates.FindAsync([userEmail], ct);
        if (state == null)
        {
            state = new KbAdminNotificationState { UserEmail = userEmail };
            db.AdminNotificationStates.Add(state);
        }
        state.Role = role;
        state.ClearedAtIso = nowIso;
        state.UpdatedAtIso = nowIso;
        state.DismissedIds = "[]";
        await db.SaveChangesAsync(ct);
    }

    public async Task DismissAdminNotificationAsync(string userEmail, string alertId, CancellationToken ct = default)
    {
        var nowIso = DateTime.UtcNow.ToString("o").Replace("+00:00", "Z");
        var state = await db.AdminNotificationStates.FindAsync([userEmail], ct);
        if (state == null)
        {
            state = new KbAdminNotificationState { UserEmail = userEmail };
            db.AdminNotificationStates.Add(state);
        }
        var dismissed = JsonSerializer.Deserialize<List<string>>(state.DismissedIds ?? "[]") ?? [];
        if (!dismissed.Contains(alertId)) dismissed.Add(alertId);
        state.DismissedIds = JsonSerializer.Serialize(dismissed);
        state.UpdatedAtIso = nowIso;
        await db.SaveChangesAsync(ct);
    }

    public async Task<bool> AcknowledgeAdminNotificationAsync(string userEmail, string alertId, CancellationToken ct = default)
    {
        var row = await db.AdminNotifications.FindAsync([alertId], ct);
        if (row == null) return false;
        var acked = JsonSerializer.Deserialize<List<string>>(row.AcknowledgedByEmails ?? "[]") ?? [];
        if (!acked.Contains(userEmail)) acked.Add(userEmail);
        row.AcknowledgedByEmails = JsonSerializer.Serialize(acked);
        await db.SaveChangesAsync(ct);
        return true;
    }

    private static Dictionary<string, object> UserToDict(KbAppUser u) => new()
    {
        ["id"] = u.Id,
        ["email"] = u.Email,
        ["password"] = u.Password ?? "",
        ["name"] = u.Name,
        ["role"] = u.Role,
        ["status"] = u.Status,
        ["entity"] = u.Entity,
        ["department"] = u.Department,
        ["designation"] = u.Designation,
        ["manager"] = u.Manager,
        ["moduleAccess"] = u.ModuleAccess,
        ["moduleRole"] = u.ModuleRole,
        ["moduleAccessRole"] = u.ModuleAccessRole,
        ["themePreference"] = u.ThemePreference,
        ["lastSignInAt"] = FormatIso(u.LastSignInAt) ?? "",
        ["loginCount"] = u.LoginCount,
        ["created_at"] = FormatIso(u.CreatedAt) ?? "",
        ["updated_at"] = FormatIso(u.UpdatedAt) ?? ""
    };

    private static Dictionary<string, object> ProfileToOnboardingDict(KbUserProfile p, string email) => new()
    {
        ["user_id"] = p.UserId,
        ["email"] = email,
        ["firstName"] = p.FirstName,
        ["lastName"] = p.LastName,
        ["surname"] = p.Surname,
        ["preferredName"] = p.PreferredName,
        ["fullName"] = p.FullName,
        ["phoneNumber"] = p.PhoneNumber,
        ["department"] = p.Department,
        ["designation"] = p.Designation,
        ["entity"] = p.Entity,
        ["manager"] = p.Manager,
        ["managedBy"] = p.ManagedBy,
        ["moduleAccess"] = p.ModuleAccess,
        ["moduleRole"] = p.ModuleRole,
        ["moduleAccessRole"] = p.ModuleAccessRole,
        ["profileImageUrl"] = p.ProfileImageUrl,
        ["profileImagePublicId"] = p.ProfileImagePublicId,
        ["themePreference"] = p.ThemePreference,
        ["token"] = p.Token ?? "",
        ["token_updated_at"] = FormatIso(p.TokenUpdatedAt) ?? "",
        ["role"] = p.OnboardingRole,
        ["status"] = p.OnboardingStatus,
        ["lastSignInAt"] = FormatIso(p.LastSignInAt) ?? "",
        ["loginCount"] = p.LoginCount,
        ["created_at"] = FormatIso(p.CreatedAt) ?? "",
        ["updated_at"] = FormatIso(p.UpdatedAt) ?? ""
    };

    private static Dictionary<string, object> NotificationToAlert(KbAdminNotification n)
    {
        var details = string.IsNullOrEmpty(n.Details) ? [] :
            JsonSerializer.Deserialize<Dictionary<string, object>>(n.Details) ?? [];
        var targetRoles = string.IsNullOrEmpty(n.TargetRoles) ? [] :
            JsonSerializer.Deserialize<List<string>>(n.TargetRoles) ?? [];
        return new Dictionary<string, object>
        {
            ["id"] = n.Id,
            ["actorEmail"] = n.ActorEmail,
            ["title"] = n.Title,
            ["message"] = n.Message,
            ["area"] = n.Area,
            ["details"] = details,
            ["targetRoles"] = targetRoles,
            ["requiresAck"] = n.RequiresAck,
            ["effectiveDateIso"] = n.EffectiveDateIso,
            ["createdAtIso"] = n.CreatedAtIso
        };
    }

    private static string? DeriveModuleAccess(string moduleAccess, string moduleAccessRole)
    {
        if (!string.IsNullOrWhiteSpace(moduleAccess)) return moduleAccess.Trim();
        if (string.IsNullOrWhiteSpace(moduleAccessRole)) return null;
        return moduleAccessRole.Contains("PDH", StringComparison.OrdinalIgnoreCase) ? "Personal Development Hub" : null;
    }

    private static string? FormatIso(DateTime? dt) => dt?.ToString("o").Replace("+00:00", "Z");

    private static DateTime? ParseIso(string? iso)
    {
        if (string.IsNullOrWhiteSpace(iso)) return null;
        if (DateTime.TryParse(iso.Replace("Z", "+00:00"), out var dt)) return dt;
        return null;
    }

    private static Dictionary<string, object> DefaultStaffPageAccess() => new()
    {
        ["user_management"] = Crud(false, false, false, false),
        ["dashboard"] = Crud(false, true, false, false),
        ["resource_allocation"] = Crud(false, false, false, false),
        ["project_data"] = Crud(false, false, false, false),
        ["reports_analytics"] = Crud(false, true, false, false),
        ["audit_logging"] = Crud(false, false, false, false),
        ["time_keeping"] = Crud(false, false, false, false)
    };

    private static Dictionary<string, object> DefaultAdminPageAccess() => new()
    {
        ["user_management"] = Crud(true, true, true, false),
        ["dashboard"] = Crud(true, true, true, false),
        ["resource_allocation"] = Crud(true, true, true, false),
        ["project_data"] = Crud(true, true, true, false),
        ["reports_analytics"] = Crud(true, true, true, false),
        ["audit_logging"] = Crud(true, true, true, false),
        ["time_keeping"] = Crud(true, true, true, false)
    };

    private static Dictionary<string, object> DefaultManagerPageAccess() => new()
    {
        ["user_management"] = Crud(false, false, false, false),
        ["dashboard"] = Crud(true, true, true, false),
        ["resource_allocation"] = Crud(true, true, true, false),
        ["project_data"] = Crud(true, true, true, false),
        ["reports_analytics"] = Crud(false, false, false, false),
        ["audit_logging"] = Crud(true, true, true, false),
        ["time_keeping"] = Crud(false, false, false, false)
    };

    private static Dictionary<string, bool> Crud(bool c, bool r, bool u, bool d) =>
        new() { ["create"] = c, ["read"] = r, ["update"] = u, ["delete"] = d };
}
