using MyApi.Data.Entities;
using MyApi.Models;

namespace MyApi.Services;

public class AuthService : IAuthService
{
    private readonly IKhonoRelationalService _relational;
    private readonly ISsoPgSyncService _ssoSync;

    public AuthService(IKhonoRelationalService relational, ISsoPgSyncService ssoSync)
    {
        _relational = relational;
        _ssoSync = ssoSync;
    }

    public async Task<User> RegisterAsync(string email, string password, string name, string? firstName = null, string? lastName = null, string? department = null, string? designation = null, string? entity = null, string role = "Staff")
    {
        var (user, profile) = await _relational.RegisterUserAsync(email, password, name, firstName, lastName, department, designation, entity, role);
        var userDict = new Dictionary<string, object>
        {
            ["email"] = user.Email,
            ["name"] = user.Name,
            ["role"] = user.Role,
            ["status"] = user.Status
        };
        var onboardingDict = new Dictionary<string, object>
        {
            ["email"] = user.Email,
            ["fullName"] = profile.FullName,
            ["department"] = profile.Department,
            ["designation"] = profile.Designation
        };
        await _ssoSync.SyncUserLoginAsync(user.Id, userDict, onboardingDict);
        return EntityToUser(user);
    }

    public async Task<User?> GetUserByEmailAsync(string email)
    {
        var (id, data) = await _relational.FindUserByEmailAsync(email.Trim().ToLowerInvariant());
        return id == null ? null : DictToUser(id, data);
    }

    public async Task<User?> GetUserByIdAsync(string id)
    {
        var (uid, data) = await _relational.FindUserByIdAsync(id);
        return uid == null ? null : DictToUser(uid, data);
    }

    private static User EntityToUser(KbAppUser u) => new()
    {
        Id = u.Id,
        Email = u.Email,
        Name = u.Name,
        FirstName = "",
        LastName = "",
        Role = u.Role,
        Status = u.Status,
        Entity = u.Entity,
        Department = u.Department,
        Designation = u.Designation,
        Manager = u.Manager,
        ModuleAccess = u.ModuleAccess,
        ModuleRole = u.ModuleRole,
        ModuleAccessRole = u.ModuleAccessRole,
        CreatedAt = u.CreatedAt ?? DateTime.UtcNow,
        UpdatedAt = u.UpdatedAt ?? DateTime.UtcNow
    };

    private static User DictToUser(string id, Dictionary<string, object> d) => new()
    {
        Id = id,
        Email = d.GetValueOrDefault("email")?.ToString() ?? "",
        Name = d.GetValueOrDefault("name")?.ToString() ?? "",
        FirstName = d.GetValueOrDefault("firstName")?.ToString() ?? "",
        LastName = d.GetValueOrDefault("lastName")?.ToString() ?? "",
        Role = d.GetValueOrDefault("role")?.ToString() ?? "Staff",
        Status = d.GetValueOrDefault("status")?.ToString() ?? "Active",
        Entity = d.GetValueOrDefault("entity")?.ToString() ?? "",
        Department = d.GetValueOrDefault("department")?.ToString() ?? "",
        Designation = d.GetValueOrDefault("designation")?.ToString() ?? "",
        Manager = d.GetValueOrDefault("manager")?.ToString() ?? "",
        ModuleAccess = d.GetValueOrDefault("moduleAccess")?.ToString() ?? "",
        ModuleRole = d.GetValueOrDefault("moduleRole")?.ToString() ?? "",
        ModuleAccessRole = d.GetValueOrDefault("moduleAccessRole")?.ToString() ?? "",
        CreatedAt = DateTime.UtcNow,
        UpdatedAt = DateTime.UtcNow
    };
}
