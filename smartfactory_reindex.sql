-- ========================================================
-- DỰ ÁN SMARTFACTORY - TỐI ƯU HÓA INDEX HỆ THỐNG IOT
-- DBA: Học viên | Target Repo: th-su-dung-ham.git
-- ========================================================

-- 1. Khởi tạo Cơ sở dữ liệu và Bảng SensorLogs
CREATE DATABASE IF NOT EXISTS smartfactory_db;
USE smartfactory_db;

DROP TABLE IF EXISTS SensorLogs;

CREATE TABLE SensorLogs (
    log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    sensor_id INT NOT NULL,
    recorded_at DATETIME NOT NULL,
    temperature DECIMAL(5,2),
    humidity DECIMAL(5,2),
    status VARCHAR(20) -- 'NORMAL', 'WARNING', 'CRITICAL'
);

-- ========================================================================
-- 2. KHỞI TẠO FAT COVERING INDEX BAN ĐẦU (Kỹ sư cũ đã tạo)
-- Nhét tất cả các cột vào Index để SELECT không cần chạm vào Clustered Index
-- ========================================================================
CREATE INDEX idx_fat_covering ON SensorLogs(sensor_id, recorded_at, temperature, humidity, status);

-- Kiểm tra trạng thái dung lượng tài nguyên ban đầu
SHOW TABLE STATUS LIKE 'SensorLogs';

-- Kiểm tra kế hoạch thực thi EXPLAIN với Fat Index
-- Kết quả: Extra chứa "Using index" (Covering Index - Đọc hoàn toàn trên cây Index)
EXPLAIN SELECT temperature, humidity, status 
FROM SensorLogs 
WHERE sensor_id = 105 AND recorded_at >= '2026-06-20';


-- ========================================================================
-- 3. TIẾN HÀNH TỐI ƯU HÓA: CẮT BỎ FAT INDEX & TẠO LEAN INDEX
-- ========================================================================

-- Xóa Fat Covering Index cồng kềnh gây nghẽn luồng Ghi (Write Bottleneck)
ALTER TABLE SensorLogs DROP INDEX idx_fat_covering;

-- Tạo Lean Index tinh gọn: Chỉ chứa các cột dùng trong WHERE và ORDER BY
CREATE INDEX idx_lean_search ON SensorLogs(sensor_id, recorded_at);


-- ========================================================================
-- 4. KHÔI PHỤC VẬN HÀNH VÀ KIỂM TRẠNG KẾT QUẢ
-- ========================================================================

-- Kiểm tra lại dung lượng tài nguyên sau khi chuyển đổi Index
SHOW TABLE STATUS LIKE 'SensorLogs';

-- Kiểm tra lại kế hoạch thực thi EXPLAIN cho truy vấn Dashboard
-- Kết quả: 
--   - key: idx_lean_search (vẫn tận dụng Index để định vị dòng nhanh chóng)
--   - type: range (truy vấn dải cực kỳ tối ưu)
--   - Extra: Không còn "Using index" (MySQL thực hiện Lookup về Clustered Index để lấy dữ liệu còn lại)
EXPLAIN SELECT temperature, humidity, status 
FROM SensorLogs 
WHERE sensor_id = 105 AND recorded_at >= '2026-06-20';