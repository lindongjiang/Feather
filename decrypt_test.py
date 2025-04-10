from Crypto.Cipher import AES
import binascii
import json
import sys

# 密钥与iOS应用中相同
key = "5486abfd96080e09e82bb2ab93258bde19d069185366b5aa8d38467835f2e7aa"
iv = "3c861af635f10076e6cecd2d95cf61a8"
encrypted_data = "b6ea1554bb81ea3c014368d7bedc2659e8e663a45bb8c91c2a61886220c67062b85390cc7efbd6faf3195225fd7d3c9cdbc4cbfd011b47582385e8650b4f794bab9ec8b2d6f865438604dfbe6012d6debc382a15a47eb8347c8b2ddc8b007a6ca38389002009c3d57029a58aeb3ecc0d0841afd362fbc0a7920c6e1020f85837ce8e4cd3aa71691f08d78fa0806e0a237277b90cd76081dd8d4baf2d29b6427eb1b2f4848ef9da81d978d64fa97b0ab4b006b7675ef829a37f453b2fd792b3cd2554733e52dd9f56bf6ff374a111b4921d37f0bfddcc0937e4a4eb532274004304ab42629bc5e3a5b919a62c7c7d551ea326c169ed6abe7212078fac9405f3ed81cb068199652fc54d9ef0a689e3d71a5e1f6736ef8a406a64dcff7e07cffecf4c97ed315c3e30c823212b70304705095a3838c8e6aba98b5c2fe2e301a3acd2287c801035e0ded0c147244536b3bc2482c818083c860307dbbaad076697360ea9d20aba516a6b3aa0613ed55451839df37f7f7ac0504f0e5f1efd691074d6d32b94d47d943e37b8ee4b2968e9403051a33a3406b6683a0b48bbcb2e9d00caccf6b83c435996bce906ae9515ca980032ccf332feaecf49fbfaa9e39ed677990de9a382ef875ab2a3d79ed748447f25c139ef5ae5cfe54033fdb48e833ccd4d309016dbb90014c4bca5003fc380b2d768874e1545bc5e7aac15a8ae2b497984edc966219368c5290bf6cdee91d0948273d4a726d819fc2e6588c872ac5de757e0af2bd8c90f5284d98242e6b5af980e76761abb5e97b24f14eea33840c6e670f6113f4376ceb6852bac902fdfc662dc7501a0969a4d13fa1dc535334d6b6d00a51eb7b3295558f946a12329108244a161fd03ab1b5d42a2f2e71da607a758c9853e2061dd3077565fee2deb5a4d809525f2000ae1f62835cc2e289792b1a3136e43894365da8adba212dcf38afceb801960111bde92507c6d3aa74a1d9ca361eee50eee51307fcfc7e15ab7143155fd87ee0ee78d2d1ed86fc25bbff9d01bbd6820b0dbd950d8d713b71a4091bf087eeadf41eb3817fe320c6638f6a8c000eec08bc827d4116795ea7c66eb56aaa267f4925f8c68b85afb503b562559a12f47381f4792f72ade9ff44e7b4c6504027de9d5ef3fecdfba26166593ea6f45161b016f3d1d026b694528a13a904cdc9b5b5323eb890e8054ce1703d4f8927a445685c290568560073d2b57648d730df83c8364e82bff93fdf66652a409e569430fc85c32d0d2f9d05572984d0b88a2058e6e42b86ba6f5501cd5298b8b4eabe84eb36ac79b3184240da29838d68a355a28968221968051ebd23e0c4a34ca529d9c407313bc5a37a576c95ac9695858284dbd9059dc20d8289939a808ee9efb023170"

try:
    # 将十六进制字符串转换为字节
    key_bytes = binascii.unhexlify(key)
    iv_bytes = binascii.unhexlify(iv)
    
    # 去除数据中的换行符
    encrypted_data = encrypted_data.replace("\n", "")
    encrypted_bytes = binascii.unhexlify(encrypted_data)

    # 创建AES解密器
    cipher = AES.new(key_bytes, AES.MODE_CBC, iv_bytes)

    # 解密数据
    decrypted = cipher.decrypt(encrypted_bytes)

    # 移除PKCS7填充
    padding_length = decrypted[-1]
    decrypted = decrypted[:-padding_length]

    # 尝试将解密后的数据解析为JSON
    try:
        json_data = json.loads(decrypted.decode('utf-8'))
        print("解密后的JSON数据:")
        print(json.dumps(json_data, indent=2, ensure_ascii=False))
    except json.JSONDecodeError:
        print("解密后的数据无法解析为JSON:")
        print(decrypted.decode('utf-8', errors='replace'))

except Exception as e:
    print(f"解密失败: {e}") 