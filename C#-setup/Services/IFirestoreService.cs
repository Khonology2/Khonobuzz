namespace MyApi.Services
{
    public interface IFirestoreService
    {
        Task<IReadOnlyList<Dictionary<string, object>>> GetUsersAsync();
        Task<IReadOnlyList<Dictionary<string, object>>> GetUsersWithOnboardingAsync();
        Task<Dictionary<string, object>?> GetUserByIdAsync(string userId);
        Task<Dictionary<string, object>?> GetUserByEmailAsync(string email);
        Task<Dictionary<string, object>?> GetOnboardingByUserIdAsync(string userId);
        Task UpdateUserAsync(string userId, Dictionary<string, object> updates);
        Task UpdateOnboardingByUserIdAsync(string userId, Dictionary<string, object> updates);
        Task DeleteUserAsync(string userId);
        Task<string> AddUserAsync(Dictionary<string, object> userData);
        Task AddOnboardingAsync(string userId, Dictionary<string, object> onboardingData);
        Task<IReadOnlyList<string>> GetDepartmentNamesAsync();
        Task AddDepartmentIfNotExistsAsync(string name);
        Task<IReadOnlyList<string>> GetDesignationNamesAsync();
        Task AddDesignationIfNotExistsAsync(string name);
        Task<IReadOnlyList<Dictionary<string, object>>> GetRolesAsync();
        Task AddRoleAsync(Dictionary<string, object> roleData);
    }
}
