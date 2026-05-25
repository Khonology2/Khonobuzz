using FirebaseAdmin;
using FirebaseAdmin.Auth;
using Google.Apis.Auth.OAuth2;
using MyApi.Models;

namespace MyApi.Services
{
    public class FirebaseService : IFirebaseService
    {
        private readonly FirebaseAuth _auth;
        private readonly FirebaseApp _app;

        public FirebaseService(IConfiguration configuration)
        {
            if (FirebaseApp.DefaultInstance == null)
            {
                _app = FirebaseApp.Create(new AppOptions
                {
                    Credential = GoogleCredential.FromFile(configuration["Firebase:CredentialsPath"])
                });
            }
            else
            {
                _app = FirebaseApp.DefaultInstance;
            }

            _auth = FirebaseAuth.GetAuth(_app);
        }

        public async Task SyncUserToFirebaseAsync(User user)
        {
            try
            {
                var userRecord = await _auth.GetUserByEmailAsync(user.Email);
                // User already exists in Firebase, update if needed
                var updateArgs = new UserRecordArgs
                {
                    Uid = user.Id,
                    Email = user.Email,
                    DisplayName = user.Name,
                    EmailVerified = true
                };
                await _auth.UpdateUserAsync(updateArgs);
            }
            catch (FirebaseAuthException)
            {
                // User doesn't exist, create new
                var userArgs = new UserRecordArgs
                {
                    Uid = user.Id,
                    Email = user.Email,
                    DisplayName = user.Name,
                    EmailVerified = true
                };
                await _auth.CreateUserAsync(userArgs);
            }
        }

        public async Task SyncOnboardingToFirebaseAsync(Onboarding onboarding)
        {
            // For PDH Firebase project
            if (FirebaseApp.DefaultInstance == null ||
                FirebaseApp.DefaultInstance.Name != "pdh")
            {
                var pdhApp = FirebaseApp.Create(new AppOptions
                {
                    Credential = GoogleCredential.FromFile("pdh-v2-firebase-adminsdk-fbsvc-24b03c7996.json")
                }, "pdh");

                var pdhAuth = FirebaseAuth.GetAuth(pdhApp);

                try
                {
                    var userRecord = await pdhAuth.GetUserByEmailAsync(onboarding.Email);
                    // Update user data in PDH Firebase
                    var updateArgs = new UserRecordArgs
                    {
                        Uid = onboarding.UserId,
                        Email = onboarding.Email,
                        DisplayName = onboarding.FullName ?? onboarding.Name
                    };
                    await pdhAuth.UpdateUserAsync(updateArgs);
                }
                catch (FirebaseAuthException)
                {
                    // Create user in PDH Firebase
                    var userArgs = new UserRecordArgs
                    {
                        Uid = onboarding.UserId,
                        Email = onboarding.Email,
                        DisplayName = onboarding.FullName ?? onboarding.Name
                    };
                    await pdhAuth.CreateUserAsync(userArgs);
                }
            }
        }
    }
}
