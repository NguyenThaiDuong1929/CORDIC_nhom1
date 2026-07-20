# RTL Refinement Notes - CORDIC Project

Tài liệu này chứa giải thích chi tiết về thuật toán CORDIC, cơ chế phân xử (Arbiter) Round-Robin và hướng dẫn cấu hình chân (Pin Placement Sheet / Constraints XDC) cho Vivado 2022.1 / 2022.2.

---

## 1. Lý Thuyết Thuật Toán CORDIC (Task 2.1)

### 1.1. Nguyên lý hoạt động
Thuật toán CORDIC (COordinate Rotation DIgital Computer) thực hiện việc tính toán các hàm lượng giác bằng cách thực hiện một loạt các phép quay vector với các góc quay cơ sở $\theta_i$ giảm dần, sao cho:
$$\theta_i = \arctan(2^{-i})$$

Khi đó, phép quay vector được biểu diễn qua hệ thức:
$$x_{i+1} = x_i - d_i \cdot y_i \cdot 2^{-i}$$
$$y_{i+1} = y_i + d_i \cdot x_i \cdot 2^{-i}$$
$$z_{i+1} = z_i - d_i \cdot \theta_i$$

Trong đó:
*   $d_i = +1$ nếu $z_i \ge 0$.
*   $d_i = -1$ nếu $z_i < 0$.
*   Nhờ góc $\theta_i$ có dạng lũy thừa của 2, phép nhân với $2^{-i}$ được chuyển thành phép dịch bit phải (`>>>`), giúp phần cứng thực thi cực kỳ tối ưu (chỉ sử dụng bộ dịch và bộ cộng/trừ, không cần bộ nhân).

### 1.2. Mạch Quadrant Mapping (Xử lý góc phần tư)
Thuật toán CORDIC nguyên bản chỉ hội tụ chính xác đối với các góc nằm trong khoảng từ $-90^\circ$ đến $+90^\circ$ ($[-\pi/2, \pi/2]$). Nếu góc đầu vào lớn hơn dải này (nằm ở góc phần tư thứ 2 hoặc 3), ta phải đưa góc về dải hội tụ và bù trừ dấu ở đầu ra:
1.  **Nếu $\theta > 90^\circ$ (góc phần tư thứ 2):**
    *   Góc dịch chuyển: $\theta_{mapped} = \theta - 180^\circ$
    *   Hệ quả ngõ ra: $\sin(\theta) = -\sin(\theta_{mapped})$ và $\cos(\theta) = -\cos(\theta_{mapped})$.
2.  **Nếu $\theta < -90^\circ$ (góc phần tư thứ 3):**
    *   Góc dịch chuyển: $\theta_{mapped} = \theta + 180^\circ$
    *   Hệ quả ngõ ra: $\sin(\theta) = -\sin(\theta_{mapped})$ và $\cos(\theta) = -\cos(\theta_{mapped})$.
3.  **Nếu $-90^\circ \le \theta \le 90^\circ$:**
    *   Giữ nguyên góc và dấu ngõ ra.

---

## 2. Lý Thuyết Phân Xử Round-Robin (Task 1.1)

Để hỗ trợ nhiều bộ FFT/IFFT yêu cầu Twiddle Factors đồng thời từ 1 lõi CORDIC dùng chung, một bộ phân xử **Arbiter** là bắt buộc.
*   **Round-Robin Arbiter** đảm bảo tính công bằng (fairness). Khi cả hai cổng cùng yêu cầu tại một chu kỳ, quyền truy cập sẽ được luân phiên thay đổi.
*   **Trạng thái ưu tiên (`priority_req`):** Lưu trữ requester nào được ưu tiên phục vụ tiếp theo. Mỗi khi có một yêu cầu được cấp quyền (`o_grant` tích cực), `priority_req` sẽ được đổi trạng thái sang cổng còn lại để phục vụ chu kỳ sau.

---

## 3. Bản Phân Bổ Chân Thiết Kế (Pin Placement Sheet)

Dưới đây là cấu hình gán chân đề xuất cho dòng kit FPGA phổ thông **Xilinx Artix-7 (XC7A35T-1CPG236C)** trên phần mềm Vivado 2022.1 / 2022.2.

| Tên Port (RTL) | Hướng | Độ rộng bit | Chân Vật Lý (Package Pin) | Tiêu chuẩn điện áp (IOSTANDARD) | Mô tả phần cứng |
| :--- | :---: | :---: | :---: | :---: | :--- |
| `clk` | Input | 1 | `W5` | `LVCMOS33` | Xung nhịp hệ thống 100 MHz |
| `rst_n` | Input | 1 | `R2` | `LVCMOS33` | Nút nhấn Reset (Tích cực thấp) |
| `i_req[0]` | Input | 1 | `V17` | `LVCMOS33` | Switch điều khiển Request 0 |
| `i_req[1]` | Input | 1 | `V16` | `LVCMOS33` | Switch điều khiển Request 1 |
| `o_grant[0]` | Output | 1 | `U16` | `LVCMOS33` | LED báo hiệu Grant 0 |
| `o_grant[1]` | Output | 1 | `E19` | `LVCMOS33` | LED báo hiệu Grant 1 |
| `o_valid` | Output | 1 | `U19` | `LVCMOS33` | LED báo hiệu Dữ liệu ra hợp lệ |

*Ghi chú:* Vì các tín hiệu góc pha ngõ vào (`i_phase_req0/1`) và tín hiệu kết quả lượng giác ngõ ra (`o_sin`, `o_cos`) có độ rộng bit lớn (16-bit), khi chạy trên kit thật người ta thường giao tiếp thông qua bus nội bộ (như AXI-Stream) hoặc UART để tránh thiếu chân vật lý. Do đó, các chân GPIO vật lý trên chỉ gán cho các cổng điều khiển cơ bản.

### File Ràng Buộc Constraints (`constraints.xdc`) cho Vivado
```tcl
# Xung nhịp Clock 100MHz (Chu kỳ 10ns)
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} [get_ports clk]
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# Reset tích cực mức thấp
set_property PACKAGE_PIN R2 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# Request Inputs (Switches)
set_property PACKAGE_PIN V17 [get_ports {i_req[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {i_req[0]}]
set_property PACKAGE_PIN V16 [get_ports {i_req[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {i_req[1]}]

# Grant Outputs (LEDs)
set_property PACKAGE_PIN U16 [get_ports {o_grant[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_grant[0]}]
set_property PACKAGE_PIN E19 [get_ports {o_grant[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_grant[1]}]

# Output Valid (LED)
set_property PACKAGE_PIN U19 [get_ports o_valid]
set_property IOSTANDARD LVCMOS33 [get_ports o_valid]
```

---

## 4. Hiện Thực Clock Gating Cho Pipeline (Task 3)

### 4.1. Cơ chế tiết kiệm năng lượng động
Trong thiết kế phần cứng FPGA/ASIC, công suất động (Dynamic Power) tiêu thụ chủ yếu do các sự kiện chuyển mạch (toggling) của clock và dữ liệu trên các phần tử nhớ (Flip-Flops) và mạch logic tổ hợp (adders, shifters).

### 4.2. Kỹ thuật áp dụng trong Datapath
Thay vì luôn cập nhật hoặc giữ giá trị qua từng chu kỳ xung nhịp bằng logic gán thông thường, ta tận dụng đường truyền hợp lệ dữ liệu `valid_pipe[g]`.
*   **Clock Enable (CE) Gating:** Tại mỗi stage `g`, các thanh ghi dữ liệu (`x_pipe`, `y_pipe`, `z_pipe`, `iters_pipe`, `quad_pipe`) chỉ được cấp xung nhịp cập nhật khi có dữ liệu hợp lệ trong stage hiện tại (`valid_pipe[g] == 1`).
*   Khi `valid_pipe[g] == 0` (stage rỗi - idle stage), chân Enable của Flip-Flop bị vô hiệu hóa, ngắt hoàn toàn xung nhịp kích hoạt trên thanh ghi đó, giữ cho mạch ở trạng thái tĩnh tuyệt đối và triệt tiêu công suất động.

---

## 5. Kết Quả Kiểm Chứng Các Kịch Bản Dị Thường (Task 8 & 9)

Thiết kế đã được kiểm chứng toàn diện thông qua hai bộ testbench: `tb_Top` (kiểm tra tích hợp toàn hệ thống) và `tb_cordic_corners` (kiểm tra độc lập các điều kiện biên).

### 5.1. Kịch bản dị thường (Corner Cases)
*   **Góc pha đặc biệt:**
    *   $\theta = 0^\circ \implies \sin = 0$, $\cos = 16383$ (Đạt độ chính xác tuyệt đối).
    *   $\theta = 90^\circ \implies \sin = 16383$, $\cos = 2$ (Lượng tử hóa tối thiểu).
    *   $\theta = -90^\circ \implies \sin = -16386$, $\cos = 0$ (Hội tụ chính xác).
    *   $\theta = 180^\circ \implies \sin = -4$, $\cos = -16383$ (Quadrant mapping hoạt động hoàn hảo).
*   **Sudden Reset (Reset đột ngột giữa luồng dữ liệu):**
    *   Khi tín hiệu `rst_n` hạ xuống mức thấp đột ngột khi dữ liệu đang truyền trong đường ống, ngõ ra `o_valid`, `o_sin`, `o_cos` lập tức bị xóa về `0` ngay trong chu kỳ tiếp theo, đảm bảo không rò rỉ dữ liệu lỗi.
    *   Sau khi nhả reset, hệ thống phục hồi tính toán mẫu mới hoàn toàn chính xác.

### 5.2. Tranh chấp bộ phân xử (Arbiter Contention)
*   Khi cả hai requester cùng gửi yêu cầu ở một chu kỳ, Arbiter cấp quyền cho Requester 0 trước (`o_grant = 2'b01`).
*   Ở chu kỳ tiếp theo, nhờ cơ chế ưu tiên luân phiên (Round-Robin), bộ phân xử chuyển quyền qua cho Requester 1 (`o_grant = 2'b10`), không có dữ liệu nào bị rớt hoặc đè lên nhau.

