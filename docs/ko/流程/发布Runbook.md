# 릴리스 Runbook

이 문서는 Godot .NET MCP의 릴리스 전 점검과 원격 릴리스 흐름을 정리합니다. 저장소 밖 프로젝트나 로컬 작업공간 흐름은 다루지 않습니다.

---

## 1. 릴리스 원칙

- `dev`는 안정 통합 분기입니다. 릴리스 전에 모든 변경은 먼저 단기 분기 PR로 `dev`에 합쳐야 합니다.
- 일반 `feature/*`, `fix/*`, `docs/*`, `chore/*`, `hotfix/*` PR은 플러그인 공개 버전 메타데이터를 `dev`와 같게 유지해야 합니다. 해당 버전을 바꿀 수 있는 것은 `dev`를 대상으로 하는 `release/*` PR뿐입니다.
- 릴리스는 유지보수자가 수동으로 시작하거나 `v*` tag를 푸시해 시작합니다. Agent가 `dev`를 직접 병합하거나 푸시하지 않습니다.
- 릴리스 설치 방식은 Godot Asset Library 설치와 `addons/godot_dotnet_mcp/` 소스 파일 직접 복사 두 가지만 남깁니다.
- zip 패키지, release 패키지, 로컬 패키징 산출물과 그 설치 절차는 만들지도, 올리지도, 기록하지도 않습니다.
- `next` draft release는 다음 버전 릴리스 노트 초안일 뿐이며, 정식 릴리스도 아니고 패키지 자산도 붙지 않습니다.

---

## 2. 릴리스 전 점검

1. `addons/godot_dotnet_mcp/plugin.cfg` 버전, `docs/en/CHANGELOG.md`, `docs/ko/CHANGELOG.md`, `docs/ja/CHANGELOG.md`, `docs/zh-CN/CHANGELOG.md`, 공개 문서가 서로 맞는지 확인합니다.
   - Changelog는 목표 버전이 바로 이전 공개 버전과 비교해 가진 중요한 변경을 모두 기록해야 합니다. 사용자에게 보이는 `Added` / `Changed` / `Fixed`만 적는 것이 아닙니다. 중요한 `Documentation`과 `Internal` 변경도 `docs/en/CHANGELOG.md`, `docs/ko/CHANGELOG.md`, `docs/ja/CHANGELOG.md`, `docs/zh-CN/CHANGELOG.md`에 남겨야 합니다. 예를 들면 release note 원본, README / docs / i18n / Runbook 업데이트, CI / harness / workflow 동작, policy 검사, protocol facts, 검증 범위 변화입니다.
   - 버전 메타데이터만 바꾸는 일은 그것 자체로 changelog에 쓰지 않습니다. 그 변경이 사용자에게 보이는 호환성, 설치 방식, 릴리스 검증 동작을 함께 바꿀 때만 기록합니다. 개발 중 생겼다가 같은 버전선 안에서 고친 내부 문제도 별도 changelog 항목으로 쓰지 않습니다.
2. 해당 버전의 `docs/zh-CN/流程/release-notes/release-notes-v*.md`가 존재하고, 사용자 중심의 수기 릴리스 서사인지 확인합니다. workflow는 changelog 버전 구간을 검사하고 commit summary를 덧붙입니다.
3. `next` draft release가 정식 릴리스 형식으로 갱신되었고, 정식 GitHub Release 본문 미리보기로 쓸 수 있는지 확인합니다.
4. PR이 현재 릴리스 목표 범위만 담고 있고, 다른 수정이나 역사상 아직 합쳐지지 않은 제출물이 섞이지 않았는지 확인합니다.
5. 공개 문서가 플러그인 자체의 설치, 사용, 릴리스, 호환성 정보만 설명하는지 확인합니다.
6. CI가 통과했는지 실행하거나 확인합니다.

```powershell
.\scripts\test_plugin_side_roslyn.ps1 -GodotPath "<Godot Editor Path>"
```

7. `.github/workflows/**`를 바꿨다면 `lint-workflows`가 통과했는지 확인합니다.
8. 정식 릴리스 tag를 푸시한다면 tag가 `v*` 형식인지, tag가 `dev`에서 도달 가능한 커밋을 가리키는지, tag 버전이 `plugin.cfg`, 영문, 한국어, 일본어, 간체 중국어 changelog와 대응하는 `docs/zh-CN/流程/release-notes/release-notes-v*.md`와 같은지 확인합니다.

---

## 3. 릴리스 노트 형식

정식 GitHub Release 본문은 `scripts/render_release_notes.ps1`가 생성하며, 두 층 구조를 유지합니다.

1. 수기 요약 층, `docs/zh-CN/流程/release-notes/release-notes-v<version>.md`에서 가져오며, 버전 주제, 핵심 하이라이트, 호환성 안내, 업그레이드 판단을 설명합니다.
2. 자동 요약 층, workflow가 먼저 `docs/zh-CN/CHANGELOG.md`의 목표 버전 또는 `Unreleased` 구간을 확인한 뒤 최근 commit summary를 덧붙입니다.

수기 요약을 쓸 때는 다음을 따릅니다.

- 이미 공개된 `v1.0.1`의 emoji 서사 구조를 배웁니다. emoji, 버전, 사용자 주제가 있는 2차 제목, 사용자가 이해하기 쉬운 버전 주제 설명 한 단락, 사용자 영향별로 나뉘고 각 항목에 emoji가 붙은 3차 제목, 마지막에는 emoji가 붙은 호환성 / 설치 / 업그레이드 안내입니다.
- 사용자에게 보이는 플러그인 능력, 편집기 경험, 진단 품질, 설치 / 업그레이드 영향, 호환성 변화만 적습니다. commit 목록, 내부 작업 목록, PR 내용을 다시 쓰지 않습니다.
- 유지보수 흐름, 개발 흐름, 릴리스 기계 변화를 수기 요약에 적지 않습니다. 예를 들면 GitHub Actions 트리거 화면, dry-run cache, PR / branch policy, CI 내부 분리, tag 검사 구현입니다. 다만 이런 변화가 최종 사용자의 설치나 사용 방식에 직접 영향을 줄 때만 적습니다.
- 현재 `plugin.cfg` 버전에 해당하는 `docs/zh-CN/流程/release-notes/release-notes-v<plugin.cfg version>.md`는 반드시 존재해야 하고, 그 버전을 언급해야 합니다. 플러그인 메타데이터가 새 버전으로 바뀌고 대응 note가 생긴 뒤에만 옛 원본을 지웁니다.
- 버전이 막 바뀌었고 아직 실제 개발 내용이 없다면, 나중에 채울 수 있는 초기 빈 템플릿을 먼저 만듭니다. 템플릿은 버전선이 초기화되었고, 정식 릴리스 전에는 바로 이전 버전 이후의 실제 사용자 보이는 변경으로 채울 것이라는 뜻만 말해야 하며, 기능, 수정, 유지보수 흐름을 미리 지어내면 안 됩니다.
- 추천 템플릿은 다음과 같습니다.

```markdown
## <emoji> Godot .NET MCP vX.Y.Z: <사용자 보이는 주제>

Godot .NET MCP `vX.Y.Z` is a <release type> for <target users>. It improves <user-facing outcome> while keeping <compatibility / installation / tool-surface expectation>.

### <emoji> <사용자 영향 영역>

Explain what changed, why it matters to plugin users, and what behavior they can expect.

### ✅ Compatibility and Upgrade Notes

Explain Godot/.NET compatibility, supported installation paths, upgrade judgment, and any user-visible caveats.
```

버전이 막 바뀐 뒤의 초기 빈 템플릿은 다음과 같습니다.

```markdown
## 🧩 Godot .NET MCP vX.Y.Z: Release Theme Pending

Godot .NET MCP `vX.Y.Z` has been initialized as the next release line. Before the final release, replace this placeholder with the actual user-visible changes shipped since the previous release.

### ✨ Highlights To Be Filled

Add user-facing capabilities here once they exist.

### 🔧 Fixes To Be Filled

Add user-facing fixes here once they exist.

### ✅ Compatibility and Upgrade Notes

Confirm Godot/.NET compatibility, supported installation paths, upgrade judgment, and any user-visible caveats before release.
```

`draft-release-notes`는 `dev`가 갱신된 뒤 같은 스크립트로 `next` draft release를 새로 고칩니다. 정식 `v*` tag 릴리스 때는 `publish-plugin`이 같은 스크립트로 최종 본문을 만듭니다.

---

## 4. 원격 릴리스 흐름

1. 최신 `origin/dev`에서 릴리스 단기 분기를 만듭니다. 예를 들면 `release/v1.0.1`입니다.
2. 버전, 변경 기록, `docs/zh-CN/流程/release-notes/release-notes-v*.md`, 공개 문서를 정리합니다.
3. 단기 분기를 푸시하고 `dev`를 대상으로 PR을 만듭니다.
4. `validate-plugin-harness`와 관련 workflow 검사가 통과할 때까지 기다립니다.
5. 유지보수자가 GitHub PR 페이지에서 수동으로 확인하고 병합합니다.
6. 수동으로 실행하거나 `draft-release-notes`가 `next` draft release를 갱신하도록 두고, 본문이 정식 릴리스 형식인지 확인합니다.
7. 우선 `publish-release` workflow를 수동으로 트리거하고, GitHub Actions의 `Use workflow from`에서 `dev`를 고른 뒤 `dry_run=true`로 버전, tag, 릴리스 노트, build 검사를 먼저 검증합니다.
8. dry run이 통과했고 릴리스 내용도 확인했다면, `publish-release`를 다시 실행해 `dry_run=false`로 둡니다. 버전과 대상 커밋이 같으면 workflow는 성공한 dry-run 기록을 재사용해 중복 build와 harness 검사를 건너뛰고, `dev`의 현재 커밋 위에 새로운 `v*` tag를 만들고, 정식 GitHub Release를 생성하고, 소비한 `next` draft release를 삭제합니다.
9. 옛 진입점을 계속 쓰려면 병합 후 `dev`에 `v*` tag를 만들고 푸시하거나, `publish-plugin` workflow를 수동 트리거해 검증할 수도 있습니다. tag 진입점은 먼저 tag 버전, 릴리스 노트 원본, `dev` 도달 가능성을 확인한 뒤 build와 harness를 실행합니다.
10. `publish-release`와 `publish-plugin`은 둘 다 릴리스 전에 버전 일치, 릴리스 노트 원본, 이미 존재하는 release를 검사합니다. 검사를 통과하면 GitHub Release를 만들고 로컬 패키지 자산은 올리지 않습니다.

`publish-release`는 릴리스 마무리만 합니다. 버전 번호를 커밋하지 않고, PR을 병합하지 않고, `dev`를 푸시하지 않고, 정식 tag를 덮거나 지우지 않고, zip / package 자산도 만들거나 올리지 않습니다. tag나 GitHub Release가 이미 있으면 workflow는 실패하고 새 버전을 고르거나 사람이 처리해야 합니다.

---

## 5. 실패 처리

- CI가 실패하면 수정을 단기 분기로 되돌리고 다시 푸시합니다. `dev`를 바로 수정하지 않습니다.
- 릴리스 노트가 틀렸다면 먼저 GitHub Release 본문을 고칩니다. 원본 문서나 changelog가 틀렸다면 단기 분기를 새로 열어 고칩니다.
- tag가 틀렸다면 원격 tag를 지울지 유지보수자가 결정합니다. Agent가 릴리스 tag를 함부로 지우거나 다시 쓰지 않습니다.
- `next` draft release 내용이 틀렸다면 먼저 `docs/zh-CN/流程/release-notes/release-notes-v*.md`나 changelog를 고치고 다시 `draft-release-notes`를 실행합니다. 렌더링 규칙 자체가 틀렸다면 workflow나 스크립트를 단기 분기 PR로 수정합니다.
