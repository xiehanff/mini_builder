# MiniBuilder Example

此示例演示 MiniBuilder 的核心功能：

## 功能展示

1. **细粒度刷新**
   - 全量 `update()` 刷新所有监听器
   - 按 id 的局部刷新
   - `shouldRebuild` 条件重建

2. **跨 Controller 依赖**（`lib/features/dependency/dependency_worker_example.dart`）
   - 根部 `MiniProvider` 注入应用依赖
   - 构造函数显式注入
   - `watchAll` 监听多个依赖
   - `Mini.batch()` 批量更新

3. **onInit 异步请求**（`lib/features/lifecycle/on_init_api_example.dart`）
   - 在 `onInit()` 中请求 API
   - 嵌套 controller 的生命周期
   - 异常处理和状态更新

## 目录结构

- `lib/main.dart`：应用启动入口，仅负责启动日志和 `runApp`
- `lib/app/`：应用根组件和全局依赖组合
- `lib/features/home/`：示例首页和页面组合
- `lib/features/counter/`：细粒度刷新 controller
- `lib/features/product/`：商品详情 controller 和页面
- `lib/features/dependency/`：跨 controller 依赖示例
- `lib/features/lifecycle/`：`onInit` 异步请求示例
- `lib/shared/`：示例共享基础设施，例如结构化日志

## 运行示例

### Web（推荐）
```bash
flutter run -d chrome
```

### macOS/Linux/Windows
```bash
flutter run
```

### 移动平台
由于示例主要展示库功能而非平台特性，当前版本移除了 Android/iOS 配置以简化维护。
如需在移动平台测试，可以：
1. 创建新的 Flutter 项目
2. 将 `lib/` 下的示例代码复制过去
3. 添加 `mini_builder` 依赖

## 运行测试

```bash
cd example
flutter test
```

**已知问题**：`dependency_worker_example_test.dart` 在某些环境下可能因 Flutter 框架的 shader 资源问题失败，这不影响实际功能。核心库测试（项目根目录 `test/`）全部通过。
