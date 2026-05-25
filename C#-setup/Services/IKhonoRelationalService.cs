using MyApi.Data.Entities;

namespace MyApi.Services;

public interface IKhonoRelationalService
{
    Task<int> GetUserCountAsync(CancellationToken ct = default);
    Task<(string? UserId, Dictionary<string, object> UserData)> FindUserByEmailAsync(string normalizedEmail, CancellationToken ct = default);
    Task<(string? UserId, Dictionary<string, object> UserData)> FindUserByIdAsync(string userId, CancellationToken ct = default);
    Task<Dictionary<string, object>> GetOnboardingAsync(string userId, CancellationToken ct = default);
    Task<List<Dictionary<string, object>>> ListUsersPayloadsAsync(CancellationToken ct = default);
    Task<(KbAppUser User, KbUserProfile Profile)> RegisterUserAsync(
        string email, string password, string name, string? firstName, string? lastName,
        string? department, string? designation, string? entity, string role, CancellationToken ct = default);
    Task ApplyUserPatchAsync(string userId, Dictionary<string, object> patch, CancellationToken ct = default);
    Task ApplyOnboardingPatchAsync(string userId, Dictionary<string, object> patch, CancellationToken ct = default);
    Task<bool> DeleteUserAsync(string userId, CancellationToken ct = default);
    Task UpdateLoginTrackingAsync(string userId, int loginCount, DateTime lastSignInAt, CancellationToken ct = default);
    Task<List<string>> ListDepartmentNamesAsync(CancellationToken ct = default);
    Task<List<string>> CreateDepartmentAsync(string name, CancellationToken ct = default);
    Task<List<string>> ListDesignationNamesAsync(CancellationToken ct = default);
    Task<List<string>> CreateDesignationAsync(string name, CancellationToken ct = default);
    Task<List<string>> ListEntityNamesAsync(CancellationToken ct = default);
    Task<List<string>> CreateEntityAsync(string name, CancellationToken ct = default);
    Task<Dictionary<string, object>> CreateRoleAsync(Dictionary<string, object> roleData, CancellationToken ct = default);
    Task SeedInitialRolesAsync(CancellationToken ct = default);
    Task<(string Id, string CreatedAtIso)> CreateAdminNotificationAsync(
        string actorEmail, string title, string message, string area,
        List<string> targetRoles, Dictionary<string, object>? details,
        bool requiresAck, string effectiveDateIso, CancellationToken ct = default);
    Task<List<Dictionary<string, object>>> ListAdminNotificationsAsync(
        string role, string userEmail, int limit, CancellationToken ct = default);
    Task ClearAdminNotificationsAsync(string role, string userEmail, CancellationToken ct = default);
    Task DismissAdminNotificationAsync(string userEmail, string alertId, CancellationToken ct = default);
    Task<bool> AcknowledgeAdminNotificationAsync(string userEmail, string alertId, CancellationToken ct = default);
}
