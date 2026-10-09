import java.util.ArrayList;

/*
  数字艺术装置风格：中文汉字粒子矩阵（自适应全屏版）
  Processing 4 / Java Mode

  核心特性：
  - 自动检测屏幕/窗口分辨率，动态调整网格
  - 字体排版完全占满整个画布
  - 支持窗口拖拽放大/缩小，自动重新排版
  - 保留所有交互逻辑：鼠标排斥 + 2 秒旋涡
  - 流畅 60fps + P2D 渲染

  使用说明：
  - 直接复制粘贴到 Processing 4 Java Mode
  - 支持拖拽窗口改变大小，会自动适应
  - 首次运行时，窗口会居中显示在屏幕上
*/

// =======================================================
// 全局参数（自适应相关）
// =======================================================

// 屏幕/画布尺寸
int canvasW;
int canvasH;

// 实际的网格行列（根据屏幕尺寸动态计算）
int cols;
int rows;

// 网格间距（会根据屏幕尺寸自动调整）
float spacingX;
float spacingY;

// 矩阵起始位置
float startX;
float startY;

// 汉字池
String hanPool =
  "零一二三四五六七八九十百千万亿时空光影数据流代码云端维度宇宙星河深海矩阵算法传输网络世界数字文明未来智能交互技术创新发展进步革命突破瞬间永恒无限循环反复迭代优化完美境界";

PFont chineseFont;

// 动态字体大小
float fontSize;
float letterAlpha = 220;
float trailAlpha = 35;

// 运动参数
float baseAmp = 0.65f;
float waveSpeed = 0.012f;
float damping = 0.93f;
float maxSpeed = 2.8f;
float springStrength = 0.065f;

// 鼠标交互参数
float repulseRadius;      // 根据屏幕大小缩放
float repulseStrength = 1.6f;
float swirlRadius;        // 根据屏幕大小缩放
float swirlStrength = 0.28f;
float vortexPullStrength = 0.12f;
float mouseStopThreshold = 2000; // 2 秒

// =======================================================
// 全局变量
// =======================================================

ArrayList<LetterParticle> particles;
PVector mousePos;
PVector smoothMouse;
PVector prevMousePos;

boolean vortexMode = false;
float lastMouseMoveTime = 0;

// 预计算缓存
float[] noiseCache;
float[] sineCache;
int cacheSize = 512;

// 记录上一帧的窗口尺寸，用于检测大小改变
int prevCanvasW = 0;
int prevCanvasH = 0;

// =======================================================
// Settings & Setup
// =======================================================

void settings() {
  // 首次启动时的窗口大小（用户可改）
  // 支持全屏：size(displayWidth, displayHeight, P2D);
  size(1280, 720, P2D);
  smooth(4);
}

void setup() {
  // 窗口居中显示在屏幕
  centerWindow();

  // 初始化缓存
  noiseCache = new float[cacheSize];
  sineCache = new float[cacheSize];
  for (int i = 0; i < cacheSize; i++) {
    noiseCache[i] = noise(i * 0.005f);
    sineCache[i] = sin(i * TWO_PI / cacheSize);
  }

  // 初始化鼠标位置
  mousePos = new PVector(mouseX, mouseY);
  smoothMouse = new PVector(mouseX, mouseY);
  prevMousePos = new PVector(mouseX, mouseY);

  // 记录初始窗口尺寸
  prevCanvasW = width;
  prevCanvasH = height;

  // 加载中文字体
  loadChineseFont();

  // 初始化粒子矩阵
  initParticleGrid();

  lastMouseMoveTime = millis();
}

// =======================================================
// 主循环
// =======================================================

void draw() {
  // 检测窗口是否被改变大小
  if (width != prevCanvasW || height != prevCanvasH) {
    handleWindowResize();
  }

  // 透明黑色覆盖制造拖尾
  fill(0, trailAlpha);
  rect(0, 0, width, height);

  updateMouse();
  updateVortexMode();

  // 更新粒子
  float timeFactor = millis() * waveSpeed * 0.001f;
  for (LetterParticle p : particles) {
    p.update(timeFactor);
  }

  // 绘制粒子
  for (LetterParticle p : particles) {
    p.display();
  }

  // 显示调试信息（可选）
  // displayDebugInfo();
}

// =======================================================
// 窗口大小适应相关
// =======================================================

void centerWindow() {
  // 计算屏幕中心位置
  int screenW = displayWidth;
  int screenH = displayHeight;
  int winX = (screenW - width) / 2;
  int winY = (screenH - height) / 2;
  surface.setLocation(winX, winY);
}

void handleWindowResize() {
  // 窗口大小改变时，重新初始化粒子网格
  println("Window resized to: " + width + " x " + height);

  prevCanvasW = width;
  prevCanvasH = height;

  // 清空旧粒子
  if (particles != null) {
    particles.clear();
  }

  // 重新初始化
  initParticleGrid();
}

void initParticleGrid() {
  // 动态计算网格参数，使得字体完全占满屏幕

  // 基础尺寸：根据屏幕分辨率设定字体大小
  // 这里采用"屏幕长边的 1/70"作为基础字体
  float refSize = max(width, height) / 70.0f;
  fontSize = constrain(refSize, 10, 20);

  // 计算字体实际占用的宽高（近似）
  float charWidth = fontSize * 0.7f;   // 汉字宽度近似为字体大小的 0.7
  float charHeight = fontSize * 1.0f;  // 汉字高度约等于字体大小

  // 计算可以放下多少列和行
  // 留出边距（屏幕 5% 的边距）
  float marginX = width * 0.03f;
  float marginY = height * 0.03f;

  float availableW = width - marginX * 2;
  float availableH = height - marginY * 2;

  cols = max(10, (int)(availableW / charWidth));
  rows = max(10, (int)(availableH / charHeight));

  // 重新计算间距，使得内容正好填满可用空间
  spacingX = availableW / cols;
  spacingY = availableH / rows;

  startX = marginX;
  startY = marginY;

  // 根据屏幕大小调整交互半径
  float screenDiag = sqrt(width * width + height * height);
  repulseRadius = screenDiag * 0.15f;   // 约 15% 屏幕对角线
  swirlRadius = screenDiag * 0.4f;      // 约 40% 屏幕对角线

  println("Grid initialized:");
  println("  Canvas: " + width + " x " + height);
  println("  Cols x Rows: " + cols + " x " + rows);
  println("  Font size: " + fontSize);
  println("  Spacing: " + spacingX + " x " + spacingY);
  println("  Repulse radius: " + repulseRadius);
  println("  Swirl radius: " + swirlRadius);

  // 加载字体（如果未加载）
  if (chineseFont == null) {
    loadChineseFont();
  }

  // 创建粒子
  particles = new ArrayList<LetterParticle>();
  for (int y = 0; y < rows; y++) {
    for (int x = 0; x < cols; x++) {
      int idx = y * cols + x;
      PVector origin = new PVector(
        startX + x * spacingX + spacingX * 0.5f,
        startY + y * spacingY + spacingY * 0.5f
      );
      char ch = getRandomHanChar(idx, x, y);
      particles.add(new LetterParticle(origin, ch, idx));
    }
  }
}

void loadChineseFont() {
  // 尝试加载中文字体，自动检测系统支持
  String[] fontNames = {
    "Microsoft YaHei",
    "PingFang SC",
    "SimHei",
    "Noto Sans CJK SC",
    "Arial Unicode MS",
    "Source Han Sans SC",
    "WenQuanYi Zen Hei"
  };

  for (String fontName : fontNames) {
    try {
      chineseFont = createFont(fontName, fontSize, true);
      if (chineseFont != null) {
        println("Successfully loaded font: " + fontName);
        textFont(chineseFont);
        textAlign(CENTER, CENTER);
        noStroke();
        return;
      }
    }
    catch (Exception e) {
      // 尝试下一个字体
    }
  }

  // 如果都没找到，使用默认字体并提示
  println("Warning: No Chinese font found. Please install a Chinese font.");
  println("Supported fonts: " + java.util.Arrays.toString(fontNames));
  chineseFont = createFont("Dialog", fontSize, true);
  textFont(chineseFont);
  textAlign(CENTER, CENTER);
  noStroke();
}

// =======================================================
// 鼠标控制
// =======================================================

void updateMouse() {
  float moveDist = dist(mouseX, mouseY, prevMousePos.x, prevMousePos.y);

  if (moveDist > 3) {
    vortexMode = false;
    lastMouseMoveTime = millis();
    prevMousePos.set(mouseX, mouseY);
  }

  // 平滑过渡鼠标位置
  smoothMouse.x = lerp(smoothMouse.x, mouseX, 0.18f);
  smoothMouse.y = lerp(smoothMouse.y, mouseY, 0.18f);
  mousePos.set(smoothMouse.x, smoothMouse.y);
}

void updateVortexMode() {
  float now = millis();
  if (now - lastMouseMoveTime > mouseStopThreshold) {
    vortexMode = true;
  }
}

void mouseMoved() {
  vortexMode = false;
  lastMouseMoveTime = millis();
}

void mouseDragged() {
  vortexMode = false;
  lastMouseMoveTime = millis();
}

// =======================================================
// 工具函数
// =======================================================

char getRandomHanChar(int idx, int x, int y) {
  int len = hanPool.length();
  int p = (idx * 7 + x * 11 + y * 13) % len;
  return hanPool.charAt(p);
}

void displayDebugInfo() {
  fill(100, 200);
  textSize(12);
  textAlign(LEFT);
  text("FPS: " + (int)frameRate, 20, 20);
  text("Particles: " + particles.size(), 20, 40);
  text("Canvas: " + width + " x " + height, 20, 60);
  text("Cols x Rows: " + cols + " x " + rows, 20, 80);
  text("Vortex: " + (vortexMode ? "ON" : "OFF"), 20, 100);
  textAlign(CENTER, CENTER);
}

// =======================================================
// 粒子类
// =======================================================

class LetterParticle {
  PVector origin;
  PVector position;
  PVector velocity;
  PVector acceleration;

  char character;
  float noiseOffsetX;
  float noiseOffsetY;
  float phase;
  float glow;
  boolean isNearMouse;

  LetterParticle(PVector origin, char ch, int idx) {
    this.origin = origin.copy();
    this.position = origin.copy();
    this.velocity = new PVector(0, 0);
    this.acceleration = new PVector(0, 0);

    this.character = ch;
    this.noiseOffsetX = noiseCache[idx % cacheSize];
    this.noiseOffsetY = noiseCache[(idx + 199) % cacheSize];
    this.phase = (idx * 0.13f) % TWO_PI;
    this.glow = 0.8f + (idx % 40) * 0.015f;
    this.isNearMouse = false;
  }

  void update(float timeFactor) {
    acceleration.set(0, 0);

    // 波浪运动：沿水平方向传播，竖直方向主要位移
    float waveIndex = (position.x * 0.06f + timeFactor * 12.0f + noiseOffsetX * 100.0f);
    int idx = (int)waveIndex % cacheSize;
    if (idx < 0) idx += cacheSize;
    float waveValue = sineCache[idx] * baseAmp;

    // 噪声扰动
    int noiseIdx = (int)((position.x * 0.03f + noiseOffsetX * 20.0f + position.y * 0.018f) % cacheSize);
    if (noiseIdx < 0) noiseIdx += cacheSize;
    float noiseValue = (noiseCache[noiseIdx] - 0.5f) * 2.4f;

    // 回归原位的弹性
    PVector spring = PVector.sub(origin, position);
    spring.mult(springStrength);

    acceleration.add(spring);
    acceleration.y += (waveValue + noiseValue) * 0.12f;

    // 交互力
    if (!vortexMode) {
      applyRepulsion();
    } else {
      applyVortex();
    }

    // 速度更新与阻尼
    velocity.add(acceleration);
    velocity.mult(damping);

    // 限制最大速度
    float speedSq = velocity.magSq();
    if (speedSq > maxSpeed * maxSpeed) {
      velocity.mult(maxSpeed / sqrt(speedSq));
    }

    position.add(velocity);

    // 边界约束（保持在网格区域内）
    float gridLeft = startX;
    float gridRight = startX + (cols - 1) * spacingX;
    float gridTop = startY;
    float gridBottom = startY + (rows - 1) * spacingY;

    if (position.x < gridLeft || position.x > gridRight) {
      position.x = constrain(position.x, gridLeft, gridRight);
      velocity.x *= -0.2f;
    }
    if (position.y < gridTop || position.y > gridBottom) {
      position.y = constrain(position.y, gridTop, gridBottom);
      velocity.y *= -0.2f;
    }
  }

  void applyRepulsion() {
    float dx = position.x - mousePos.x;
    float dy = position.y - mousePos.y;
    float distSq = dx * dx + dy * dy;
    float distLimit = repulseRadius * repulseRadius;

    if (distSq < distLimit && distSq > 0.0001f) {
      float dist = sqrt(distSq);
      float falloff = 1.0f - dist / repulseRadius;

      float nx = dx / dist;
      float ny = dy / dist;

      float force = falloff * repulseStrength;
      acceleration.x += nx * force;
      acceleration.y += ny * force;

      // 轻微切向扰动
      float tx = -ny * falloff * 0.45f;
      float ty = nx * falloff * 0.45f;
      acceleration.x += tx;
      acceleration.y += ty;
    }
  }

  void applyVortex() {
    float dx = position.x - mousePos.x;
    float dy = position.y - mousePos.y;
    float distSq = dx * dx + dy * dy;
    float swirlLimit = swirlRadius * swirlRadius;

    if (distSq < swirlLimit && distSq > 0.0001f) {
      float dist = sqrt(distSq);
      float falloff = 1.0f - dist / swirlRadius;

      float nx = dx / dist;
      float ny = dy / dist;

      // 向心吸引力
      float pull = falloff * vortexPullStrength * 2.7f;
      acceleration.x += (-nx) * pull;
      acceleration.y += (-ny) * pull;

      // 切向力（形成旋涡）
      float tangential = falloff * swirlStrength * 7.0f;
      acceleration.x += (-ny) * tangential;
      acceleration.y += nx * tangential;

      isNearMouse = (dist < 80);
    } else {
      isNearMouse = false;
    }
  }

  void display() {
    float dx = position.x - mousePos.x;
    float dy = position.y - mousePos.y;
    float dist = sqrt(dx * dx + dy * dy);

    // 颜色：深蓝 -> 电光蓝 -> 青绿 -> 白色
    float colorValue = noiseCache[(int)((position.x * 0.012f + noiseOffsetX * 50.0f) % cacheSize)];
    float r, g, b;

    if (dist < 70 || (vortexMode && dist < 110)) {
      r = 255;
      g = 255;
      b = 255;
    } else {
      r = lerp(20, 90, colorValue);
      g = lerp(90, 220, colorValue);
      b = lerp(150, 255, colorValue);
    }

    // 透明度随距离变化
    float alpha = letterAlpha;
    if (dist < 120) {
      alpha = lerp(180, 255, 1.0f - dist / 120.0f);
    }

    // 晕染感（白色高亮周围的柔光）
    if (dist < 110) {
      fill(255, 255, 255, 18 + (1.0f - dist / 110.0f) * 40);
      textSize(fontSize);
      text(character, position.x, position.y);
    }

    // 主文字
    fill(r, g, b, alpha);
    textSize(fontSize);
    text(character, position.x, position.y);
  }
}
