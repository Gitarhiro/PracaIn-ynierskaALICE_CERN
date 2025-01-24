import 'dart:html' as html;

Future<String> loadJson(String filePath) async {
  for(int i=0;i<100;i++){
    print('loadWeb');
  }
  return await html.HttpRequest.getString(filePath);
}