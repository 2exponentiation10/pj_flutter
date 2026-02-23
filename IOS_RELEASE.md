# iOS Native Build Guide

## 1) Preflight
- macOS + Xcode installed
- Apple Developer account configured in Xcode
- `flutter doctor` all green for iOS toolchain
- Xcode -> Settings -> Components 에서 iOS Device Support 설치 완료

## 2) One-command preflight
```bash
cd /Users/LSY/dev/깃헙/pj_flutter
./scripts/ios_release_prep.sh
```

## 3) Open in Xcode
```bash
open ios/Runner.xcworkspace
```

## 4) Signing
- Runner target -> `Signing & Capabilities`
- Team 선택
- Bundle Identifier 고유값으로 설정 (예: `store.protfolio.satoori`)
- Automatically manage signing 체크

## 5) Archive and TestFlight
- Xcode 메뉴: `Product` -> `Archive`
- `Distribute App` -> `App Store Connect` -> `Upload`
- App Store Connect에서 TestFlight 빌드 처리 후 테스터 배포

## 6) iOS microphone checklist
- 앱 첫 실행 시 마이크 권한 허용
- iOS 설정 -> 앱 -> `마이크` ON
- 앱 내 음성 기능 테스트 3회 연속 수행
- 평가 API 응답 200 확인
