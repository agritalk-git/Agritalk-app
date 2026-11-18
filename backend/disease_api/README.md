# Local disease API

This Flask service is used by the disease-query pages while developing with the
Android emulator. The Flutter app's `.env` points to `http://10.0.2.2:10000`,
which Android maps to the development computer.

From the repository root, create a virtual environment, install the
dependencies, and start the service:

```powershell
py -m venv backend\disease_api\.venv
backend\disease_api\.venv\Scripts\python.exe -m pip install -r backend\disease_api\requirements.txt
backend\disease_api\.venv\Scripts\python.exe backend\disease_api\app.py
```

The service listens on port `10000`. Check that it is reachable by opening
`http://127.0.0.1:10000/` on the development computer; the response should
contain `"ok": true`.

The debug-probe route is disabled by default. This development server is not
intended to be exposed to the public internet.
