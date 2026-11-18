# Task for Copilot: Find the live disease-score calculation

I am working on the Agritalk backend that serves the Flutter app. Please trace where the disease risk score is calculated and identify how to add support for rice (稻米).

## Context from the Flutter app

- The guava disease page calls `fetchGroupScore` and `fetchGroupScoreHistory`.
- Those methods request these live API routes:
  - `/odata/api/v1-Odata/GroupDevices/score/`
  - `/odata/api/v1-Odata/GroupDevices/score_history/`
- The requests include `groupUUID`, `fruit`, and `disease`. The current guava page sends `fruit=番石榴` and disease names such as `介殼蟲` and `炭疽病`.
- The response score is read from the API response and plotted by the Flutter app. The Flutter chart does not calculate the score.
- The `backend/disease_api/app.py` in the Flutter project is a demo/local service, not the live Agritalk score backend. Do not make the requested score changes there unless you confirm this is the actual service handling these routes.

## Please investigate first

1. Find the route/controller that handles both score endpoints.
2. Follow the code to the service, model, query, scheduled job, or other component that creates the score. Determine whether the score is calculated on request or precomputed and stored.
3. Explain the current formula or data flow, including what `score` means, where its input data comes from, and how the history endpoint obtains historical scores.
4. Identify the relevant files and functions, and point out any tests or existing crop-specific implementations.
5. Check how the backend recognizes crop and disease names, and whether the requested values are validated or mapped to internal identifiers.

## Rice support

After locating the implementation, explain the smallest safe change needed to support rice (稻米), including the exact backend files and tests to update. Do not invent a formula or change existing crop behavior. If the rice scoring formula, required input data, or disease names are not defined in this repository, stop before implementing it and tell me exactly what information is needed.

If the formula and requirements are present, implement rice support consistently for both current scores and score history, preserve existing crops, and add or update focused tests. Run those tests and report the results.
