import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;


void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ImageProviderModel(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Tools',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class ImageProviderModel extends ChangeNotifier {
  final List<File> _imageFiles = [];
  final Set<int> _selectedIndexes = {};
  bool _processing = false;

  List<File> get imageFiles => _imageFiles;
  bool get processing => _processing;
  Set<int> get selectedIndexes => _selectedIndexes;

  void addFiles(List<File> files) {
    _imageFiles.addAll(files);
    notifyListeners();
  }

  void clearFiles() {
    _imageFiles.clear();
    _selectedIndexes.clear();
    notifyListeners();
  }

  void selectAll() {
    _selectedIndexes.clear();
    for (int i = 0; i < _imageFiles.length; i++) {
      _selectedIndexes.add(i);
    }
    notifyListeners();
  }

  void deselectAll() {
    _selectedIndexes.clear();
    notifyListeners();
  }

  void toggleSelect(int index) {
    if (_selectedIndexes.contains(index)) {
      _selectedIndexes.remove(index);
    } else {
      _selectedIndexes.add(index);
    }
    notifyListeners();
  }

  void removeSelected() {
    _selectedIndexes.toList().sort((a, b) => b.compareTo(a));
    for (final idx in _selectedIndexes) {
      _imageFiles.removeAt(idx);
    }
    _selectedIndexes.clear();
    notifyListeners();
  }

  set processing(bool value) {
    _processing = value;
    notifyListeners();
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Tools'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: DropTarget(
              onDragDone: (details) {
                _addDroppedPaths(details.files.map((f) => f.path).toList());
              },
              child: Container(
                color: Colors.grey[200],
                child: Consumer<ImageProviderModel>(
                  builder: (context, model, child) {
                    if (model.imageFiles.isEmpty) {
                      return const Center(
                        child: Text('Drag and drop images or a folder here, or click the button below.'),
                      );
                    }
                    return Column(
                      children: [
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () => context.read<ImageProviderModel>().selectAll(),
                              child: const Text('全选'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => context.read<ImageProviderModel>().deselectAll(),
                              child: const Text('取消全选'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => context.read<ImageProviderModel>().removeSelected(),
                              child: const Text('移除选中'),
                            ),
                          ],
                        ),
                        Expanded(
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 150,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4,
                            ),
                            itemCount: model.imageFiles.length,
                            itemBuilder: (context, index) {
                              final selected = model.selectedIndexes.contains(index);
                              return GestureDetector(
                                onTap: () => model.toggleSelect(index),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Image.file(
                                        model.imageFiles[index],
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    if (selected)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Icon(Icons.check_circle, color: Colors.blue, size: 24),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Operations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  // Operation buttons will be added here
                  Consumer<ImageProviderModel>(
                    builder: (context, model, child) {
                      return AbsorbPointer(
                        absorbing: model.processing,
                        child: Opacity(
                          opacity: model.processing ? 0.5 : 1.0,
                          child: Column(
                            children: [
                              Wrap(
                                spacing: 8.0,
                                runSpacing: 4.0,
                                children: <Widget>[
                                  ElevatedButton(onPressed: () => _processImages(_trim), child: const Text('Trim')),
                                  ElevatedButton(onPressed: _showResizeDialog, child: const Text('Resize')),
                                  ElevatedButton(onPressed: () => _processImages(_grayscale), child: const Text('Grayscale')),
                                  ElevatedButton(onPressed: _showTransparentDialog, child: const Text('Make BG Transparent')),
                                  ElevatedButton(onPressed: _showRotateDialog, child: const Text('Rotate')),
                                ],
                              ),
                              if (model.processing)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(width: 10),
                                      Text('Processing...'),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            allowMultiple: true,
            type: FileType.image,
          );

          if (result != null) {
            final files = result.paths.map((p) => File(p!)).toList();
            context.read<ImageProviderModel>().addFiles(files);
          }
        },
        label: const Text('Select Images'),
        icon: const Icon(Icons.add_photo_alternate),
      ),
    );
  }

  void _addDroppedPaths(List<String> paths) {
    final model = context.read<ImageProviderModel>();
    List<File> filesToAdd = [];
    final supportedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tif', '.tiff', '.pdf'];

    for (final p in paths) {
      final type = FileSystemEntity.typeSync(p);
      if (type == FileSystemEntityType.file) {
        if (supportedExtensions.contains(path.extension(p).toLowerCase())) {
          filesToAdd.add(File(p));
        }
      } else if (type == FileSystemEntityType.directory) {
        final dir = Directory(p);
        final entities = dir.listSync(recursive: true);
        for (final entity in entities) {
          if (entity is File) {
            if (supportedExtensions.contains(path.extension(entity.path).toLowerCase())) {
              filesToAdd.add(entity);
            }
          }
        }
      }
    }
    model.addFiles(filesToAdd);
  }

  Future<void> _processImages(Future<img.Image?> Function(img.Image) operation) async {
    final model = context.read<ImageProviderModel>();
    final List<File> filesToProcess = model.selectedIndexes.isNotEmpty
      ? model.selectedIndexes.map((i) => model.imageFiles[i]).toList()
      : model.imageFiles;
    if (filesToProcess.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No images to process.')),
      );
      return;
    }
    model.processing = true;
    try {
      final downloadsDir = await getDownloadsDirectory();
      final outputDir = Directory(path.join(downloadsDir!.path, 'ImageToolSet_Output'));
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }
      for (final file in filesToProcess) {
        final imageBytes = await file.readAsBytes();
        final image = img.decodeImage(imageBytes);
        if (image == null) continue;
        final processedImage = await operation(image);
        if (processedImage != null) {
          final String extension = path.extension(file.path);
          final String baseName = path.basenameWithoutExtension(file.path);
          final newFileName = '${baseName}_processed$extension';
          final newFilePath = path.join(outputDir.path, newFileName);
          final newFile = File(newFilePath);
          if (extension.toLowerCase() == '.jpg' || extension.toLowerCase() == '.jpeg') {
            await newFile.writeAsBytes(img.encodeJpg(processedImage, quality: 85));
          } else if (extension.toLowerCase() == '.tif' || extension.toLowerCase() == '.tiff') {
            await newFile.writeAsBytes(img.encodeTiff(processedImage)); // image 3.x 默认LZW压缩
          } else {
            await newFile.writeAsBytes(img.encodePng(processedImage, level: 6));
          }
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Processing complete!'),
          action: SnackBarAction(
            label: 'Open Folder',
            onPressed: () async {
              try {
                await Process.run('explorer', [outputDir.path]);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not open the folder.')),
                );
              }
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      model.processing = false;
      // 保留图片列表，方便继续操作
    }
  }

  Future<img.Image?> _trim(img.Image image) async {
    // 裁剪白色或透明边缘，兼容 image 3.x Pixel 类型
    int left = 0, right = image.width - 1, top = 0, bottom = image.height - 1;
    final bgPixel = image.getPixel(0, 0);
    bool isBg(img.Pixel pixel) {
      // 允许一定容差，适配白色和近白色
      return (pixel.r > 240 && pixel.g > 240 && pixel.b > 240 && pixel.a > 240) ||
             (pixel.r == bgPixel.r && pixel.g == bgPixel.g && pixel.b == bgPixel.b && pixel.a == bgPixel.a);
    }
    // 上
    for (int y = 0; y < image.height; y++) {
      bool found = false;
      for (int x = 0; x < image.width; x++) {
        if (!isBg(image.getPixel(x, y))) {
          found = true;
          break;
        }
      }
      if (found) {
        top = y;
        break;
      }
    }
    // 下
    for (int y = image.height - 1; y >= 0; y--) {
      bool found = false;
      for (int x = 0; x < image.width; x++) {
        if (!isBg(image.getPixel(x, y))) {
          found = true;
          break;
        }
      }
      if (found) {
        bottom = y;
        break;
      }
    }
    // 左
    for (int x = 0; x < image.width; x++) {
      bool found = false;
      for (int y = top; y <= bottom; y++) {
        if (!isBg(image.getPixel(x, y))) {
          found = true;
          break;
        }
      }
      if (found) {
        left = x;
        break;
      }
    }
    // 右
    for (int x = image.width - 1; x >= 0; x--) {
      bool found = false;
      for (int y = top; y <= bottom; y++) {
        if (!isBg(image.getPixel(x, y))) {
          found = true;
          break;
        }
      }
      if (found) {
        right = x;
        break;
      }
    }
    int w = right - left + 1;
    int h = bottom - top + 1;
    if (w <= 0 || h <= 0) return image;
    return img.copyCrop(image, x: left, y: top, width: w, height: h);
  }

  Future<img.Image?> _grayscale(img.Image image) async {
    return img.grayscale(image);
  }

  void _showResizeDialog() {
    double scale = 1.0;
    int? width;
    int? height;
    final widthController = TextEditingController();
    final heightController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Resize Image'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Note: Applying scale will override width/height.'),
              TextField(
                decoration: const InputDecoration(labelText: 'Scale (e.g., 0.5 for 50%)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) => scale = double.tryParse(value) ?? 1.0,
              ),
              TextField(
                controller: widthController,
                decoration: const InputDecoration(labelText: 'Width (pixels)'),
                keyboardType: TextInputType.number,
                onChanged: (value) => width = int.tryParse(value),
              ),
              TextField(
                controller: heightController,
                decoration: const InputDecoration(labelText: 'Height (pixels)'),
                keyboardType: TextInputType.number,
                onChanged: (value) => height = int.tryParse(value),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _processImages((image) async {
                  int targetWidth, targetHeight;
                  if (scale != 1.0) {
                    targetWidth = (image.width * scale).round();
                    targetHeight = (image.height * scale).round();
                  } else {
                    targetWidth = width ?? image.width;
                    targetHeight = height ?? image.height;
                  }
                  return img.copyResize(image, width: targetWidth, height: targetHeight);
                });
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  void _showTransparentDialog() {
    // For simplicity, we'll make pixels that match the color of the top-left pixel transparent.
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Make Background Transparent'),
            content: const Text('This will make pixels matching the top-left corner color transparent. This is a simple implementation and may not work for all images.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _processImages((image) async {
                    if (image.format != img.Format.uint8 || image.numChannels != 4) {
                       image = image.convert(format: img.Format.uint8, numChannels: 4);
                    }
                    final cornerColor = image.getPixel(0, 0);
                    for (final pixel in image) {
                      if (pixel == cornerColor) {
                        pixel.a = 0;
                      }
                    }
                    return image;
                  });
                },
                child: const Text('Apply'),
              ),
            ],
          );
        });
  }

  void _showRotateDialog() {
    double angle = 90;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rotate Image'),
          content: TextField(
            decoration: const InputDecoration(labelText: 'Angle (degrees)'),
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            onChanged: (value) => angle = double.tryParse(value) ?? 90,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _processImages((image) async => img.copyRotate(image, angle: angle));
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }
}

