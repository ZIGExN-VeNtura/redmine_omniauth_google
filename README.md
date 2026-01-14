# Redmine Google OAuth Login Plugin

Plugin cho phép đăng nhập Redmine bằng tài khoản Google sử dụng OAuth2.

## Tính năng

- Đăng nhập Redmine bằng tài khoản Google
- Hỗ trợ giới hạn domain email được phép (vd: chỉ cho phép @company.com)
- Tương thích với xác thực 2 yếu tố (2FA) của Redmine
- Hỗ trợ cả hai phương thức: Google OAuth và password truyền thống
- Giao diện nút đăng nhập Google theo chuẩn Google Branding

## Yêu cầu

- Redmine 5.0 trở lên
- Ruby 2.7+
- Rails 6.1+

## Cài đặt

1. Copy thư mục `redmine_omniauth_google` vào `plugins/`:

```bash
cd /path/to/redmine
cp -r redmine_omniauth_google plugins/
```

2. Khởi động lại Redmine:

```bash
# Nếu dùng Puma
bundle exec rails server

# Hoặc restart service
sudo systemctl restart redmine
```

## Cấu hình Google OAuth

### Bước 1: Tạo Google Cloud Project

1. Truy cập [Google Cloud Console](https://console.cloud.google.com/)
2. Tạo project mới hoặc chọn project có sẵn
3. Bật **Google+ API** (nếu chưa bật):
   - Vào **APIs & Services > Library**
   - Tìm "Google+ API" và click **Enable**

### Bước 2: Tạo OAuth 2.0 Credentials

1. Vào **APIs & Services > Credentials**
2. Click **Create Credentials > OAuth 2.0 Client IDs**
3. Nếu chưa cấu hình OAuth consent screen:
   - Chọn **User Type**: Internal (cho G Suite) hoặc External
   - Điền thông tin ứng dụng (tên, email liên hệ)
   - Thêm scope: `email`, `profile`, `openid`
4. Quay lại **Credentials**, tạo OAuth Client:
   - **Application type**: Web application
   - **Name**: Redmine Login (hoặc tên tùy chọn)
   - **Authorized redirect URIs**: `https://your-redmine-domain/oauth_google/callback`
5. Click **Create**
6. Lưu lại **Client ID** và **Client Secret**

### Bước 3: Cấu hình Plugin trong Redmine

1. Đăng nhập Redmine với quyền Admin
2. Vào **Administration > Plugins**
3. Tìm **Redmine Google OAuth Login** và click **Configure**
4. Điền thông tin:

| Trường | Mô tả |
|--------|-------|
| Enable Google OAuth Login | Tick để bật tính năng |
| Google Client ID | Client ID từ Google Cloud Console |
| Google Client Secret | Client Secret từ Google Cloud Console |
| Allowed Email Domains | Danh sách domain phân cách bởi dấu phẩy (vd: `company.com, example.org`). Để trống để cho phép tất cả domain |

5. Click **Apply**

## Sử dụng

### Đăng nhập

1. Vào trang đăng nhập Redmine (`/login`)
2. Sẽ thấy nút **"Sign in with Google"** phía dưới form đăng nhập
3. Click nút để đăng nhập bằng tài khoản Google
4. Chọn tài khoản Google và cấp quyền truy cập
5. Nếu email Google khớp với email user trong Redmine, đăng nhập thành công

### Lưu ý quan trọng

- **Chỉ hỗ trợ user đã tồn tại**: Plugin không tự động tạo user mới. Email Google phải khớp với email của user đã có trong Redmine.
- **Phân biệt hoa thường**: Email được so sánh không phân biệt hoa thường.
- **2FA**: Nếu user bật xác thực 2 yếu tố, sau khi xác thực Google sẽ yêu cầu nhập mã OTP.

## Cấu trúc Plugin

```
redmine_omniauth_google/
├── init.rb                              # Đăng ký plugin
├── README.md                            # File này
├── config/
│   ├── routes.rb                        # Định nghĩa routes
│   └── locales/
│       ├── en.yml                       # Ngôn ngữ tiếng Anh
│       └── vi.yml                       # Ngôn ngữ tiếng Việt
├── app/
│   ├── controllers/
│   │   └── oauth_google_controller.rb   # Xử lý OAuth flow
│   └── views/
│       ├── settings/
│       │   └── _google_oauth_settings.html.erb
│       └── hooks/
│           └── _google_login_button.html.erb
├── lib/
│   ├── redmine_omniauth_google.rb       # Module chính
│   └── redmine_omniauth_google/
│       └── hooks.rb                     # Hook vào login page
└── assets/
    └── stylesheets/
        └── google_oauth.css             # CSS cho nút login
```

## API Endpoints

| Method | Path | Mô tả |
|--------|------|-------|
| GET | `/oauth_google` | Bắt đầu OAuth flow, redirect đến Google |
| GET | `/oauth_google/callback` | Nhận callback từ Google sau khi user xác thực |

## Bảo mật

- **CSRF Protection**: Sử dụng `state` parameter để chống tấn công CSRF
- **Domain Validation**: Kiểm tra email domain trước khi cho phép đăng nhập
- **HTTPS**: Khuyến nghị chỉ sử dụng với HTTPS để bảo vệ thông tin xác thực
- **Token Security**: Access token chỉ được sử dụng một lần và không lưu trữ

## Xử lý lỗi

| Lỗi | Nguyên nhân | Cách xử lý |
|----|-------------|------------|
| "Google OAuth login is not enabled" | Plugin chưa được bật | Vào Settings và bật plugin |
| "Invalid OAuth state" | CSRF token không khớp | Thử đăng nhập lại |
| "Your email domain is not allowed" | Email không thuộc domain cho phép | Liên hệ admin để thêm domain |
| "No Redmine account found" | Email Google không có trong Redmine | Tạo user với email tương ứng |

## Gỡ lỗi

### Kiểm tra logs

```bash
tail -f log/production.log | grep -i oauth
```

### Kiểm tra routes

```bash
bundle exec rails routes | grep oauth_google
```

### Kiểm tra plugin đã được load

```bash
bundle exec rake redmine:plugins RAILS_ENV=production
```

## Đóng góp

1. Fork repository
2. Tạo branch mới (`git checkout -b feature/tinh-nang-moi`)
3. Commit thay đổi (`git commit -am 'Thêm tính năng mới'`)
4. Push lên branch (`git push origin feature/tinh-nang-moi`)
5. Tạo Pull Request

## License

Plugin này được phát hành theo giấy phép GNU General Public License v2 (GPLv2).

## Tác giả

- Redmine Team

## Changelog

### v1.0.0
- Phát hành bản đầu
- Hỗ trợ đăng nhập bằng Google OAuth2
- Hỗ trợ giới hạn domain email
- Tương thích với Redmine 2FA
