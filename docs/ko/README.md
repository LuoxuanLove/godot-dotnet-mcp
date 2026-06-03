<div align="center">
  <a href="#godot-net-mcp"><img src="../../asset_library/hero.svg" alt="GODOT .NET MCP - Godot .NET용 에디터 내 MCP 브리지" width="960"></a>
</div>

<p align="center"><a href="https://github.com/LuoxuanLove/godot-dotnet-mcp/releases/latest"><img alt="Latest Stable" src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.github.com%2Frepos%2FLuoxuanLove%2Fgodot-dotnet-mcp%2Freleases%2Flatest&amp;query=%24.tag_name&amp;label=stable&amp;color=f59e0b&amp;style=flat-square&amp;labelColor=24292f"></a> <a href="https://godotengine.org/"><img alt="Godot 4.6+" src="https://img.shields.io/badge/Godot-4.6%2B-478cbf?style=flat-square&amp;labelColor=24292f"></a> <a href="https://dotnet.microsoft.com/"><img alt=".NET 8" src="https://img.shields.io/badge/.NET-8-512bd4?style=flat-square&amp;labelColor=24292f"></a> <a href="https://godotengine.org/asset-library/asset/4923"><img alt="Godot Asset Library 4923" src="https://img.shields.io/badge/Godot%20Asset%20Library-4923-478cbf?style=flat-square&amp;labelColor=24292f"></a> <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-22c55e?style=flat-square&amp;labelColor=24292f"></p>

| 홈 | 도구 | 설정 |
|---|---|---|
| ![홈 대시보드](../../asset_library/home-cn.png) | ![도구 브라우저](../../asset_library/tools-cn.png) | ![클라이언트 설정](../../asset_library/config-cn.png) |

# Godot .NET MCP

Godot .NET MCP는 Godot 4.6+ .NET 프로젝트를 위한 에디터 내 MCP 플러그인입니다. Godot 에디터 안에서 직접 실행되며, MCP를 지원하는 클라이언트에 에디터 상태, 현재 씬, 선택된 노드, 실행 정보, 진단 결과, 스크린샷 같은 실시간 프로젝트 컨텍스트를 제공합니다.

MCP 서비스는 Godot 플러그인 안에 포함되어 있습니다. 플러그인을 활성화하고 Dock에서 서비스를 시작하면 되며, 별도의 백그라운드 프로세스를 실행할 필요가 없습니다.

## 왜 필요한가

Godot 프로젝트는 단순히 `.tscn`, `.tres`, 스크립트 파일의 모음이 아닙니다.

보고 있는 씬, 선택된 노드, 에디터 출력, 실행 중인 게임 화면과 상태, 최근 오류, 플러그인 설정은 모두 변경 방향에 영향을 줍니다. Godot .NET MCP는 이 에디터 내부 컨텍스트를 MCP 클라이언트에 전달하여, 디렉터리 스냅샷만 보고 추측하는 일을 줄입니다.

작업이 코드 파일뿐 아니라 Godot 에디터와 게임 런타임에서도 이루어진다면 이 플러그인이 특히 유용합니다.

## 주요 기능

|       | 기능 | 설명 |
| :---: | :--- | :--- |
| 🎛️ | **에디터와 함께 실행** | MCP 서비스가 Godot 플러그인에서 직접 제공되며 추가 백그라운드 프로세스가 필요 없습니다. |
| 🚀 | **낮은 설정 비용** | Godot Asset Library에서 설치하고, 일반적인 MCP 클라이언트 설정을 생성하며, GitHub 소스에서 플러그인을 업데이트할 수 있습니다. |
| 🎮 | **실시간 Godot 에디터 컨텍스트** | 현재 씬, 선택된 노드, Dock 상태, 로그, 실행 정보, 진단 요약, 에디터 스크린샷을 Agent에 제공합니다. |
| 🌳 | **씬, 리소스, 바인딩 진단** | 씬 트리, 리소스 참조, 의존성, 씬 구조 문제, C# export 바인딩 상태를 살펴보도록 돕습니다. |
| ▶️ | **게임 런타임 지원** | 씬 시작과 중지, 런타임 진단 확인, 입력 수행, 게임 런타임 화면 캡처를 지원합니다. |
| 🔎 | **Roslyn 기반 C# 지원** | 플러그인 내부 Roslyn 구문 검사를 사용해 클래스, 기반 타입, 메서드, enum, export 멤버 등 C# 스크립트 구조를 읽습니다. |
| 🐞 | **Godot DAP 디버깅** | Godot DAP를 통해 브레이크포인트, 스레드, 스택 트레이스, 출력 이벤트를 읽고 pause, continue, step-over를 수행합니다. 관리형 C# 브레이크포인트에는 별도의 .NET 디버거가 필요합니다. |
| 📚 | **MCP Resources와 Prompts** | 프로젝트 리소스, 진단 읽기 진입점, 일반적인 Godot 워크플로용 Prompt Guide를 제공합니다. |
| 🧰 | **도구 확장** | `custom_tools/`에서 `user_*` GDScript 도구를 선택적으로 핫로드하여 프로젝트 고유 MCP 기능을 추가할 수 있습니다. |

## 설치

### Godot Asset Library에서 설치

1. Godot에서 프로젝트를 엽니다.
2. `AssetLib` 탭을 엽니다.
3. `Godot .NET MCP`를 검색합니다.
4. 플러그인을 설치합니다.
5. `Project Settings > Plugins`에서 `Godot .NET MCP`를 활성화합니다.
6. `MCPDock`을 열고 `Home`에서 서비스를 시작합니다.

### 소스에서 설치

플러그인 소스 디렉터리를 Godot 프로젝트에 복사합니다.

```text
addons/godot_dotnet_mcp
```

그런 다음 `Project Settings > Plugins`에서 활성화합니다.

## 첫 사용

1. Godot 4.6+ .NET 프로젝트에 플러그인을 설치하고 활성화합니다.
2. `MCPDock`을 엽니다.
3. `Home`에서 MCP 서비스를 시작합니다.
4. 설정 페이지에서 MCP 클라이언트 설정을 생성하거나 복사합니다.
5. 클라이언트로 돌아가 서비스에 연결하고 현재 Godot 프로젝트 상태를 읽게 합니다.

## 문서

- [변경 로그](CHANGELOG.md)
- [로드맵](ROADMAP.md)
- [문서 개요](overview.md)
- [설치와 배포](architecture/installation-and-release.md)
- [사용자 확장](modules/user-extensions.md)

## 저자의 말

저는 아직 학생이지만 게임 만들기에 깊은 열정을 가지고 있습니다. 예전에는 혼자서 전통적인 방식으로 리듬 게임 프로젝트 전체를 작성한 적이 있습니다. 솔직히 코드 세부 사항과 디버깅을 붙잡고 씨름하는 일은 고통스러웠습니다.

AI 시대가 오면서 모든 것이 바뀌었고, 코드는 훨씬 저렴해졌습니다. Agent와 MCP 같은 훌륭한 개념을 알게 된 뒤 저는 매우 기뻤습니다. AI가 제 아이디어를 간단하고 빠르게 현실로 만들고, 설계, 개발, 검증, 그 밖의 모든 일을 자율적으로 끝내 주기를 바랐습니다.

그래서 이 MCP 플러그인을 직접 만들고, 제 게임을 만들 때 직접 사용하기로 했습니다. 이 플러그인은 실제 작업 속에서 검증될 것입니다. 제가 먼저 시행착오를 겪고, 다듬고, 고쳐 나가겠습니다.

이 프로젝트의 코드는 100% AI가 직접 생성했지만, 공식 버전에 들어가기 전에 최대한 검증할 수 있도록 엄격한 자동 검사, 개발 흐름, 릴리스 흐름을 준비했습니다.

여기까지 읽었다면 Godot .NET MCP를 한 번 사용해 보세요. 저는 계속 시장을 조사하고 강력한 아이디어를 배워 이 플러그인에 반영할 것입니다. 이 플러그인은 여러분의 Agent와 게임 프로젝트를 가장 가깝게 이어 주는 접점이 될 것입니다.

## 라이선스

MIT. 자세한 내용은 LICENSE를 참조하세요.
