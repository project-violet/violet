# This source code is a part of Project Violet.
# Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

# GCP에서 Bookmark Event 추출해서 Assets Update 해주는 스크립트

import json
import os
from datetime import datetime, timedelta

from google.cloud import bigquery

# pip install --upgrade google-api-python-client
# pip install google.cloud.bigquery
# https://cloud.google.com/docs/authentication/end-user
# gcloud auth application-default login

client = bigquery.Client()

# 최근 한 달 동안의 bookmark events를 추출한다.
timestamp = int((datetime.now() - timedelta(days=30)).timestamp() * 1000 * 1000)

query = f"""
SELECT
  param.value.string_value as article,
  COUNT(*) as count
FROM
  `real-violet-app.analytics_238885015.events_*`,
  UNNEST(event_params) AS param
WHERE
  event_name = 'bookmark_article'
  AND param.key = 'Article'
  AND event_timestamp >= {timestamp}
GROUP BY
  param.value.string_value
ORDER BY count DESC
"""

datas = []
for row in client.query_and_wait(query):
    data = {
        "article": row["article"],
        "count": row["count"],
    }
    datas.append(data)

print(len(datas))

filename = "assets/daily/bookmarks.json"
os.makedirs(os.path.dirname(filename), exist_ok=True)
with open(filename, "w") as file:
    file.write(json.dumps(datas))
