# vk_downloader
Application for downloading media files from VK.COM

## VK OAuth setup

1. Create or use an existing VK application and note its application ID.
2. Configure a custom URI scheme redirect (for example `vk1234567://auth`) on every target platform.
3. Update the constants in `lib/services/vk_oauth_config.dart` so that `defaultVkOAuthConfig`
   contains your `clientId`, `redirectUri`, and the desired permission scopes.
4. Run the application. The splash screen checks the stored Hive session and opens the login
   screen when authentication is required. After a successful VK OAuth flow, the access token and
   user information are cached in Hive and you are redirected to the download screen automatically.
