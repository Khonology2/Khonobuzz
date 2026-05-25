namespace MyApi.Services
{
    public interface IPdhFirestoreService
    {
        bool IsConfigured { get; }
        Task SetUserAsync(string uid, Dictionary<string, object> data);
        Task SetOnboardingAsync(string uid, Dictionary<string, object> data);
        Task DeleteUserAsync(string uid);
    }
}
