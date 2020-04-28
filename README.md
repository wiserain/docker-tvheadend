# docker-tvheadend

다음의 특징을 가지는 docker-tvheadend 이미지

1.  **linuxserver/tvheadend 기반:**
다양한 docker용 앱 이미지를 제작/배포하고 있는 [linuxserver.io](https://linuxserver.io/)의 [소스](https://github.com/linuxserver/docker-tvheadend)를 기반으로 한다. 차이점은 tvheadend 빌드 옵션을 보다 소스의 기본값에 충실하여 더 나은 실행환경을 도모한다.

2.  **대한민국 IPTV를 위한 EPG grabber 탑재:**
이 기능은 [epg2xml](https://github.com/wiserain/epg2xml)과 내장 [tv_grab_file](https://github.com/nurtext/tv_grab_file_synology)을 이용하였다.

## 실행 방법

아래 세가지 방법 중 자신에게 맞는 하나를 선택하여 컨테이너를 생성/실행한다.

#### docker 명령어 사용시:

```bash
docker run -d \
    --name=<container name> \
    --network=host \
    -v <path to recordings>:/recordings \
    -v <path to config>:/config \
    -v <path to epg2xml>:/epg2xml \
    -e PUID=<UID for user> \
    -e PGID=<GID for user> \
    wiserain/tvheadend:stable
```

#### docker-compose 사용시:

```yml
version: '2'

services:
  <service name>:
    container_name: <container name>
    image: wiserain/tvheadend:stable
    restart: always
    network_mode: "host"
    volumes:
      - <path to config>:/config
      - <path to recordings>:/recordings
      - <path to epg2xml>:/epg2xml
    environment:
      - PUID=<UID for user>
      - PGID=<GID for user>
```

#### Synology DSM 사용시: [별도 문서 참조](https://github.com/wiserain/docker-tvheadend/blob/epgkr/assets/how-to-run-on-synology.md)

 작성 시점이 오래 되어 상세 내용은 조금 다를 수 있으니 지금 보고 있는 문서의 내용을 우선으로 한다.

## EPG 사용법

컨테이너를 실행 후 ```http://localhost:9981/```를 통해 WEBUI로 접속한 다음, ```Configuration > Channel / EPG > EPG Grabber Modules```로 이동하면 아래 이미지와 같이 3개의 IPTV 서비스를 위한 internal XMLTV grabber가 마련되어 있으니 Enable 시켜서 사용하면 된다.

![](https://github.com/wiserain/docker-tvheadend/blob/epgkr/assets/images/PicPick_Capture_20171206_002.png)

이미지 태그 기준 4.1-2493 버전부터 ```epg2xml```의 옵션을 전달 받아 실행하는 모듈을 추가하였다. 왼쪽에서 ```Korea (epg2xml)```을 선택하고 오른쪽 옵션 창에서 ```epg2xml``` 이후의 arguments를 주면 된다. 예외 처리가 되어 있지 않기 때문에 출력에 관련된 ```-o -s -d```는 extra arguments로 입력하면 안된다.

#### 처음 EPG 설정 시 유의사항

Socket으로 직접 밀어 넣는 external grabber와 달리 내부적으로 cron을 실행한다. 아래 그림과 같이 EPG Grabber 탭에 보면 기본 설정으로 매일 12시 24시 4분에 실행해서 epg를 가져온다. 하지만 버그가 있는지 기본 설정을 무시하고 끊임없이 실행되는 문제가 초반에 있다. 그러므로 설정을 바꿔서 저장해주고 ```Re-run Internal EPG Grabbers```을 눌러서 실행해준다. 어떤 값으로든 변경 후에는 문제없이 정상적으로 동작하는 것을 확인하였다. Cron 설정 방법에 대해서는 [링크](http://docs.tvheadend.org/webui/config_epggrab/#cron-multi-line-config-text-areas)를 참고바람.

![](https://github.com/wiserain/docker-tvheadend/blob/epgkr/assets/images/PicPick_Capture_20170331_001.png)


## 관련 설정들

### 이미지 태그 네이밍 규칙

```
{main_tag}-{tvh_ver}
```

|  | 선택 가능한 값 | 설명  |
|---|---|---|
| ```main_tag```  | ```latest```, ```latest-ns```, ```stable```, ```stable-ns```, ```ubuntu``` | - **latest**: 최신 이미지 버전. [새로운 기능](https://tvheadend.org/projects/tvheadend/roadmap)을 체험할 수 있는 개발 버전으로 약간 불안정할 수 있다.<br> - **stable**: 최신 tvheadend release 버전 [참고](https://doozer.io/tvheadend/tvheadend)<br> - 뒤에 붙는 ```-ns```는 non-static build를 의미한다.<br> - **ubuntu**: latest 태그와 같은 tvheadend 버전을 따르지만, alpine 대신 ubuntu를 기반으로 빌드하였다. |
| ```tvh_ver``` |  | 형식은 {tvheadend version}-{build number} 이며 생략할 경우 최신 빌드를 따름 |

모든 조합이 가능하지는 않으며, 사용 가능한 이미지 버전은 [여기](https://hub.docker.com/r/wiserain/tvheadend/tags/)서 확인할 수 있다. 특별한 일이 없으면 매주 한 번 새롭게 빌드 된다.

### 네트워크 모드

docker는 멀티캐스트 패킷 라우팅이 안되기 때문에 tvheadend를 이용해 IPTV를 보기 위해서는 무조건 ```hosted network```를 사용해야 한다. 일부 낮은 docker engine 버전(예를 들어 Synology DSM 5.2)에서는 지원하지 않으니 참고. ```hosted network```란 포트 포워딩이나 매핑을 하지 않고 호스트의 네트워크에 그대로 붙인다는 의미이므로 tvheadend가 사용하는 포트를 바꾸고 싶다면 앱 실행 시 옵션을 주어서 변경해야 한다. docker에서는 다음과 같이 환경 변수를 추가해주면 된다. ```RUN_OPTS=--http_port <port number> --htsp_port <port number>```

### 환경변수

docker-tvheadend의 동작을 제어하는 환경변수와 가능한 옵션을 설명한다. 참고로 환경변수는 컨테이너 생성 시점에 그 값이 고정 되므로 변경을 원한다면 컨테이너를 삭제/재생성 해야한다. 먼저 필수로 지정해야하는 환경변수는 다음과 같다.

| 이름  | 설명  | 기본값 |
|---|---|---|
| ```PUID``` / ```PGID```  | 컨테이너 내부의 앱이 외부의 볼륨에 접근할 수 있도록 하는 권한에 대한 것이다. [여기](https://github.com/linuxserver/docker-tvheadend#user--group-identifiers)를 참고하여 설정한다. 적절하게 설정하지 않으면, EPG 관련 스크립트가 동작하지 않거나 녹화가 안될 수 있다.  | ```911``` / ```911```  |
| ```TZ```  | docker-tvheadend에 적용되는 timezone 설정이다. 이게 제대로 안되면 EPG에 시간차가 발생한다.  | ```Asia/Seoul```  |

epg2xml 관련 환경변수는 다음과 같다.

| 이름  | 설명  | 기본값 |
|---|---|---|
| ```EPG2XML_FROM```  | wonipapa님의 개발 중단으로 인해 각자 도생하고 있는 현재의 상황에 보다 유연하게 대응하고자 어디서 가져올 것인지 ```EPG2XML_FROM="wiserain"```을 통해서 지정할 수 있다. 정확하게는 ```git clone https://github.com/${EPG2XML_FROM}/epg2xml.git``` 명령어로 가져온다.   | ```wiserain```  |
| ```EPG2XML_VER```  | master가 아닌 특정 commit나 branch의 버전을 사용하고자 할 경우 입력한다. ```git checkout ${BRANCH or SHA1}```   | ```null```  |
| ```UPDATE_EPG2XML```  | epg2xml을 업데이트 하고 싶지 않다면 ```1```이 아닌 값을 입력한다. ```epg2xml.json```은 이 값에 관계없이 파일이 없을때만 설치한다. | ```1```  |
| ```CHANNEL_FROM```  | epg2xml 스크립트와 마찬가지로 Channel.json을 어디에서 가져올지 지정할 수 있다. | ```wonipapa```  |
| ```UPDATE_CHANNEL```  | 채널 정보를 담고 있는 ```Channel.json``` 파일을 업데이트 한다. 더이상 업데이트 하지 않기를 원하면 ```1```이 아닌 값을 입력한다. | ```1```  |

추가로 사용 가능한 환경변수는 다음과 같다.

| 이름  | 설명  | 기본값 |
|---|---|---|
| ```RUN_OPTS```  | tvheadend 바이너리에 직접 전달되는 실행옵션. 대표적으로 tvheadend의 동작 포트를 바꿀때 쓸 수 있다. ```--http_port <port number> --htsp_port <port number>```   | ```null```  |
| ```TVH_DVB_SCANF_PATH```  | TVH 일반 설정 가운데 DVB 스캔 파일 경로를 컨테이너 시작할 때 지정한다. 이 경로를 기준으로 볼륨 매핑 ```-v /my/scan/folder:/usr/share/tvheadend/data/dvb-scan/atsc:ro```을 하면 ```/my/scan/folder``` 폴더에 있는 자신만의 주파수 설정 파일을 이용해서 스캔할 수 있다.  | ```/usr/share/tvheadend/data/dvb-scan/```  |
| ```TVH_UI_LEVEL```  | TVH 일반 설정 가운데 보기 옵션. 전문가 수준으로.  | ```2```  |


## 어쩌면 도움이 될지도 모르는 정보

1.  컨테이너를 시작할 때마다 ```/etc/cont-init.d/``` 안의 스크립트를 이용해서 초기화를 진행하고 ```/etc/services.d/```안의 서비스를 실행한다. 무슨 일이 일어났는지 궁금하거나 생각대로 되지 않으면 로그를 확인하자.
2.  ~~epg2xml 동작 언어는 php이다. 성능은 python이 약간 좋지만 그 차이가 미미한 반면, docker로 deploy할 때 php가 꽤 유용한 기능을 제공한다.~~ epg2xml 동작 언어는 python3로 변경되었다.
3.  ```epg2xml.json```은 경로에 파일이 없는 경우에만 다운로드하여 설치하고 경로에 있으면 원래 것을 보존한다. 따라서 같이 업데이트하고 싶으면 파일들을 지우고 컨테이너 삭제/생성/실행하면 된다. 그것도 싫으면 그냥 수동으로 받아서 복사/붙여넣기 하면 된다.
4.  예전에는 내부적으로 epg2xml를 실행할 때 다음의 arguments ```-i {KT/SK/LG} -d```를 썼으나 이제는 ```-i {KT/SK/LG} -o /epg2xml/xmltv.xml```로 실행한 다음 ```cat /epg2xml/xmltv.xml```로 불러온다. 중간에 파일로 저장하는 과정이 추가된 것이다.
5.  EPG를 ```/epg2xml/xmltv.xml```에 한 번 저장하는 이유는 이 경로를 웹서버로 노출시켜 다른 앱에서도 가져다 쓰기 쉽게 하기 위함이다. php 내장 기능을 이용해 ```/epg2xml``` 폴더의 내용이 ```http://<tvheadend ip>:9983/```으로 서비스 되므로, tvheadend가 실행되면서 주기적으로 파일로 저장해 놓은 EPG 정보를 ```http://<<tvheadend ip>:9983/xmltv.xml```로 접속하여 쓸 수 있다. 원래는 Plex DVR를 위해 짜낸 기능이지만 여러모로 유용하게 사용할 수 있을 것이다.


## 자주 묻는 질문

[문제가 발생하면 읽어보세요.](https://github.com/wiserain/docker-tvheadend/blob/epgkr/assets/faqs.md)
