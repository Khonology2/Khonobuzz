using System.Text.Json;
using Google.Cloud.Firestore;
using Google.Cloud.Firestore.V1;

namespace MyApi.Services
{
    public class PdhFirestoreService : IPdhFirestoreService
    {
        private readonly FirestoreDb? _db;

        public bool IsConfigured => _db != null;

        public PdhFirestoreService(IConfiguration configuration)
        {
            var json = Environment.GetEnvironmentVariable("PDH_FIREBASE_CREDENTIALS_JSON")?.Trim();
            if (string.IsNullOrEmpty(json))
            {
                var path = Environment.GetEnvironmentVariable("PDH_FIREBASE_CREDENTIALS_PATH")?.Trim()
                    ?? configuration["Firebase:PdhCredentialsPath"];
                if (!string.IsNullOrEmpty(path) && File.Exists(path))
                    json = File.ReadAllText(path);
            }
            if (string.IsNullOrEmpty(json))
            {
                _db = null;
                return;
            }
            var cred = JsonSerializer.Deserialize<JsonElement>(json);
            var projectId = cred.GetProperty("project_id").GetString();
            if (string.IsNullOrEmpty(projectId))
            {
                _db = null;
                return;
            }
            try
            {
                var clientBuilder = new FirestoreClientBuilder { JsonCredentials = json };
                _db = FirestoreDb.Create(projectId, clientBuilder.Build());
            }
            catch
            {
                _db = null;
            }
        }

        public async Task SetUserAsync(string uid, Dictionary<string, object> data)
        {
            if (_db == null) return;
            var docRef = _db.Collection("users").Document(uid);
            await docRef.SetAsync(ToFirestoreDict(data), SetOptions.MergeAll);
        }

        public async Task SetOnboardingAsync(string uid, Dictionary<string, object> data)
        {
            if (_db == null) return;
            var docRef = _db.Collection("onboarding").Document(uid);
            await docRef.SetAsync(ToFirestoreDict(data), SetOptions.MergeAll);
        }

        public async Task DeleteUserAsync(string uid)
        {
            if (_db == null) return;
            await _db.Collection("users").Document(uid).DeleteAsync();
            await _db.Collection("onboarding").Document(uid).DeleteAsync();
        }

        private static Dictionary<string, object> ToFirestoreDict(Dictionary<string, object> d)
        {
            var out_ = new Dictionary<string, object>();
            foreach (var kv in d)
            {
                if (kv.Value == null) continue;
                if (kv.Value is DateTime dt)
                    out_[kv.Key] = Timestamp.FromDateTime(dt.ToUniversalTime());
                else if (kv.Value.GetType().FullName?.Contains("FieldValue") == true)
                    out_[kv.Key] = kv.Value;
                else if (kv.Value is Dictionary<string, object> nested)
                    out_[kv.Key] = ToFirestoreDict(nested);
                else
                    out_[kv.Key] = kv.Value;
            }
            return out_;
        }
    }
}
