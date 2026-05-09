package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync/atomic"
	"syscall"
	"time"
	"unsafe"
)

type serialPortInfo struct {
	Device       string `json:"device"`
	Name         string `json:"name"`
	Description  string `json:"description"`
	HWID         string `json:"hwid"`
	VID          string `json:"vid"`
	PID          string `json:"pid"`
	SerialNumber string `json:"serial_number"`
	Manufacturer string `json:"manufacturer"`
	Product      string `json:"product"`
	Location     string `json:"location"`
	Interface    string `json:"interface"`
}

type serialConfig struct {
	Port         string
	Baudrate     int
	Timeout      float64
	WriteTimeout float64
	Bytesize     int
	Parity       string
	Stopbits     string
	Xonxoff      bool
	Rtscts       bool
	Dsrdtr       bool
	MaxWaitSec   float64
	LogFile      string
	Send         string
}

func usage() {
	fmt.Println("Usage:")
	fmt.Println("  serial_agent_go scan [--json]")
	fmt.Println("  serial_agent_go io [common options] [--send \"cmd\"]")
	fmt.Println("  serial_agent_go terminal [common options]")
	fmt.Println("  serial_agent_go terminal-raw [common options]")
	fmt.Println("")
	fmt.Println("Common options:")
	fmt.Println("  --port /dev/ttyACM0")
	fmt.Println("  --auto-select")
	fmt.Println("  --vid 1a86 --pid 55d4 --serial-number xxx --product xxx --description xxx")
	fmt.Println("  --baudrate 115200 --timeout 1 --write-timeout 1")
	fmt.Println("  --bytesize 8 --parity N --stopbits 1")
	fmt.Println("  --xonxoff=false --rtscts=false --dsrdtr=false")
	fmt.Println("  --max-wait-sec 3 --log-file /tmp/serial.log")
}

func listSerialPortsDetail() ([]serialPortInfo, error) {
	devs := discoverTTYDevices()
	items := make([]serialPortInfo, 0, len(devs))
	for _, dev := range devs {
		base := filepath.Base(dev)
		sysPath := filepath.Join("/sys/class/tty", base, "device")
		realPath, _ := filepath.EvalSymlinks(sysPath)
		vid := readFirstExisting(
			filepath.Join(realPath, "idVendor"),
			filepath.Join(realPath, "..", "idVendor"),
			filepath.Join(realPath, "..", "..", "idVendor"),
		)
		pid := readFirstExisting(
			filepath.Join(realPath, "idProduct"),
			filepath.Join(realPath, "..", "idProduct"),
			filepath.Join(realPath, "..", "..", "idProduct"),
		)
		sn := readFirstExisting(
			filepath.Join(realPath, "serial"),
			filepath.Join(realPath, "..", "serial"),
			filepath.Join(realPath, "..", "..", "serial"),
		)
		manufacturer := readFirstExisting(
			filepath.Join(realPath, "manufacturer"),
			filepath.Join(realPath, "..", "manufacturer"),
			filepath.Join(realPath, "..", "..", "manufacturer"),
		)
		product := readFirstExisting(
			filepath.Join(realPath, "product"),
			filepath.Join(realPath, "..", "product"),
			filepath.Join(realPath, "..", "..", "product"),
		)
		iface := readFirstExisting(
			filepath.Join(realPath, "interface"),
			filepath.Join(realPath, "..", "interface"),
			filepath.Join(realPath, "..", "..", "interface"),
		)
		desc := product
		if desc == "" {
			desc = manufacturer
		}
		hwid := ""
		if vid != "" || pid != "" {
			hwid = fmt.Sprintf("%s:%s", ensureHexPrefix(strings.ToLower(vid)), ensureHexPrefix(strings.ToLower(pid)))
		}
		item := serialPortInfo{
			Device:       dev,
			Name:         base,
			Description:  desc,
			HWID:         hwid,
			VID:          ensureHexPrefix(strings.ToLower(vid)),
			PID:          ensureHexPrefix(strings.ToLower(pid)),
			SerialNumber: sn,
			Manufacturer: manufacturer,
			Product:      product,
			Location:     filepath.Base(filepath.Dir(realPath)),
			Interface:    iface,
		}
		items = append(items, item)
	}
	sort.Slice(items, func(i, j int) bool {
		return items[i].Device < items[j].Device
	})
	return items, nil
}

func discoverTTYDevices() []string {
	patterns := []string{"/dev/ttyACM*", "/dev/ttyUSB*", "/dev/ttyS*"}
	set := make(map[string]struct{})
	for _, p := range patterns {
		matches, _ := filepath.Glob(p)
		for _, m := range matches {
			set[m] = struct{}{}
		}
	}
	out := make([]string, 0, len(set))
	for k := range set {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

func readFirstExisting(paths ...string) string {
	for _, p := range paths {
		if p == "" {
			continue
		}
		b, err := os.ReadFile(p)
		if err == nil {
			return strings.TrimSpace(string(b))
		}
	}
	return ""
}

func ensureHexPrefix(v string) string {
	if v == "" {
		return ""
	}
	if strings.HasPrefix(v, "0x") {
		return v
	}
	return "0x" + v
}

func normalizeHex(v string) string {
	v = strings.TrimSpace(strings.ToLower(v))
	if v == "" {
		return ""
	}
	return ensureHexPrefix(v)
}

func autoSelectSerialPort(vid, pid, serialNumber, product, description string) (string, error) {
	ports, err := listSerialPortsDetail()
	if err != nil {
		return "", err
	}
	if len(ports) == 0 {
		return "", errors.New("未发现串口设备")
	}

	vidN := normalizeHex(vid)
	pidN := normalizeHex(pid)
	snN := strings.ToLower(strings.TrimSpace(serialNumber))
	productN := strings.ToLower(strings.TrimSpace(product))
	descN := strings.ToLower(strings.TrimSpace(description))
	hasFilter := vidN != "" || pidN != "" || snN != "" || productN != "" || descN != ""

	candidates := ports
	if snN != "" {
		filtered := make([]serialPortInfo, 0)
		for _, p := range candidates {
			if strings.ToLower(strings.TrimSpace(p.SerialNumber)) == snN {
				filtered = append(filtered, p)
			}
		}
		candidates = filtered
	}
	if vidN != "" {
		filtered := make([]serialPortInfo, 0)
		for _, p := range candidates {
			if strings.ToLower(strings.TrimSpace(p.VID)) == vidN {
				filtered = append(filtered, p)
			}
		}
		candidates = filtered
	}
	if pidN != "" {
		filtered := make([]serialPortInfo, 0)
		for _, p := range candidates {
			if strings.ToLower(strings.TrimSpace(p.PID)) == pidN {
				filtered = append(filtered, p)
			}
		}
		candidates = filtered
	}
	if productN != "" {
		filtered := make([]serialPortInfo, 0)
		for _, p := range candidates {
			if strings.Contains(strings.ToLower(p.Product), productN) {
				filtered = append(filtered, p)
			}
		}
		candidates = filtered
	}
	if descN != "" {
		filtered := make([]serialPortInfo, 0)
		for _, p := range candidates {
			if strings.Contains(strings.ToLower(p.Description), descN) {
				filtered = append(filtered, p)
			}
		}
		candidates = filtered
	}

	if hasFilter && len(candidates) == 0 {
		return "", errors.New("自动选口失败：未找到匹配 vid/pid/sn/product/description 的设备")
	}
	if len(candidates) == 0 {
		candidates = ports
	}

	sort.Slice(candidates, func(i, j int) bool {
		a := candidates[i].Device
		b := candidates[j].Device
		return portPriority(a) < portPriority(b) || (portPriority(a) == portPriority(b) && a < b)
	})
	return candidates[0].Device, nil
}

func portPriority(dev string) int {
	switch {
	case strings.HasPrefix(dev, "/dev/ttyACM"):
		return 0
	case strings.HasPrefix(dev, "/dev/ttyUSB"):
		return 1
	default:
		return 2
	}
}

func parityFromText(v string) (int, error) {
	switch strings.ToUpper(strings.TrimSpace(v)) {
	case "N":
		return 0, nil
	case "E":
		return 1, nil
	case "O":
		return 2, nil
	default:
		return 0, fmt.Errorf("unsupported parity: %s, expected N/E/O", v)
	}
}

func stopBitsFromText(v string) (int, error) {
	switch strings.TrimSpace(v) {
	case "1":
		return 1, nil
	case "1.5":
		return 15, nil
	case "2":
		return 2, nil
	default:
		return 1, fmt.Errorf("unsupported stopbits: %s, expected 1/1.5/2", v)
	}
}

func baudFlag(v int) (uint32, error) {
	switch v {
	case 9600:
		return syscall.B9600, nil
	case 19200:
		return syscall.B19200, nil
	case 38400:
		return syscall.B38400, nil
	case 57600:
		return syscall.B57600, nil
	case 115200:
		return syscall.B115200, nil
	case 230400:
		return syscall.B230400, nil
	default:
		return 0, fmt.Errorf("unsupported baudrate: %d (支持: 9600/19200/38400/57600/115200/230400)", v)
	}
}

func openPort(cfg *serialConfig) (*os.File, error) {
	parityMode, err := parityFromText(cfg.Parity)
	if err != nil {
		return nil, err
	}
	stopBitsMode, err := stopBitsFromText(cfg.Stopbits)
	if err != nil {
		return nil, err
	}
	baud, err := baudFlag(cfg.Baudrate)
	if err != nil {
		return nil, err
	}

	fd, err := syscall.Open(cfg.Port, syscall.O_RDWR|syscall.O_NOCTTY|syscall.O_NONBLOCK, 0)
	if err != nil {
		return nil, err
	}
	if err := syscall.SetNonblock(fd, false); err != nil {
		_ = syscall.Close(fd)
		return nil, err
	}
	if err := configureSerial(fd, baud, cfg.Bytesize, parityMode, stopBitsMode, cfg.Timeout, cfg.Xonxoff, cfg.Rtscts); err != nil {
		_ = syscall.Close(fd)
		return nil, err
	}
	if cfg.Dsrdtr {
		fmt.Fprintln(os.Stderr, "[warn] 当前 Go 标准库实现不支持 dsrdtr，参数将被忽略")
	}
	return os.NewFile(uintptr(fd), cfg.Port), nil
}

func configureSerial(fd int, baud uint32, bytesize int, parityMode int, stopBitsMode int, timeoutSec float64, xonxoff bool, rtscts bool) error {
	t, err := tcget(fd)
	if err != nil {
		return err
	}
	t.Iflag = 0
	t.Oflag = 0
	t.Lflag = 0
	t.Cflag = syscall.CLOCAL | syscall.CREAD
	t.Cflag &^= syscall.CSIZE
	switch bytesize {
	case 5:
		t.Cflag |= syscall.CS5
	case 6:
		t.Cflag |= syscall.CS6
	case 7:
		t.Cflag |= syscall.CS7
	default:
		t.Cflag |= syscall.CS8
	}
	t.Cflag &^= syscall.PARENB
	t.Cflag &^= syscall.PARODD
	if parityMode == 1 {
		t.Cflag |= syscall.PARENB
	} else if parityMode == 2 {
		t.Cflag |= syscall.PARENB
		t.Cflag |= syscall.PARODD
	}
	t.Cflag &^= syscall.CSTOPB
	if stopBitsMode == 2 {
		t.Cflag |= syscall.CSTOPB
	}
	// 1.5 stopbits is not universally supported by Linux termios for UART; fallback to 2.
	if stopBitsMode == 15 {
		t.Cflag |= syscall.CSTOPB
	}

	if xonxoff {
		t.Iflag |= syscall.IXON | syscall.IXOFF
	}
	if rtscts {
		// Linux-specific hardware flow control bit.
		const CRTSCTS = 0x80000000
		t.Cflag |= CRTSCTS
	}

	t.Cflag |= baud
	t.Ispeed = baud
	t.Ospeed = baud

	vtime := uint8(timeoutSec * 10.0)
	if vtime == 0 {
		vtime = 1
	}
	t.Cc[syscall.VMIN] = 0
	t.Cc[syscall.VTIME] = vtime

	return tcset(fd, t)
}

func tcget(fd int) (*syscall.Termios, error) {
	var t syscall.Termios
	_, _, errno := syscall.Syscall(syscall.SYS_IOCTL, uintptr(fd), uintptr(syscall.TCGETS), uintptr(unsafe.Pointer(&t)))
	if errno != 0 {
		return nil, errno
	}
	return &t, nil
}

func tcset(fd int, t *syscall.Termios) error {
	_, _, errno := syscall.Syscall(syscall.SYS_IOCTL, uintptr(fd), uintptr(syscall.TCSETS), uintptr(unsafe.Pointer(t)))
	if errno != 0 {
		return errno
	}
	return nil
}

func stdinIsTTY() bool {
	_, err := tcget(int(os.Stdin.Fd()))
	return err == nil
}

func makeStdinRaw(fd int) (*syscall.Termios, error) {
	orig, err := tcget(fd)
	if err != nil {
		return nil, err
	}
	raw := *orig
	raw.Iflag &^= syscall.IGNBRK | syscall.BRKINT | syscall.PARMRK | syscall.ISTRIP | syscall.INLCR | syscall.IGNCR | syscall.ICRNL | syscall.IXON
	raw.Oflag &^= syscall.OPOST
	raw.Lflag &^= syscall.ECHO | syscall.ECHONL | syscall.ICANON | syscall.ISIG | syscall.IEXTEN
	raw.Cflag &^= syscall.CSIZE | syscall.PARENB
	raw.Cflag |= syscall.CS8
	raw.Cc[syscall.VMIN] = 1
	raw.Cc[syscall.VTIME] = 0
	if err := tcset(fd, &raw); err != nil {
		return nil, err
	}
	return orig, nil
}

func appendLog(path, direction string, payload []byte) {
	if path == "" || len(payload) == 0 {
		return
	}
	ts := time.Now().Format("2006-01-02 15:04:05.000")
	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer f.Close()
	_, _ = f.WriteString(fmt.Sprintf("[%s] [%s] %s", ts, direction, string(payload)))
}

func readUntilQuiet(port *os.File, quietSec, maxSec float64) []byte {
	deadline := time.Now().Add(time.Duration(maxSec * float64(time.Second)))
	lastData := time.Now()
	buf := make([]byte, 0, 4096)
	tmp := make([]byte, 1024)

	for time.Now().Before(deadline) {
		n, err := port.Read(tmp)
		if n > 0 {
			buf = append(buf, tmp[:n]...)
			lastData = time.Now()
			continue
		}
		if err != nil && !errors.Is(err, io.EOF) {
			break
		}
		if time.Since(lastData) >= time.Duration(quietSec*float64(time.Second)) {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	return buf
}

func cmdScan(args []string) int {
	fs := flag.NewFlagSet("scan", flag.ContinueOnError)
	asJSON := fs.Bool("json", false, "以 JSON 输出")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	items, err := listSerialPortsDetail()
	if err != nil {
		fmt.Fprintf(os.Stderr, "[error] %v\n", err)
		return 2
	}
	if *asJSON {
		enc := json.NewEncoder(os.Stdout)
		enc.SetEscapeHTML(false)
		enc.SetIndent("", "  ")
		_ = enc.Encode(items)
		return 0
	}
	if len(items) == 0 {
		fmt.Println("未发现串口设备")
		return 0
	}
	for _, item := range items {
		fmt.Printf(
			"%s | desc=%s | vid=%s | pid=%s | sn=%s\n",
			item.Device, item.Description, item.VID, item.PID, item.SerialNumber,
		)
	}
	return 0
}

func bindCommonFlags(fs *flag.FlagSet, cfg *serialConfig) (autoSelect *bool, vid, pid, sn, product, desc *string) {
	fs.StringVar(&cfg.Port, "port", "", "设备节点，例如 /dev/ttyACM0")
	autoSelect = fs.Bool("auto-select", false, "自动选择串口")
	vid = fs.String("vid", "", "匹配 VID")
	pid = fs.String("pid", "", "匹配 PID")
	sn = fs.String("serial-number", "", "匹配序列号")
	product = fs.String("product", "", "匹配产品名关键字")
	desc = fs.String("description", "", "匹配描述关键字")
	fs.IntVar(&cfg.Baudrate, "baudrate", 115200, "波特率")
	fs.Float64Var(&cfg.Timeout, "timeout", 1.0, "读超时(秒)")
	fs.Float64Var(&cfg.WriteTimeout, "write-timeout", 1.0, "写超时(秒)")
	fs.IntVar(&cfg.Bytesize, "bytesize", 8, "数据位(5/6/7/8)")
	fs.StringVar(&cfg.Parity, "parity", "N", "校验位(N/E/O)")
	fs.StringVar(&cfg.Stopbits, "stopbits", "1", "停止位(1/1.5/2)")
	fs.BoolVar(&cfg.Xonxoff, "xonxoff", false, "软件流控")
	fs.BoolVar(&cfg.Rtscts, "rtscts", false, "RTS/CTS 流控")
	fs.BoolVar(&cfg.Dsrdtr, "dsrdtr", false, "DSR/DTR 流控")
	fs.Float64Var(&cfg.MaxWaitSec, "max-wait-sec", 3.0, "输出等待时间")
	fs.StringVar(&cfg.LogFile, "log-file", "", "可选，串口日志文件路径")
	return
}

func resolvePort(cfg *serialConfig, autoSelect bool, vid, pid, sn, product, desc string) error {
	if cfg.Port != "" {
		return nil
	}
	if autoSelect || vid != "" || pid != "" || sn != "" || product != "" || desc != "" {
		p, err := autoSelectSerialPort(vid, pid, sn, product, desc)
		if err != nil {
			return err
		}
		cfg.Port = p
		return nil
	}
	return errors.New("请指定 --port，或使用 --auto-select/--vid/--pid/--serial-number")
}

func cmdIO(args []string) int {
	var cfg serialConfig
	fs := flag.NewFlagSet("io", flag.ContinueOnError)
	autoSelect, vid, pid, sn, product, desc := bindCommonFlags(fs, &cfg)
	send := fs.String("send", "", "一次性发送并读取输出")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	cfg.Send = *send
	if err := resolvePort(&cfg, *autoSelect, *vid, *pid, *sn, *product, *desc); err != nil {
		fmt.Fprintf(os.Stderr, "[error] %v\n", err)
		return 2
	}

	port, err := openPort(&cfg)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[error] %v\n", err)
		return 2
	}
	defer port.Close()

	fmt.Printf("[serial] connected: %s@%d\n", cfg.Port, cfg.Baudrate)
	if cfg.Send != "" {
		payload := []byte(cfg.Send + "\n")
		_, _ = port.Write(payload)
		appendLog(cfg.LogFile, "TX", payload)
	}
	out := readUntilQuiet(port, 0.3, cfg.MaxWaitSec)
	appendLog(cfg.LogFile, "RX", out)
	if len(out) == 0 {
		fmt.Println("(无输出)")
	} else {
		fmt.Print(string(out))
	}
	return 0
}

func runRawTerminal(cfg *serialConfig, tag string) int {
	if !stdinIsTTY() {
		fmt.Fprintf(os.Stderr, "[error] %s 需要在交互式 TTY 终端中运行\n", tag)
		return 2
	}

	port, err := openPort(cfg)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[error] %v\n", err)
		return 2
	}
	defer port.Close()

	fmt.Printf("[%s] connected: %s@%d, bytesize=%d, parity=%s, stopbits=%s, xonxoff=%v, rtscts=%v, dsrdtr=%v\n",
		tag, cfg.Port, cfg.Baudrate, cfg.Bytesize, cfg.Parity, cfg.Stopbits, cfg.Xonxoff, cfg.Rtscts, cfg.Dsrdtr)
	fmt.Printf("[%s] 长连接透传已开启（支持 Tab 补齐），按 Ctrl+] 退出。\n", tag)

	oldState, err := makeStdinRaw(int(os.Stdin.Fd()))
	if err != nil {
		fmt.Fprintf(os.Stderr, "[error] failed to enter raw mode: %v\n", err)
		return 2
	}
	defer func() {
		_ = tcset(int(os.Stdin.Fd()), oldState)
		fmt.Printf("\n[%s] disconnected\n", tag)
	}()

	var stop int32
	done := make(chan struct{})

	go func() {
		defer close(done)
		buf := make([]byte, 2048)
		for atomic.LoadInt32(&stop) == 0 {
			n, err := port.Read(buf)
			if n > 0 {
				chunk := append([]byte(nil), buf[:n]...)
				_, _ = os.Stdout.Write(chunk)
				appendLog(cfg.LogFile, "RX", chunk)
			}
			if err != nil && !errors.Is(err, io.EOF) {
				time.Sleep(20 * time.Millisecond)
			}
		}
	}()

	in := make([]byte, 1024)
	for {
		n, err := os.Stdin.Read(in)
		if n > 0 {
			data := append([]byte(nil), in[:n]...)
			if idx := bytes.IndexByte(data, 0x1d); idx >= 0 { // Ctrl+]
				head := data[:idx]
				if len(head) > 0 {
					_, _ = port.Write(head)
					appendLog(cfg.LogFile, "TX", head)
				}
				atomic.StoreInt32(&stop, 1)
				break
			}
			_, _ = port.Write(data)
			appendLog(cfg.LogFile, "TX", data)
		}
		if err != nil {
			atomic.StoreInt32(&stop, 1)
			break
		}
	}

	<-done
	return 0
}

func cmdTerminal(args []string, rawName string) int {
	var cfg serialConfig
	fs := flag.NewFlagSet(rawName, flag.ContinueOnError)
	autoSelect, vid, pid, sn, product, desc := bindCommonFlags(fs, &cfg)
	if err := fs.Parse(args); err != nil {
		return 2
	}
	if err := resolvePort(&cfg, *autoSelect, *vid, *pid, *sn, *product, *desc); err != nil {
		fmt.Fprintf(os.Stderr, "[error] %v\n", err)
		return 2
	}
	return runRawTerminal(&cfg, rawName)
}

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}

	var code int
	switch os.Args[1] {
	case "scan":
		code = cmdScan(os.Args[2:])
	case "io":
		code = cmdIO(os.Args[2:])
	case "terminal":
		code = cmdTerminal(os.Args[2:], "serial")
	case "terminal-raw":
		code = cmdTerminal(os.Args[2:], "serial-raw")
	case "-h", "--help", "help":
		usage()
		code = 0
	default:
		fmt.Fprintf(os.Stderr, "[error] unknown subcommand: %s\n\n", os.Args[1])
		usage()
		code = 2
	}
	os.Exit(code)
}
