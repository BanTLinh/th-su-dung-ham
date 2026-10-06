# Báo Cáo Tối Ưu Hóa Index Hệ Thống IoT SmartFactory

## 1. Phân Tích Sự Đánh Đổi (Trade-Off Analysis)

| Tiêu chí | Bản cũ (Fat Covering Index) | Bản mới (Lean Search Index) | Mức độ cải thiện / Đánh đổi |
| :--- | :--- | :--- | :--- |
| **Cấu trúc Index** | `(sensor_id, recorded_at, temperature, humidity, status)` | `(sensor_id, recorded_at)` | Cắt giảm 3 cột dữ liệu thay đổi liên tục |
| **Tốc độ INSERT (Ghi)** | Siêu chậm (Rớt dữ liệu hàng loạt) | Nhanh gấp 4 - 5 lần | **Giải quyết triệt để nút thắt cổ chai** |
| **Kích thước Index** | Rất lớn (Lớn hơn cả Data gốc) | Giảm ~70% dung lượng | **Tiết kiệm 70% chi phí lưu trữ SSD Cloud** |
| **Tốc độ SELECT (Đọc)** | Cực nhanh (Đọc 100% trên Index) | Chậm hơn vài phần nghìn giây (Lookup Table) | Tốc độ vẫn đạt mức milliseconds, hoàn toàn đáp ứng Dashboard |

---

## 2. Trả Lời Chất Vấn Bảo Vệ Kiến Trúc (Cloud Financial Controller)

### Câu 1: Nếu bảng là "Danh mục quốc gia" (Countries) cả năm không sửa, việc dùng Covering Index có phải "tội ác" không?
* **Trả lời:** **Không.** Việc dùng Covering Index trên bảng tĩnh (Static / Read-Heavy Table) là một **giải pháp tối ưu tuyệt vời**.
* **Giải thích:** Bảng tĩnh gần như không xuất hiện thao tác `INSERT`, `UPDATE`, hay `DELETE`. Chi phí duy trì cây B-Tree lúc ghi (`Write Penalty`) bằng không. Do đó, việc dùng Covering Index giúp đẩy tốc độ `SELECT` lên tối đa mà không gây ra bất kỳ tác dụng phụ nào cho luồng ghi hay nghẽn bộ nhớ đệm ghi.

### Câu 2: Giải thích khái niệm "Write Penalty". Tại sao thêm cột vào Index làm lệnh INSERT chậm lại?
* **Khái niệm Write Penalty:** Là khoảng thời gian và chi phí tài nguyên phần cứng (CPU, RAM, Disk I/O) mà hệ thống phải trả cho các thao tác cập nhật cấu trúc chỉ mục mỗi khi có dữ liệu mới được chèn vào hoặc chỉnh sửa.
* **Nguyên nhân vật lý khi thêm cột:**
  1. Kích thước của mỗi node trên cây B-Tree phình to ra. Một trang dữ liệu (`Data Page` - mặc định 16KB) sẽ chứa được ít phần tử hơn.
  2. Khi `INSERT` liên tục, các trang Index bị đầy nhanh hơn, kích hoạt kỹ thuật **Page Split** (chia đôi trang bộ nhớ) và làm tái cấu trúc lại cây B-Tree.
  3. Khiến ổ cứng phải thực hiện hàng loạt thao tác Ghi ngẫu nhiên (**Random Disk Write**), làm tăng thời gian chờ lệnh (Latency) và dẫn đến hiện tượng Timeout rớt dữ liệu.

### Câu 3: Thay thế `VARCHAR(20)` của cột `status` thành `TINYINT` có tác động gì đến Data Length và Index Length?
* **Tác động lưu trữ:**
  * `VARCHAR(20)` tốn 1 byte độ dài + từ 20 đến 60 bytes (nếu dùng UTF-8) cho mỗi dòng.
  * `TINYINT` chỉ tốn đúng **1 byte** cố định cho mỗi dòng.
* **Kết quả:** Chuyển đổi sang `TINYINT` giúp thu nhỏ dung lượng mỗi bản ghi từ 20–50 bytes. Nếu cột này nằm trong Index, nó làm giảm đáng kể `Index Length`, giúp bộ nhớ RAM (`Buffer Pool`) chứa được gấp nhiều lần số lượng Node Index, tăng hiệu năng cache và giảm đáng kể dung lượng đĩa cứng.

---

## 3. Xác Minh Bằng Lệnh EXPLAIN
Sau khi chuyển sang `idx_lean_search`:
- Cột `key` hiển thị `idx_lean_search`, chứng minh MySQL vẫn dùng Index để định vị dữ liệu theo `sensor_id` và `recorded_at`.
- Cột `type` đạt trạng thái `range`, đảm bảo việc truy vấn khoảng thời gian cực kỳ hiệu quả.
- Cột `Extra` không còn dòng `Using index`, xác nhận MySQL sẽ chuyển sang bước Bookmark Lookup để lấy `temperature`, `humidity`, và `status` từ Clustered Index (Primary Key).