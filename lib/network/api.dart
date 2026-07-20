import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sura_driver/color/color.dart';

class Network {
  final String _url = Url.url;
  final String _url2 = Url.url;

  //if you are using android studio emulator, change localhost to 10.0.2.2

  // _getToken() async {
  //   SharedPreferences localStorage = await SharedPreferences.getInstance();
  //   token = jsonDecode(localStorage.getString('token'))['token'];
  // }

  checkData(data, apiUrl) async {
    var fullUrl = _url + apiUrl;
    final Uri url = Uri.parse(fullUrl);
    print(url);
    final http.Response response = await http.post(url, body: data);
    print(response.body);
    return response;
  }

  Future<bool> checkData2(data, apiUrl) async {
    var fullUrl = _url2 + apiUrl;
    final Uri url = Uri.parse(fullUrl);
    print(url);
    final http.Response response = await http.post(url, body: data);
    print(response.body);

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseMap = json.decode(response.body);
      SharedPreferences type = await SharedPreferences.getInstance();
      print(responseMap['data']['type']);
      return (responseMap['success'] == 'true' ||
          responseMap['success'] == true);
    } else {
      return false;
    }
  }

  Future<bool> image(data, apiUrl) async {
    var fullUrl = _url2 + apiUrl;
    final Uri url = Uri.parse(fullUrl);
    print(url);
    final http.Response response = await http.post(url, body: data);
    print(response.body);

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseMap = json.decode(response.body);
      SharedPreferences type = await SharedPreferences.getInstance();
      type.setString('type', responseMap['user']['type']);
      print(responseMap['user']['type']);
      return (responseMap['success'] == 'true' ||
          responseMap['success'] == true);
    } else {
      return false;
    }
  }

  Future<String> Pay(data, apiUrl) async {
    var fullUrl = _url2 + apiUrl;
    final Uri url = Uri.parse(fullUrl);
    print(url);
    final http.Response response = await http.post(url, body: data);
    print(response.body);
    if (response.statusCode == 200) {
      final Map<String, dynamic> responseMap = json.decode(response.body);

      print(responseMap);
      print(responseMap['success'] == 'true' || responseMap['success'] == true);

      if (responseMap['success'] == 'true' || responseMap['success'] == true) {
        print(responseMap['url']);
        return responseMap['url'];
      } else
        return "err";
    } else {
      return "err";
    }
  }

  getData(data, apiUrl) async {
    var fullUrl = _url + apiUrl;
    final Uri url = Uri.parse(fullUrl);

    return await http.post(url, body: data);
  }

  register(data, apiUrl) async {
    var fullUrl = _url + apiUrl;
    final Uri url = Uri.parse(fullUrl);

    return await http.post(url, body: data);
  }
}
