# Serial AI Agent 套件

面向 Linux 串口设备的 AI Agent 工具集，基于 `PySerial + LangChain/CrewAI`，并提供 `pexpect` 交互能力。

## 目录说明

- `serial_core.py`: 串口底层读写会话（打开/关闭/发送命令/读取输出）
- `serial_pexpect.py`: 交互式串口终端封装（依赖 `picocom` + `pexpect`）
- `serial_agent/`: 串口高层工作流
- `serial_agent/discovery.py`: 串口选口与 USB 串口过滤
- `serial_agent/login_check.py`: Linux 登录和命令校验
- `serial_agent/uboot.py`: U-Boot 串口打断、重启与升级入口控制
- `serial_agent_cli.py`: 上层统一串口抽象接口
- `langchain_tools.py`: LangChain `StructuredTool` 封装
- `crewai_tools.py`: CrewAI `Tool` 封装
- `trae_serial_terminal.py`: 面向 Trae AI 终端的串口 CLI（扫描/参数化连接/输入输出）
- `example_langchain_agent.py`: LangChain Agent 示例
- `example_crewai_agent.py`: CrewAI Agent 示例
- `example_bt_wifi_provision.py`: 串口一键执行 WiFi 配网 + 蓝牙配对示例

## 安装依赖

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47/linux_serial_agent
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## 基础用法（直接调用）

```python
from serial_core import SerialSession, make_serial_config

cfg = make_serial_config(
    port="/dev/ttyACM0",
    baudrate=115200,
    bytesize="8",
    parity="N",
    stopbits="1",
    xonxoff=False,
    rtscts=False,
    dsrdtr=False,
)
sess = SerialSession(cfg)
sess.open()
print(sess.run_command("uname -a"))
sess.close()
```

## 统一串口接口

```bash
python3 linux_serial_agent/serial_agent_cli.py login-check --cmd "uname -a"
python3 linux_serial_agent/serial_agent_cli.py enter-fastboot --port /dev/ttyACM0
python3 linux_serial_agent/serial_agent_cli.py enter-usb-sdp --port /dev/ttyACM0
python3 linux_serial_agent/serial_agent_cli.py uboot-command --port /dev/ttyACM0 --command "printenv bootcmd"
```

说明：
- `serial_agent_cli.py` 是上层编排层唯一需要依赖的串口接口。
- 该接口只处理串口发现、串口登录与 U-Boot 串口控制，不调用 USB 烧录能力。
- 自动选口默认只优先挑选 `ttyUSB*` / `ttyACM*` 这类外接 USB 串口。
- 若当前环境只有宿主机自带 `ttyS*`，通常说明 USB 转串口尚未透传到这台 Linux 主机/虚拟机。

## Trae 终端一键调用

扫描串口：

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47/linux_serial_agent
python3 trae_serial_terminal.py scan
```

带参数打开并发送一次命令：

```bash
python3 trae_serial_terminal.py io \
  --auto-select --vid 1a86 --pid 55d4 \
  --baudrate 115200 \
  --bytesize 8 \
  --parity N \
  --stopbits 1 \
  --xonxoff false \
  --rtscts false \
  --dsrdtr false \
  --send "help"
```

进入交互模式（连续输入输出，默认透传，支持 Tab 补齐）：

```bash
python3 trae_serial_terminal.py terminal --auto-select --vid 1a86 --pid 55d4 --baudrate 115200
```

纯透传模式（字符级，不等回车，行为更接近 putty）：

```bash
python3 trae_serial_terminal.py terminal-raw --auto-select --vid 1a86 --pid 55d4 --baudrate 115200
```

纯透传并落盘日志（收发双向）：

```bash
python3 trae_serial_terminal.py terminal-raw \
  --auto-select --vid 1a86 --pid 55d4 \
  --baudrate 115200 \
  --log-file /tmp/serial_openix.log
```

说明：
- `terminal` 与 `terminal-raw` 都是长连接透传模式，串口输出会持续实时显示（类似 putty）。
- 按键会实时发送到串口，`Tab` 会直接送到设备端用于命令补齐。
- 两个模式都仅支持 `Ctrl+]` 本地退出，不再使用 `:quit`，可避免误退出终端。
- 透传模式下 `Ctrl+C/Backspace` 不由本地终端拦截，行为更接近原生串口终端。
- `--log-file` 仅在 `terminal-raw` 模式下记录串口收发日志（`[RX]/[TX]`）。
- `scan --json` 可输出结构化 JSON，便于 AI 终端解析。
- 自动选口优先顺序：`sn -> vid/pid -> product/description -> ttyACM/ttyUSB`。
- 指定 `vid/pid/sn/product/description` 但未命中时会直接报错，不会回退到无关串口。

## Go 版本（新增）

目录内新增 Go 实现：
- `main.go`: Go 版本串口 CLI（`scan/io/terminal/terminal-raw`）
- `go.mod`: Go 依赖定义

编译：

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47/linux_serial_agent
go mod tidy
go build -o trae_serial_terminal_go main.go
```

示例：

```bash
./trae_serial_terminal_go scan --json
./trae_serial_terminal_go terminal --auto-select --vid 1a86 --pid 55d4 --baudrate 115200
```

说明：
- Go 版本同样是长连接透传，支持 `Tab` 直通补齐。
- `terminal` 与 `terminal-raw` 都仅通过 `Ctrl+]` 退出。
- 当前 Go 串口库不支持 `xonxoff/rtscts/dsrdtr`，传参会提示并忽略。

## LangChain 用法

```bash
export OPENAI_API_KEY=your_key
python3 example_langchain_agent.py
```

## CrewAI 用法

```bash
export OPENAI_API_KEY=your_key
python3 example_crewai_agent.py
```

## 交互场景（登录、密码、确认框）

```python
from serial_pexpect import PexpectSerialTerminal

t = PexpectSerialTerminal("/dev/ttyUSB0", 115200)
t.open()
t.login("root", "123456")
print(t.run("dmesg | tail -n 20"))
t.close()
```

## 注意事项

- 运行用户需要串口权限（通常加入 `dialout` 组）。
- `serial_pexpect.py` 依赖系统安装 `picocom`。
- 默认串口参数是 `115200 8N1`，并支持 `xonxoff/rtscts/dsrdtr` 流控配置。
