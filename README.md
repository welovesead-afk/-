# SEA.D 업무통합 시스템

씨드(SEA.D) 건해조류 소분·식품가공 업무통합 시스템. 1단계 범위: 기준정보(품목·BOM·거래처) + 입고·생산일지·재고·로트 연결.

- 화면: `web/` (카페24 호스팅에 배포되는 정적 파일)
- 데이터: Supabase (접속 정보는 `.env` — `.env.example` 참고, git에 올리지 않음)
- 회사 원본 자료(엑셀·PDF)는 저장소에 올리지 않습니다 (`.gitignore`).

## 카페24 배포

`web/` 폴더를 GitHub Actions가 카페24 FTP로 올립니다. 비밀번호는 코드에 없고 GitHub Secrets에만 있습니다.

### 최초 1회 설정 (저장소 관리자)

GitHub 저장소 → **Settings → Secrets and variables → Actions**

**Secrets** 탭 → New repository secret

| 이름 | 값 |
|---|---|
| `FTP_SERVER` | `welovesead.my.cafe24.com` |
| `FTP_USERNAME` | FTP 아이디 |
| `FTP_PASSWORD` | FTP 비밀번호 |

**Variables** 탭 (선택 — 없으면 기본값 사용)

| 이름 | 기본값 | 설명 |
|---|---|---|
| `FTP_DIR` | `/www/erp/` | 올릴 폴더. 홈페이지 최상위(`/www/`)는 덮어쓰기 방지를 위해 차단됨 |
| `SITE_URL` | `https://welovesead.my.cafe24.com/erp/` | 배포 후 접속 확인 주소 |
| `FTP_PROTOCOL` | `ftp` | `ftps` 지원 시 변경 |

### 배포 실행

GitHub → **Actions → 카페24 배포 → Run workflow**. 또는 Claude에게 "배포해줘".
배포 후 `version.json`의 커밋 번호로 새 버전이 올라갔는지 자동 확인합니다.
