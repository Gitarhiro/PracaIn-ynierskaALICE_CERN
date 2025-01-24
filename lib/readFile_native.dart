import 'package:flutter/services.dart' show rootBundle;

Future<String> loadJson(String filePath) async {
  for(int i=0;i<100;i++){
    print('loadNative');
  }

  return await rootBundle.loadString(filePath);

}