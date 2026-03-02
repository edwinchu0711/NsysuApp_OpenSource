import 'dart:typed_data';
import 'dart:convert'; // base64Decode
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math';
const int IMG_WIDTH = 124;  // 根據你的模型輸入調整
const int IMG_HEIGHT = 24;  // 根據你的模型輸入調整
const String CHARACTERS = "0123456789"; // 只有數字

class CaptchaPredictor {
  late Interpreter _interpreter;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// 載入模型
  Future<void> loadModel() async {
    try {
      print('Loading model...');
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      
      // 打印模型信息
      var inputTensors = _interpreter.getInputTensors();
      var outputTensors = _interpreter.getOutputTensors();
      
      print('✅ Model loaded successfully');
      print('📥 輸入張量數量: ${inputTensors.length}');
      print('📥 輸入形狀: ${inputTensors[0].shape}');
      print('📥 輸入類型: ${inputTensors[0].type}');
      print('📤 輸出張量數量: ${outputTensors.length}');
      print('📤 輸出形狀: ${outputTensors[0].shape}');
      print('📤 輸出類型: ${outputTensors[0].type}');
      
      _loaded = true;
    } catch (e) {
      _loaded = false;
      print('Error loading model: $e');
    }
  }


  String predict(Uint8List imageBytes) {
    if (!_loaded) {
      print('❌ 模型未載入');
      return "MODEL_NOT_LOADED";
    }

    try {
      print('📊 開始預測，圖片大小: ${imageBytes.length} bytes');

      // 1. 解碼圖片
      img.Image? raw = img.decodeImage(imageBytes);
      if (raw == null) {
        print('❌ 無法解碼圖片');
        return "INVALID_IMAGE";
      }

      // 2. 預處理：Resize -> HSV分離 -> 去噪 -> 正規化
      // 這一口氣完成所有動作，直接產出模型需要的輸入張量 [1, 24, 124, 1]
      // 這裡我們會強制 resize 到 IMG_WIDTH x IMG_HEIGHT
      img.Image resized = img.copyResize(raw, width: IMG_WIDTH, height: IMG_HEIGHT);
      
      var input = _preprocessSmartHSV(resized);
      print('✅ 預處理完成 (HSV+去噪)，輸入形狀: [1, 24, 124, 1]');

      // 3. 準備 Output Buffers
      final outputsByIndex = <int, List<List<double>>>{
        0: List.generate(1, (_) => List.filled(10, 0.0)),
        1: List.generate(1, (_) => List.filled(10, 0.0)),
        2: List.generate(1, (_) => List.filled(10, 0.0)),
        3: List.generate(1, (_) => List.filled(10, 0.0)),
      };

      // 4. 執行推論
      _interpreter.runForMultipleInputs([input], outputsByIndex);

      // 5. 解析輸出 (維持你原本的邏輯)
      final ordered = List<List<double>?>.filled(4, null);
      final re = RegExp(r':(\d+)$');

      for (int outIndex = 0; outIndex < 4; outIndex++) {
        final t = _interpreter.getOutputTensor(outIndex);
        final name = t.name ?? '';
        final m = re.firstMatch(name);

        // 如果 tensor name 解析失敗，嘗試直接用 index 對應 (fallback)
        int slot = outIndex; 
        if (m != null) {
           slot = int.parse(m.group(1)!);
        }
        
        if (slot >= 0 && slot < 4) {
          ordered[slot] = outputsByIndex[outIndex]![0];
        }
      }

      if (ordered.any((e) => e == null)) {
        // 如果名字對不上，就直接按順序 0,1,2,3 嘗試
        print("⚠️ Tensor name 解析可能有誤，使用預設順序");
         return _decodeOutputSingle(outputsByIndex[0]![0]) +
                _decodeOutputSingle(outputsByIndex[1]![0]) +
                _decodeOutputSingle(outputsByIndex[2]![0]) +
                _decodeOutputSingle(outputsByIndex[3]![0]);
      }

      final d0 = _decodeOutputSingle(ordered[0]!);
      final d1 = _decodeOutputSingle(ordered[1]!);
      final d2 = _decodeOutputSingle(ordered[2]!);
      final d3 = _decodeOutputSingle(ordered[3]!);

      return d0 + d1 + d2 + d3;

    } catch (e, stackTrace) {
      print('❌ 預測錯誤: $e');
      print('堆疊: $stackTrace');
      return "ERROR";
    }
  }

  // --- 新增的輔助方法 (取代原本的 adaptiveThreshold 和 prepareInput) ---

  /// 核心邏輯：HSV 智能分離 + 轉 Tensor
  /// 邏輯：S > 30 (彩色) 或 V < 140 (深色) => 文字(1.0)，否則背景(0.0)
  List<List<List<List<double>>>> _preprocessSmartHSV(img.Image image) {
    // 初始化 Tensor [1, 24, 124, 1]
    var input = List.generate(
      1,
      (_) => List.generate(
        IMG_HEIGHT,
        (_) => List.generate(
          IMG_WIDTH,
          (_) => List.filled(1, 0.0),
        ),
      ),
    );

    // 建立暫存 Map 用於去噪運算 (0=黑, 1=白)
    List<List<int>> binaryMap = List.generate(
      IMG_HEIGHT, 
      (_) => List.filled(IMG_WIDTH, 0)
    );

    // 1. HSV 計算與初步二值化
    for (int y = 0; y < IMG_HEIGHT; y++) {
      for (int x = 0; x < IMG_WIDTH; x++) {
        final pixel = image.getPixel(x, y);
        
        int r = pixel.r.toInt();
        int g = pixel.g.toInt();
        int b = pixel.b.toInt();

        // 計算 V (Value/Brightness) = max(R,G,B)
        int cMax = max(r, max(g, b));
        int cMin = min(r, min(g, b));
        int delta = cMax - cMin;

        // 計算 S (Saturation) 0~255
        // 如果 cMax 為 0，S 為 0，否則 (delta / cMax) * 255
        double s = (cMax == 0) ? 0.0 : (delta / cMax) * 255.0;
        int v = cMax; // V 就是最亮的值 0~255

        // --- 篩選條件 (跟 Python 邏輯一致) ---
        // S > 30: 代表有顏色 (紅綠藍紫...)
        // V < 140: 代表顏色很深 (深黑/深藍)
        bool isCharacter = (s > 30) || (v < 140);

        binaryMap[y][x] = isCharacter ? 1 : 0;
      }
    }

    // 2. 簡單去噪 (模擬 Morphology Open)
    // 去除孤立的噪點
    _simpleDenoise(binaryMap);

    // 3. 填入 Tensor (正規化為 0.0 或 1.0)
    for (int y = 0; y < IMG_HEIGHT; y++) {
      for (int x = 0; x < IMG_WIDTH; x++) {
        input[0][y][x][0] = binaryMap[y][x].toDouble(); 
      }
    }

    return input;
  }

  /// 簡單去噪：如果一個白點周圍的白點鄰居少於 2 個，視為雜訊移除
  void _simpleDenoise(List<List<int>> map) {
    // 記錄要移除的點，避免在迴圈中直接修改影響計算
    List<Point<int>> pixelsToRemove = [];

    for (int y = 1; y < IMG_HEIGHT - 1; y++) {
      for (int x = 1; x < IMG_WIDTH - 1; x++) {
        if (map[y][x] == 1) {
          // 檢查 8 鄰域
          int neighbors = 0;
          if (map[y-1][x] == 1) neighbors++;
          if (map[y+1][x] == 1) neighbors++;
          if (map[y][x-1] == 1) neighbors++;
          if (map[y][x+1] == 1) neighbors++;
          if (map[y-1][x-1] == 1) neighbors++;
          if (map[y-1][x+1] == 1) neighbors++;
          if (map[y+1][x-1] == 1) neighbors++;
          if (map[y+1][x+1] == 1) neighbors++;

          // 門檻設為 2 (可自行調整 1~3)
          if (neighbors < 2) {
            pixelsToRemove.add(Point(x, y));
          }
        }
      }
    }

    // 執行移除
    for (var p in pixelsToRemove) {
      map[p.y.toInt()][p.x.toInt()] = 0;
    }
  }

  // 解碼單個輸出 (保持不變)
  String _decodeOutputSingle(List<double> output) {
    int maxIndex = 0;
    double maxValue = output[0];
    
    for (int i = 1; i < output.length; i++) {
      if (output[i] > maxValue) {
        maxValue = output[i];
        maxIndex = i;
      }
    }
    return maxIndex.toString();
  }
  
  
  
  // // 解碼單個輸出
  // String _decodeOutputSingle(List<double> output) {
  //   int maxIndex = 0;
  //   double maxValue = output[0];
    
  //   for (int i = 1; i < output.length; i++) {
  //     if (output[i] > maxValue) {
  //       maxValue = output[i];
  //       maxIndex = i;
  //     }
  //   }
    
  //   print('   最大值索引: $maxIndex, 信心度: ${(maxValue * 100).toStringAsFixed(2)}%');
    
  //   return maxIndex.toString();
  // }


  // /// 準備單個字符的輸入數據
  // List<List<List<List<double>>>> _prepareInput(img.Image image) {
  //   // 形狀: [1, 24, 124, 1]
  //   var input = List.generate(
  //     1,
  //     (_) => List.generate(
  //       IMG_HEIGHT,  // 24
  //       (_) => List.generate(
  //         IMG_WIDTH, // 124
  //         (_) => List.filled(1, 0.0),
  //       ),
  //     ),
  //   );

  //   for (int y = 0; y < IMG_HEIGHT; y++) {
  //     for (int x = 0; x < IMG_WIDTH; x++) {
  //       final pixel = image.getPixel(x, y);
  //       final value = pixel.r.toInt();
  //       input[0][y][x][0] = value / 255.0;  // 正規化到 0-1
  //     }
  //   }

  //   return input;
  // }


  // /// 自適應二值化
  // img.Image _adaptiveThreshold(img.Image gray, {int threshold = 128}) {
  //   final bin = img.Image(width: gray.width, height: gray.height);

  //   for (int y = 0; y < gray.height; y++) {
  //     for (int x = 0; x < gray.width; x++) {
  //       final v = gray.getPixel(x, y).r.toInt();

  //       // INV：小於 threshold => 白(255)，否則黑(0)
  //       final b = (v < threshold) ? 255 : 0;

  //       bin.setPixelRgba(x, y, b, b, b, 255);
  //     }
  //   }
  //   return bin;
  // }

  /// 釋放資源
  void dispose() {
    if (_loaded) {
      _interpreter.close();
      _loaded = false;
    }
  }
}
