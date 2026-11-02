class ApiConfig {
  ApiConfig._();

  // Android emulator -> Spring Boot running on your computer.
  static const String baseUrl = 'http://10.0.2.2:8080';

  static const Duration requestTimeout = Duration(seconds: 15);

  static const String registerEndpoint = '/api/auth/register';
  static const String loginEndpoint = '/api/auth/login';
}
