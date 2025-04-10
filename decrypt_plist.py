import requests
import json
from Crypto.Cipher import AES
import binascii

# 密钥与iOS应用中相同
key = "5486abfd96080e09e82bb2ab93258bde19d069185366b5aa8d38467835f2e7aa"

# 尝试获取plist内容
plist_path = "/api/plist/0e2d6ae5a3a96251aa2711a887887b3e/de2a15ab096ff856a54fc9b04a560abd7183fe29c5df150decd88769f7993101ccd7039c497d51a60261a01a5cca021cd51dd48af8de4793c8992c78b592554892f1cb6ca8dc13aa87d2b7f8b6481a106f161f8bbe2408bae3e93492d1c0a45812d15f7fa6b3eb9ca1ed0eaefd11739f"
base_url = "https://renmai.cloudmantoub.online"
plist_url = base_url + plist_path

print(f"尝试获取plist: {plist_url}")

try:
    response = requests.get(plist_url)
    if response.status_code == 200:
        print("成功获取plist内容")
        
        # 检查内容是否为加密数据
        try:
            data = response.json()
            if "iv" in data and "data" in data:
                # 处理加密的plist内容
                iv = data["iv"]
                encrypted_data = data["data"]
                
                print(f"发现加密数据，IV: {iv}")
                print(f"加密数据长度: {len(encrypted_data)}")
                
                # 解密plist内容
                key_bytes = binascii.unhexlify(key)
                iv_bytes = binascii.unhexlify(iv)
                encrypted_bytes = binascii.unhexlify(encrypted_data)
                
                cipher = AES.new(key_bytes, AES.MODE_CBC, iv_bytes)
                decrypted = cipher.decrypt(encrypted_bytes)
                
                # 移除PKCS7填充
                padding_length = decrypted[-1]
                decrypted = decrypted[:-padding_length]
                
                # 显示解密结果
                print("\n解密后的plist内容:")
                print(decrypted.decode('utf-8', errors='replace'))
            else:
                # 非加密内容
                print("\n获取到的plist内容(非加密):")
                print(response.text)
        except json.JSONDecodeError:
            # 内容不是JSON格式，可能是直接的plist
            print("\n获取到的plist内容(可能是直接的XML):")
            print(response.text[:500] + "..." if len(response.text) > 500 else response.text)
    else:
        print(f"获取失败，状态码: {response.status_code}")
        print(response.text)
except Exception as e:
    print(f"请求过程中出错: {e}") 