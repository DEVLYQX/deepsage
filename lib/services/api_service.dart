import 'package:deepsage/services/storage_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';


class ApiService {
  ApiService._();

  static final instance = ApiService._();
  final _db = StorageService.instance;
  final String cryptoApiUrl = 'https://api-stg.3lgn.com';
  final String onyxApiUrl = 'https://stg.deepsage.io/api';


  Future<ApiResponse<dynamic>> _call(
      Future<Response<dynamic>> request, {
        bool expectsData = false,
      }) async {
    try {
      final result = (await request).data;
      return ApiResponse.success(result);
    } on DioException catch (e) {
      // Logger().e(e.response.toString());
      return handleDioError(e);
    }
    catch (e, s) {
      if (!kReleaseMode) Logger().e(e, stackTrace: s);
    }
    return ApiResponse.failure('Something went wrong');
  }


  Future<Dio> _dio(bool isCrypto,) async {
    final accessToken = await _db.accessToken;

    final dio = Dio(
      BaseOptions(
        baseUrl: isCrypto ? cryptoApiUrl : onyxApiUrl,
        headers: {
          'Content-Type': 'application/json',
          if(isCrypto) 'x-cypress-env': 'true', // To bypass CAPTCHA as mentioned
          if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        },
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          Logger().i('Uri Path ${request.uri.path}  ${request.path}');
          if(request.uri.path.contains('/api/auth/login')) {
            request.headers['Content-Type'] = 'application/x-www-form-urlencoded';
          }
          handler.next(request);
        }
      )
    );
    if (!kReleaseMode) dio.interceptors.add(PrettyDioLogger(requestHeader: true, requestBody: true));

    return dio;
  }

  ApiResponse<dynamic> handleDioError(DioException error) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return ApiResponse.failure(
        'Please check your internet and try again.',
      );
    }

    if (error.type == DioExceptionType.badResponse) {
      String errorMessage = 'Unexpected error occurred';

      final e = error.response.toString();
      if (e.toString().contains('Invalid email')) {
        errorMessage = 'Please enter a valid email address';
      } else if (e.toString().contains('email should not be empty')) {
        errorMessage = 'Email field cannot be empty';
      } else if (e.toString().contains('password')) {
        errorMessage = 'Invalid password';
      } else if (e.toString().contains('Validation failed')) {
        errorMessage = 'Please check your email and password';
      } else {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      }

      return ApiResponse.failure( errorMessage, error.response?.statusCode,);
    }
    return ApiResponse.failure(
      'An unexpected error occurred',
    );
  }



  Future<ApiResponse> post(String path, Object body, {bool expectsData = false, bool isCrypto = false, bool encoded = false}) async {
    return _call((await _dio(isCrypto)).post(path, data: body), expectsData: expectsData);
  }

  Future<ApiResponse> get(String path,  [Map<String, dynamic>? queryParams, bool isCrypto = false]) async {
    return _call((await _dio(isCrypto)).get(path, queryParameters: queryParams),
        expectsData: true);
  }

}

class ApiResponse<T> {
  ApiResponse({this.data, this.message, this.code});
  final T? data;
  final String? message;
  final int? code;

  factory ApiResponse.success(T? data) => ApiResponse(data: data, code: 200);
  factory ApiResponse.failure(String msg, [int? code]) => ApiResponse(message: msg, code: code);
  bool get isSuccess => data != null;
}
