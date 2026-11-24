# 카드픽 프로젝트 구조 및 동작 요약

> 검토 기준: 공개 저장소 `s10wy/cardPick`, 커밋 `2fda64a`
> 이 문서는 저장소의 코드와 설정을 읽어 정리한 정적 분석입니다. 앱이나 서버를 실행해 동작을 검증한 결과는 아닙니다.

## 1. 프로젝트 한눈에 보기

카드픽은 은행 계좌와 거래 내역을 한곳에 모으고, 사용자의 소비 패턴 및 카드별 혜택을 비교해 카드를 추천하려는 금융 앱 프로젝트입니다. Flutter 앱, Spring Boot 서버, 은행별 가상 FastAPI 서버가 함께 들어 있습니다.

주요 연동 흐름은 다음과 같습니다.

```text
Flutter 앱
  └─ Spring Boot API (기본 주소: localhost:8080)
       ├─ 회원가입·로그인, 앱용 자산·거래 조회, 카드 추천
       └─ 은행별 FastAPI API (기본 포트: 8001, 8002, 8003)
            ├─ 하나은행 샘플 서버
            ├─ 국민은행 샘플 서버
            └─ 누리은행 샘플 서버
```

은행 연동은 실제 금융기관 연결이 아니라 프로젝트 내부의 가상 은행 API를 대상으로 합니다.

## 2. 폴더 구성

| 경로 | 역할 |
|---|---|
| [`flutter_application_1/`](flutter_application_1/) | Android, iOS, 웹, 데스크톱 대상 Flutter 앱 |
| [`grad2_backend0514/choi/`](grad2_backend0514/choi/) | Java 17 및 Spring Boot 3.4 기반 앱 백엔드 |
| [`grad2bankServer-main/central/`](grad2bankServer-main/central/) | 이메일 인증, 로그인, JWT 및 자산 통합을 구현한 별도 FastAPI 서버 |
| [`grad2bankServer-main/hana/`](grad2bankServer-main/hana/) | 하나은행 샘플 계좌·카드·혜택 데이터 API |
| [`grad2bankServer-main/kukmin/`](grad2bankServer-main/kukmin/) | 국민은행 샘플 데이터 API |
| [`grad2bankServer-main/noori/`](grad2bankServer-main/noori/) | 누리은행 샘플 데이터 API |
| [`.gitignore`](.gitignore) | 환경 파일, 빌드 결과, 캐시, IDE 파일 등의 업로드 제외 규칙 |

Flutter 화면의 시작점은 [`main.dart`](flutter_application_1/lib/main.dart)이고, 하단 탭 구성은 [`root_screen.dart`](flutter_application_1/lib/screens/root_screen.dart)에 있습니다. 서버 주소와 화면의 API 호출은 [`api_config.dart`](flutter_application_1/lib/config/api_config.dart), [`api_service.dart`](flutter_application_1/lib/services/api_service.dart)에서 확인할 수 있습니다.

## 3. Flutter 앱 기능

앱 이름과 UI에서 확인되는 주요 화면은 다음과 같습니다.

- **로그인·회원가입**: 이메일 인증, 가입, 로그인 기능을 연결합니다. 로그인 성공 시 이메일과 JWT를 `SharedPreferences`에 저장합니다.
- **홈/내 자산**: 통합 잔액, 계좌, 카드 등 자산 정보를 보여주려는 화면입니다.
- **가계부**: 이번 달 거래를 수입·지출 및 카테고리별로 표시합니다.
- **카드 추천**: 소비 내역과 카드 혜택을 바탕으로 추천 결과를 표시합니다.
- **주변 혜택**: 지도와 주변 매장 혜택 화면의 UI가 있습니다.
- **계좌 연동, 알림, 설정, 이체, 결제** 화면도 포함되어 있습니다.

화면의 주요 API 연결 코드는 [`login_screen.dart`](flutter_application_1/lib/screens/login_screen.dart), [`signup_screen.dart`](flutter_application_1/lib/screens/signup_screen.dart), [`api_service.dart`](flutter_application_1/lib/services/api_service.dart)에 있습니다.

### 앱에서 호출하는 API

Flutter 설정상 기본 서버 주소는 플랫폼에 따라 `localhost:8080` 또는 Android 에뮬레이터용 `10.0.2.2:8080`입니다. 실제 기기 주소 설정도 코드에 있지만 기본으로 선택되어 있지는 않습니다.

| 목적 | 앱에서 요청하는 경로 |
|---|---|
| 로그인 | `POST /api/auth/login` |
| 이메일 인증·가입 | `POST /api/auth/send-code`, `/api/auth/verify-code`, `/api/auth/signup` |
| 통합 자산 조회 | `GET /integrated-assets/{email}` |
| 이번 달 거래 조회 | `GET /transactions/current-month/{email}` |
| 카드 추천 | `GET /cards/recommendation/{email}` |
| 전체 카드 조회 | `GET /cards/all`을 호출하는 함수가 있으나, 현재 Spring 소스에서 이 경로의 API 구현은 확인되지 않았고 Flutter 코드에서 해당 함수의 호출부도 확인되지 않았습니다. |

지도 화면은 실제 지도 API 대신 임시 배경과 샘플 마커를 사용합니다([`map_benefit_screen.dart`](flutter_application_1/lib/screens/map_benefit_screen.dart)). 결제 화면에는 실제 결제 API 대신 시뮬레이션 동작이 있습니다. 이체 화면도 Flutter 소스에서 서버 통신이 확인되지 않아 실제 은행 이체 기능으로 보기는 어렵습니다.

## 4. Spring Boot 앱 백엔드

Spring 프로젝트 설정은 [`build.gradle`](grad2_backend0514/choi/build.gradle)에 있습니다. Spring Web/WebFlux, JPA, Security, 메일, JWT 라이브러리를 사용하고 PostgreSQL JDBC 드라이버가 포함되어 있습니다.

주요 역할은 다음과 같습니다.

- `/api/auth/*`: 이메일 인증 코드 발송·확인, 회원가입, 로그인
- `/integrated-assets/{userEmail}`: 은행별 API 결과를 합쳐 자산 응답 구성
- `/transactions/current-month/{userEmail}`: 통합 거래에서 이번 달 내역을 추림
- `/cards/recommendation/{userEmail}`: 카드 혜택 분석 결과 반환

자산 통합은 [`AssetService.java`](grad2_backend0514/choi/src/main/java/com/example/choi/AssetService.java), 카드 추천은 [`CardRecommendationService.java`](grad2_backend0514/choi/src/main/java/com/example/choi/recommendation/service/CardRecommendationService.java)에서 처리합니다. 추천 코드는 거래 카테고리를 정규화하고, 현재 월 지출 및 전월 지출을 분석하며, 카드의 기본 혜택·프로모션 규칙을 시뮬레이션해 상위 카드를 선정하도록 작성되어 있습니다.

### 사용자별 데이터 관련 주의점

계정 인증과 금융 데이터 조회가 실제 사용자별로 안전하게 연결되는지는 운영 전 통합 테스트가 필요합니다. 배포 전에는 인증, 권한 확인, 사용자 간 데이터 분리를 함께 점검해야 합니다.

## 5. FastAPI 가상 은행 및 별도 중앙 서버

### 은행별 API

`hana`, `kukmin`, `noori` 서버에는 계좌·카드·혜택·프로모션·거래 모델과 API가 있습니다. 각 서버는 사용자 자산 조회(`/user/assets/{email}`), 카드 카탈로그(`/api/v1/catalog/cards`) 및 카드 상세 조회를 제공합니다. Spring의 [`AssetService.java`](grad2_backend0514/choi/src/main/java/com/example/choi/AssetService.java)와 [`RecommendationCatalogProvider.java`](grad2_backend0514/choi/src/main/java/com/example/choi/recommendation/service/RecommendationCatalogProvider.java)는 이 API들을 호출하도록 작성되어 있습니다.

은행 서버 실행 방법은 [`grad2bankServer-main/README.md`](grad2bankServer-main/README.md)에 적혀 있습니다. 안내된 포트는 하나 8001, 국민 8002, 누리 8003입니다. Python 의존성 설치 목록(`requirements.txt` 또는 `pyproject.toml`)은 저장소에서 확인되지 않았습니다.

### 별도 `central` 서버

`central`은 FastAPI 기반의 또 다른 회원가입·이메일 인증·JWT 로그인·자산 통합 구현입니다. 그러나 현재 Flutter 앱의 기본 URL과 인증 경로는 Spring Boot 서버를 가리키므로, 저장소에 공존하는 별도/이전 구현으로 보입니다.

이 서버와 은행별 API는 Spring Boot 경로와 별도의 구현입니다. `central`을 사용할 계획이라면 현재 은행 서버 및 클라이언트와 API·환경 설정이 일치하는지 통합 점검이 필요합니다.

## 6. 실행 환경과 문서 상태

- Flutter 앱은 `flutter_application_1`에서 `flutter pub get` 후 `flutter run`으로 실행하는 구조입니다.
- Spring 서버는 `grad2_backend0514\choi`에서 Gradle Wrapper로 실행할 수 있습니다. 데이터베이스·메일 설정이 유효해야 합니다.
- FastAPI 은행 서버 실행 예시는 `grad2bankServer-main/README.md`에 있습니다. 은행 서버별로 포트가 다르므로 각 서버를 별도 실행해야 합니다.
- Flutter의 [`README.md`](flutter_application_1/README.md)는 현재 기본 Flutter 템플릿 안내 수준이며, 전체 서비스 구조나 서버 실행 절차는 설명하지 않습니다.
- 빌드, 테스트, 실제 API 연결 및 데이터베이스 연결은 이 문서 작성 과정에서 실행 검증하지 않았습니다.

## 7. 설정 및 보안 원칙

실제 비밀번호, 토큰, 개인 식별 정보, 내부 전용 설정값은 문서와 저장소에 기록하지 않아야 합니다. 개발·배포 환경별 설정은 환경변수나 비밀 저장소를 사용하고, 공개 저장소에 인증정보가 포함된 적이 있다면 해당 값을 교체하고 Git 이력까지 점검해야 합니다.

## 8. 확인된 개선 우선순위

1. 인증정보를 환경변수나 비밀 저장소로 관리하고, Git 이력에 민감정보가 남지 않도록 점검합니다.
2. 사용자 인증과 데이터 접근 권한, 사용자별 데이터 분리를 통합 테스트합니다.
3. 클라이언트가 사용하는 API와 서버 구현을 비교해 미사용·누락된 경로를 정리합니다.
4. 병행 구현된 FastAPI 중앙 서버의 사용 여부를 결정하고, 유지한다면 전체 연동 규약을 일치시킵니다.
5. 지도·이체·결제 화면은 실제 API 연동 여부를 명확히 표시하고, 시뮬레이션 기능은 실제 금융 동작과 구분합니다.
6. 루트에 전체 실행 안내와 Python 의존성 명세, 테스트 절차를 추가합니다.
