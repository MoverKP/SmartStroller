import sys
import time
import threading
import json
import os
import webbrowser
from collections import deque
from http.server import HTTPServer, SimpleHTTPRequestHandler
import socketserver

# Try to import serial with better error handling
try:
    from serial import Serial
except ImportError as e:
    print(f"Error importing serial module: {e}")
    print("Please make sure pyserial is installed: pip install pyserial")
    sys.exit(1)
except AttributeError as e:
    print(f"Error: serial module doesn't have Serial attribute: {e}")
    print("This might be caused by a file named 'serial.py' in your directory.")
    print("Please check for any files named 'serial.py' and rename or remove them.")
    sys.exit(1)

# Global variables for GPS data
gps_data = {'lat': None, 'lon': None, 'valid': False, 'timestamp': None}
position_history = deque(maxlen=100)  # Store last 100 positions
data_lock = threading.Lock()
map_file = os.path.join(os.path.dirname(__file__), 'gps_map.html')
json_file = os.path.join(os.path.dirname(__file__), 'gps_data.json')

# Function to update GPS data (thread-safe)
def update_gps_data(lat, lon):
    global gps_data, position_history
    with data_lock:
        gps_data['lat'] = lat
        gps_data['lon'] = lon
        gps_data['valid'] = True
        gps_data['timestamp'] = time.time()
        position_history.append({'lon': lon, 'lat': lat, 'time': time.time()})
        
        # Write to JSON file for HTML to read
        try:
            data_to_write = {
                'current': {'lat': lat, 'lon': lon},
                'history': list(position_history)
            }
            with open(json_file, 'w', encoding='utf-8') as f:
                json.dump(data_to_write, f, indent=2)
        except Exception as e:
            print(f"Error writing GPS data to file: {e}")

# Function to create HTML file with Google Maps or Gaode Map
def create_map_html(map_type='google'):
    if map_type.lower() == 'google':
        return create_google_map_html()
    else:
        return create_gaode_map_html()

def create_google_map_html():
    html_content = '''<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GPS实时位置追踪 - Google Maps</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            font-family: Arial, sans-serif;
        }
        #mapContainer {
            width: 100%;
            height: 100vh;
        }
        #infoPanel {
            position: absolute;
            top: 10px;
            left: 10px;
            background: rgba(255, 255, 255, 0.9);
            padding: 15px;
            border-radius: 5px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.3);
            z-index: 1000;
            min-width: 200px;
        }
        #infoPanel h3 {
            margin: 0 0 10px 0;
            color: #333;
        }
        #infoPanel p {
            margin: 5px 0;
            font-size: 14px;
        }
        .status {
            font-weight: bold;
        }
        .status.waiting {
            color: #ff9800;
        }
        .status.active {
            color: #4caf50;
        }
    </style>
</head>
<body>
    <div id="mapContainer"></div>
    <div id="infoPanel">
        <h3>GPS实时追踪</h3>
        <p>状态: <span id="status" class="status waiting">等待GPS数据...</span></p>
        <p>纬度: <span id="lat">--</span></p>
        <p>经度: <span id="lon">--</span></p>
        <p>更新时间: <span id="updateTime">--</span></p>
    </div>

    <script src="https://maps.googleapis.com/maps/api/js?key=AIzaSyAaBO9D6HaMOinmruJpnSnEyc9IFaTIqng&callback=initMap" async defer></script>
    <script>
        // 注意：请将 YOUR_API_KEY 替换为您的Google Maps API Key
        // 获取API Key: https://console.cloud.google.com/google/maps-apis
        // 需要启用 "Maps JavaScript API"
        
        var map;
        var marker;
        var polyline;
        var path = [];
        var apiKeyValid = false;
        
        // 初始化地图
        function initMap() {
            try {
                // 默认位置（北京天安门）
                var defaultCenter = { lat: 39.90923, lng: 116.397428 };
                
                map = new google.maps.Map(document.getElementById('mapContainer'), {
                    zoom: 15,
                    center: defaultCenter,
                    mapTypeId: 'roadmap'
                });
                
                apiKeyValid = true;
                
                // 开始轮询GPS数据
                loadGPSData();
                setInterval(loadGPSData, 1000); // 每秒更新一次
            } catch (e) {
                console.error('地图初始化失败:', e);
                document.getElementById('mapContainer').innerHTML = 
                    '<div style="padding: 50px; text-align: center; color: red;">' +
                    '<h2>地图加载失败</h2>' +
                    '<p>请检查API Key是否正确配置</p>' +
                    '<p>获取API Key: <a href="https://console.cloud.google.com/google/maps-apis" target="_blank">Google Cloud Console</a></p>' +
                    '</div>';
            }
        }
        
        // 加载GPS数据
        function loadGPSData() {
            if (!apiKeyValid || !map) {
                return;
            }
            
            fetch('gps_data.json?t=' + new Date().getTime())
                .then(response => response.json())
                .then(data => {
                    if (data.current && data.current.lat && data.current.lon) {
                        updateMap(data.current.lat, data.current.lon, data.history || []);
                    }
                })
                .catch(error => {
                    // 静默处理，等待GPS数据
                });
        }
        
        // 更新地图
        function updateMap(lat, lon, history) {
            if (!apiKeyValid || !map) {
                return;
            }
            
            var position = { lat: lat, lng: lon };
            
            // 更新信息面板
            document.getElementById('status').textContent = '已连接';
            document.getElementById('status').className = 'status active';
            document.getElementById('lat').textContent = lat.toFixed(6) + '°';
            document.getElementById('lon').textContent = lon.toFixed(6) + '°';
            document.getElementById('updateTime').textContent = new Date().toLocaleTimeString('zh-CN');
            
            // 创建或更新标记
            if (!marker) {
                marker = new google.maps.Marker({
                    position: position,
                    map: map,
                    title: '当前位置',
                    icon: {
                        path: google.maps.SymbolPath.CIRCLE,
                        scale: 8,
                        fillColor: '#FF0000',
                        fillOpacity: 1,
                        strokeColor: '#FFFFFF',
                        strokeWeight: 2
                    }
                });
            } else {
                marker.setPosition(position);
            }
            
            // 更新路径
            if (history && history.length > 0) {
                path = history.map(function(item) {
                    return { lat: item.lat, lng: item.lon };
                });
                
                if (!polyline) {
                    polyline = new google.maps.Polyline({
                        path: path,
                        geodesic: true,
                        strokeColor: '#3366FF',
                        strokeOpacity: 1.0,
                        strokeWeight: 3,
                        map: map
                    });
                } else {
                    polyline.setPath(path);
                }
            }
            
            // 移动地图中心到当前位置
            map.setCenter(position);
            
            // 如果只有一个点，设置合适的缩放级别
            if (history.length <= 1) {
                map.setZoom(15);
            } else {
                // 自动调整视野以包含所有路径点
                var bounds = new google.maps.LatLngBounds();
                path.forEach(function(point) {
                    bounds.extend(point);
                });
                map.fitBounds(bounds);
            }
        }
        
        // 如果API加载失败，显示错误信息
        window.gm_authFailure = function() {
            document.getElementById('mapContainer').innerHTML = 
                '<div style="padding: 50px; text-align: center; color: red;">' +
                '<h2>Google Maps API Key未配置或无效</h2>' +
                '<p>请编辑 gps_map.html 文件，将 YOUR_API_KEY 替换为您的Google Maps API Key</p>' +
                '<p><a href="https://console.cloud.google.com/google/maps-apis" target="_blank">点击这里获取API Key</a></p>' +
                '<p>获取步骤：</p>' +
                '<ol style="text-align: left; display: inline-block;">' +
                '<li>访问Google Cloud Console并登录</li>' +
                '<li>创建项目或选择现有项目</li>' +
                '<li>启用 "Maps JavaScript API"</li>' +
                '<li>创建API密钥</li>' +
                '<li>将密钥替换到HTML文件中的YOUR_API_KEY位置</li>' +
                '</ol>' +
                '</div>';
        };
    </script>
</body>
</html>'''
    
    with open(map_file, 'w', encoding='utf-8') as f:
        f.write(html_content)
    
    print(f"Google Maps HTML文件已创建: {map_file}")
    print("注意: 请将HTML文件中的 YOUR_API_KEY 替换为您的Google Maps API Key")
    print("获取API Key: https://console.cloud.google.com/google/maps-apis")
    print("需要启用 'Maps JavaScript API'")

def create_gaode_map_html():
    html_content = '''<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GPS实时位置追踪 - 高德地图</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            font-family: Arial, sans-serif;
        }
        #mapContainer {
            width: 100%;
            height: 100vh;
        }
        #infoPanel {
            position: absolute;
            top: 10px;
            left: 10px;
            background: rgba(255, 255, 255, 0.9);
            padding: 15px;
            border-radius: 5px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.3);
            z-index: 1000;
            min-width: 200px;
        }
        #infoPanel h3 {
            margin: 0 0 10px 0;
            color: #333;
        }
        #infoPanel p {
            margin: 5px 0;
            font-size: 14px;
        }
        .status {
            font-weight: bold;
        }
        .status.waiting {
            color: #ff9800;
        }
        .status.active {
            color: #4caf50;
        }
    </style>
</head>
<body>
    <div id="mapContainer"></div>
    <div id="infoPanel">
        <h3>GPS实时追踪</h3>
        <p>状态: <span id="status" class="status waiting">等待GPS数据...</span></p>
        <p>纬度: <span id="lat">--</span></p>
        <p>经度: <span id="lon">--</span></p>
        <p>更新时间: <span id="updateTime">--</span></p>
    </div>

    <script src="https://webapi.amap.com/maps?v=2.0&key=YOUR_API_KEY"></script>
    <script>
        // 注意：请将 YOUR_API_KEY 替换为您的高德地图API Key
        // 获取API Key: https://lbs.amap.com/api/javascript-api/guide/abc/prepare
        // 或者访问: https://console.amap.com/dev/key/app
        
        var map;
        var marker;
        var polyline;
        var path = [];
        var apiKeyValid = false;
        
        // 检查API Key是否有效
        function checkAPIKey() {
            if (typeof AMap === 'undefined') {
                document.getElementById('mapContainer').innerHTML = 
                    '<div style="padding: 50px; text-align: center; color: red;">' +
                    '<h2>高德地图API Key未配置</h2>' +
                    '<p>请编辑 gps_map.html 文件，将 YOUR_API_KEY 替换为您的高德地图API Key</p>' +
                    '<p><a href="https://console.amap.com/dev/key/app" target="_blank">点击这里获取API Key</a></p>' +
                    '<p>获取步骤：</p>' +
                    '<ol style="text-align: left; display: inline-block;">' +
                    '<li>访问高德开放平台并注册/登录</li>' +
                    '<li>进入控制台创建应用</li>' +
                    '<li>获取Web服务(JS API)的Key</li>' +
                    '<li>将Key替换到HTML文件中的YOUR_API_KEY位置</li>' +
                    '</ol>' +
                    '</div>';
                return false;
            }
            return true;
        }
        
        // 初始化地图
        function initMap() {
            if (!checkAPIKey()) {
                return;
            }
            
            try {
                map = new AMap.Map('mapContainer', {
                    zoom: 15,
                    center: [116.397428, 39.90923], // 默认北京天安门
                    viewMode: '3D'
                });
                
                // 添加地图控件
                map.addControl(new AMap.Scale());
                map.addControl(new AMap.ToolBar());
                
                apiKeyValid = true;
                
                // 开始轮询GPS数据
                loadGPSData();
                setInterval(loadGPSData, 1000); // 每秒更新一次
            } catch (e) {
                console.error('地图初始化失败:', e);
                document.getElementById('mapContainer').innerHTML = 
                    '<div style="padding: 50px; text-align: center; color: red;">' +
                    '<h2>地图加载失败</h2>' +
                    '<p>请检查API Key是否正确配置</p>' +
                    '</div>';
            }
        }
        
        // 加载GPS数据
        function loadGPSData() {
            if (!apiKeyValid) {
                return;
            }
            
            fetch('gps_data.json?t=' + new Date().getTime())
                .then(response => response.json())
                .then(data => {
                    if (data.current && data.current.lat && data.current.lon) {
                        updateMap(data.current.lat, data.current.lon, data.history || []);
                    }
                })
                .catch(error => {
                    // 静默处理，等待GPS数据
                });
        }
        
        // 更新地图
        function updateMap(lat, lon, history) {
            if (!apiKeyValid || !map) {
                return;
            }
            var position = [lon, lat];
            
            // 更新信息面板
            document.getElementById('status').textContent = '已连接';
            document.getElementById('status').className = 'status active';
            document.getElementById('lat').textContent = lat.toFixed(6) + '°';
            document.getElementById('lon').textContent = lon.toFixed(6) + '°';
            document.getElementById('updateTime').textContent = new Date().toLocaleTimeString('zh-CN');
            
            // 创建或更新标记
            if (!marker) {
                marker = new AMap.Marker({
                    position: position,
                    map: map,
                    icon: new AMap.Icon({
                        size: new AMap.Size(40, 50),
                        image: 'https://webapi.amap.com/theme/v1.3/markers/n/mid.png',
                        imageOffset: new AMap.Pixel(-9, -3),
                        imageSize: new AMap.Size(18, 25)
                    }),
                    title: '当前位置'
                });
            } else {
                marker.setPosition(position);
            }
            
            // 更新路径
            if (history && history.length > 0) {
                path = history.map(function(item) {
                    return [item.lon, item.lat];
                });
                
                if (!polyline) {
                    polyline = new AMap.Polyline({
                        path: path,
                        isOutline: true,
                        outlineColor: '#ffeeff',
                        borderWeight: 3,
                        strokeColor: '#3366FF',
                        strokeOpacity: 1,
                        strokeWeight: 3,
                        strokeStyle: 'solid',
                        lineJoin: 'round',
                        lineCap: 'round',
                        zIndex: 50,
                        map: map
                    });
                } else {
                    polyline.setPath(path);
                }
            }
            
            // 移动地图中心到当前位置
            map.setCenter(position);
            
            // 如果只有一个点，设置合适的缩放级别
            if (history.length <= 1) {
                map.setZoom(15);
            } else {
                // 自动调整视野以包含所有路径点
                map.setFitView([polyline]);
            }
        }
        
        // 页面加载完成后初始化地图
        window.onload = initMap;
    </script>
</body>
</html>'''
    
    with open(map_file, 'w', encoding='utf-8') as f:
        f.write(html_content)
    
    print(f"高德地图HTML文件已创建: {map_file}")
    print("注意: 请将HTML文件中的 YOUR_API_KEY 替换为您的高德地图API Key")
    print("获取API Key: https://lbs.amap.com/api/javascript-api/guide/abc/prepare")

# Windows COM port - change 'COM6' to your actual COM port number
# You can find it in Device Manager under "Ports (COM & LPT)"
try:
    ser = Serial('COM6', 115200)  # 115200是GPS的波特率
    print("Serial port opened successfully on COM6")
except Exception as e:
    print(f"Error opening serial port: {e}")
    print("Please check:")
    print("1. COM port number is correct (check Device Manager)")
    print("2. No other program is using the port")
    print("3. GPS device is connected")
    sys.exit(1)

# Function to read GPS data in a separate thread
def read_gps_data():
    global ser
    print("Reading GPS data... Press Ctrl+C to stop")
    while True:
        try:
            line = ser.readline().decode('utf-8', errors='ignore').strip()
            # #打印所有串口数据
            # print(line)
            GNRMC_line = line
            # GNGLL_line = line
            # GNGLL_line = line
            if GNRMC_line.startswith('$GNRMC'):
                print(GNRMC_line)
                GNRMC_line = GNRMC_line.split(',')  # 将line以"，"为分隔符
                #GNRMC_line格式为：['$GNRMC', '132558.000', 'A', '3412.93903', 'N', '11708.08969', 'E', '0.00', '0.00', '081221', '', '', 'A75']
                #GNRMC_line格式为：['$GNRMC', '当天UTC时间', 'A表示数据有效', '纬度', 'N-北', '精度', 'E-东', '对地速度，单位为节', '对地真航向，单位为度', '日期(dd 为日,mm为月,yy为年)', '', '', 'A75']
                # print(GNRMC_line)  #查看数据类型
                # 时间转化省略（需要把UTC转化为北京时间）
                # Lat ddmm.mmmm 纬度，前2字符表示度，后面的字符表示分,需要转化为小数形式
                # Only process if data is valid (status 'A')
                if len(GNRMC_line) > 5 and GNRMC_line[2] == 'A' and GNRMC_line[3] and GNRMC_line[5]:
                    lat_str = GNRMC_line[3]
                    lon_str = GNRMC_line[5]
                    # Convert latitude: ddmm.mmmm format
                    lat_deg = float(lat_str[:2])
                    lat_min = float(lat_str[2:])
                    latitude = lat_deg + lat_min / 60.0
                    # Convert longitude: dddmm.mmmm format
                    lon_deg = float(lon_str[:3])
                    lon_min = float(lon_str[3:])
                    longitude = lon_deg + lon_min / 60.0
                    
                    # Apply hemisphere indicators
                    if GNRMC_line[4] == 'S':
                        latitude = -latitude
                    if GNRMC_line[6] == 'W':
                        longitude = -longitude
                    
                    print('纬度：' + GNRMC_line[4] + ' ' + str(latitude))
                    print('经度：' + GNRMC_line[6] + ' ' + str(longitude))
                    
                    # Update GPS data for plotting
                    update_gps_data(latitude, longitude)
        except Exception as e:
            if isinstance(e, KeyboardInterrupt):
                break
            print(f"Error reading data: {e}")
            time.sleep(0.1)  # Brief pause before retrying

# Parse command line arguments for map type
map_type = 'google'  # Default to Google Maps
if len(sys.argv) > 1:
    if sys.argv[1].lower() in ['gaode', 'amap', '高德']:
        map_type = 'gaode'
    elif sys.argv[1].lower() in ['google', 'gmaps']:
        map_type = 'google'

# Create initial JSON file
initial_data = {'current': None, 'history': []}
with open(json_file, 'w', encoding='utf-8') as f:
    json.dump(initial_data, f)

# Create HTML file with selected map
print(f"使用地图类型: {'高德地图' if map_type == 'gaode' else 'Google Maps'}")
create_map_html(map_type)

# Start a simple HTTP server to serve the files
def start_http_server():
    os.chdir(os.path.dirname(map_file))
    handler = SimpleHTTPRequestHandler
    httpd = socketserver.TCPServer(("", 8000), handler)
    httpd.serve_forever()

# Start HTTP server in a separate thread
http_thread = threading.Thread(target=start_http_server, daemon=True)
http_thread.start()
time.sleep(1)  # Give server time to start

# Start GPS reading in a separate thread
gps_thread = threading.Thread(target=read_gps_data, daemon=True)
gps_thread.start()

# Open map in browser
try:
    map_url = "http://localhost:8000/gps_map.html"
    print(f"\n正在打开高德地图...")
    print(f"地图地址: {map_url}")
    print(f"如果浏览器没有自动打开，请手动访问: {map_url}")
    webbrowser.open(map_url)
    print("\nGPS数据正在实时更新到地图...")
    print("按 Ctrl+C 停止程序")
    
    # Keep the program running
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    print("\n程序已停止")
finally:
    if ser.is_open:
        ser.close()
        print("串口已关闭")
