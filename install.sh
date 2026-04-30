#!/bin/bash
# TokenPals 자동 설치 스크립트
# 사용법: bash <(curl -fsSL https://raw.githubusercontent.com/devTheKiwi/tokenpals/main/install.sh)

set -e

echo "🐾 TokenPals 설치 시작..."

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 함수: 성공 메시지
success() {
    echo -e "${GREEN}✓${NC} $1"
}

# 함수: 오류 메시지
error() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

# 함수: 정보 메시지
info() {
    echo -e "${YELLOW}→${NC} $1"
}

# 1. 기존 앱 제거
info "1️⃣  기존 TokenPals 종료 중..."
killall TokenPals 2>/dev/null || true
sleep 1

info "기존 앱 제거 중..."
rm -rf ~/Applications/TokenPals.app 2>/dev/null || true
rm -rf /Applications/TokenPals.app 2>/dev/null || true
success "기존 앱 제제 완료"

# 2. 설정 초기화
info "2️⃣  설정 초기화 중..."
security delete-generic-password -a TokenPals 2>/dev/null || true
defaults delete com.tokenpals 2>/dev/null || true
rm -rf ~/.tokenpals 2>/dev/null || true
success "설정 초기화 완료"

# 3. 저장소 다운로드
info "3️⃣  저장소 다운로드 중..."
REPO_DIR="${HOME}/tokenpals"
rm -rf "$REPO_DIR" 2>/dev/null || true
git clone https://github.com/devTheKiwi/tokenpals.git "$REPO_DIR" || error "저장소 클론 실패"
cd "$REPO_DIR"
success "저장소 다운로드 완료: $REPO_DIR"

# 4. Swift 빌드
info "4️⃣  Swift 빌드 중... (1~2분 소요)"
echo ""

# 실시간 프로그레스 표시
swift build -c release 2>&1 | while IFS= read -r line; do
    # 진행 중인 부분 하이라이트
    if echo "$line" | grep -qE "Compiling|Linking|Build complete"; then
        echo -e "${YELLOW}$line${NC}"
    elif echo "$line" | grep -q "error:"; then
        echo -e "${RED}$line${NC}"
    else
        echo "$line"
    fi
done

echo ""

if [ ! -f ".build/release/TokenPals" ]; then
    error "빌드 실패 — Swift 설치 확인"
fi
success "빌드 완료"

# 5. 앱 번들 생성 및 설치
info "5️⃣  앱 설치 중..."
mkdir -p /Applications

# .app 번들 디렉토리 구조 생성
APP_BUNDLE="/Applications/TokenPals.app"
rm -rf "$APP_BUNDLE" 2>/dev/null || true
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 실행 파일 복사
cp "$REPO_DIR/.build/release/TokenPals" "$APP_BUNDLE/Contents/MacOS/TokenPals" || error "설치 실패"
chmod +x "$APP_BUNDLE/Contents/MacOS/TokenPals"

# Info.plist 생성
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>TokenPals</string>
    <key>CFBundleDisplayName</key>
    <string>TokenPals</string>
    <key>CFBundleIdentifier</key>
    <string>com.tokenpals.app</string>
    <key>CFBundleExecutable</key>
    <string>TokenPals</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

success "앱 설치 완료: /Applications/TokenPals.app"

# 6. 앱 실행
info "6️⃣  TokenPals 시작 중..."
open /Applications/TokenPals.app

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 TokenPals 설치 완료!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "📂 저장소 위치: ~/tokenpals"
echo ""
echo "📝 다음 단계:"
echo "  1. 메뉴바의 🥔 아이콘 클릭"
echo "  2. '로그인...' 선택"
echo "  3. 이메일 입력 → 6자리 코드 입력"
echo "  4. 다른 디바이스에서도 같은 이메일로 로그인"
echo "  5. 방에 각 디바이스의 펫이 나타남!"
echo ""
echo "💡 팁: Keychain 권한 요청 → 'Always Allow' 선택"
echo ""
