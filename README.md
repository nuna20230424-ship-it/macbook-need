# mac-essentials 🍎

맥북 필수 무료 앱 10개를 **Homebrew**로 한 번에 자동 설치하는 에이전트.
GitHub 오픈소스 큐레이션(awesome-macos 등)과 YouTube/블로그 추천에서 반복 등장하는 앱들로 선정.

## 빠른 시작
```bash
cd ~/mac-essentials
./install.sh            # 전체 설치 (Homebrew 없으면 자동 설치)
```

## 옵션
| 명령 | 설명 |
|------|------|
| `./install.sh` | 전체 설치 (이미 있는 앱은 건너뜀) |
| `./install.sh --dry-run` | 실제 설치 없이 미리보기 |
| `./install.sh --list` | 설치 대상 목록만 출력 |
| `./install.sh --update` | 설치된 앱까지 최신으로 업그레이드 |
| `./install.sh --help` | 도움말 |

## 설치되는 앱
| 앱 | 용도 |
|----|------|
| Raycast | 런처·검색·클립보드 (Spotlight 대체) |
| Rectangle | 창 정렬 (Magnet 무료 대체) |
| Maccy | 클립보드 히스토리 |
| AltTab | 윈도우식 Alt-Tab 창 전환 |
| Stats | 메뉴바 시스템 모니터 |
| MonitorControl | 외부 모니터 밝기·볼륨 |
| IINA | 만능 미디어 플레이어 |
| Keka | 압축·해제 |
| Bitwarden | 비밀번호 관리 |
| Visual Studio Code | 코드 에디터 |

## 커스터마이즈
앱 추가/삭제는 **`apps.txt`** 파일만 편집하면 됩니다 (형식: `cask토큰 | 표시이름 | 설명`).
`brew search --cask <이름>` 으로 토큰을 찾을 수 있습니다.

## 특징
- **멱등성**: 여러 번 돌려도 안전 (이미 설치된 앱은 건너뜀)
- **내결함성**: 한 앱이 실패해도 나머지는 계속 진행, 마지막에 요약
- **로그**: 전 과정 `install.log`에 기록
- Apple Silicon / Intel 자동 판별
