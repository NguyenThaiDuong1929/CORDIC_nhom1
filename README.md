# Adaptive CORDIC Processor & Verification Environment

Dự án này hiện thực một bộ xử lý CORDIC 16-bit thích ứng hiệu năng cao bằng ngôn ngữ Verilog (RTL) cùng với mô hình mô phỏng, kiểm thử tự động và giao diện trực quan hóa bằng Python. 

Thiết kế này tối ưu hóa công suất động tiêu thụ (Dynamic Power) bằng cách tự động điều chỉnh số lượng vòng lặp (Adaptive Iteration Depth) dựa trên sơ đồ điều chế (Modulation Scheme) và tỷ lệ tín hiệu trên nhiễu (SNR) của hệ thống OFDM, kết hợp với kỹ thuật **Clock Gating** trên đường ống (Pipeline). Ngoài ra, hệ thống tích hợp bộ phân xử **Round-Robin Arbiter** hỗ trợ 2 cổng yêu cầu đồng thời từ các bộ FFT/IFFT.

---

## 📂 Cấu trúc thư mục dự án

```text
CORDIC/
├── CORDIC/                         # Thư mục chứa mã nguồn RTL và mô phỏng phần cứng
│   ├── rtl/                        # Mã nguồn Verilog (DUT)
│   │   ├── top.v                   # Module bao bọc ngoài cùng (Top Wrapper)
│   │   ├── arbiter.v               # Bộ phân xử Round-Robin cho 2 requesters
│   │   ├── controller.v            # Bộ điều khiển quyết định số vòng lặp dựa trên Mod & SNR
│   │   ├── datapath.v              # Lõi tính toán CORDIC 16 tầng với Clock Gating
│   │   └── memory.v                # Bảng LUT Arctangent fixed-point
│   ├── tb/                         # Các file Testbench Verilog
│   │   ├── tb_Top.v                # Testbench kiểm tra tích hợp toàn hệ thống
│   │   ├── tb_TestVectors.v        # Testbench tự động kiểm tra với 10k vector từ Python
│   │   ├── tb_VerifySpecific.v     # Testbench kiểm tra các case biên cụ thể
│   │   └── test_bench.v            # Testbench cơ bản
│   ├── sim/                        # Cấu hình mô phỏng (Makefile, file lists)
│   │   ├── Makefile                # Makefile chạy mô phỏng nhanh bằng ModelSim/Questa
│   │   ├── compile.f               # File list tổng hợp để biên dịch
│   │   ├── rtl.f                   # Danh sách file nguồn RTL
│   │   └── tb.f                    # Danh sách file nguồn Testbench
│   └── cordic.xpr                  # Project file của Xilinx Vivado
├── python simulation/              # Mô phỏng toán học và sinh dữ liệu kiểm thử bằng Python
│   ├── cordic_model.py             # Mô hình CORDIC fixed-point 16-bit (Bit-true model)
│   ├── test_vector_gen.py          # Script sinh tự động 10,000 vector kiểm thử (.txt)
│   ├── verify_example.py           # Script kiểm chứng nhanh một số case cụ thể
│   ├── gui_app.py                  # Giao diện trực quan hóa đường hội tụ CORDIC (Tkinter)
│   ├── requirements.txt            # Thư viện Python cần thiết
│   └── test_vectors.txt            # File dữ liệu vector đầu vào/ra mẫu
└── các file ngoài/                 # Tài liệu hướng dẫn thiết kế & file lưu vết mô phỏng
    ├── RTL_Refinement_Notes.md     # Ghi chú lý thuyết thuật toán, pinout kit FPGA và clock gating
    └── IDEA and TASK_CORDIC(1).md  # Ý tưởng thiết kế và danh sách các Task của dự án
```

---

## ⚙️ 1. Hướng dẫn cài đặt & Chạy mô phỏng Python

Phần Python cung cấp mô hình toán học dấu phẩy tĩnh (Fixed-Point Bit-True Model) để làm chuẩn (Golden Model) đối chiếu với phần cứng RTL, sinh vector kiểm thử tự động và giao diện đồ họa tương tác trực quan.

### Bước 1.1: Tạo môi trường ảo và cài đặt thư viện
Mở terminal tại thư mục gốc của dự án và chạy các lệnh sau:

```bash
# Tạo môi trường ảo Python (nếu chưa có)
python -m venv .venv

# Kích hoạt môi trường ảo (Windows)
.venv\Scripts\activate

# Cài đặt các thư viện cần thiết
pip install -r "python simulation/requirements.txt"
```

### Bước 1.2: Chạy ứng dụng giao diện trực quan (GUI App)
Ứng dụng GUI cho phép bạn nhập góc pha, chọn chuẩn điều chế (BPSK, QPSK, 16QAM, ...) và điều chỉnh SNR để quan sát số vòng lặp thay đổi trực quan, xem đồ thị đường hội tụ CORDIC qua từng stage và bấm nút sinh 10,000 vector kiểm thử.

```bash
python "python simulation/gui_app.py"
```

### Bước 1.3: Sinh file Test Vectors thủ công
Nếu bạn muốn tự động tạo mới file dữ liệu vector kiểm thử (`test_vectors.txt` chứa 10,000 mẫu ngẫu nhiên đầu vào và đầu ra mong muốn tương ứng để nạp vào Verilog):

```bash
python "python simulation/test_vector_gen.py" "python simulation/test_vectors.txt"
```

### Bước 1.4: Kiểm tra nhanh mô hình Python
Chạy script verify để kiểm chứng mô hình Python hoạt động chính xác theo các case biên:

```bash
python "python simulation/verify_example.py"
```

---

## 🛠️ 2. Hướng dẫn chạy mô phỏng RTL (ModelSim / QuestaSim / Vivado)

Dự án hỗ trợ chạy mô phỏng thông qua hai cách: Sử dụng Command Line (Makefile với ModelSim/QuestaSim) hoặc mở trực tiếp trên Xilinx Vivado.

### Cách 1: Sử dụng Command Line (Makefile)
Truy cập vào thư mục `CORDIC/sim/` trong terminal và sử dụng các lệnh `make`:

```bash
# Di chuyển đến thư mục mô phỏng
cd CORDIC/sim

# 1. Dọn dẹp các file rác cũ
make clean

# 2. Biên dịch (Build) toàn bộ thiết kế RTL & Testbench
make build

# 3. Chạy mô phỏng mặc định (sử dụng tb_Top để test hoạt động tích hợp)
make run TB_NAME=tb_Top

# 4. Chạy mô phỏng kiểm tra Vector lớn tự động (tb_TestVectors đọc test_vectors.txt)
make run TB_NAME=tb_TestVectors

# 5. Chạy mô phỏng kiểm tra các góc biên và trường hợp cụ thể (tb_VerifySpecific)
make run TB_NAME=tb_VerifySpecific

# 6. Mở công cụ hiển thị sóng dạng sóng (Waveform) trên giao diện GUI
make wave TB_NAME=tb_Top
```

*Ghi chú:* Bạn có thể gộp cả biên dịch và chạy bằng lệnh: `make all TB_NAME=tb_TestVectors`.

### Cách 2: Sử dụng Xilinx Vivado GUI
1. Mở phần mềm **Vivado** (khuyên dùng phiên bản 2022.1 hoặc 2022.2).
2. Chọn **Open Project** và tìm đến file `CORDIC/cordic.xpr`.
3. Trong cửa sổ **Sources**, bạn sẽ nhìn thấy cấu trúc phân cấp thiết kế:
   - **Design Sources**: Khối `cordic_top` chứa `cordic_controller`, `cordic_datapath`, `cordic_arbiter`, và `cordic_memory`.
   - **Simulation Sources**: Chứa các testbench (`tb_Top`, `tb_TestVectors`, `tb_VerifySpecific`).
4. Chuột phải vào testbench mong muốn (ví dụ `tb_TestVectors`) -> Chọn **Set as Top**.
5. Click **Run Simulation** -> **Run Behavioral Simulation** để chạy mô phỏng và xem dạng sóng trực quan.

---

## 📐 3. Lý thuyết & Nguyên lý Hoạt động của Hệ thống


1. **Bộ điều khiển thích ứng (Adaptive Controller)**: 
   - Dựa trên chuẩn điều chế (từ BPSK đến 256-QAM) và mức SNR ước lượng, module `controller.v` sẽ chọn số vòng lặp tối ưu cần thiết (từ 4 đến 16 vòng lặp). Góc điều chế phức tạp cần độ chính xác cao hơn thì số vòng lặp nhiều hơn.
2. **Clock Gating cho Pipeline**: 
   - Thay vì chạy đủ 16 vòng lặp cho mọi trường hợp gây lãng phí năng lượng, tại các stage nằm ngoài khoảng yêu cầu (`stage >= o_req_iters`), tín hiệu kích hoạt thanh ghi bị ngắt hoàn toàn. Trạng thái các thanh ghi được giữ tĩnh tuyệt đối, triệt tiêu Dynamic Power.
3. **Mạch Quadrant Mapping**: 
   - Giúp mở rộng dải hoạt động của CORDIC từ góc hẹp $[-\pi/2, \pi/2]$ ra toàn bộ vòng tròn lượng giác $[-\pi, \pi]$ bằng cách dịch góc về góc phần tư thứ nhất/thứ tư và đảo dấu giá trị Sine/Cosine ngõ ra một cách chính xác.
4. **Cơ chế Phân xử Round-Robin**:
   - Khi có nhiều bộ FFT/IFFT cùng yêu cầu Twiddle Factor cùng lúc, bộ phân xử `arbiter.v` sẽ phân chia tài nguyên luân phiên để tránh đụng độ dữ liệu (Data Collision) và đảm bảo tính công bằng.

---

## 📌 4. Ràng buộc Chân Vật Lý (Pin Constraints) cho Kit FPGA Artix-7
Nếu bạn cần hiện thực hóa thiết kế này trên kit FPGA vật lý **Artix-7 (XC7A35T-1CPG236C)**, file cấu hình chân đề xuất nằm ở:
`CORDIC/constraints.xdc` (Xem đặc tả chi tiết trong mục 3 của file [RTL_Refinement_Notes.md](file:///c:/Users/Dell/Downloads/CORDIC/c%C3%A1c%20file%20ngo%C3%A0i/RTL_Refinement_Notes.md)).
#   C O R D I C _ n h o m 1  
 