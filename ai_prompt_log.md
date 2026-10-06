# AI Prompt Log - Database Tuning Assistant (SmartFactory Project)

## Topic 1: Khái niệm Covering Index và cơ chế Clustered Index vs Secondary Index
* **Prompt:** "Hãy giải thích cơ chế Covering Index trong MySQL InnoDB. Tại sao câu lệnh SELECT chứa tất cả các cột trong Secondary Index lại không cần đọc Clustered Index (Primary Key)?"
* **Ghi nhận kiến thức:** Trong InnoDB, Clustered Index lưu trữ toàn bộ dữ liệu của bảng. Secondary Index lưu các cột chỉ mục + Primary Key. Khi truy vấn `SELECT` chỉ yêu cầu các cột có sẵn trong Secondary Index, MySQL sẽ lấy dữ liệu ngay trên cây B-Tree của Secondary Index (`Using index`) mà không cần tốn 1 bước Lookup nhảy sang Clustered Index.

## Topic 2: Tính toán dung lượng Byte (Byte Calculation) của các kiểu dữ liệu
* **Prompt:** "Hãy tính chi tiết dung lượng Byte cho 1 bản ghi trong Index `(sensor_id, recorded_at, temperature, humidity, status)` với kiểu dữ liệu INT, DATETIME, DECIMAL(5,2), VARCHAR(20) utf8mb4."
* **Ghi nhận kiến thức:**
  - `sensor_id` (INT): 4 bytes
  - `recorded_at` (DATETIME): 5 bytes
  - `temperature` (DECIMAL(5,2)): 3 bytes
  - `humidity` (DECIMAL(5,2)): 3 bytes
  - `status` (VARCHAR(20) utf8mb4): 1 byte length + (20 * 4) = 81 bytes max
  - **Tổng Fat Index:** ~96 bytes/bản ghi.
  - **Lean Index `(sensor_id, recorded_at)`:** Chỉ tốn 9 bytes/bản ghi (Giảm hơn 10 lần dung lượng mỗi Node Index!).

## Topic 3: Cơ chế B-Tree Page Split và Write Penalty trong hệ thống IoT
* **Prompt:** "Tại sao hệ thống IoT chèn hàng chục nghìn bản ghi/giây lại bị đơ (Timeout) khi bảng có Fat Covering Index? Hãy giải thích dưới góc độ B-Tree Page Split và Disk I/O."
* **Ghi nhận kiến thức:** Vì Fat Index có kích thước byte lớn, mỗi trang bộ nhớ 16KB chỉ chứa được số lượng node rất ít. Tần suất ghi cao làm các trang bộ nhớ liên tục bị tràn, buộc InnoDB thực hiện `Page Split` và ghi đĩa ngẫu nhiên (Random Writes). Việc này tiêu tốn CPU và I/O của đĩa SSD, tạo ra hàng đợi ghi nghẽn (Write Stalls) dẫn đến rớt kết nối dữ liệu IoT.