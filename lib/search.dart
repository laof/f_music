// https://www.musicenc.com/searchr/?token=???

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'dart:convert';

Future<List> search(String name) async {
  String str = Uri.encodeFull("https://www.musicenc.com/?search=$name");
  var url = Uri.parse(str);
  var response = await http.get(url);
  var document = parse(response.body);

  var ul = document.querySelectorAll(".list li");

  List list = List.generate(ul.length, (index) {
    var ele = ul[index];
    var span = ele.querySelector("span");
    var author = "";

    if (span != null) {
      author = span.innerHtml;
      author = author.replaceAll("&amp;", "&");
    }

    var a = ele.querySelector("a");
    String? token = "";
    String name = "";
    if (a != null) {
      name = a.innerHtml.replaceAll("&nbsp;", " ");
      token = a.attributes["dates"];
    }

    return {
      "index": index,
      "name": name,
      "token": token,
      "author": author,
    };
  });

  return list;
}

Future<String> getMP3(token) async {
  Uri url = Uri.parse("https://www.musicenc.com/searchr/?token=$token");
  var res = await http.get(url);

  // a element
  var aEle = parse(res.body).querySelector(".downBu.secm3");
  var href = aEle?.attributes["href"];

  if (href == null) {
    return "";
  } else if (href.startsWith("http")) {
    return getJavascriptData(href);
  } else if (href.startsWith("javascript:")) {
    return getHerfData(href);
  }
  return "";
}

Future<String> getJavascriptData(htmlurl) async {
  var spec = "_hello_lova_spec_";
  var url = Uri.parse(htmlurl);
  var response = await http.get(url);

  var str = response.body.replaceAll("\"", spec);
  str = str.replaceAll("'", spec);
  var token = str.split("pics=$spec")[1].split(spec)[0];

  if (token == "") {
    return "";
  }

  List<int> bytes2 = base64Decode(token);
  String decodeStr = String.fromCharCodes(bytes2);
  var mp3url = await http.get(Uri.parse(decodeStr));
  return mp3url.body;
}

// javascript:tps('aHR0cHM6Ly9hbnRpc2VydmVyLmt1d28uY24vYW50aS5zP2Zvcm1hdD1tcDN8YWFjJnJpZD0xMTg5ODAmYnI9MzIwa21wMyZ0eXBlPWNvbnZlcnRfdXJsJnJlc3BvbnNlPXJlcw==');
Future<String> getHerfData(String funstr) async {
  var ref = RegExp("(?<=['|\"]).*(?=['|\"])");
  String? cc = ref.firstMatch(funstr)?.group(0);
  if (cc == null) {
    return "";
  }
  List<int> bytes2 = base64Decode(cc);
  var url2 = String.fromCharCodes(bytes2);

  http.Request req = http.Request("Get", Uri.parse(url2))
    ..followRedirects = false;
  http.Client baseClient = http.Client();
  http.StreamedResponse response = await baseClient.send(req);
  var ccccc = response.headers['location'];
  baseClient.close();

  if (ccccc == null) {
    return "";
  }

  return ccccc;
}

// get fdasfa3455gfs2gf323;
String oldversion() {
  var str = "call('fdasfa3455gfs2gf323')";
  var ref = RegExp("(?<=['|\"]).*(?=['|\"])");
  String? cc = ref.firstMatch(str)?.group(0);
  if (cc != null) {
    List<int> bytes2 = base64Decode(cc);
    String decodeStr = String.fromCharCodes(bytes2);
    return decodeStr;
  }
  return "";
}
