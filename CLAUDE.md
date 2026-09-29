# CLAUDE.md

씨드(SEA.D, 부산 기장 건해조류 소분·식품가공, 직원 5명) 업무통합 시스템.
**작업을 시작하기 전에 `docs/PROJECT_LOG.md`(결정 사항·대기 질문·다음 할 일)를 먼저 읽을 것.**

- 응답은 한국어, 사용자는 제조·유통 실무자 → IT 용어는 풀어서
- 계획을 먼저 보여주고 단계마다 확인받기. 기록 삭제 금지(취소+수정이력). 비밀번호·키는 코드/파일에 쓰지 않기
- 회사 원본 자료(xlsx·pdf·csv, 금액 포함)는 저장소에 올리지 않기
- 화면 용어: 원자재 / 원자재(가공) / 부자재 / 반제품 / 완제품, OEM 별도. 완제품 공식명은 카탈로그 기준
- 추적 기준: 소비기한(= 원물 건조일 + 36개월)
- 배포: "배포해줘" → GitHub Actions `deploy.yml`(workflow_dispatch) 실행 → https://welovesead.mycafe24.com/erp/ 확인
- DB 두 벌(Supabase / 카페24 MariaDB)은 같은 구조 유지. 바꾸면 양쪽 SQL과 `db/test/run_*_test.sh` 모두 갱신
- 화면 시안: `web/` (정적, ES 모듈). 예시 데이터 `web/js/demo-data.js`, 업무 규칙 `web/js/store-demo.js`
