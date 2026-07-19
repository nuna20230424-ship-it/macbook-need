#!/usr/bin/env bash
#
# mac-essentials — 맥북 필수 무료 앱 자동 설치 에이전트
#
# 하는 일:
#   1) Homebrew 없으면 자동 설치 (Apple Silicon / Intel 자동 판별)
#   2) apps.txt 매니페스트를 읽어 각 앱을 멱등(idempotent)하게 설치
#      - 이미 설치된 앱은 건너뜀
#      - 실패해도 다음 앱 계속 진행
#   3) 끝에 성공/건너뜀/실패 요약 리포트 출력
#
# 사용법:
#   ./install.sh            # 전체 설치
#   ./install.sh --dry-run  # 실제 설치 없이 무엇을 할지만 출력
#   ./install.sh --list     # 설치 대상 목록만 출력
#   ./install.sh --update   # 이미 설치된 앱까지 최신으로 업그레이드
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${SCRIPT_DIR}/apps.txt"
LOG_FILE="${SCRIPT_DIR}/install.log"

DRY_RUN=0
UPDATE=0
LIST_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --update)  UPDATE=1 ;;
    --list)    LIST_ONLY=1 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//' | head -n 22
      exit 0 ;;
    *) echo "알 수 없는 옵션: $arg (사용법: --help)"; exit 1 ;;
  esac
done

# ---- 예쁜 출력 ----------------------------------------------------------------
if [ -t 1 ]; then
  BOLD="$(printf '\033[1m')"; DIM="$(printf '\033[2m')"; RESET="$(printf '\033[0m')"
  GREEN="$(printf '\033[32m')"; YELLOW="$(printf '\033[33m')"; RED="$(printf '\033[31m')"; BLUE="$(printf '\033[34m')"
else
  BOLD=""; DIM=""; RESET=""; GREEN=""; YELLOW=""; RED=""; BLUE=""
fi
log()  { echo "$*" | tee -a "$LOG_FILE"; }
info() { log "${BLUE}▶${RESET} $*"; }
ok()   { log "${GREEN}✔${RESET} $*"; }
warn() { log "${YELLOW}‒${RESET} $*"; }
err()  { log "${RED}✗${RESET} $*"; }

echo "===== mac-essentials run: $(date '+%Y-%m-%d %H:%M:%S') =====" >> "$LOG_FILE"

# ---- Homebrew 확인/설치 -------------------------------------------------------
ensure_brew() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi
  # 설치돼 있지만 PATH에만 없는 경우 먼저 시도
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$p" ]; then
      eval "$("$p" shellenv)"
      return 0
    fi
  done

  warn "Homebrew가 없습니다. 설치를 시작합니다 (관리자 암호를 물어볼 수 있음)."
  if [ "$DRY_RUN" = "1" ]; then
    info "[dry-run] Homebrew 설치를 건너뜁니다."
    return 0
  fi
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || { err "Homebrew 설치 실패"; exit 1; }

  # 방금 설치한 brew를 PATH에 등록
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$p" ] && eval "$("$p" shellenv)"
  done
  command -v brew >/dev/null 2>&1 || { err "brew를 PATH에서 찾지 못했습니다."; exit 1; }
  ok "Homebrew 설치 완료"
}

# ---- 매니페스트 파싱 ----------------------------------------------------------
[ -f "$MANIFEST" ] || { err "매니페스트를 찾을 수 없음: $MANIFEST"; exit 1; }

declare -a TOKENS NAMES
while IFS= read -r line; do
  line="${line%%$'\r'}"                        # CRLF 방어
  [ -z "${line// }" ] && continue              # 빈 줄
  [ "${line#\#}" != "$line" ] && continue      # 주석
  token="$(echo "${line%%|*}" | xargs)"        # 첫 필드 = cask 토큰
  rest="${line#*|}"
  name="$(echo "${rest%%|*}" | xargs)"         # 둘째 필드 = 표시이름
  [ -z "$token" ] && continue
  [ -z "$name" ] && name="$token"
  TOKENS+=("$token"); NAMES+=("$name")
done < "$MANIFEST"

TOTAL=${#TOKENS[@]}

if [ "$LIST_ONLY" = "1" ]; then
  echo "${BOLD}설치 대상 ${TOTAL}개:${RESET}"
  for i in "${!TOKENS[@]}"; do printf "  %2d. %-20s (%s)\n" "$((i+1))" "${NAMES[$i]}" "${TOKENS[$i]}"; done
  exit 0
fi

# ---- 실행 ---------------------------------------------------------------------
echo
info "${BOLD}맥북 필수 무료 앱 ${TOTAL}개 설치를 시작합니다${RESET}"
[ "$DRY_RUN" = "1" ] && warn "DRY-RUN 모드: 실제로 설치하지 않습니다."
echo

ensure_brew
[ "$DRY_RUN" != "1" ] && { info "Homebrew 업데이트 중..."; brew update >/dev/null 2>&1 || warn "brew update 경고(무시 가능)"; }

installed=(); skipped=(); upgraded=(); failed=()

app_exists() {  # /Applications 또는 ~/Applications 에 <이름>.app 이 이미 있는가 (수동 설치 포함)
  [ -d "/Applications/$1.app" ] || [ -d "$HOME/Applications/$1.app" ]
}

for i in "${!TOKENS[@]}"; do
  token="${TOKENS[$i]}"; name="${NAMES[$i]}"
  printf "\n[%d/%d] ${BOLD}%s${RESET} ${DIM}(%s)${RESET}\n" "$((i+1))" "$TOTAL" "$name" "$token"

  # brew cask로 관리되지 않아도, 이미 앱 번들이 존재하면 건너뜀
  if ! brew list --cask "$token" >/dev/null 2>&1 && app_exists "$name"; then
    if [ "$UPDATE" = "1" ]; then
      warn "이미 설치됨(brew 외부) — 업그레이드하려면 먼저 앱을 삭제 후 재실행하세요. 건너뜀"
    else
      ok "이미 설치됨(brew 외부) — 건너뜀"
    fi
    skipped+=("$name"); continue
  fi

  if brew list --cask "$token" >/dev/null 2>&1; then
    if [ "$UPDATE" = "1" ]; then
      if [ "$DRY_RUN" = "1" ]; then info "[dry-run] 업그레이드 대상"; upgraded+=("$name"); continue; fi
      if brew upgrade --cask "$token" >>"$LOG_FILE" 2>&1; then ok "$name 업그레이드 완료(또는 이미 최신)"; upgraded+=("$name")
      else err "$name 업그레이드 실패 (자세히: $LOG_FILE)"; failed+=("$name"); fi
    else
      ok "이미 설치됨 — 건너뜀"; skipped+=("$name")
    fi
    continue
  fi

  if [ "$DRY_RUN" = "1" ]; then info "[dry-run] 새로 설치 예정"; installed+=("$name"); continue; fi

  info "설치 중..."
  if brew install --cask "$token" >>"$LOG_FILE" 2>&1; then
    ok "$name 설치 완료"; installed+=("$name")
  else
    err "$name 설치 실패 (자세히: $LOG_FILE)"; failed+=("$name")
  fi
done

# ---- 요약 ---------------------------------------------------------------------
echo
log "${BOLD}================ 설치 요약 ================${RESET}"
log "  신규 설치 : ${GREEN}${#installed[@]}${RESET}  ${installed[*]:-—}"
[ "$UPDATE" = "1" ] && log "  업그레이드 : ${#upgraded[@]}  ${upgraded[*]:-—}"
log "  건너뜀    : ${YELLOW}${#skipped[@]}${RESET}  ${skipped[*]:-—}"
log "  실패      : ${RED}${#failed[@]}${RESET}  ${failed[*]:-—}"
log "  로그 파일 : $LOG_FILE"
echo

if [ "${#failed[@]}" -gt 0 ]; then exit 1; fi
ok "완료! 🎉"
