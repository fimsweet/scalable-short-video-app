# scalable-short-video-app
Background:
Ứng dụng chia sẻ video ngắn (short-video apps) đã trở thành một trong những xu hướng toàn cầu, điển hình là TikTok, Instagram Reels hay YouTube Shorts. Những nền tảng này không chỉ cung cấp chức năng xem video, mà còn tích hợp nhiều tính năng tương tác thời gian thực như bình luận, lượt thích, theo dõi, và gợi ý nội dung dựa trên hành vi người dùng.

Để xây dựng một hệ thống tương tự, cần giải quyết các thách thức về:

Xử lý và lưu trữ video streaming dung lượng lớn.

Giao tiếp thời gian thực giữa người dùng.

Khả năng mở rộng (scalability) để đáp ứng lượng người dùng tăng trưởng nhanh.

Tích hợp cloud-native services nhằm đảm bảo hiệu năng, tính sẵn sàng cao và tối ưu chi phí.

 
Objectives:
Phát triển ứng dụng di động (cross-platform) bằng Flutter, hỗ trợ đăng tải, xem và tương tác với video ngắn.

Thiết kế và triển khai hệ thống backend có khả năng mở rộng, phục vụ video streaming và giao tiếp real-time.

Tích hợp dịch vụ cloud để lưu trữ, phân phối video, cũng như quản lý thông báo và kết nối người dùng.

Đánh giá hiệu năng của hệ thống qua các thử nghiệm tải (load testing) và so sánh chi phí triển khai.

 
Scope:
Ứng dụng di động: Flutter (Android/iOS), giao diện đơn giản và trực quan.

Đăng tải video.

Xem feed video.

Tương tác: like, comment, follow.

Nhận thông báo khi có hoạt động mới.

Chức năng cốt lõi:

Backend: Xử lý lưu trữ video, streaming, giao tiếp thời gian thực và gợi ý nội dung cơ bản.

Cloud deployment: triển khai hạ tầng trên cloud (AWS hoặc GCP).

Giới hạn: không xây dựng hệ thống recommendation phức tạp, chỉ dừng ở mức prototype.

 
Methodology:
1. Requirement Analysis
Thu thập và xác định yêu cầu chức năng (upload, xem video, tương tác, thông báo).
Xác định yêu cầu phi chức năng: khả năng mở rộng, độ trễ thấp, độ tin cậy cao.
2. System Design
Frontend: Ứng dụng Flutter với kiến trúc MVVM.
Backend: Kiến trúc microservices (Node.js/NestJS hoặc Spring Boot).
API Gateway để điều phối request, quản lý xác thực và logging.
Video Storage & Streaming: Lưu video trên AWS S3, phân phối qua CDN (AWS CloudFront).
Database: PostgreSQL/MySQL cho dữ liệu quan hệ, Redis cho cache và real-time session.
Real-time Communication: WebSocket hoặc gRPC cho chat/comment trực tuyến.
Push Notification: Firebase Cloud Messaging (FCM).
3. Implementation

Phát triển ứng dụng di động bằng Flutter.
Xây dựng các microservice (user, video, interaction, notification).
Đóng gói backend bằng Docker và triển khai trên Kubernetes cluster.
4. Deployment on Cloud
Sử dụng AWS (hoặc GCP/Azure) cho cơ sở hạ tầng.
Tận dụng Kubernetes (EKS/GKE) để tự động mở rộng (auto-scaling) và quản lý container.
Thiết lập giám sát bằng Prometheus + Grafana.
Logging và phân tích bằng ELK Stack (Elasticsearch, Logstash, Kibana).
5. Testing & Evaluation
Functional Testing: kiểm tra toàn bộ chức năng chính.
Performance Testing: load testing bằng k6/JMeter để đo throughput, latency.
Scalability Testing: stress test với số lượng người dùng đồng thời lớn.
Cost Evaluation: phân tích chi phí vận hành trên cloud.
Expected Results:
Một ứng dụng di động (Flutter) hoạt động được, hỗ trợ đăng tải và chia sẻ video ngắn.
Hệ thống backend có khả năng mở rộng và vận hành trên cloud với hiệu năng ổn định.
Video streaming mượt mà với độ trễ thấp nhờ CDN và caching.
Hệ thống real-time (comment, like, follow) hoạt động ổn định.
Báo cáo đánh giá chi tiết hiệu năng, khả năng mở rộng và chi phí triển khai.
Technologies: Flutter, Node.js/Spring Boot, AWS S3, CloudFront, Firebase, WebSocket.