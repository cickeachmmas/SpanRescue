import socket, json, time

# Host: try GO address; change if needed based on adb IP output
HOST = "192.168.49.1"
PORT = 8888

try:
    print(f"Connecting to {HOST}:{PORT}...")
    s = socket.create_connection((HOST, PORT), timeout=10)
    f = s.makefile("rwb")
    msg = {"type":"test","from":"pc","text":"hello from PC"}
    line = (json.dumps(msg) + "\n").encode()
    s.sendall(line)
    print("SENT:", line)
    # حاول قراءة رد لمدة قصيرة
    s.settimeout(5)
    try:
        resp = f.readline()
        print("RECV:", resp)
    except Exception as e:
        print("No response or read timeout:", e)
    s.close()
except Exception as e:
    print("Connection failed:", e)
