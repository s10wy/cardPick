Fastapi 가상환경 기반 가상은행서버

본 코드는 Fastapi 패키지 일부 설치가 필요함

은행 서버 키기: uvicorn main:app --reload --port 8001

각각 hana: 8001, kukmin: 8002, noori: 8003포트로 서버 오픈 


fast start guide
cd hana
python -m uvicorn main:app --host 127.0.0.1 --port 8001 --reload

cd .\kukmin\
python -m uvicorn main:app --host 127.0.0.1 --port 8002 --reload

cd .\noori\
python -m uvicorn main:app --host 127.0.0.1 --port 8003 --reload