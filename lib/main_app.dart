import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_dart/three_dart.dart' as three;
import 'package:three_dart_jsm/three_dart_jsm.dart' as three_jsm;

import 'readFile_web.dart' if (dart.library.io) 'readFile_native.dart';

class WebGlLoaderObj extends StatefulWidget {
  const WebGlLoaderObj({Key? key}) : super(key: key);
  @override
  State<WebGlLoaderObj> createState() => _MyAppState();
}

class _MyAppState extends State<WebGlLoaderObj> {
  late FlutterGlPlugin three3dRender;
  three.WebGLRenderer? renderer;

  int? fboId;
  late double width;
  late double height;

  Size? screenSize;

  late three.Scene scene;
  late three.Camera camera;
  late three.Mesh mesh;

  double dpr = 1.0;

  var amount = 4;

  bool verbose = true;
  bool disposed = false;

  Map<String, three.Object3D> objects = {};
  Map<String, List<three.Line>> geometries = {};

  late three.Texture texture;
  late three.WebGLRenderTarget renderTarget;
  dynamic sourceTexture;

  final GlobalKey<three_jsm.DomLikeListenableState> _globalKey = GlobalKey<three_jsm.DomLikeListenableState>();
  late three_jsm.OrbitControls controls;

  Map<String, bool> models = {
    'CPV': true,
    'EMC': true,
    'HMP': true,
    'ITS': true,
    'MCH': true,
    'MFT': true,
    'MID': true,
    'PHS': true,
    'TOF': true,
    'TPC': true,
    'TRD': true,
  };

  Map<String, bool> tracks = {
    'track1': false,
    'track2': false,
    'track3': false,
  };

  @override
  void initState() {
    super.initState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    width = screenSize!.width;
    height = screenSize!.height;

    three3dRender = FlutterGlPlugin();

    Map<String, dynamic> options = {
      "antialias": true,
      "alpha": false,
      "width": width.toInt(),
      "height": height.toInt(),
      "dpr": dpr
    };

    await three3dRender.initialize(options: options);

    setState(() {});

    // Wait for web
    Future.delayed(const Duration(milliseconds: 100), () async {
      await three3dRender.prepareContext();

      initScene();
    });
  }

  initSize(BuildContext context) {
    if (screenSize != null) {
      return;
    }

    final mqd = MediaQuery.of(context);

    screenSize = mqd.size;
    dpr = mqd.devicePixelRatio;

    initPlatformState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (BuildContext context) {
          initSize(context);
          return SingleChildScrollView(child: _build(context));
        },
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            backgroundColor: Colors.black,
            child: const Text(
              "render",
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () {
              render();
            },
          ),
          SizedBox(width: 10),
          PopupMenuButton<String>(
            color: Colors.black,
            offset: Offset(0, -48),
            child:  const Text(
                "models",
                style: TextStyle(color: Colors.white)),
            itemBuilder: (BuildContext context) {
              return models.keys.map((String key) {
                return PopupMenuItem<String>(
                  value: key,
                  child: StatefulBuilder(
                    builder: (BuildContext context, StateSetter setState) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            key,
                            style: TextStyle(color: Colors.white),
                          ),
                          Checkbox(
                            value: models[key],
                            activeColor: Colors.white,
                            checkColor: Colors.black,
                            onChanged: (bool? newValue) {
                              if (newValue == null) return;
                              bool oldValue = tracks[key] ?? false;
                              bool operationSuccessful = true;
                              if (newValue) {
                                try {
                                  scene.add(objects[key]!);
                                } catch (e) {
                                  print("Error while adding elements: $e");
                                  operationSuccessful = false;
                                }
                              } else {
                                try {
                                  scene.remove(objects[key]!);
                                } catch (e) {
                                  print("Error while removing elements: $e");
                                  operationSuccessful = false;
                                }
                              }
                              render();
                              setState(() {
                                models[key] = newValue!;
                                if(newValue) {
                                  scene.add(objects[key]!);
                                } else {
                                  scene.remove(objects[key]!);
                                }
                              });
                            },
                          ),
                        ],
                      );
                    },
                  ),
                );
              }).toList();
            },
          ),
          SizedBox(width: 10),
          PopupMenuButton<String>(
            color: Colors.black,
            offset: Offset(0, -48),
            child:  const Text(
                "tracks",
                style: TextStyle(color: Colors.white)),
            itemBuilder: (BuildContext context) {
              return tracks.keys.map((String key) {
                return PopupMenuItem<String>(
                  value: key,
                  child: StatefulBuilder(
                    builder: (BuildContext context, StateSetter setState) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            key,
                            style: const TextStyle(color: Colors.white),
                          ),
                          Checkbox(
                            value: tracks[key],
                            activeColor: Colors.white,
                            checkColor: Colors.black,
                            onChanged: (bool? newValue) async {
                              if (newValue == null) return;
                              bool oldValue = tracks[key] ?? false;
                              bool operationSuccessful = true;
                              if (newValue) {
                                try {
                                  for (var line in geometries[key]!) {
                                    if (!scene.children.contains(line)) {
                                      scene.add(line);
                                    }
                                  }
                                } catch (e) {
                                  print("Error while adding elements: $e");
                                  operationSuccessful = false;
                                }
                              } else {
                                try {
                                  for (var line in geometries[key]!) {
                                    if (scene.children.contains(line)) {
                                      scene.remove(line);
                                    }
                                  }
                                } catch (e) {
                                  print("Error while removing elements: $e");
                                  operationSuccessful = false;
                                }
                              }
                              render();
                              if (operationSuccessful) {
                                setState(() {
                                  tracks[key] = newValue!;

                                });
                              } else {
                                print("Operation failed, state will not be changed.");
                              }
                            },
                          ),
                        ],
                      );
                    },
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
    );
  }

  Widget _build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            three_jsm.DomLikeListenable(
              key: _globalKey,
              builder: (BuildContext context) {
                return Container(
                  width: width,
                  height: height,
                  color: Colors.black,
                  child: Builder(builder: (BuildContext context) {
                    if (kIsWeb) {
                      return three3dRender.isInitialized
                          ? HtmlElementView(viewType: three3dRender.textureId!.toString())
                          : Container();
                    } else {
                      return three3dRender.isInitialized
                          ? Texture(textureId: three3dRender.textureId!)
                          : Container();
                    }
                  }),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  render() {
    int t = DateTime.now().millisecondsSinceEpoch;

    final gl = three3dRender.gl;

    renderer!.render(scene, camera);

    int t1 = DateTime.now().millisecondsSinceEpoch;

    if (verbose) {
      print("render cost: ${t1 - t} ");
      print(renderer!.info.memory);
      print(renderer!.info.render);
    }

    gl.flush();

    if (verbose) print(" render: sourceTexture: $sourceTexture ");

    if (!kIsWeb) {
      three3dRender.updateTexture(sourceTexture);
    }
  }

  initRenderer() {
    Map<String, dynamic> options = {
      "width": width,
      "height": height,
      "gl": three3dRender.gl,
      "antialias": true,
      "canvas": three3dRender.element
    };
    renderer = three.WebGLRenderer(options);
    renderer!.setPixelRatio(dpr);
    renderer!.setSize(width, height, false);
    renderer!.shadowMap.enabled = false;

    if (!kIsWeb) {
      var pars = three.WebGLRenderTargetOptions({"format": three.RGBAFormat});
      renderTarget = three.WebGLRenderTarget((width * dpr).toInt(), (height * dpr).toInt(), pars);
      renderTarget.samples = 4;
      renderer!.setRenderTarget(renderTarget);
      sourceTexture = renderer!.getRenderTargetGLTexture(renderTarget);
    }
  }

  initScene() {
    initRenderer();
    initPage();
  }

  Future<void> loadOBJ(file, color) async {
    try {
      var loader = three_jsm.OBJLoader(null);
      three.Object3D object = await loader.loadAsync('assets/models/$file.obj');

      final material = three.MeshPhongMaterial({
        "color": color,
        "shininess": 100,
      });

      object.traverse((child) {
        if (child is three.Mesh) {
          child.material = material;
        }
      });

      object.scale.set(0.2, 0.2, 0.2);
      object.position.set(0, 0, 0);
      objects[file] = object;

      scene.add(object);
    } catch(e){
      print("did not load $file");
    }
  }

  Future<void> loadTracks(file, color) async {
    try {
      String jsonString;

      jsonString = await loadJson('assets/tracks/$file.json');

      final data = json.decode(jsonString);
      List<three.Line> sum = [];
      final tracks = data['mTracks'];
      for (var track in tracks) {
        final geometry = three.BufferGeometry();

        final vertices = <double>[];
        for (var i = 0; i < track['mPolyX'].length; i++) {
          vertices.addAll([
            track['mPolyX'][i],
            track['mPolyY'][i],
            track['mPolyZ'][i],
          ]);
        }
        final float32Vertices = Float32Array.fromList(vertices);

        geometry.setAttribute(
          'position',
          three.Float32BufferAttribute(float32Vertices, 3),
        );

        final material = three.LineBasicMaterial({
          "color": color,
          "linewidth": 2,
          "linejoin": "round",
        });

        final line = three.Line(geometry, material);
        sum.add(line);
      }
      geometries[file] = sum;


    }catch(e){
      print("did not load $file");
    }
  }

  initPage() async {
    camera = three.PerspectiveCamera(100, width / height, 0.1, 1000);
    camera.position.set(200, 100, 100);

    controls = three_jsm.OrbitControls(camera, _globalKey);
    controls.dampingFactor = 0.05;
    controls.screenSpacePanning = false;
    controls.minDistance = 10;
    controls.maxDistance = 1000;
    controls.maxPolarAngle = three.Math.pi / 2;

    scene = three.Scene();

    var ambientLight = three.AmbientLight(0xcccccc, 1);
    scene.add(ambientLight);

    var pointLight = three.PointLight(0xffffff, 1);
    camera.add(pointLight);
    scene.add(camera);
    Map<String, int> files = {
      'CPV': 0xEB6F47,
      'EMC': 0xF5F5DC,
      'HMP': 0x0000FF,
      'ITS': 0x8A2BE2,
      'MCH': 0x7FFF00,
      'MFT': 0xDC143C,
      'MID': 0x00FFFF,
      'PHS': 0x006400,
      'TOF': 0xFF8C00,
      'TPC': 0x9932CC,
      'TRD': 0xE9967A,
    };

    Map<String, int> tracks = {
      'track1': 0xF5F5DC,
      'track2': 0x8A2BE2,
      'track3': 0x0000FF,
    };

    final modelTasks = files.entries.map((entry) async {
      print('Loading model: ${entry.key}');
      await loadOBJ(entry.key, entry.value);
      print('Model ${entry.key} loaded.');
    });

    // Load tracks concurrently
    final trackTasks = tracks.entries.map((entry) async {
      print('Loading track: ${entry.key}');
      await loadTracks(entry.key, entry.value);
      print('Track ${entry.key} loaded.');
    });

    await Future.wait([...modelTasks, ...trackTasks]);

    animate();
  }

  animate() {
    if (!mounted || disposed) {
      return;
    }

    render();

    Future.delayed(Duration(milliseconds: 1), () {
      animate();
    });
  }



  @override
  void dispose() {
    print(" dispose ............. ");
    disposed = true;
    three3dRender.dispose();

    super.dispose();
  }
}
