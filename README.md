# Node Exporter
**Prometheus Node Exporter 二次开发与功能拓展**

### 本地开发调试流程
1. **进入 `./cmd` 目录，执行 `build.cmd` 命令**
2. **配置调试环境**
    - 打开 **Edit Configurations** 菜单
    - 点击 **Add New Configuration**，选择 **Go Remote**
   ![调试配置](img/debug.png)
3. **启动 Debug 模式**  
   访问以下地址进行调试：[http://127.0.0.1:9100/metrics](http://127.0.0.1:9100/metrics)
