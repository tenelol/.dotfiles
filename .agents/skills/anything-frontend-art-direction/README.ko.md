# Anything Frontend Art Direction

[日本語](README.md) · [English](README.en.md) · [简体中文](README.zh-CN.md) · **한국어**

Anything Frontend Art Direction은 주제에 맞는 색, 서체, 여백, 구도를 고르는 데 쓰는 일본어 프런트엔드 디자인 스킬입니다. 실제 작품을 보면서 디자이너가 왜 그렇게 디자인했는지 읽고, 내 화면에 활용할 표현을 고를 수 있습니다. 구현이나 검토 중 궁금한 점이 생기면 12개 분야, 1,464개 항목의 색인에서 관련 명세와 연구 원문을 찾아볼 수 있습니다.

## Motion Atlas와 함께 만든 예제 · DEAD AIR FM

[**브라우저에서 DEAD AIR FM 열기**](https://rna4219.github.io/anything-frontend-art-direction/examples/dead-air-fm/)

[![DEAD AIR FM 화면. 오른쪽에는 헤드폰을 쓴 DJ가 보이고, 왼쪽에는 분홍색 방송국 이름과 청록색 재생 버튼이 있다.](docs/dead-air-fm.webp)](https://rna4219.github.io/anything-frontend-art-direction/examples/dead-air-fm/)

DEAD AIR FM은 도쿄의 한밤중을 배경으로 한 가상의 해적 라디오 방송국입니다. Anything Frontend Art Direction을 사용해 일러스트에서 화면에 쓸 색을 골랐습니다. 방송국 이름에는 헤드폰 선의 분홍색을, 재생 버튼에는 DJ 재킷의 청록색을 썼습니다. 채널을 바꾸면 숫자가 잠깐 뒤섞인 뒤 새 주파수가 표시됩니다. 이 효과에는 [Motion Atlas](https://github.com/RNA4219/motion-atlas)를 사용했습니다.

**「周波数を選ぶ」(주파수 선택)** 아래에서 듣고 싶은 채널을 누르면 곡이 재생됩니다. **세 채널의 곡은 모두 YuE2로 생성했습니다.** 87.9 MHz에서는 다크 일렉트로, 92.4 MHz에서는 앰비언트 덥, 98.6 MHz에서는 브레이크비트를 들을 수 있습니다. 일러스트와 음원, 글꼴이 HTML 파일 하나에 들어 있습니다. 이 파일을 저장하면 오프라인에서도 들을 수 있습니다. [단일 HTML 파일 다운로드](https://github.com/RNA4219/anything-frontend-art-direction/raw/refs/heads/main/examples/dead-air-fm/index.html) · [HTML 소스 보기](examples/dead-air-fm/index.html)

## 예제 · 시오마치 영화제

[**브라우저에서 시오마치 영화제 열기**](https://rna4219.github.io/anything-frontend-art-direction/examples/shiomachi-film/)

![시오마치 영화제의 데스크톱 화면. 해 질 무렵의 항구 위에 흰색 명조체로 영화제 이름이 크게 쓰여 있고, 아래에는 일정과 장소, 상영 시간표 링크가 있다.](docs/shiomachi-film.png)

시오마치 영화제(潮待ち映画祭)는 항구에서 열리는 가상의 야외 영화제입니다. 일본어 제목에는 굵은 Shippori Mincho B1(しっぽり明朝B1)을, 영문 부제에는 Cormorant Garamond 이탤릭체를 썼습니다. 시간표에서 날짜를 고르면 그날 상영하는 두 작품이 나옵니다. 상영 시작 시각은 Noto Sans JP로, 그 옆의 영화 제목은 명조체로 표시합니다.

[영화제 HTML 파일을 내려받아](https://github.com/RNA4219/anything-frontend-art-direction/raw/refs/heads/main/examples/shiomachi-film/index.html) 브라우저에서 열 수 있습니다. 데스크톱과 모바일용 이미지, 글꼴, CSS, JavaScript가 한 파일에 들어 있습니다. 오프라인에서도 상영 날짜를 바꾸고 각 영화의 줄거리를 펼치거나 접을 수 있습니다. [HTML 소스 보기](examples/shiomachi-film/index.html)

## 스킬 사용법

1. [ZIP 파일을 내려받아 압축을 풀거나](https://github.com/RNA4219/anything-frontend-art-direction/archive/refs/heads/main.zip) `git clone https://github.com/RNA4219/anything-frontend-art-direction.git`을 실행합니다.
2. ZIP을 사용했다면 압축을 푼 폴더의 이름을 `anything-frontend-art-direction`으로 바꿉니다. 폴더를 사용 중인 도구의 스킬 디렉터리에 넣습니다. 사용 지침은 [SKILL.md](SKILL.md)에 있습니다.
3. 다음과 같이 요청해 보세요. “anything-frontend-art-direction으로 항구에서 열리는 야외 영화제 페이지를 만들어 줘. 실제 영화제 이름으로 서체 두 가지를 비교하고, 휴대폰에서도 상영 시각을 쉽게 찾을 수 있게 해 줘.”

참고 자료는 일본어로 작성한 Markdown 문서입니다. 각 항목의 링크를 열면 원래 게시된 사이트에서 작품 이미지와 자료 원문을 볼 수 있습니다.

| 알아보고 싶은 것 | 참고 자료 |
| --- | --- |
| 주제에 맞는 사례를 찾고 색, 서체, 구도 고르기 | [디자인 과정](references/visual-direction.md) · [구도와 모바일 배치](references/visual-composition.md) · [서체와 색](references/visual-craft.md) |
| 백화점, 게임 등 상업 디자인 사례 찾기 | [세계 각지의 작품·자료 247건](references/design-works.md) |
| 실제 화면에서 서체를 어떻게 썼고 디자이너가 그 이유를 어떻게 설명했는지 살펴보기 | [서체 조사 데이터와 읽는 법](data/typography/README.md) |
| 구현 문제 재현하기 | [HTML 템플릿 11종](templates/README.md) · [12개 분야 색인](SKILL.md) · [출처 목록](sources.md) |
| 화면 검토하기 | [접근성](checklists/accessibility.md) · [폼](checklists/forms.md) · [모션](checklists/motion.md) · [성능](checklists/performance.md) |

서체 조사 자료는 247개 작품에서 수집한 기록 292건으로, CSV와 SQLite 형식으로 볼 수 있습니다. 그중 46개 작품에서는 글자의 형태와 크기, 배치 등을 살펴보고 디자이너가 밝힌 이유와 대조했습니다.

## 라이선스

이 저장소에서 작성한 해설, 조사 데이터의 서술과 편집 내용, 템플릿, 예제용 코드·이미지·음원은 [MIT 라이선스](LICENSE)로 배포합니다.

각 예제에 포함된 글꼴에는 **SIL Open Font License 1.1**이 적용됩니다. 예제 HTML에는 MIT 저작권 표시와 허가문, 각 글꼴의 저작권 표시와 라이선스 전문이 들어 있습니다. 링크로 소개한 제3자의 작품이나 자료를 사용할 때는 원래 배포처의 이용 조건을 확인하세요. [배포 파일별 출처와 라이선스](NOTICE.md)
