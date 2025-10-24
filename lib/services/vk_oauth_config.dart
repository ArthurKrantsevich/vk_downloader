class VkOAuthConfig {
  const VkOAuthConfig({
    required this.clientId,
    required this.redirectUri,
    this.scopes = const ['offline', 'photos'],
    this.apiVersion = '5.131',
  });

  final String clientId;
  final String redirectUri;
  final List<String> scopes;
  final String apiVersion;

  String get redirectScheme => Uri.parse(redirectUri).scheme;

  Uri buildAuthorizationUri({String? state}) {
    return Uri.https(
      'oauth.vk.com',
      '/authorize',
      <String, String>{
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'display': 'mobile',
        'response_type': 'token',
        'scope': scopes.join(','),
        'v': apiVersion,
        if (state != null) 'state': state,
      },
    );
  }
}

const VkOAuthConfig defaultVkOAuthConfig = VkOAuthConfig(
  clientId: 'REPLACE_WITH_CLIENT_ID',
  redirectUri: 'vk1234567://auth',
  scopes: ['offline', 'photos', 'video'],
);
