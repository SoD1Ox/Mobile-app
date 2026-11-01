import os, sys
os.environ['DATABASE_URL'] = 'sqlite:////tmp/test_agency.db'
os.environ['SECRET_KEY'] = 'test-secret-key-long-enough-32-bytes!!'
sys.path.insert(0, '/workspace/backend')
os.chdir('/workspace/backend')

from app.db.vis import get_engine
from app.db.base import Base
import app.models.user, app.models.vacancy, app.models.candidate, app.models.application, app.models.company, app.models.skill
eng = get_engine()
Base.metadata.create_all(eng)
print('1. schema created OK')

from fastapi.testclient import TestClient
from app.main import app as fastapi_app
client = TestClient(fastapi_app)

r = client.post('/api/v1/auth/register', json={'username':'tester','email':'t@t.ru','full_name':'Test','password':'pass1234'})
print('3. register:', r.status_code, (str(r.json().get('detail','')) if r.status_code>=400 else 'OK'))

r = client.post('/api/v1/auth/login', json={'username':'tester','password':'pass1234'})
print('4. login tester:', r.status_code)
if r.status_code == 200:
    tok = r.json()['access_token']
    h = {'Authorization': 'Bearer ' + tok}
    for name, url in [('vacancies','/api/v1/vacancies?page=1&page_size=5'),
                      ('apps-mine','/api/v1/applications?mine=true&page_size=10'),
                      ('candidates','/api/v1/candidates?page=1&page_size=5')]:
        rr = client.get(url, headers=h)
        print('   ', name, rr.status_code)
    codes = [client.post('/api/v1/auth/login', json={'username':'x','password':'y'}).status_code for _ in range(8)]
    print('8. rate-limit codes:', codes)
print('SMOKE DONE')
