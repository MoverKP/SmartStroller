地图API Key设置说明
==================

程序支持两种地图：Google Maps（默认）和高德地图

一、使用 Google Maps（推荐，默认）
----------------------------------
步骤：
1. 访问 Google Cloud Console: https://console.cloud.google.com/google/maps-apis
2. 登录您的Google账号
3. 创建新项目或选择现有项目
4. 启用 "Maps JavaScript API"
5. 创建API密钥（Credentials -> Create Credentials -> API Key）
6. 打开 gps_map.html 文件
7. 找到这一行：AIzaSyAaBO9D6HaMOinmruJpnSnEyc9IFaTIqng
   <script src="https://maps.googleapis.com/maps/api/js?key=YOUR_API_KEY&callback=initMap" async defer></script>
8. 将 YOUR_API_KEY 替换为您获取的API Key
9. 保存文件

运行：
python GPSDataReading.py
或
python GPSDataReading.py google

注意：
- Google Maps 提供每月 $200 的免费额度（通常足够个人使用）
- 需要绑定信用卡（但不会自动扣费，除非超出免费额度）

二、使用高德地图
---------------
步骤：
1. 访问高德开放平台：https://console.amap.com/dev/key/app
2. 注册/登录账号
3. 进入控制台，创建新应用
4. 选择"Web服务(JS API)"类型
5. 获取API Key
6. 打开 gps_map.html 文件
7. 找到这一行：
   <script src="https://webapi.amap.com/maps?v=2.0&key=YOUR_API_KEY"></script>
8. 将 YOUR_API_KEY 替换为您获取的API Key
9. 保存文件

运行：
python GPSDataReading.py gaode
或
python GPSDataReading.py amap

注意：
- 高德地图API Key是免费的，但需要注册账号
- 适合在中国大陆使用

通用说明：
---------
- 地图会在 http://localhost:8000 上运行
- 程序会自动打开浏览器显示地图
- 如果浏览器没有自动打开，请手动访问该地址
- GPS数据会每秒实时更新到地图上
- 按 Ctrl+C 停止程序
