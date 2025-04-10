<?php
$data = file_get_contents('php://input');
$plistBegin   = '<?xml version="1.0"';
$plistEnd   = '</plist>';
$pos1 = strpos($data, $plistBegin);
$pos2 = strpos($data, $plistEnd);
$data2 = substr ($data,$pos1,$pos2-$pos1+strlen($plistEnd));

// 记录接收到的原始数据用于调试
file_put_contents('udid_log.txt', $data, FILE_APPEND);

// 尝试使用simplexml_load_string解析XML数据
$xml = simplexml_load_string($data2);

// 如果simplexml解析失败，则使用原始的xml_parser方法
if ($xml === false) {
    $xml = xml_parser_create();
    xml_parse_into_struct($xml, $data2, $vs);
    xml_parser_free($xml);

    $UDID = "";
    $CHALLENGE = "";
    $DEVICE_NAME = "";
    $DEVICE_PRODUCT = "";
    $DEVICE_VERSION = "";
    $iterator = 0;

    $arrayCleaned = array();
    foreach($vs as $v){
        if($v['level'] == 3 && $v['type'] == 'complete'){
            $arrayCleaned[]= $v;
        }
        $iterator++;
    }

    $data = "";
    $iterator = 0;

    foreach($arrayCleaned as $elem){
        $data .= "\n==".$elem['tag']." -> ".$elem['value']."<br/>";

        switch ($elem['value']) {
            case "CHALLENGE":
                $CHALLENGE = $arrayCleaned[$iterator+1]['value'];
                break;
            case "DEVICE_NAME":
                $DEVICE_NAME = $arrayCleaned[$iterator+1]['value'];
                break;
            case "PRODUCT":
                $DEVICE_PRODUCT = $arrayCleaned[$iterator+1]['value'];
                break;
            case "UDID":
                $UDID = $arrayCleaned[$iterator+1]['value'];
                break;
            case "VERSION":
                $DEVICE_VERSION = $arrayCleaned[$iterator+1]['value'];
                break;                       
        }
        $iterator++;
    }
} else {
    // 使用simplexml解析数据
    $UDID = "";
    $CHALLENGE = "";
    $DEVICE_NAME = "";
    $DEVICE_PRODUCT = "";
    $DEVICE_VERSION = "";
    
    // 遍历XML获取设备信息
    foreach ($xml->dict->dict->children() as $key => $value) {
        if ((string)$key == 'key') {
            $currentKey = (string)$value;
        } else {
            switch ($currentKey) {
                case "UDID":
                    $UDID = (string)$value;
                    break;
                case "CHALLENGE":
                    $CHALLENGE = (string)$value;
                    break;
                case "DEVICE_NAME":
                    $DEVICE_NAME = (string)$value;
                    break;
                case "PRODUCT":
                    $DEVICE_PRODUCT = (string)$value;
                    break;
                case "VERSION":
                    $DEVICE_VERSION = (string)$value;
                    break;
            }
        }
    }
}

// 可选：将UDID和设备信息保存到数据库
// saveToDatabase($UDID, $DEVICE_NAME, $DEVICE_PRODUCT, $DEVICE_VERSION);

// 构建回调URL，使用应用的URL Scheme
$callbackUrl = "mantou://udid/".$UDID;

// 生成HTML页面，自动重定向回应用
header('Content-Type: text/html');
echo '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>UDID获取成功</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            text-align: center;
            padding: 20px;
            background-color: #f8f8f8;
        }
        .container {
            max-width: 500px;
            margin: 0 auto;
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
        }
        .udid {
            word-break: break-all;
            background: #f5f5f5;
            padding: 10px;
            border-radius: 5px;
            font-family: monospace;
            margin: 20px 0;
        }
        .button {
            display: inline-block;
            background-color: #007aff;
            color: white;
            padding: 12px 20px;
            text-decoration: none;
            border-radius: 6px;
            font-weight: bold;
            margin-top: 10px;
        }
        .note {
            color: #666;
            font-size: 14px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>UDID获取成功</h1>
        <p>您的设备UDID是：</p>
        <div class="udid">' . $UDID . '</div>
        <p>点击下方按钮返回应用：</p>
        <a href="' . $callbackUrl . '" class="button">返回应用</a>
        <p class="note">如果按钮无效，请手动复制UDID并返回应用</p>
    </div>
    <script>
        // 3秒后自动重定向回应用
        setTimeout(function() {
            window.location.href = "' . $callbackUrl . '";
        }, 3000);
    </script>
</body>
</html>';
?> 