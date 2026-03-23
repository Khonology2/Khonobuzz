using System.Text.Json;
using Google.Cloud.Firestore;
using Google.Cloud.Firestore.V1;

namespace MyApi.Services
{
    public class FirestoreService : IFirestoreService
    {
        private readonly FirestoreDb _db;

        public FirestoreService(IConfiguration configuration)
        {
            var json = Environment.GetEnvironmentVariable("FIREBASE_CREDENTIALS_JSON")?.Trim();
            if (string.IsNullOrEmpty(json))
            {
                var path = Environment.GetEnvironmentVariable("FIREBASE_CREDENTIALS_PATH")?.Trim()
                    ?? configuration["Firebase:CredentialsPath"];
                if (!string.IsNullOrEmpty(path) && File.Exists(path))
                    json = File.ReadAllText(path);
            }
            if (string.IsNullOrEmpty(json))
                throw new InvalidOperationException("Firebase credentials not configured. Set FIREBASE_CREDENTIALS_JSON or FIREBASE_CREDENTIALS_PATH or Firebase:CredentialsPath.");

            var cred = JsonSerializer.Deserialize<JsonElement>(json);
            var projectId = cred.GetProperty("project_id").GetString()
                ?? throw new InvalidOperationException("Firebase JSON missing project_id");

            var clientBuilder = new FirestoreClientBuilder { JsonCredentials = json };
            _db = FirestoreDb.Create(projectId, clientBuilder.Build());
        }

        private static Dictionary<string, object>? DocToDict(DocumentSnapshot? doc)
        {
            if (doc == null || !doc.Exists) return null;
            var d = new Dictionary<string, object>();
            foreach (var kv in doc.ToDictionary())
                d[kv.Key] = ConvertFirestoreValue(kv.Value);
            return d;
        }

        private static object ConvertFirestoreValue(object? v)
        {
            if (v == null) return null!;
            if (v is Timestamp ts) return ts.ToDateTime();
            return v;
        }

        public async Task<IReadOnlyList<Dictionary<string, object>>> GetUsersAsync()
        {
            var snapshot = await _db.Collection("users").GetSnapshotAsync();
            var list = new List<Dictionary<string, object>>();
            foreach (var doc in snapshot.Documents)
            {
                var d = DocToDict(doc);
                if (d != null)
                {
                    d["id"] = doc.Id;
                    list.Add(d);
                }
            }
            return list;
        }

        public async Task<IReadOnlyList<Dictionary<string, object>>> GetUsersWithOnboardingAsync()
        {
            var users = await GetUsersAsync();
            var result = new List<Dictionary<string, object>>();
            foreach (var user in users)
            {
                var uid = user.GetValueOrDefault("id")?.ToString() ?? "";
                var ob = await GetOnboardingByUserIdAsync(uid);
                var merged = MergeUserWithOnboarding(user, ob);
                result.Add(merged);
            }
            result.Sort((a, b) =>
            {
                var aUpd = GetDateTime(a, "updatedAt") ?? GetDateTime(a, "created_at") ?? DateTime.MinValue;
                var bUpd = GetDateTime(b, "updatedAt") ?? GetDateTime(b, "created_at") ?? DateTime.MinValue;
                return bUpd.CompareTo(aUpd);
            });
            return result;
        }

        private static Dictionary<string, object> MergeUserWithOnboarding(Dictionary<string, object> user, Dictionary<string, object>? ob)
        {
            var obEmpty = ob == null || ob.Count == 0;
            var firstName = (obEmpty ? null : ob!.GetValueOrDefault("firstName") ?? ob.GetValueOrDefault("name"))?.ToString()
                ?? user.GetValueOrDefault("firstName")?.ToString() ?? "";
            var lastName = (obEmpty ? null : ob!.GetValueOrDefault("lastName") ?? ob.GetValueOrDefault("surname"))?.ToString()
                ?? user.GetValueOrDefault("lastName")?.ToString() ?? "";
            var modAccess = user.GetValueOrDefault("moduleAccess")?.ToString() ?? ob?.GetValueOrDefault("moduleAccess")?.ToString() ?? "";
            var modRole = user.GetValueOrDefault("moduleAccessRole")?.ToString() ?? ob?.GetValueOrDefault("moduleAccessRole")?.ToString() ?? "";
            var dept = ob?.GetValueOrDefault("department")?.ToString() ?? user.GetValueOrDefault("department")?.ToString() ?? "";
            var desig = ob?.GetValueOrDefault("designation")?.ToString() ?? user.GetValueOrDefault("designation")?.ToString() ?? "";
            var entity = user.GetValueOrDefault("entity")?.ToString() ?? ob?.GetValueOrDefault("entity")?.ToString() ?? "";
            var manager = user.GetValueOrDefault("manager")?.ToString() ?? ob?.GetValueOrDefault("manager")?.ToString() ?? "";
            var profileUrl = ob?.GetValueOrDefault("profileImageUrl")?.ToString() ?? user.GetValueOrDefault("profileImageUrl")?.ToString() ?? "";
            var createdAt = user.GetValueOrDefault("created_at");
            var updatedAt = user.GetValueOrDefault("updated_at");
            var lastSignIn = user.GetValueOrDefault("lastSignInAt");
            return new Dictionary<string, object>
            {
                ["id"] = user.GetValueOrDefault("id") ?? "",
                ["email"] = user.GetValueOrDefault("email") ?? "",
                ["role"] = user.GetValueOrDefault("role") ?? "Staff",
                ["status"] = user.GetValueOrDefault("status") ?? "Active",
                ["firstName"] = firstName,
                ["lastName"] = lastName,
                ["department"] = dept,
                ["designation"] = desig,
                ["entity"] = entity,
                ["manager"] = manager,
                ["moduleAccess"] = modAccess,
                ["moduleRole"] = user.GetValueOrDefault("moduleRole")?.ToString() ?? ob?.GetValueOrDefault("moduleRole")?.ToString() ?? "",
                ["moduleAccessRole"] = modRole,
                ["profileImageUrl"] = profileUrl,
                ["createdAt"] = createdAt is DateTime dt ? dt.ToString("o") + "Z" : createdAt?.ToString() ?? "",
                ["updatedAt"] = updatedAt is DateTime du ? du.ToString("o") + "Z" : updatedAt?.ToString() ?? "",
                ["lastSignInAt"] = lastSignIn is DateTime dk ? dk.ToString("o") + "Z" : lastSignIn?.ToString() ?? ""
            };
        }

        private static DateTime? GetDateTime(Dictionary<string, object> d, string key)
        {
            if (!d.TryGetValue(key, out var v) || v == null) return null;
            if (v is DateTime dt) return dt;
            if (v is Timestamp ts) return ts.ToDateTime();
            return null;
        }

        public async Task<Dictionary<string, object>?> GetUserByIdAsync(string userId)
        {
            var doc = await _db.Collection("users").Document(userId).GetSnapshotAsync();
            var d = DocToDict(doc);
            if (d != null) d["id"] = userId;
            return d;
        }

        public async Task<Dictionary<string, object>?> GetUserByEmailAsync(string email)
        {
            var normalized = email.Trim().ToLowerInvariant();
            var query = _db.Collection("users").WhereEqualTo("email", normalized).Limit(1);
            var snapshot = await query.GetSnapshotAsync();
            var doc = snapshot.Documents.FirstOrDefault();
            if (doc == null) return null;
            var d = DocToDict(doc);
            if (d != null) d["id"] = doc.Id;
            return d;
        }

        public async Task<Dictionary<string, object>?> GetOnboardingByUserIdAsync(string userId)
        {
            var query = _db.Collection("onboarding").WhereEqualTo("user_id", userId).Limit(1);
            var snapshot = await query.GetSnapshotAsync();
            var doc = snapshot.Documents.FirstOrDefault();
            return DocToDict(doc);
        }

        public async Task UpdateUserAsync(string userId, Dictionary<string, object> updates)
        {
            updates["updated_at"] = FieldValue.ServerTimestamp;
            await _db.Collection("users").Document(userId).UpdateAsync(ToFirestoreDict(updates));
        }

        public async Task UpdateOnboardingByUserIdAsync(string userId, Dictionary<string, object> updates)
        {
            updates["updated_at"] = FieldValue.ServerTimestamp;
            var query = _db.Collection("onboarding").WhereEqualTo("user_id", userId).Limit(1);
            var snapshot = await query.GetSnapshotAsync();
            var doc = snapshot.Documents.FirstOrDefault();
            if (doc != null)
                await doc.Reference.UpdateAsync(ToFirestoreDict(updates));
        }

        public async Task DeleteUserAsync(string userId)
        {
            await _db.Collection("users").Document(userId).DeleteAsync();
            var query = _db.Collection("onboarding").WhereEqualTo("user_id", userId);
            var snapshot = await query.GetSnapshotAsync();
            foreach (var doc in snapshot.Documents)
                await doc.Reference.DeleteAsync();
        }

        public async Task<string> AddUserAsync(Dictionary<string, object> userData)
        {
            var docRef = await _db.Collection("users").AddAsync(ToFirestoreDict(userData));
            return docRef.Id;
        }

        public async Task AddOnboardingAsync(string userId, Dictionary<string, object> onboardingData)
        {
            onboardingData["user_id"] = userId;
            await _db.Collection("onboarding").AddAsync(ToFirestoreDict(onboardingData));
        }

        public async Task<IReadOnlyList<string>> GetDepartmentNamesAsync()
        {
            var snapshot = await _db.Collection("departments").GetSnapshotAsync();
            var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var doc in snapshot.Documents)
            {
                var n = (doc.GetValue<string>("name") ?? "").Trim();
                if (!string.IsNullOrEmpty(n)) names.Add(n);
            }
            return names.OrderBy(n => n, StringComparer.OrdinalIgnoreCase).ToList();
        }

        public async Task AddDepartmentIfNotExistsAsync(string name)
        {
            var n = name.Trim();
            if (string.IsNullOrEmpty(n)) return;
            var q = _db.Collection("departments").WhereEqualTo("name", n).Limit(1);
            var snap = await q.GetSnapshotAsync();
            if (snap.Documents.Count == 0)
                await _db.Collection("departments").AddAsync(new Dictionary<string, object> { ["name"] = n });
        }

        public async Task<IReadOnlyList<string>> GetDesignationNamesAsync()
        {
            var snapshot = await _db.Collection("designations").GetSnapshotAsync();
            var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var doc in snapshot.Documents)
            {
                var n = (doc.GetValue<string>("name") ?? "").Trim();
                if (!string.IsNullOrEmpty(n)) names.Add(n);
            }
            return names.OrderBy(n => n, StringComparer.OrdinalIgnoreCase).ToList();
        }

        public async Task AddDesignationIfNotExistsAsync(string name)
        {
            var n = name.Trim();
            if (string.IsNullOrEmpty(n)) return;
            var q = _db.Collection("designations").WhereEqualTo("name", n).Limit(1);
            var snap = await q.GetSnapshotAsync();
            if (snap.Documents.Count == 0)
                await _db.Collection("designations").AddAsync(new Dictionary<string, object> { ["name"] = n });
        }

        public async Task<IReadOnlyList<Dictionary<string, object>>> GetRolesAsync()
        {
            var snapshot = await _db.Collection("roles").GetSnapshotAsync();
            var list = new List<Dictionary<string, object>>();
            foreach (var doc in snapshot.Documents)
            {
                var d = DocToDict(doc);
                if (d != null)
                {
                    d["id"] = doc.Id;
                    list.Add(d);
                }
            }
            return list;
        }

        public async Task AddRoleAsync(Dictionary<string, object> roleData)
        {
            roleData["created_at"] = FieldValue.ServerTimestamp;
            roleData["updated_at"] = FieldValue.ServerTimestamp;
            await _db.Collection("roles").AddAsync(ToFirestoreDict(roleData));
        }

        private static Dictionary<string, object> ToFirestoreDict(Dictionary<string, object> d)
        {
            var out_ = new Dictionary<string, object>();
            foreach (var kv in d)
            {
                if (kv.Value is DateTime dt)
                    out_[kv.Key] = Timestamp.FromDateTime(dt.ToUniversalTime());
                else if (kv.Value is Dictionary<string, object> nested)
                    out_[kv.Key] = ToFirestoreDict(nested);
                else
                    out_[kv.Key] = kv.Value;
            }
            return out_;
        }
    }
}
